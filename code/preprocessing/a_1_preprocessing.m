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
    %       .highpass_cutoff       - High-pass filter cutoff
    %       .lowpass_cutoff        - Low-pass filter cutoff
    %       .line_noise_frequency  - Line noise frequency for notch filtering
    %       .flatline_criterion    - Criterion for detecting flatline channels
    %       .artifact_threshold    - Threshold to exclude artifacts
    %
    % Author: Pia Reinfeld, Paul Steinfath

    fprintf('Starting initial preprocessing...\n');

    %% Extract parameters from config
    crop_marker_path = prepro_config.crop_marker_path;
    error_log_path = prepro_config.error_log_path;
    sampling_rate = prepro_config.sampling_rate;
    electrode_file = prepro_config.electrode_file;
    highpass_cutoff = prepro_config.highpass_cutoff;
    lowpass_cutoff = prepro_config.lowpass_cutoff;
    line_noise_frequency = prepro_config.line_noise_frequency;
    flatline_criterion = prepro_config.flatline_criterion;
    artifact_threshold = prepro_config.artifact_threshold;

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
            newID = [subjid '.set'];

            % if subject is already in prep - folder, skip it
            if any(strcmp(prepFileList, newID))
                continue
            end

            %% load data
            [EEG, ~] = pop_loadbv(raw_data_path, files(i).name);

            % keep subjid stored in EEG struct
            EEG.setname = subjid;

            % add montage EEG electrodes
            EEG = pop_chanedit(EEG, 'lookup', electrode_file);

            %% Filter EEG
            EEG = pop_eegfiltnew(EEG, 'hicutoff', highpass_cutoff, 'plotfreqz', 0);
            EEG = pop_eegfiltnew(EEG, 'locutoff', lowpass_cutoff, 'plotfreqz', 0);

            % Notch filter for main EEG data
            nf_lowpass_cu = line_noise_frequency - 1;
            nf_highpass_cu = line_noise_frequency + 1;
            EEG = pop_eegfiltnew(EEG, 'locutoff', nf_lowpass_cu, 'hicutoff', nf_highpass_cu, 'revfilt', 1, 'plotfreqz', 0);

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

            % %% run ICA
            % % get rank of the ICA data
            % dataRank = sum(eig(cov(double(EEG.data'))) > 1E-7);

            % % run extended infomax ICA
            % EEG_ica_result = pop_runica(EEG, 'icatype', 'runica', 'pca', dataRank, 'options', {'extended' 1});

            % % Transfer ICA results to the main EEG dataset
            % EEG.icawinv = EEG_ica_result.icawinv;
            % EEG.icasphere = EEG_ica_result.icasphere;
            % EEG.icaweights = EEG_ica_result.icaweights;
            % EEG.icachansind = EEG_ica_result.icachansind;

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
