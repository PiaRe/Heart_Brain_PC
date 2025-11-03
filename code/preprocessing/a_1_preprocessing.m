function a_1_preprocessing(raw_data_path, preprocessed_data_path, prepro_config)
    % A_1_PREPROCESSING - Initial preprocessing and ICA
    %
    % This function performs the initial preprocessing steps including:
    % - Loading raw EEG data
    % - Downsampling
    % - Filtering
    % - Notch filtering
    % - Channel cleaning
    %
    % Inputs:
    %   raw_data_path         - Path to directory containing raw EEG files (string)
    %   preprocessed_data_path - Path to directory for saving preprocessed EEG files (string)
    %   prepro_config         - Structure containing preprocessing configuration:
    %       .crop_marker_path      - Path to crop marker files
    %       .error_log_path        - Path for error logs
    %       .sampling_rate         - Target sampling rate for downsampling
    %       .electrode_file        - Path to electrode montage file
    %       .high_cutoff       - High-frequency cutoff
    %       .low_cutoff            - Low-frequency cutoff
    %       .line_noise_frequency  - Line noise frequency for notch filtering
    %       .flatline_criterion    - Criterion for detecting flatline channels
    %       .artefact_thresh    - Threshold to exclude artifacts
    %
    % Author: Pia Reinfeld, Paul Steinfath

    fprintf('Starting initial preprocessing...\n');

    %% Extract parameters from config
    crop_marker_path = prepro_config.crop_marker_path;
    error_log_path = prepro_config.error_log_path;
    sampling_rate = prepro_config.sampling_rate;
    electrode_file = prepro_config.electrode_file;
    high_cutoff = prepro_config.high_cutoff;
    low_cutoff = prepro_config.low_cutoff;
    ecg_high_cutoff = prepro_config.ecg_high_cutoff;
    ecg_low_cutoff = prepro_config.ecg_low_cutoff;
    line_noise_frequency = prepro_config.line_noise_frequency;
    flatline_criterion = prepro_config.flatline_criterion;

    %% get files
    files = find_files_by_extension(raw_data_path, '*.vhdr');

    %% get (if any) already preprocessed filenames
    prepFiles = find_files_by_extension(preprocessed_data_path, '*.set');
    prepFileList = {prepFiles.name};

    %% preprocess data and save as set
    parfor i = 1:length(files) % TODO: change to parfor

        try

            % subject ID and name for saving
            subjid = extract_subject_id(files(i).name, '.vhdr');

            % if subject is already in prep - folder, skip it
            if any(strcmp(prepFileList, [subjid(1:12), '.set'])) % TODO: change
                continue
            end

            %% load data
            [EEG, ~] = pop_loadbv(raw_data_path, files(i).name);

            % keep subjid stored in EEG struct
            EEG.setname = subjid;

            % add montage EEG electrodes
            EEG = pop_chanedit(EEG, 'lookup', electrode_file);

            %% Separate filtering for EEG and ECG channels
            % Find channel indices
            ekg_idx = find(strcmp({EEG.chanlocs.labels}, 'EKG'));
            non_ekg_idx = setdiff(1:EEG.nbchan, ekg_idx);

            % Filter EEG and other channels (VEOG, HEOG)
            EEG_temp = pop_select(EEG, 'channel', non_ekg_idx);
            EEG_temp = pop_eegfiltnew(EEG_temp, 'hicutoff', high_cutoff, 'plotfreqz', 0);
            EEG_temp = pop_eegfiltnew(EEG_temp, 'locutoff', low_cutoff, 'plotfreqz', 0);

            % Notch filter for EEG data
            nf_low_cu = line_noise_frequency - 1;
            nf_high_cu = line_noise_frequency + 1;
            EEG_temp = pop_eegfiltnew(EEG_temp, 'locutoff', nf_low_cu, 'hicutoff', nf_high_cu, 'revfilt', 1, 'plotfreqz', 0);

            % Filter ECG separately with higher cutoff to preserve R-peak morphology
            EKG_temp = pop_select(EEG, 'channel', ekg_idx);
            EKG_temp = pop_eegfiltnew(EKG_temp, 'hicutoff', ecg_high_cutoff, 'plotfreqz', 0);
            EKG_temp = pop_eegfiltnew(EKG_temp, 'locutoff', ecg_low_cutoff, 'plotfreqz', 0);

            EKG_temp = pop_eegfiltnew(EKG_temp, 'locutoff', nf_low_cu, 'hicutoff', nf_high_cu, 'revfilt', 1, 'plotfreqz', 0);

            % Merge channels back together
            EEG.data = [EEG_temp.data; EKG_temp.data];
            EEG.chanlocs = [EEG_temp.chanlocs, EKG_temp.chanlocs];
            EEG.nbchan = length(EEG.chanlocs);

            %% Resample to sampling_rate
            EEG = pop_resample(EEG, sampling_rate);

            %% Apply crop markers if available
            % Look for crop marker file
            subjid_short = subjid(1:min(12, length(subjid)));
            crop_pattern = [subjid_short, '_Ruhe_Startmarker_S99*'];
            crop_files = dir(fullfile(crop_marker_path, crop_pattern));

            if ~isempty(crop_files)
                crop_file_path = fullfile(crop_marker_path, crop_files(1).name);
                EEG = apply_crop_markers(EEG, crop_file_path, error_log_path, subjid);
            end

            %% restore ECG and EOG channels
            % select ECG and EOG channels and save it in its own struct
            % inside EEG struct
            EEG.ECG = pop_select(EEG, 'channel', {'EKG'});
            EEG.VEOG = pop_select(EEG, 'channel', {'VEOG'});
            EEG.HEOG = pop_select(EEG, 'channel', {'HEOG'});
            EEG = pop_select(EEG, 'channel', 1:31);

            % keep backup for channel interpolation
            originalEEG = EEG;

            %% remove flat channels for both datasets
            EEG = clean_artifacts(EEG, 'ChannelCriterion', 'off', 'FlatlineCriterion', flatline_criterion, 'BurstCriterion', 'off', 'WindowCriterion', 'off');

            % store removed channels in EEG struct
            allchan = {originalEEG.chanlocs.labels};
            EEG.reject.removed_channels = allchan(~ismember({originalEEG.chanlocs.labels}, {EEG.chanlocs.labels}));

            %% interpolate both datasets
            EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');

            %% reject artifacts
            % mark artifacts that exceed threshold and remove them
            [EEG, rejData] = trimOutlier(EEG, 40, 500);
            EEG.rejData = rejData;

            if any(rejData ~= [1 1000])
                EEG = pop_select(EEG, 'nopoint', [rejData(:, 1) rejData(:, 2)]);
            end

            % save results
            pop_saveset(EEG, 'filename', subjid(1:12), 'filepath', preprocessed_data_path); % TODO:change

        catch ME
            % in case something goes wrong, save an error log
            fileID = fopen([error_log_path, subjid, '_error_log.txt'], 'w');
            fprintf(fileID, '%6s\n', subjid);
            fprintf(fileID, '%6s\n', getReport(ME));
            fclose(fileID);

        end

    end

    fprintf('Initial preprocessing completed.\n');

end
