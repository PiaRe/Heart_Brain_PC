function a_4_reintegrate_ecg(post_ica_path, error_log_path)
    % A_4_REINTEGRATE_ECG - Reintegrate ECG channel into EEG data structure
    %
    % This function takes ICA-cleaned EEG data and reintegrates the ECG channel
    % that was previously stored separately in EEG.ECG.data back into the main
    % EEG.data matrix as a regular channel. This is necessary for subsequent
    % statistical analyses that need access to the ECG channel.
    %
    % The files are overwritten in place (no separate output directory).
    %
    % Inputs:
    %   post_ica_path   - Path to ICA-cleaned .set files (input and output)
    %   error_log_path  - Path for error logging
    %
    % Outputs:
    %   - EEG datasets with ECG channel reintegrated (.set files) overwritten in post_ica_path
    %   - Error logs in error_log_path (if errors occur)
    %
    % The ECG channel will be added as the last channel in EEG.data with
    % the label 'ECG'.
    %
    % CRITICAL: EEG.ECG.data MUST exist. If it doesn't, the script will abort with an error.
    %
    % Author: Pia Reinfeld
    % Date: October 2025

    fprintf('Starting ECG reintegration...\n');

    %% Get file names
    files = find_files_by_extension(post_ica_path, '*.set');

    if isempty(files)
        error('No .set files found in %s', post_ica_path);
    end

    %% Loop over subjects
    fprintf('Processing %d subjects...\n', length(files));

    parfor i = 1:length(files)

        try
            subjid = extract_subject_id(files(i).name);
            fprintf('Processing subject: %s\n', subjid);

            % Load ICA-cleaned data
            EEG = pop_loadset('filename', files(i).name, 'filepath', post_ica_path);
            EEG = eeg_checkset(EEG);

            % CRITICAL: Check if ECG data exists - MUST be present
            if ~isfield(EEG, 'ECG') || ~isfield(EEG.ECG, 'data') || isempty(EEG.ECG.data)
                error('Subject %s: CRITICAL ERROR - EEG.ECG.data does not exist or is empty! This is required for the analysis.', subjid);
            end

            % Remove existing ECG channel if present (shouldn't be, but check anyway)
            ecg_idx = find(strcmp({EEG.chanlocs.labels}, 'ECG'));

            if ~isempty(ecg_idx)
                fprintf('  Removing existing ECG channel at index %d\n', ecg_idx);
                EEG = pop_select(EEG, 'nochannel', ecg_idx);
                EEG = eeg_checkset(EEG);
            end

            % Get ECG data from stored ECG struct
            ECG_data = EEG.ECG.data(1, :);

            % Verify dimensions match
            if size(ECG_data, 2) ~= size(EEG.data, 2)
                error('Subject %s: ECG data length (%d) does not match EEG data length (%d)', ...
                    subjid, size(ECG_data, 2), size(EEG.data, 2));
            end

            % Add ECG data as new channel
            fprintf('  Adding ECG channel with %d samples\n', length(ECG_data));
            EEG.data(end + 1, :) = ECG_data;
            EEG.nbchan = size(EEG.data, 1);

            EEG.chanlocs(end + 1).labels = 'ECG';
            EEG.chanlocs(end).type = 'ECG';

            % Check dataset integrity
            EEG = eeg_checkset(EEG);

            % Verify ECG channel was added correctly
            ecg_idx_new = find(strcmp({EEG.chanlocs.labels}, 'ECG'));

            if isempty(ecg_idx_new)
                error('Subject %s: ECG channel was not added correctly', subjid);
            end

            fprintf('  ECG channel successfully added at index %d\n', ecg_idx_new);
            fprintf('  Total channels: %d\n', EEG.nbchan);

            % Save dataset with reintegrated ECG (overwrite in place)
            pop_saveset(EEG, 'filename', [subjid, '.set'], 'filepath', post_ica_path);
            fprintf('  Saved (overwritten): %s\n', subjid);

            % Delete old error logs if they exist
            old_error_file = [error_log_path, subjid, '_error_log_ecg_reintegration.txt'];

            if isfile(old_error_file)
                delete(old_error_file);
            end

        catch ME
            fprintf('ERROR processing subject %s: %s\n', subjid, ME.message);

            % Write error log
            error_file = [error_log_path, subjid, '_error_log_ecg_reintegration.txt'];
            fileID = fopen(error_file, 'w');

            if fileID > 0
                fprintf(fileID, 'Subject: %s\n', subjid);
                fprintf(fileID, 'Error: %s\n', ME.message);
                fprintf(fileID, '\nFull error report:\n');
                fprintf(fileID, '%s\n', getReport(ME));
                fclose(fileID);
            end

        end

    end

    fprintf('ECG reintegration completed.\n');

end
