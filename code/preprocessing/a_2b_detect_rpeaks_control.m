function a_2b_detect_rpeaks_control(preprocessed_data_path, output_path, rpeak_config)
    % A_2B_DETECT_RPEAKS_CONTROL - Detect R-peaks and add heartbeat events for control group
    %
    % This function detects R-peaks in ECG data for the control group where no
    % external ECG event files are available. It uses the ECG channel stored
    % in the EEG structure to perform automated R-peak detection and adds heartbeat
    % events to the EEG structure.
    %
    % The function classifies detected heartbeats as:
    % - iN (isolated normal beat): Normal beats surrounded by other normal beats
    % - badECG: Beats detected in bad data segments
    %
    % Inputs:
    %   preprocessed_data_path - Path to directory containing preprocessed EEG .set files (string)
    %   output_path           - Path to directory for saving processed files (string)
    %   rpeak_config          - Structure containing R-peak detection configuration:
    %       .error_log_path        - Path for saving error logs
    %       .sampling_rate         - Sampling rate of the data (Hz)
    %       .detection_method      - R-peak detection method ('heplab_slowdetect')
    %
    % Outputs:
    %   - EEG files with detected R-peak events saved to output_path
    %   - Console output with processing status
    %   - Error logs saved to error_log_path if processing fails
    %
    % Requirements:
    %   - EEGLAB toolbox
    %   - HEPLAB toolbox (for heplab_slowdetect function)
    %   - EEG.ECG field containing ECG data
    %
    % Author: Pia Reinfeld, Paul Steinfath
    % Date: October 2025

    fprintf('Starting R-peak detection for control group...\n');

    %% Extract parameters from config
    error_log_path = rpeak_config.error_log_path;
    sampling_rate = rpeak_config.sampling_rate;
    detection_method = rpeak_config.detection_method;

    % Initialize variables
    EEGfiles = dir(fullfile(preprocessed_data_path, '*.set'));

    if isempty(EEGfiles)
        error('No .set files found in %s', preprocessed_data_path);
    end

    fprintf('Found %d files to process\n', length(EEGfiles));

    %% Process each EEG file
    parfor i = 1:length(EEGfiles)

        fprintf('Processing file %d/%d: %s\n', i, length(EEGfiles), EEGfiles(i).name);

        try
            % Load EEG data
            EEG = pop_loadset('filename', EEGfiles(i).name, 'filepath', preprocessed_data_path);
            fileName = EEGfiles(i).name(1:12);

            % Check if ECG field exists
            if ~isfield(EEG, 'ECG') || isempty(EEG.ECG)
                error('ECG field not found or empty for file %s', fileName);
            end

            % Extract ECG data from ECG field
            ECG = EEG.ECG.data(1, :);

            % Detect R-peaks using specified method
            switch detection_method
                case 'heplab_slowdetect'
                    rPeaks = heplab_slowdetect(ECG, sampling_rate);
                otherwise
                    error('Unknown detection method: %s', detection_method);
            end

            fprintf('  Detected %d R-peaks for %s\n', length(rPeaks), fileName);

            % Add R-peak events to EEG structure
            for j = 1:length(rPeaks)

                % Check if R-peak falls in a bad data segment
                if isfield(EEG, 'rejData') && ~isempty(EEG.rejData)
                    is_bad = any(rPeaks(j) >= (EEG.rejData(:, 1) - 1) * 2 & ...
                        rPeaks(j) <= (EEG.rejData(:, 2) - 1) * 2);
                else
                    is_bad = false;
                end

                % Classify beat
                if is_bad
                    beat_type = 'badECG';
                else
                    beat_type = 'iN'; % Initially mark as isolated normal beat
                end

                % Add event to EEG structure
                EEG.event(end + 1).type = beat_type;
                EEG.event(end).latency = rPeaks(j);
                EEG.event(end).duration = 0;

            end

            EEG.ECG.event = EEG.event;
            % Verify EEG structure consistency
            EEG = eeg_checkset(EEG);

            % Save processed EEG file
            pop_saveset(EEG, 'filename', [fileName '.set'], 'filepath', output_path);

            fprintf('  Successfully saved %s with %d events\n', fileName, length(EEG.event));

        catch ME
            % Save error log
            fileID = fopen(fullfile(error_log_path, [fileName '_rpeak_error_log.txt']), 'w');
            fprintf(fileID, 'File: %s\n', fileName);
            fprintf(fileID, 'Error message: %s\n', ME.message);
            fprintf(fileID, 'Stack trace:\n%s\n', getReport(ME));
            fclose(fileID);
            fprintf('Error processing %s: %s\n', fileName, ME.message);
        end

    end

    % Display completion status
    fprintf('R-peak detection completed for all %d files.\n', length(EEGfiles));
    fprintf('Results saved to: %s\n', output_path);

end
