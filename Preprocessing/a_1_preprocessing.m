function a_1_preprocessing(data_path, crop_path, save_path, error_path, fs, elecfile, ica_highpass_cu, ica_lowpass_cu, line_noise_f, flatline_crit, artefact_thresh)
    % A_1_PREPROCESSING - Initial preprocessing and ICA
    %
    % This function performs the initial preprocessing steps including:
    % - Loading raw EEG data
    % - Downsampling
    % - Filtering for ICA decomposition
    % - Notch filtering
    % - Channel cleaning
    % - ICA decomposition
    %
    % Inputs:
    %   data_path        - Path to directory containing raw EEG files (string)
    %   save_path         - Path to directory for saving preprocessed EEG files (string)
    %   error_path        - Path to directory containing error logs (string)
    %   fs               - Target sampling rate for downsampling (double)
    %   elecfile         - Path to electrode montage file (string)
    %   ica_highpass_cu  - High-pass filter cutoff for ICA preprocessing (double)
    %   ica_lowpass_cu   - Low-pass filter cutoff for ICA preprocessing (double)
    %   line_noise_f     - Line noise frequency for notch filtering (e.g., 50 Hz or 60 Hz) (double)
    %   flatline_crit    - Criterion for detecting flatline channels (double)
    %
    % Author: Pia Reinfeld

    fprintf('Starting initial preprocessing and ICA...\n');

    %% get files
    files = dir(fullfile(data_path, '*.vhdr'));

    %% get (if any) already preprocessed filenames
    prepFiles = dir(fullfile(save_path, '*.set'));
    prepFileList = {prepFiles.name};

    %% preprocess data and save as set
    for i = 1:length(files)

        try

            % subject ID and name for saving
            subjid = files(i).name(1:end - 5);
            newID = [subjid '.set'];

            % if subject is already in prep-folder, skip it
            if any(strcmp(prepFileList, newID))
                continue
            end

            % load data
            [EEG, com] = pop_loadbv(data_path, files(i).name);

            % keep subjid stored in EEG struct
            EEG.setname = files(i).name(1:end - 5);

            % add montage EEG electrodes
            EEG = pop_chanedit(EEG, 'lookup', elecfile);

            % High-pass Filter
            EEG = pop_eegfiltnew(EEG, 'hicutoff', ica_highpass_cu, 'plotfreqz', 0);
            % Low-pass Filter
            EEG = pop_eegfiltnew(EEG, 'locutoff', ica_lowpass_cu, 'plotfreqz', 0);

            % Notch filter for line-noise filtering
            nf_lowpass_cu = line_noise_f - 1;
            nf_highpass_cu = line_noise_f + 1;
            EEG = pop_eegfiltnew(EEG, 'locutoff', nf_lowpass_cu, 'hicutoff', nf_highpass_cu, 'revfilt', 1, 'plotfreqz', 0);

            % resample to fs
            EEG = pop_resample(EEG, fs);

            %% Apply crop markers if available
            % Look for crop marker file
            subjid_short = subjid(1:min(10, length(subjid)));
            crop_pattern = [subjid_short, '_Ruhe_Startmarker_S99*'];
            crop_files = dir(fullfile(crop_path, crop_pattern));

            if ~isempty(crop_files)
                crop_file_path = fullfile(crop_path, crop_files(1).name);
                EEG = apply_crop_markers(EEG, crop_file_path, error_path, subjid);
            end

            % select ECG and EOG channels and save it in its own struct
            % inside EEG struct
            EEG.ECG = pop_select(EEG, 'channel', {'EKG'});
            EEG.VEOG = pop_select(EEG, 'channel', {'VEOG'});
            EEG.HEOG = pop_select(EEG, 'channel', {'HEOG'});
            EEG = pop_select(EEG, 'channel', [1:31]);

            % keep backup for channel interpolation
            originalEEG = EEG;

            % remove flat channels
            EEG = clean_artifacts(EEG, 'ChannelCriterion', 'off', 'FlatlineCriterion', flatline_crit, 'BurstCriterion', 'off', 'WindowCriterion', 'off');

            % store removed channels in EEG struct
            allchan = {originalEEG.chanlocs.labels};
            EEG.reject.removed_channels = allchan(~ismember({originalEEG.chanlocs.labels}, {EEG.chanlocs.labels}));

            % interpolate
            EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
            eeg_checkset(EEG);

            % % mark artifacts that exceed threshold and remove them prior ICA
            % [EEG, rejData] = trimOutlier_adjust_new(EEG, artefact_thresh, 40, 500);
            % EEG.rejData = rejData;

            % % only reject data if rejData is not empty and has valid format
            % if ~isempty(rejData) && size(rejData, 2) >= 2 && size(rejData, 1) > 0
            %     % ensure rejData contains valid integer values
            %     rejData = round(rejData);
            %     rejData(rejData < 1) = 1;
            %     rejData(rejData > size(EEG.data, 2)) = size(EEG.data, 2);

            %     % reject artifacts
            %     EEG = pop_select(EEG, 'nopoint', [rejData(:, 1) rejData(:, 2)]);
            %     fprintf('Rejected %d artifact segments for subject %s\n', size(rejData, 1), subjid);
            % else
            %     fprintf('No artifacts detected for subject %s\n', subjid);
            % end

            % get rank of the data
            dataRank = sum(eig(cov(double(EEG.data'))) > 1E-7);

            % run extended infomax ICA
            EEG = pop_runica(EEG, 'icatype', 'runica', 'pca', dataRank, 'options', {'extended' 1});

            % save results
            pop_saveset(EEG, 'filename', subjid, 'filepath', save_path);

        catch ME
            % in case something goes wrong, save an error log
            fileID = fopen([error_path, subjid, '_error_log.txt'], 'w');
            fprintf(fileID, '%6s\n', subjid);
            fprintf(fileID, '%6s\n', getReport(ME));
            fclose(fileID);

        end

    end

    fprintf('Initial preprocessing and ICA completed.\n');

end
