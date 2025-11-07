function a_5_epoch_timedomain(input_data_path, epoched_path, epoch_config, output_filename)
    % A_5_EPOCH_TIMEDOMAIN - Epoch the data for time domain HEP analysis
    %
    % This function performs epoching for Heartbeat Evoked Potentials (HEP) analysis.
    % It processes both premature contractions (PC) and control subjects with normal beats.
    %
    % Key steps:
    %   1. Loads preprocessed EEG data (with or without ICA) with reintegrated ECG channel
    %   2. Creates epochs around different heartbeat types (PAC, PVC, normal beats)
    %   3. Removes epochs marked as bad ECG artifacts
    %   4. Applies baseline correction with different options
    %   5. Handles overlapping epochs for preceding beats (PAC-1, PVC-1)
    %   6. Converts data to FieldTrip format for further analysis
    %   7. Computes time-locked averages for each beat type
    %   8. Generates grand averages across subjects
    %   9. Saves epoched data and analysis results
    %
    % Inputs:
    %   input_data_path    - Path to preprocessed data (with or without ICA) with reintegrated ECG (string)
    %   epoched_path       - Path for saving epoched data (string)
    %   epoch_config       - Structure containing epoching configuration:
    %       .error_log_path       - Path for saving error logs
    %       .epoch_length         - Time window for epochs [start, end] in ms
    %       .baseline_time        - Baseline time window [start, end] in ms
    %       .baseline_option      - Baseline option ('no', 'ref', 'int')
    %       .analysis_beat_types  - Cell array of beat types to analyze
    %       .subject_type         - 'PC' or 'control'
    %       .min_trials_required  - Minimum number of trials required
    %   output_filename    - Name of the output .mat file
    %
    % Outputs:
    %   - Epoched EEG data saved in epoched_path
    %   - HEP analysis results structure (allsubj_PC/allsubj_control) with grand averages
    %   - Processing logs and error logs
    %
    % Structure of saved variables:
    %   allsubj_PC.PAC/PVC.(beat_type) - Cell array of individual PC subjects
    %   allsubj_PC.PAC/PVC.grand_average.(beat_type) - Grand average across PC subjects
    %   allsubj_control.PAC/PVC.(beat_type) - Cell array of individual control subjects (separated by S/V prefix)
    %   allsubj_control.PAC/PVC.grand_average.(beat_type) - Grand average across control subjects
    %   allsubj_control.PC - Combined PAC+PVC control subjects for overall comparisons
    %
    % Beat type mapping:
    %   For PC subjects: PAC-4, PAC-3, PAC-2, PAC-1, iPAC, PAC+1, PAC+2, PAC+3, PAC+4
    %                   PVC-4, PVC-3, PVC-2, PVC-1, iPVC, PVC+1, PVC+2, PVC+3
    %   For control subjects: iN (isolated normal beats)
    %                        Control subjects are also separated into PAC (S-prefix) and PVC (V-prefix) groups
    %
    % Author: Pia Reinfeld

    %% Extract parameters from config
    error_log_path = epoch_config.error_log_path;
    epoch_length = epoch_config.epoch_length;
    baseline_time = epoch_config.baseline_time;
    baseline_option = epoch_config.baseline_option;
    analysis_beat_types = epoch_config.analysis_beat_types;
    subject_type = epoch_config.subject_type;
    min_trials_required = epoch_config.min_trials_required;

    eeg_channels_range = epoch_config.eeg_channels;

    fprintf('Starting epoching for time domain HEP analysis for %s subjects...\n', subject_type);

    files = find_files_by_extension(input_data_path, '*.set');

    if isempty(files)
        error('No .set files found in %s', input_data_path);
    end

    % Initialize results structure
    allsubj = struct();

    % Define beat types based on subject type and config
    if strcmp(subject_type, 'PC')
        % Use beat types from config (all analysis labels)
        beat_conditions = analysis_beat_types;

        % Separate PAC and PVC beat types
        pac_beats = beat_conditions(contains(beat_conditions, 'PAC'));
        pvc_beats = beat_conditions(contains(beat_conditions, 'PVC'));

        % Add iN beat type to both PAC and PVC groups
        % Ensure consistent dimensions (vertical concatenation for column vectors)
        pac_beats = [pac_beats; {'iN'}];
        pvc_beats = [pvc_beats; {'iN'}];

        condition_groups = {'PAC', 'PVC'}; % Groups for PAC and PVC beats
    elseif strcmp(subject_type, 'control')
        % For control subjects, only use iN beat, but separate into PAC and PVC groups
        % based on subject ID (S = PAC, V = PVC)
        beat_conditions = {'iN'};
        condition_groups = {'PAC', 'PVC'}; % Control subjects also separated by PAC/PVC
    else
        error('subject_type must be either "PC" or "control"');
    end

    % Initialize structure for each condition group
    for group_idx = 1:length(condition_groups)
        group = condition_groups{group_idx};
        allsubj.(group) = struct();

        % Initialize cell arrays for each beat type relevant to this group
        if strcmp(subject_type, 'PC')

            if strcmp(group, 'PAC')
                relevant_beat_types = pac_beats;
            elseif strcmp(group, 'PVC')
                relevant_beat_types = pvc_beats;
            end

        else % control
            % Control subjects also separated into PAC and PVC groups
            % Only iN beat type for both groups
            relevant_beat_types = beat_conditions; % just {'iN'}
        end

        for beat_idx = 1:length(relevant_beat_types)
            beat_type = relevant_beat_types{beat_idx};
            field_name = beattype_to_fieldname(beat_type);
            allsubj.(group).(field_name) = {};
        end

    end

    % Open log file
    log_file = fopen(fullfile(error_log_path, sprintf('a_4_timedomain_%s_log.txt', subject_type)), 'wt');

    % Configure fieldtrip baseline correction
    cfg_baseline = [];
    cfg_baseline.baseline = baseline_time / 1000; % Convert to seconds for fieldtrip

    % Store reference condition data for baseline correction (if needed)
    reference_baseline_data = struct();

    %% First pass: Process reference condition for baseline correction
    % This pass is only needed when baseline_option is 'ref' and only for PC subjects
    % Control subjects always use 'int' baseline regardless of baseline_option
    if strcmp(baseline_option, 'ref') && strcmp(subject_type, 'PC')
        fprintf('Computing reference condition for baseline correction...\n');

        for subj_idx = 1:length(files)
            filename = files(subj_idx).name;
            subjid = extract_subject_id(filename);

            % Use PC-3 as reference beat for PC subjects
            switch subjid(1)
                case 'S'
                    current_reference_beat = 'PAC-3';
                case 'V'
                    current_reference_beat = 'PVC-3';
                otherwise
                    fprintf('Warning: Could not determine condition for subject %s\n', subjid);
                    continue;
            end

            fprintf('  Processing reference %s for subject %s\n', current_reference_beat, subjid);

            try
                % Load EEG data
                EEG = pop_loadset('filename', filename, 'filepath', input_data_path);
                EEG = eeg_checkset(EEG);

                % Create epochs for reference condition
                EEG_ref = pop_epoch(EEG, {current_reference_beat}, epoch_length / 1000, 'epochinfo', 'yes');

                if EEG_ref.trials >= min_trials_required
                    EEG_ref = eeg_checkset(EEG_ref);

                    % Convert to fieldtrip and extract baseline values
                    data_ref = eeglab2fieldtrip(EEG_ref, 'preprocessing', 'chan_loc');
                    data_ref.fsample = EEG_ref.srate;

                    % Extract baseline period for PC-3 reference
                    cfg_baseline_extract = [];
                    cfg_baseline_extract.trials = 'all';
                    cfg_baseline_extract.toilim = baseline_time / 1000; % Convert to seconds for fieldtrip
                    data_bsl = ft_redefinetrial(cfg_baseline_extract, data_ref);

                    bsl = [];
                    % Calculate baseline value, i.e. the mean of the baseline period
                    for itrial = 1:size(data_bsl.trial, 2)
                        bsl{itrial} = mean(data_bsl.trial{itrial}, 2);
                    end

                    reference_baseline_data.(subjid) = bsl;
                    fprintf('    Reference %s computed for %s: %d trials\n', current_reference_beat, subjid, EEG_ref.trials);
                else
                    fprintf('    Warning: Subject %s has insufficient %s trials (%d) for reference\n', subjid, current_reference_beat, EEG_ref.trials);
                end

            catch ME
                fprintf('Error computing reference for subject %s: %s\n', subjid, ME.message);
            end

        end

    end

    %% Process each subject
    for subj_idx = 1:length(files)

        starttime = tic;
        filename = files(subj_idx).name;
        subjid = extract_subject_id(filename);

        fprintf('Processing subject %d/%d: %s\n', subj_idx, length(files), subjid);

        try
            % Load EEG data
            EEG = pop_loadset('filename', filename, 'filepath', input_data_path);
            EEG = eeg_checkset(EEG);

            % Determine condition from filename
            if strcmp(subject_type, 'PC')

                switch subjid(1)
                    case 'S'
                        current_group = 'PAC';
                        relevant_beats = pac_beats;
                    case 'V'
                        current_group = 'PVC';
                        relevant_beats = pvc_beats;
                    otherwise
                        error('Unknown subject prefix "%s" for PC subject %s. Expected "S" (PAC) or "V" (PVC).', subjid(1), subjid);
                end

            else % control
                % Control subjects also separated by PAC/PVC based on subject ID
                switch subjid(1)
                    case 'S'
                        current_group = 'PAC';
                    case 'V'
                        current_group = 'PVC';
                    otherwise
                        error('Unknown subject prefix "%s" for control subject %s. Expected "S" (PAC) or "V" (PVC).', subjid(1), subjid);
                end

                relevant_beats = {'iN'};
            end

            fprintf('  Subject group: %s\n', current_group);

            % Process each relevant beat type for this subject
            for beat_idx = 1:length(relevant_beats)
                beat_type = relevant_beats{beat_idx};
                field_name = beattype_to_fieldname(beat_type);

                % Create epochs for this beat type
                try
                    % Apply overlapping correction for iPAC and iPVC beats
                    if strcmp(beat_type, 'iPAC') || strcmp(beat_type, 'iPVC')
                        % Correction for overlapping preceding beats into premature beats
                        % by subtracting averaged HEP(iN) from PAC-1/PVC-1 time periods in continuous data
                        % and then building iPAC/iPVC epochs from the corrected continuous signal
                        % Note: Always using iN for overlapping correction, independent of reference_beat

                        % Compute iN HEP specifically for overlapping correction
                        EEG_iN = pop_epoch(EEG, {'iN'}, epoch_length / 1000, 'epochinfo', 'yes');

                        % Remove all epochs with overlapping beats and badECG
                        % Note: iN should not be in exclude_types since we're selecting iN epochs
                        exclude_types = [setdiff(pac_beats, {'iN'}); setdiff(pvc_beats, {'iN'}); {'badECG'}];

                        EEG_iN = pop_selectevent(EEG_iN, 'type', exclude_types, ...
                            'deleteevents', 'off', 'deleteepochs', 'on', 'invertepochs', 'on');

                        % Remove duplicate events in same epoch for iN (ensures isolated normal beats)
                        epochValues = [EEG_iN.event.epoch];
                        toKeep = true(size(epochValues));
                        uniqueEpochs = unique(epochValues);

                        % Only process duplicates if there are any
                        if length(epochValues) > length(uniqueEpochs)

                            for i = 1:length(uniqueEpochs)
                                epochIndex = find(epochValues == uniqueEpochs(i));

                                if length(epochIndex) > 1
                                    toKeep(epochIndex(2:end)) = false;
                                end

                            end

                        end

                        EEG_iN.event = EEG_iN.event(toKeep);

                        if EEG_iN.trials < min_trials_required
                            error('Subject %s has insufficient iN trials (%d) for overlapping correction of %s. At least %d trials required.', ...
                                subjid, EEG_iN.trials, beat_type, min_trials_required);
                        end

                        EEG_iN = eeg_checkset(EEG_iN);
                        data_iN = eeglab2fieldtrip(EEG_iN, 'preprocessing', 'chan_loc');
                        data_iN.fsample = EEG_iN.srate;
                        data_iN = ft_timelockbaseline(cfg_baseline, data_iN);

                        cfg_avg_iN = [];
                        cfg_avg_iN.channel = 'all';
                        cfg_avg_iN.latency = 'all';
                        cfg_avg_iN.parameter = 'avg';
                        cfg_avg_iN.keeptrials = 'no';

                        iN_HEP = ft_timelockanalysis(cfg_avg_iN, data_iN);

                        % Create correction matrix
                        EEG_correction = EEG;
                        EEG_correction.data = zeros(size(EEG.data));

                        % Find all PAC-1 or PVC-1 events and apply correction to their time periods
                        nevents = length(EEG.event);
                        epoch_samples = round(epoch_length * EEG.srate / 1000); % Convert to samples

                        % Determine the corresponding preceding beat type
                        switch beat_type
                            case 'iPAC'
                                preceding_beat_type = 'PAC-1';
                            case 'iPVC'
                                preceding_beat_type = 'PVC-1';
                        end

                        % Calculate artifical data with average of iN at epochs of PC-1 and
                        % otherwise zero for later subtraction from real EEG data
                        for event_idx = 1:nevents

                            if ischar(EEG.event(event_idx).type) && strcmp(EEG.event(event_idx).type, preceding_beat_type)
                                latency_sample = EEG.event(event_idx).latency;
                                start_sample = max(1, latency_sample + epoch_samples(1));
                                end_sample = min(size(EEG.data, 2), latency_sample + epoch_samples(2));

                                % Apply iN HEP subtraction to PAC-1/PVC-1 time periods
                                ref_start_idx = 1;
                                ref_end_idx = min(size(iN_HEP.avg, 2), end_sample - start_sample + 1);
                                data_start_idx = start_sample;
                                data_end_idx = start_sample + ref_end_idx - 1;

                                if data_end_idx <= size(EEG_correction.data, 2)
                                    EEG_correction.data(eeg_channels_range, data_start_idx:data_end_idx) = ...
                                        iN_HEP.avg(eeg_channels_range, ref_start_idx:ref_end_idx);
                                end

                            end

                        end

                        % Create corrected EEG data
                        EEG_corrected = EEG;
                        EEG_corrected.data(eeg_channels_range, :) = EEG.data(eeg_channels_range, :) - EEG_correction.data(eeg_channels_range, :);

                        % Epoch the corrected data around iPAC/iPVC events
                        EEG_epoch = pop_epoch(EEG_corrected, {beat_type}, epoch_length / 1000, 'epochinfo', 'yes');
                        fprintf('    Applied iN overlapping correction to %s time periods for %s epochs\n', preceding_beat_type, beat_type);

                    else

                        % Regular epoching for all other beat types
                        EEG_epoch = pop_epoch(EEG, {beat_type}, epoch_length / 1000, 'epochinfo', 'yes');
                    end

                    % Check if we have enough epochs
                    if EEG_epoch.trials < min_trials_required
                        fprintf('Warning: Subject %s has only %d trials for %s - skipping\n', ...
                            subjid, EEG_epoch.trials, beat_type);
                        continue;
                    end

                    EEG_epoch = eeg_checkset(EEG_epoch);

                    % Convert to fieldtrip format
                    data_ft = eeglab2fieldtrip(EEG_epoch, 'preprocessing', 'chan_loc');
                    data_ft.fsample = EEG_epoch.srate;

                    % Apply baseline correction based on option
                    switch baseline_option
                        case 'no'
                            % No baseline correction
                            data_processed = data_ft;
                        case 'ref'
                            % Apply baseline of PC-3 beat to all beats
                            % Control subjects and beat type 'iN' always use 'int' baseline regardless of baseline_option setting
                            if strcmp(subject_type, 'PC') && ~strcmp(beat_type, 'iN')
                                % Check if we have PC-3 baseline data for this subject
                                if isfield(reference_baseline_data, subjid)
                                    % Apply the PC-3 baseline to this beat type using apply_baseline function
                                    data_processed = apply_baseline(reference_baseline_data.(subjid), data_ft);
                                else
                                    % Determine which PC-3 type was expected
                                    switch subjid(1)
                                        case 'S'
                                            expected_reference = 'PAC-3';
                                        case 'V'
                                            expected_reference = 'PVC-3';
                                        otherwise
                                            expected_reference = 'PC-3';
                                    end

                                    error('Reference condition (%s) baseline not available for subject %s. Cannot apply baseline correction ''ref''.', expected_reference, subjid);
                                end

                            else
                                % Control subjects always use 'int' baseline (normal time-window baseline)
                                data_processed = ft_timelockbaseline(cfg_baseline, data_ft);
                            end

                        case 'int'
                            % Baseline to condition of interest (normal time-window baseline)
                            data_processed = ft_timelockbaseline(cfg_baseline, data_ft);
                        otherwise
                            error('Unknown baseline_option: %s', baseline_option);
                    end

                    % Compute time-locked average
                    cfg_avg = [];
                    cfg_avg.channel = 'all';
                    cfg_avg.latency = 'all';
                    cfg_avg.parameter = 'avg';
                    cfg_avg.keeptrials = 'no';

                    timelocked_data = ft_timelockanalysis(cfg_avg, data_processed);

                    % Store in results structure
                    allsubj.(current_group).(field_name){end + 1} = timelocked_data;

                    fprintf('  - Processed %s: %d trials\n', beat_type, EEG_epoch.trials);

                catch ME
                    error_msg = sprintf('Error processing %s for subject %s: %s', beat_type, subjid, ME.message);
                    fprintf('%s\n', error_msg);

                    % Write message to log file if file handle is valid
                    if log_file ~= -1
                        fprintf(log_file, '%s\n', error_msg);
                    end

                    % Break on critical errors to skip remaining beat types for this subject
                    if contains(ME.message, 'insufficient') || contains(ME.message, 'Reference condition')
                        break;
                    end

                end

            end

            % Log successful processing
            time_iteration = datestr(seconds(toc(starttime)), 'HH:MM:SS');

            if log_file ~= -1
                fprintf(log_file, 'Subject#: %d, %s, group: %s, time_iteration: %s\n', ...
                    subj_idx, subjid, current_group, time_iteration);
            end

        catch ME
            fprintf('Error processing subject %s: %s\n', subjid, ME.message);

            if log_file ~= -1
                fprintf(log_file, 'Error processing subject %s: %s\n', subjid, ME.message);
            end

        end

    end

    % After processing all subjects: Combine PAC and PVC fields into PC group
    % This applies to both PC and control subjects
    % Collect all unique beat type fields from PAC and PVC
    pac_fields = fieldnames(allsubj.PAC);
    pvc_fields = fieldnames(allsubj.PVC);
    all_fields = unique([pac_fields; pvc_fields]);
    allsubj.PC = struct();

    for f = 1:length(all_fields)
        field_name = all_fields{f};
        pac_data = {};
        pvc_data = {};

        if isfield(allsubj.PAC, field_name)
            pac_data = allsubj.PAC.(field_name);
        end

        if isfield(allsubj.PVC, field_name)
            pvc_data = allsubj.PVC.(field_name);
        end

        % Remove empty cells
        pac_data = pac_data(~cellfun('isempty', pac_data));
        pvc_data = pvc_data(~cellfun('isempty', pvc_data));
        allsubj.PC.(field_name) = [pac_data, pvc_data];
    end

    %% Save results
    % Use provided output filename
    output_path = fullfile(epoched_path, output_filename);

    try
        % Rename variable based on subject type before saving
        if strcmp(subject_type, 'PC')
            allsubj_PC = allsubj;
            save(output_path, 'allsubj_PC', '-v7.3');
        else
            allsubj_control = allsubj;
            save(output_path, 'allsubj_control', '-v7.3');
        end

        fprintf('Results saved to: %s\n', output_path);
    catch ME
        error_msg = sprintf('Error saving results: %s', ME.message);
        fprintf('%s\n', error_msg);

        % Write message to log file if file handle is valid
        if log_file ~= -1
            fprintf(log_file, '%s\n', error_msg);
        end

    end

    % Close log file
    if log_file ~= -1
        fclose(log_file);
    end

    fprintf('Time domain HEP analysis completed for %s subjects.\n', subject_type);

end
