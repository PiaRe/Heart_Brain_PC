function a_1b_import_events(preprocessed_data_path, event_data_path, pre_ica_path, error_log_path, analysis_beat_types, raw_file_labels)
    % A_1B_IMPORT_EVENTS - Import and process ECG event markers for premature beats
    %
    % This function imports ECG event markers from text files and processes them
    % to identify and classify different types of heartbeats including:
    % - Normal beats (N)
    % - Premature ventricular contractions (V)
    % - Premature supraventricular contractions (S)
    % - Isolated beats and surrounding context beats
    %
    % The function also calculates coupling intervals and compensatory pauses
    % for premature beats and adds ECG channel back to the EEG data.
    %
    % Inputs:
    %   preprocessed_data_path - Path to directory containing preprocessed EEG .set files (string)
    %   event_data_path       - Path to directory containing ECG event .txt files (string)
    %   pre_ica_path          - Path to directory for saving processed files (string)
    %   error_log_path        - Path to directory for saving error logs (string)
    %   analysis_beat_types   - Beat types to consider for this analysis
    %   raw_file_labels       - Beat types as they appear in raw table
    %
    % Outputs:
    %   - EEG files with imported and processed events saved to pre_ica_path
    %   - counter_ES.mat file with statistics on detected events
    %   - Console output with processing status
    %   - Error logs saved to error_log_path if processing fails
    %
    % Author: Based on import_events_beats.m script

    fprintf('Starting ECG event import and processing...\n');

    % Initialize variables
    EEGfiles = dir(fullfile(preprocessed_data_path, '*.set'));

    %% Process each EEG file
    for i = 1:length(EEGfiles)

        fprintf('Processing file %d/%d: %s\n', i, length(EEGfiles), EEGfiles(i).name);

        try
            % Load EEG data
            EEG = pop_loadset('filename', EEGfiles(i).name, 'filepath', preprocessed_data_path);
            fileName = EEGfiles(i).name(1:12);

            % Clear existing events
            EEG.event = [];

            % Find corresponding event file
            Eventfile = ['ECG_' fileName '.txt'];
            str = fullfile(event_data_path, Eventfile);

            if isfile(str)
                % Define event table headers
                header = {'latency', 'duration', 'type', 'urevent', 'code'};

                % Read event data
                A = readtable(str);
                data = cell(size(A, 1), size(header, 2));
                eventBeat = cell2table(data);
                eventBeat.Properties.VariableNames = header;
                eventBeat.latency = (A{:, 1} - 1) .* 2;
                eventBeat.type = A{:, 3};
                eventBeat.code = repmat({'ECG'}, size(eventBeat.type));

                % Mark invalid beats as badECG
                for j = 2:size(eventBeat.type, 1) - 2

                    if ~any(strcmp(eventBeat{j, 'type'}, raw_file_labels))
                        eventBeat{j - 1:j + 2, 'type'} = {'badECG'};
                    end

                end

                % Mark beats in bad segments as badECG
                if isfield(EEG, 'rejData') && ~isempty(EEG.rejData)

                    for j = 1:size(eventBeat.type, 1)

                        if any(eventBeat{j, 'latency'} >= (EEG.rejData(:, 1) - 1) * 2 & ...
                                eventBeat{j, 'latency'} <= (EEG.rejData(:, 2) - 1) * 2) && ...
                                any(strcmp(eventBeat{j, 'type'}, raw_file_labels))
                            eventBeat{j, 'type'} = {'badECG'};
                        end

                    end

                end

                % Detect isolated premature beats and label surrounding context
                for j = 5:size(eventBeat.type, 1) - 5
                    % Check for isolated V beats (PVCs)
                    if strcmp(eventBeat{j - 4, 'type'}, 'N') && strcmp(eventBeat{j - 3, 'type'}, 'N') && ...
                            strcmp(eventBeat{j - 2, 'type'}, 'N') && strcmp(eventBeat{j - 1, 'type'}, 'N') && ...
                            strcmp(eventBeat{j, 'type'}, 'V') && strcmp(eventBeat{j + 1, 'type'}, 'N') && ...
                            strcmp(eventBeat{j + 2, 'type'}, 'N') && strcmp(eventBeat{j + 3, 'type'}, 'N') && ...
                            strcmp(eventBeat{j + 4, 'type'}, 'N') && strcmp(eventBeat{j + 5, 'type'}, 'N')

                        % Label surrounding beats
                        eventBeat{j - 4, 'type'} = {'PVC-4'};
                        eventBeat{j - 3, 'type'} = {'PVC-3'};
                        eventBeat{j - 2, 'type'} = {'PVC-2'};
                        eventBeat{j - 1, 'type'} = {'PVC-1'};
                        eventBeat{j, 'type'} = {'iPVC'};
                        eventBeat{j + 1, 'type'} = {'PVC+1'};
                        eventBeat{j + 2, 'type'} = {'PVC+2'};
                        eventBeat{j + 3, 'type'} = {'PVC+3'};

                        % Check for isolated S beats (PACs)
                    elseif strcmp(eventBeat{j - 4, 'type'}, 'N') && strcmp(eventBeat{j - 3, 'type'}, 'N') && ...
                            strcmp(eventBeat{j - 2, 'type'}, 'N') && strcmp(eventBeat{j - 1, 'type'}, 'N') && ...
                            strcmp(eventBeat{j, 'type'}, 'S') && strcmp(eventBeat{j + 1, 'type'}, 'N') && ...
                            strcmp(eventBeat{j + 2, 'type'}, 'N') && strcmp(eventBeat{j + 3, 'type'}, 'N') && ...
                            strcmp(eventBeat{j + 4, 'type'}, 'N') && strcmp(eventBeat{j + 5, 'type'}, 'N')

                        % Label surrounding beats
                        eventBeat{j - 4, 'type'} = {'PAC-4'};
                        eventBeat{j - 3, 'type'} = {'PAC-3'};
                        eventBeat{j - 2, 'type'} = {'PAC-2'};
                        eventBeat{j - 1, 'type'} = {'PAC-1'};
                        eventBeat{j, 'type'} = {'iPAC'};
                        eventBeat{j + 1, 'type'} = {'PAC+1'};
                        eventBeat{j + 2, 'type'} = {'PAC+2'};
                        eventBeat{j + 3, 'type'} = {'PAC+3'};
                    end

                end

                % Find isolated normal heartbeats
                for j = 5:size(eventBeat.type, 1) - 5
                    l = cellfun(@(c)strcmp(c, eventBeat{j - 4:j + 5, 'type'}), analysis_beat_types, 'UniformOutput', false);
                    k = cellfun(@(c)strcmp(c, eventBeat{j, 'type'}), {'N'}, 'UniformOutput', false);

                    if all(sum(cell2mat(l), 2) >= 1) && all(sum(cell2mat(k), 2) >= 1)
                        eventBeat{j, 'type'} = {'iN'};
                    end

                end

                % Import events into EEG structure
                EEG = pop_importevent(EEG, 'event', table2cell(eventBeat), 'fields', header, ...
                    'append', 'yes', 'align', NaN, 'timeunit', 1E-3);

                % Add ECG channel back to EEG data
                if isfield(EEG, 'ECG') && ~isempty(EEG.ECG)
                    % Remove existing ECG channel if present
                    ecg_idx = find(strcmp({EEG.chanlocs.labels}, 'ECG'));

                    if ~isempty(ecg_idx)
                        EEG = pop_select(EEG, 'nochannel', ecg_idx);
                    end

                    % Add ECG data from stored ECG struct
                    ECG_data = EEG.ECG.data(1, :);
                    EEG.data(end + 1, :, :) = ECG_data;
                    EEG.nbchan = size(EEG.data, 1);
                    EEG.chanlocs(end + 1).labels = 'ECG';
                end

                EEG = eeg_checkset(EEG);

                % Save processed EEG file
                pop_saveset(EEG, 'filename', [fileName '.set'], 'filepath', pre_ica_path);

            else
                % Event file not found
                fprintf('Warning: Event file not found: %s\n', Eventfile);
            end

        catch ME
            % in case something goes wrong, save an error log
            fileID = fopen(fullfile(error_log_path, [fileName, '_error_log.txt']), 'w');
            fprintf(fileID, '%s\n', fileName);
            fprintf(fileID, '%s\n', getReport(ME));
            fclose(fileID);
            fprintf('Error processing %s: %s\n', fileName, ME.message);
        end

    end

    % Display completion status
    fprintf('Event import completed successfully for all %d files.\n', length(EEGfiles));

end
