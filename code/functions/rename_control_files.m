%% RENAME_CONTROL_FILES - Rename control files from C_ to S_ or V_ based on matching
%
% This helper script renames existing control files that were copied with
% 'C_' prefix to the correct group prefix ('S_' or 'V_') based on the
% matched pairs CSV file.
%
% Author: Pia Reinfeld

clear; clc; close all;

%% Load configuration
config = setup_project_config();

%% File paths
matchedPairsFile = '/data/hu_reinfeld/Desktop/OwnProjects.lnk/HEP_ES/Heart_Brain_PC/data/matching/matched_pairs_pc_controls.csv';

% Directories to process
dirsToProcess = {
                 config.paths.raw_control_data;
                 config.paths.no_ica_control_path;
                 };

% Log file
logFile = [config.paths.error_log_path, 'rename_control_files_log.txt'];

%% Read matched pairs CSV file
fprintf('Reading matched pairs file...\n');

try
    T_matched = readtable(matchedPairsFile, 'Delimiter', ',');
    fprintf('Successfully loaded %d matched pairs.\n', height(T_matched));
catch ME
    fprintf('Error reading matched pairs file: %s\n', ME.message);
    return;
end

% Extract healthy subject IDs and corresponding groups
healthyIDs = T_matched.ID_healthy;
esGroups = T_matched.Group;

% Create lookup map: healthyID -> group
lookupMap = containers.Map(healthyIDs, esGroups);

fprintf('Created lookup map for %d healthy subjects.\n', length(healthyIDs));

%% Initialize logging
if ~exist(config.paths.error_log_path, 'dir')
    mkdir(config.paths.error_log_path);
end

fileID = fopen(logFile, 'w');
fprintf(fileID, 'Control files rename log - %s\n', char(datetime('now')));
fprintf(fileID, '================================\n\n');

%% Process each directory
totalRenamed = 0;
totalErrors = 0;

for dirIdx = 1:length(dirsToProcess)
    currentDir = dirsToProcess{dirIdx};

    if ~exist(currentDir, 'dir')
        fprintf('Directory does not exist: %s (skipping)\n', currentDir);
        fprintf(fileID, 'SKIPPED: Directory does not exist: %s\n', currentDir);
        continue;
    end

    fprintf('\n=== Processing directory: %s ===\n', currentDir);
    fprintf(fileID, '\n=== Processing directory: %s ===\n', currentDir);

    % Find all files starting with 'C_'
    allFiles = dir(fullfile(currentDir, 'C_*'));
    fprintf('Found %d files with C_ prefix.\n', length(allFiles));

    renamedCount = 0;
    errorCount = 0;

    for i = 1:length(allFiles)
        oldFileName = allFiles(i).name;

        % Extract subject ID from filename
        % Format: C_LI########_Ruhe.ext or C_LI########.ext
        % ID format: LI followed by digits and optionally X (e.g., LI00107379, LI0047101X)
        tokens = regexp(oldFileName, 'C_(LI\d+X?)[\._]', 'tokens');

        if isempty(tokens)
            fprintf('Warning: Could not extract subject ID from: %s\n', oldFileName);
            fprintf(fileID, 'WARNING: Could not extract subject ID from: %s\n', oldFileName);
            errorCount = errorCount + 1;
            continue;
        end

        subjID = tokens{1}{1}; % Lookup the group for this subject

        if isKey(lookupMap, subjID)
            matchedGroup = lookupMap(subjID);

            % Determine new prefix
            if strcmp(matchedGroup, 'SV')
                newPrefix = 'S_';
            elseif strcmp(matchedGroup, 'V')
                newPrefix = 'V_';
            else
                fprintf('Warning: Unknown group "%s" for subject %s\n', matchedGroup, subjID);
                fprintf(fileID, 'WARNING: Unknown group "%s" for subject %s\n', matchedGroup, subjID);
                errorCount = errorCount + 1;
                continue;
            end

            % Create new filename
            newFileName = strrep(oldFileName, 'C_', newPrefix);

            % Full paths
            oldFilePath = fullfile(currentDir, oldFileName);
            newFilePath = fullfile(currentDir, newFileName);

            % Check if target file already exists
            if exist(newFilePath, 'file')
                fprintf('Warning: Target file already exists: %s (skipping)\n', newFileName);
                fprintf(fileID, 'WARNING: Target file already exists: %s (skipping)\n', newFileName);
                errorCount = errorCount + 1;
                continue;
            end

            % Rename the file
            try
                movefile(oldFilePath, newFilePath);
                fprintf('Renamed: %s -> %s (Group: %s)\n', oldFileName, newFileName, matchedGroup);
                fprintf(fileID, 'SUCCESS: %s -> %s (Group: %s)\n', oldFileName, newFileName, matchedGroup);
                renamedCount = renamedCount + 1;
            catch ME
                fprintf('Error renaming %s: %s\n', oldFileName, ME.message);
                fprintf(fileID, 'ERROR renaming %s: %s\n', oldFileName, ME.message);
                errorCount = errorCount + 1;
            end

        else
            fprintf('Warning: Subject %s not found in matched pairs table (file: %s)\n', subjID, oldFileName);
            fprintf(fileID, 'WARNING: Subject %s not found in matched pairs table (file: %s)\n', subjID, oldFileName);
            errorCount = errorCount + 1;
        end

    end

    fprintf('Directory summary: %d files renamed, %d errors\n', renamedCount, errorCount);
    fprintf(fileID, 'Directory summary: %d files renamed, %d errors\n\n', renamedCount, errorCount);

    totalRenamed = totalRenamed + renamedCount;
    totalErrors = totalErrors + errorCount;
end

%% Final summary
fprintf(fileID, '\n================================\n');
fprintf(fileID, 'FINAL SUMMARY:\n');
fprintf(fileID, 'Total files renamed: %d\n', totalRenamed);
fprintf(fileID, 'Total errors: %d\n', totalErrors);
fprintf(fileID, 'Directories processed: %d\n', length(dirsToProcess));

fclose(fileID);

fprintf('\n=== RENAME OPERATION COMPLETE ===\n');
fprintf('Total files renamed: %d\n', totalRenamed);
fprintf('Total errors: %d\n', totalErrors);
fprintf('Log file saved to: %s\n', logFile);

if totalErrors > 0
    fprintf('\nSome errors occurred. Check the log file for details.\n');
end
