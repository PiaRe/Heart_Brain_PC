%% COPY_SUBJECT_FILES - Copy EEG files based on subject list
%
% This script reads a CSV file with subject information, extracts subject IDs,
% searches for corresponding .eeg files in multiple directories, and copies
% them to a target directory.
%
% Author: Pia Reinfeld

clear; clc; close all;

%% File paths
csvFile = '/data/hu_reinfeld/Desktop/HEP_ES.lnk/additional/SubjList_103subj.csv';
targetDir = '/data/pt_02778/HEP_ES/Heart_Brain_PC/final/raw/';
markerTargetDir = '/data/pt_02778/HEP_ES/Heart_Brain_PC/final/raw/crop_marker/';

% Search directories for EEG files
searchDirs = {
              '/data/pt_02035/Data/eeg_data/ruhe/',
              '/data/p_02035/Missing_files/fehlende_Daten/',
              '/data/p_02035/Data/esf_data_2014-08-21/EEG/Ruhe/'
              };

% Marker files directory
markerDir = '/data/pt_02584/Patty/premature_beats/eeg_marker_files/';

% Log file for errors and status
logFile = '/data/pt_02778/HEP_ES/Heart_Brain_PC/final/Logfiles/copy_files_log.txt'; % % Read CSV file
fprintf('Reading subject list from CSV file...\n');

try
    T = readtable(csvFile, 'Delimiter', ',');
    fprintf('Successfully loaded %d subjects from CSV file.\n', height(T));
catch ME
    fprintf('Error reading CSV file: %s\n', ME.message);
    return;
end

%% Extract subject IDs from ECG filenames
% Extract ID from ECG_subjnum_file column (format: ECG_LI########_Ruhe.hea.csv)
subjectIDs = cell(height(T), 1);

for i = 1:height(T)
    filename = T.ECG_subjnum_file{i};
    % Extract ID between 'ECG_' and '_Ruhe'
    if contains(filename, 'ECG_') && contains(filename, '_Ruhe')
        startIdx = strfind(filename, 'ECG_') + 4;
        endIdx = strfind(filename, '_Ruhe') - 1;

        if ~isempty(startIdx) && ~isempty(endIdx) && endIdx > startIdx
            subjectIDs{i} = filename(startIdx:endIdx);
        else
            subjectIDs{i} = '';
        end

    else
        subjectIDs{i} = '';
    end

end

% Remove empty IDs
validIdx = ~cellfun(@isempty, subjectIDs);
subjectIDs = subjectIDs(validIdx);
groups = T.group(validIdx);

fprintf('Extracted %d valid subject IDs.\n', length(subjectIDs));

%% Initialize logging
fileID = fopen(logFile, 'w');
fprintf(fileID, 'File copy log - %s\n', datestr(now));
fprintf(fileID, '================================\n\n');

%% Search and copy files
filesFound = 0;
filesNotFound = 0;
filesCopied = 0;
markersFound = 0;
markersNotFound = 0;
markersCopied = 0;

for i = 1:length(subjectIDs)
    subjID = subjectIDs{i};
    group = groups{i};
    fileFound = false;

    fprintf('Processing subject %d/%d: %s (Group: %s)\n', i, length(subjectIDs), subjID, group);

    % Search through all directories
    for dirIdx = 1:length(searchDirs)
        currentDir = searchDirs{dirIdx};

        % Look for files matching the pattern: subjID_Ruhe.eeg
        searchPattern = fullfile(currentDir, [subjID, '_Ruhe.eeg']);
        files = dir(searchPattern);

        if ~isempty(files)
            % File found - copy it
            sourceFile = fullfile(currentDir, files(1).name);

            % Create target filename with group prefix
            if strcmp(group, 'SV')
                targetFileName = ['S_', files(1).name];
            elseif strcmp(group, 'V')
                targetFileName = ['V_', files(1).name];
            else
                targetFileName = files(1).name; % Keep original name if group unknown
            end

            targetFile = fullfile(targetDir, targetFileName);

            try
                % Copy the .eeg file
                copyfile(sourceFile, targetFile);

                % Also copy associated .vhdr and .vmrk files if they exist
                [~, baseName, ~] = fileparts(files(1).name);

                % Copy .vhdr file
                vhdrSource = fullfile(currentDir, [baseName, '.vhdr']);

                if exist(vhdrSource, 'file')
                    vhdrTarget = fullfile(targetDir, [targetFileName(1:end - 4), '.vhdr']);
                    copyfile(vhdrSource, vhdrTarget);
                end

                % Copy .vmrk file
                vmrkSource = fullfile(currentDir, [baseName, '.vmrk']);

                if exist(vmrkSource, 'file')
                    vmrkTarget = fullfile(targetDir, [targetFileName(1:end - 4), '.vmrk']);
                    copyfile(vmrkSource, vmrkTarget);
                end

                fprintf(fileID, 'SUCCESS EEG: %s -> %s (from %s)\n', subjID, targetFileName, currentDir);
                fileFound = true;
                filesCopied = filesCopied + 1;
                break; % Exit loop once file is found and copied

            catch ME
                fprintf(fileID, 'ERROR copying EEG %s: %s\n', subjID, ME.message);
                fprintf('Error copying EEG file for subject %s: %s\n', subjID, ME.message);
            end

        end

    end

    %% Search and copy marker files
    % Look for marker files matching the pattern: subjID_Ruhe_Startmarker_S99
    markerPattern = fullfile(markerDir, [subjID, '_Ruhe_Startmarker_S99*']);
    markerFiles = dir(markerPattern);
    markerFound = false;

    if ~isempty(markerFiles)
        % Marker file found - copy it
        markerSourceFile = fullfile(markerDir, markerFiles(1).name);

        % Create target filename with group prefix
        if strcmp(group, 'SV')
            markerTargetFileName = ['S_', markerFiles(1).name];
        elseif strcmp(group, 'V')
            markerTargetFileName = ['V_', markerFiles(1).name];
        else
            markerTargetFileName = markerFiles(1).name; % Keep original name if group unknown
        end

        markerTargetFile = fullfile(markerTargetDir, markerTargetFileName);

        try
            copyfile(markerSourceFile, markerTargetFile);
            fprintf(fileID, 'SUCCESS MARKER: %s -> %s\n', subjID, markerTargetFileName);
            markerFound = true;
            markersCopied = markersCopied + 1;

        catch ME
            fprintf(fileID, 'ERROR copying MARKER %s: %s\n', subjID, ME.message);
            fprintf('Error copying marker file for subject %s: %s\n', subjID, ME.message);
        end

    else
        fprintf(fileID, 'MARKER NOT FOUND: %s\n', subjID);
        fprintf('Marker file not found for subject: %s\n', subjID);
    end

    %% Update counters
    if fileFound
        filesFound = filesFound + 1;
    else
        filesNotFound = filesNotFound + 1;
        fprintf(fileID, 'EEG NOT FOUND: %s\n', subjID);
        fprintf('EEG file not found for subject: %s\n', subjID);
    end

    if markerFound
        markersFound = markersFound + 1;
    else
        markersNotFound = markersNotFound + 1;
    end

end

%% Summary
fprintf(fileID, '\n================================\n');
fprintf(fileID, 'SUMMARY:\n');
fprintf(fileID, 'Total subjects processed: %d\n', length(subjectIDs));
fprintf(fileID, 'EEG files found: %d\n', filesFound);
fprintf(fileID, 'EEG files not found: %d\n', filesNotFound);
fprintf(fileID, 'EEG files successfully copied: %d\n', filesCopied);
fprintf(fileID, 'Marker files found: %d\n', markersFound);
fprintf(fileID, 'Marker files not found: %d\n', markersNotFound);
fprintf(fileID, 'Marker files successfully copied: %d\n', markersCopied);

fclose(fileID);

fprintf('\n=== COPY OPERATION COMPLETE ===\n');
fprintf('Total subjects processed: %d\n', length(subjectIDs));
fprintf('EEG files found: %d\n', filesFound);
fprintf('EEG files not found: %d\n', filesNotFound);
fprintf('EEG files successfully copied: %d\n', filesCopied);
fprintf('Marker files found: %d\n', markersFound);
fprintf('Marker files not found: %d\n', markersNotFound);
fprintf('Marker files successfully copied: %d\n', markersCopied);
fprintf('Log file saved to: %s\n', logFile);

if filesNotFound > 0 || markersNotFound > 0
    fprintf('\nSome files were not found. Check the log file for details.\n');
end
