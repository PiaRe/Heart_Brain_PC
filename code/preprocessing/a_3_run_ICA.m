function a_3_run_ICA(no_ica_path, pre_ica_path, post_ica_path, ica_config)
    % A_3_RUN_ICA Remove ICA components based on various artifact criteria
    %
    % The function:
    %   1. Detects R-peaks for ECG component identification
    %   2. Identifies and removes ICA components related to:
    %      - Heart artifacts (ECG)
    %      - Muscle artifacts
    %      - Eye movements
    %      - Line noise
    %      - Channel noise
    %      - Other artifacts
    %   3. Generates quality assessment plots
    %   4. Saves cleaned datasets and error logs
    %
    % Inputs:
    %   no_ica_path           - Path to non-ICA datasets for copying ICA weights
    %   pre_ica_path          - Path to input .set files
    %   post_ica_path         - Path to save cleaned datasets
    %   ica_config            - Structure containing ICA configuration:
    %       .error_log_path        - Path to save error logs
    %       .qa_path               - Path to save quality assessment plots
    %       .analysis_window       - Window size for ICA analysis
    %       .thresholds            - Structure with artifact rejection thresholds:
    %           .ecg_std_deviation   - ECG component rejection threshold
    %           .ecg_correlation     - ECG component correlation threshold
    %           .muscle_artifact     - Muscle artifact rejection threshold
    %           .eye_artifact        - Eye movement artifact rejection threshold
    %           .line_noise          - Line noise rejection threshold
    %           .channel_noise       - Channel noise rejection threshold
    %           .other_artifact      - Other artifact rejection threshold
    %       .analysis_beat_types   - Beat types to consider for analysis
    %
    % Outputs:
    %   - Cleaned EEG datasets (.set files) in post_ica_path
    %   - Quality assessment plots (.png files) in qa_path:
    %     * Component topographies showing ECG and removed components
    %     * Power spectral density plots before and after ICA
    %     * Correlation plots between ECG and ICA components
    %     * Variance explained by each component
    %     * ECG artifact detection summary plots
    %   - Processing summary statistics
    %   - Error logs in error_log_path (if errors occur)
    %
    % Author: Paul Steinfath, Pia Reinfeld

    %% Extract parameters from config
    error_log_path = ica_config.error_log_path;
    qa_path = ica_config.qa_path;
    ica_analysis_window = ica_config.analysis_window;
    threshold_config = ica_config.thresholds;
    analysis_beat_types = ica_config.analysis_beat_types;

    eeg_channels = ica_config.eeg_channels;

    %% get file names
    files = find_files_by_extension(pre_ica_path, '*.set');

    %% get already processed data
    savefiles = find_files_by_extension(post_ica_path, '*.set');
    savefilesnames = {savefiles.name};

    %% Loop over subjects
    parfor i = 1:length(files)

        try
            subjid = extract_subject_id(files(i).name);

            % if subject exists, skip

            if any(strcmp(savefilesnames, [subjid, '.set']))
                continue
            end

            % create QA folders
            if ~isfolder([qa_path, subjid])
                mkdir([qa_path, subjid]);
            end

            % load data
            EEG_ICA = pop_loadset('filename', files(i).name, 'filepath', pre_ica_path);
            EEG = pop_loadset('filename', files(i).name, 'filepath', no_ica_path);

            %% Remove ECG channel if present in EEG data
            % Check if ECG channel exists in EEG_ICA and remove it
            %in theory this should not happen, no?
            ecg_chan_idx_ica = find(strcmp({EEG_ICA.chanlocs.labels}, 'ECG') | strcmp({EEG_ICA.chanlocs.labels}, 'EKG'));

            if ~isempty(ecg_chan_idx_ica)
                EEG_ICA = pop_select(EEG_ICA, 'nochannel', ecg_chan_idx_ica);
                fprintf('Subject %s: Removed ECG channel from EEG_ICA\n', subjid);
            end

            % Check if ECG channel exists in EEG and remove it
            ecg_chan_idx = find(strcmp({EEG.chanlocs.labels}, 'ECG') | strcmp({EEG.chanlocs.labels}, 'EKG'));

            if ~isempty(ecg_chan_idx)
                EEG = pop_select(EEG, 'nochannel', ecg_chan_idx);
                fprintf('Subject %s: Removed ECG channel from EEG\n', subjid);
            end

            %% Create ECG template before epoching
            all_analysis_beat_types = [analysis_beat_types; {'iN'}; {'N'}]; %this could go to the config file

            % Epoch ECG data to create template
            % EEG_ICA.ECG.event = EEG_ICA.event; % Copy events before epoching
            ECG_epoched = pop_epoch(EEG_ICA.ECG, all_analysis_beat_types, ica_analysis_window);
            ECG_epoched = pop_rmbase(ECG_epoched, [ica_analysis_window(1) 0]);
            ECG_template = mean(ECG_epoched.data, 3); % Create template from averaged epochs

            %% Epoch on R-Peaks
            % epoch data around all heartbeats
            EEG_ICA = pop_epoch(EEG_ICA, all_analysis_beat_types, ica_analysis_window);

            %% run ICA on epoched data

            % get rank of the ICA data
            dataRank = sum(eig(cov(double(EEG.data'))) > 1E-7);

            % run extended infomax ICA
            EEG_ICA = pop_runica(EEG_ICA, 'icatype', 'runica', 'pca', dataRank, 'options', {'extended' 1});
            EEG_ICA.icaact = (EEG_ICA.icaweights * EEG_ICA.icasphere) * EEG_ICA.data(EEG_ICA.icachansind, :);

            %% select ICA components

            % Select ICA components based on ECG template
            [EEG_ICA, cV, rejV] = ecg_ica_corr(EEG_ICA, ECG_template, all_analysis_beat_types, ica_analysis_window, threshold_config.ecg_std_deviation);

            % plot & save correlated ECG components
            plot_ecg_ica_comps(EEG_ICA, rejV, cV, [qa_path, subjid, '/'], subjid);
            close all

            % run IClabel for classification of components on continuous data
            EEG_ICA = pop_iclabel(EEG_ICA, 'default');

            %% Copy ICA components from epochend to continous data

            EEG.icawinv = EEG_ICA.icawinv;
            EEG.icasphere = EEG_ICA.icasphere;
            EEG.icaweights = EEG_ICA.icaweights;
            EEG.icachansind = EEG_ICA.icachansind;
            EEG.etc = EEG_ICA.etc;

            eeg_checkset(EEG);
            
            EEG.icaact = (EEG.icaweights * EEG.icasphere) * EEG.data(EEG.icachansind, :);

            %% Heart Components
            % Use correlation + ICLabel to find components
            % correlated with the ECG > ecg_correlation and not classified as brain by IClabel
            rej_heart_pos = find(rejV + (cV > threshold_config.ecg_correlation) == 2);
            rej_heart_pos_corr = rej_heart_pos(~(EEG_ICA.etc.ic_classification.ICLabel.classifications(rej_heart_pos, 1) > 0.99));
            EEG.etc.ic_remove.heart = rej_heart_pos_corr;

            %% Muscle, eye, line noise, channel noise and other Components
            % Add above threshold component idx to original set
            EEG.etc.ic_remove.muscle = find(EEG_ICA.etc.ic_classification.ICLabel.classifications(:, 2) >= threshold_config.muscle_artifact);
            EEG.etc.ic_remove.eye = find(EEG_ICA.etc.ic_classification.ICLabel.classifications(:, 3) >= threshold_config.eye_artifact);
            EEG.etc.ic_remove.LineNoise = find(EEG_ICA.etc.ic_classification.ICLabel.classifications(:, 5) >= threshold_config.line_noise);
            EEG.etc.ic_remove.ChannelNoise = find(EEG_ICA.etc.ic_classification.ICLabel.classifications(:, 6) >= threshold_config.channel_noise);
            EEG.etc.ic_remove.other = find(EEG_ICA.etc.ic_classification.ICLabel.classifications(:, 7) >= threshold_config.other_artifact);

            % save correlation and index of potential heart components
            EEG.etc.ECG.ic_ecg_corr = cV;
            EEG.etc.ECG.ic_ecg_corr_above_thres = rejV;

            % reject components
            reject = unique([EEG.etc.ic_remove.heart', EEG.etc.ic_remove.muscle', EEG.etc.ic_remove.eye', EEG.etc.ic_remove.LineNoise', EEG.etc.ic_remove.ChannelNoise', EEG.etc.ic_remove.other']);
            EEGclean = pop_subcomp(EEG, reject);
            EEGclean = eeg_checkset(EEGclean);

            % save cleaned dataset
            EEGclean = pop_saveset(EEGclean, 'filename', subjid, 'filepath', post_ica_path);

            %% Some quality assessment (QA) Plots

            % Plot spectogram (using configured EEG channels)
            figure; plot_spec(EEGclean.data(eeg_channels, :)', EEG.srate, 'f_max', 70);
            saveas(gcf, [qa_path, subjid, '/', subjid, '_PSD_post_ICA.png'], 'png');

            % pre-clean PSD
            figure; plot_spec(EEG.data(eeg_channels, :)', EEG.srate, 'f_max', 70);
            saveas(gcf, [qa_path, subjid, '/', subjid, '_PSD_pre_ICA.png'], 'png');

            % plot removed components
            pop_topoplot(EEG, 0, reject, subjid, [], 0, 'electrodes', 'on', 'iclabel', 'on', 'iclabel', 'on');
            saveas(gcf, [qa_path, subjid, '/', subjid, '_removed_components.png'], 'png');

            % plot all components
            pop_topoplot(EEG, 0, 1:size(EEG.icaact, 1), subjid, [], 0, 'electrodes', 'on', 'iclabel', 'on');
            saveas(gcf, [qa_path, subjid, '/', subjid, '_all_components.png'], 'png');

            % plot artefact components that have high probability to be brain activity
            brain_comps = reject(EEG.etc.ic_classification.ICLabel.classifications(reject, 1) > 0.995);

            if any(brain_comps)
                pop_topoplot(EEG, 0, brain_comps, subjid, [], 0, 'electrodes', 'on', 'iclabel', 'on');
                saveas(gcf, [qa_path, subjid, '/', subjid, '_potential_brain_components.png'], 'png');
            end

            % if Loop completed and previously a error log was created, delete the error log
            if isfile([error_log_path, subjid, '_error_log_ICA_comp_select.txt'])
                delete([error_log_path, subjid, '_error_log_ICA_comp_select.txt']);
            end

            close all;

        catch ME

            fileID = fopen([error_log_path, subjid, '_error_log_ICA_comp_select.txt'], 'w');
            fprintf(fileID, '%6s\n', subjid);
            fprintf(fileID, '%6s\n', getReport(ME));
            fclose(fileID);

        end

    end

end
