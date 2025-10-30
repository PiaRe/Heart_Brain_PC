%% COPY_SUBJECT_FILES - Copy EEG files based on subject list
%
% This script reads a CSV file with subject information, extracts subject IDs,
% searches for corresponding .eeg files in multiple directories, and copies
% them to a target directory.
%
% Author: Pia Reinfeld

clear; clc; close all;

%% Load configuration
config = setup_project_config();

%% File paths
csvFile = '/data/hu_reinfeld/Desktop/HEP_ES.lnk/additional/SubjList_103subj.csv';
matchedPairsFile = '/data/hu_reinfeld/Desktop/OwnProjects.lnk/HEP_ES/Heart_Brain_PC/data/matching/matched_pairs_pc_controls.csv';

% Use paths from config
targetDir = config.paths.raw_pc_data;
markerTargetDir = config.paths.crop_marker_path;
controlTargetDir = config.paths.raw_control_data;

% Search directories for EEG files
searchDirs = {
              '/data/pt_02035/Data/eeg_data/ruhe/';
              '/data/p_02035/Missing_files/fehlende_Daten/';
              '/data/p_02035/Data/esf_data_2014-08-21/EEG/Ruhe/'
              };

% Marker files directory
markerDir = '/data/pt_02584/Patty/premature_beats/eeg_marker_files/';

% Log file for errors and status
logFile = [config.paths.error_log_path, 'copy_files_log.txt'];

%% Read CSV file
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

%% Create necessary directories
if ~exist(targetDir, 'dir')
    mkdir(targetDir);
    fprintf('Created directory: %s\n', targetDir);
end

if ~exist(markerTargetDir, 'dir')
    mkdir(markerTargetDir);
    fprintf('Created directory: %s\n', markerTargetDir);
end

if ~exist(config.paths.error_log_path, 'dir')
    mkdir(config.paths.error_log_path);
    fprintf('Created directory: %s\n', config.paths.error_log_path);
end

%% Initialize logging
fileID = fopen(logFile, 'w');
fprintf(fileID, 'File copy log - %s\n', char(datetime('now')));
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

        try
            copyfile(markerSourceFile, fullfile(markerTargetDir, markerTargetFileName));
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

%% ========================================================================
%% Part 2: Process Healthy Control Subjects from Matched Pairs
%% ========================================================================

fprintf('\n\n=== PROCESSING HEALTHY CONTROL SUBJECTS ===\n');

% Read matched pairs CSV file
try
    fprintf('Reading matched pairs file...\n');
    T_matched = readtable(matchedPairsFile, 'Delimiter', ',');
    fprintf('Successfully loaded %d matched pairs.\n', height(T_matched));
catch ME
    fprintf('Error reading matched pairs file: %s\n', ME.message);
    fprintf('Skipping healthy control subjects processing.\n');
    return;
end

% Extract healthy subject IDs
healthyIDs = T_matched.ID_healthy;
% Extract corresponding ES group (from ID_ES)
esIDs = T_matched.ID_ES;
esGroups = T_matched.Group;
fprintf('Extracted %d healthy subject IDs.\n', length(healthyIDs));

% Reopen log file in append mode
fileID = fopen(logFile, 'a');
fprintf(fileID, '\n\n================================\n');
fprintf(fileID, 'HEALTHY CONTROL SUBJECTS - %s\n', char(datetime('now')));
fprintf(fileID, '================================\n\n');

% Initialize counters for healthy subjects
controlFilesFound = 0;
controlFilesNotFound = 0;
controlFilesCopied = 0;
controlMarkersFound = 0;
controlMarkersNotFound = 0;
controlMarkersCopied = 0;

% Create target directories if they don't exist
if ~exist(controlTargetDir, 'dir')
    mkdir(controlTargetDir);
    fprintf('Created directory: %s\n', controlTargetDir);
end

% Process each healthy subject
for i = 1:length(healthyIDs)
    subjID = healthyIDs{i};
    matchedGroup = esGroups{i}; % Get the group of the matched ES subject
    fileFound = false;

    fprintf('Processing healthy subject %d/%d: %s (Matched to Group: %s)\n', i, length(healthyIDs), subjID, matchedGroup);

    % Search through all directories for EEG files
    for dirIdx = 1:length(searchDirs)
        currentDir = searchDirs{dirIdx};

        % Look for files matching the pattern: subjID_Ruhe.eeg
        searchPattern = fullfile(currentDir, [subjID, '_Ruhe.eeg']);
        files = dir(searchPattern);

        if ~isempty(files)
            % File found - copy it
            sourceFile = fullfile(currentDir, files(1).name);

            % Create target filename with group prefix matching the ES subject
            if strcmp(matchedGroup, 'SV')
                targetFileName = ['S_', files(1).name];
            elseif strcmp(matchedGroup, 'V')
                targetFileName = ['V_', files(1).name];
            else
                targetFileName = ['C_', files(1).name]; % Fallback to 'C_' if group unknown
            end

            targetFile = fullfile(controlTargetDir, targetFileName);

            try
                % Copy the .eeg file
                copyfile(sourceFile, targetFile);

                % Also copy associated .vhdr and .vmrk files if they exist
                [~, baseName, ~] = fileparts(files(1).name);

                % Copy .vhdr file
                vhdrSource = fullfile(currentDir, [baseName, '.vhdr']);

                if exist(vhdrSource, 'file')
                    vhdrTarget = fullfile(controlTargetDir, [targetFileName(1:end - 4), '.vhdr']);
                    copyfile(vhdrSource, vhdrTarget);
                end

                % Copy .vmrk file
                vmrkSource = fullfile(currentDir, [baseName, '.vmrk']);

                if exist(vmrkSource, 'file')
                    vmrkTarget = fullfile(controlTargetDir, [targetFileName(1:end - 4), '.vmrk']);
                    copyfile(vmrkSource, vmrkTarget);
                end

                fprintf(fileID, 'SUCCESS CONTROL EEG: %s -> %s (from %s)\n', subjID, targetFileName, currentDir);
                fileFound = true;
                controlFilesCopied = controlFilesCopied + 1;
                break; % Exit loop once file is found and copied

            catch ME
                fprintf(fileID, 'ERROR copying CONTROL EEG %s: %s\n', subjID, ME.message);
                fprintf('Error copying EEG file for healthy subject %s: %s\n', subjID, ME.message);
            end

        end

    end

    % Search and copy marker files for healthy subjects
    markerPattern = fullfile(markerDir, [subjID, '_Ruhe_Startmarker_S99*']);
    markerFiles = dir(markerPattern);
    markerFound = false;

    if ~isempty(markerFiles)
        % Marker file found - copy it
        markerSourceFile = fullfile(markerDir, markerFiles(1).name);

        % Create target filename with group prefix matching the ES subject
        if strcmp(matchedGroup, 'SV')
            markerTargetFileName = ['S_', markerFiles(1).name];
        elseif strcmp(matchedGroup, 'V')
            markerTargetFileName = ['V_', markerFiles(1).name];
        else
            markerTargetFileName = ['C_', markerFiles(1).name]; % Fallback to 'C_' if group unknown
        end

        try
            copyfile(markerSourceFile, fullfile(markerTargetDir, markerTargetFileName));
            fprintf(fileID, 'SUCCESS CONTROL MARKER: %s -> %s\n', subjID, markerTargetFileName);
            markerFound = true;
            controlMarkersCopied = controlMarkersCopied + 1;
        catch ME
            fprintf(fileID, 'ERROR copying CONTROL MARKER %s: %s\n', subjID, ME.message);
            fprintf('Error copying marker file for healthy subject %s: %s\n', subjID, ME.message);
        end

    else
        fprintf(fileID, 'CONTROL MARKER NOT FOUND: %s\n', subjID);
        fprintf('Marker file not found for healthy subject: %s\n', subjID);
    end

    % Update counters
    if fileFound
        controlFilesFound = controlFilesFound + 1;
    else
        controlFilesNotFound = controlFilesNotFound + 1;
        fprintf(fileID, 'CONTROL EEG NOT FOUND: %s\n', subjID);
        fprintf('EEG file not found for healthy subject: %s\n', subjID);
    end

    if markerFound
        controlMarkersFound = controlMarkersFound + 1;
    else
        controlMarkersNotFound = controlMarkersNotFound + 1;
    end

end

% Write summary for healthy controls
fprintf(fileID, '\n================================\n');
fprintf(fileID, 'HEALTHY CONTROLS SUMMARY:\n');
fprintf(fileID, 'Total healthy subjects processed: %d\n', length(healthyIDs));
fprintf(fileID, 'Control EEG files found: %d\n', controlFilesFound);
fprintf(fileID, 'Control EEG files not found: %d\n', controlFilesNotFound);
fprintf(fileID, 'Control EEG files successfully copied: %d\n', controlFilesCopied);
fprintf(fileID, 'Control marker files found: %d\n', controlMarkersFound);
fprintf(fileID, 'Control marker files not found: %d\n', controlMarkersNotFound);
fprintf(fileID, 'Control marker files successfully copied: %d\n', controlMarkersCopied);

fclose(fileID);

fprintf('\n=== HEALTHY CONTROL COPY OPERATION COMPLETE ===\n');
fprintf('Total healthy subjects processed: %d\n', length(healthyIDs));
fprintf('Control EEG files found: %d\n', controlFilesFound);
fprintf('Control EEG files not found: %d\n', controlFilesNotFound);
fprintf('Control EEG files successfully copied: %d\n', controlFilesCopied);
fprintf('Control marker files found: %d\n', controlMarkersFound);
fprintf('Control marker files not found: %d\n', controlMarkersNotFound);
fprintf('Control marker files successfully copied: %d\n', controlMarkersCopied);

if controlFilesNotFound > 0 || controlMarkersNotFound > 0
    fprintf('\nSome control files were not found. Check the log file for details.\n');
end

fprintf('\n=== ALL OPERATIONS COMPLETE ===\n');
fprintf('Log file saved to: %s\n', logFile);
