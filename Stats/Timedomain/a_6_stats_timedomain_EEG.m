function a_6_stats_timedomain_EEG(epochs_path, error_log_path, output_path, stats_config, input_filename, epochs_path_control)
    % A_6_STATS_TIMEDOMAIN_EEG - Statistical analysis of HEP in time domain
    %
    % This function performs statistical analysis of heartbeat evoked potentials
    % in the time domain using cluster-based permutation testing.
    %
    % Inputs:
    %   epochs_path         - Path to epoched data files (PC group or main data)
    %   error_log_path     - Path for error logging
    %   output_path        - Path for saving results
    %   stats_config       - Statistics configuration structure (config.stats)
    %   input_filename     - Name of the input file to load
    %   epochs_path_control - Optional: Path to control group data for group comparison
    %
    % The function loads epoched data, performs statistical comparisons based
    % on the configured parameters, and saves results.
    %
    % Author: Pia Reinfeld

    fprintf('Starting time domain statistical analysis...\n');

    try
        %% Extract configuration parameters
        beat_comparison = stats_config.beat_comparison;
        beat_reference = stats_config.beat_reference;

        % group_select is not needed for PAC vs PVC comparison
        if isfield(stats_config, 'group_select')
            group_select = stats_config.group_select;
        else
            group_select = 'N/A'; % For PAC vs PVC comparison
        end

        stat_params = stats_config.statistical_analysis;

        % Convert beat types to valid MATLAB field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        % Check if this is a control group comparison
        is_control_analysis = isfield(stats_config, 'is_control_analysis') && stats_config.is_control_analysis;

        % Check if this is a PAC vs PVC comparison
        is_pac_pvc_comparison = isfield(stats_config, 'is_pac_pvc_comparison') && stats_config.is_pac_pvc_comparison;

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group select: %s\n', group_select);
        fprintf('  Control analysis: %s\n', mat2str(is_control_analysis));
        fprintf('  PAC vs PVC comparison: %s\n', mat2str(is_pac_pvc_comparison));

        %% Load layout and neighbours for statistical analysis
        settings_path = stat_params.paths.settings_path;
        load(fullfile(settings_path, 'layout.mat'), 'layout');
        load(fullfile(settings_path, 'neighbours.mat'), 'neighbours');
        fprintf('Loaded layout and neighbours from: %s\n', settings_path);

        %% Setup paths and parameters

        full_data_path = fullfile(epochs_path, input_filename);

        if ~exist(full_data_path, 'file')
            error('Data file not found: %s', full_data_path);
        end

        % Load PC group data (variable is named allsubj_PC in the file)
        load(full_data_path, 'allsubj_PC');
        fprintf('Loaded PC group data from: %s\n', input_filename);

        % Load control group data if this is a control comparison
        if is_control_analysis

            if nargin < 6 || isempty(epochs_path_control)
                error('Control group path required for control analysis but not provided');
            end

            % Get control filename from config
            control_filename = stats_config.control_filename;

            control_file = fullfile(epochs_path_control, control_filename);

            if ~exist(control_file, 'file')
                error('Control group data file not found: %s', control_file);
            end

            % Load control group data
            load(control_file, 'allsubj_control');
            fprintf('Loaded control group data from: %s\n', control_filename);
        end

        % Select group data based on configuration
        % Note: allsubj_PC.PC contains combined PAC+PVC data from a_4_epoch_timedomain

        if is_pac_pvc_comparison
            % PAC vs PVC comparison: compare same beat type between PAC and PVC groups
            % Always compare PAC (comparison) vs PVC (reference)
            comparison_group_data = allsubj_PC.PAC; % PAC data
            reference_group_data = allsubj_PC.PVC; % PVC data

            comparison_data = comparison_group_data.(beat_comparison_field);
            reference_data = reference_group_data.(beat_reference_field);
            beat_type = 'PAC_vs_PVC';

        elseif is_control_analysis
            % Group comparison: PC/PAC/PVC iN beats vs Control group iN beats
            group_data = allsubj_PC.(group_select);
            comparison_data = group_data.(beat_comparison_field);
            reference_data = allsubj_control.control.(beat_reference_field);
            beat_type = group_select;

        else
            % Within-subject comparison (e.g., -3 vs +1)
            group_data = allsubj_PC.(group_select);
            comparison_data = group_data.(beat_comparison_field);
            reference_data = group_data.(beat_reference_field);
            beat_type = group_select;
        end

        % Prepare data for FieldTrip statistical analysis
        if isempty(comparison_data) || isempty(reference_data)
            error('No data found for the specified beat comparison or reference.');
        end

        %% Check if trial downsampling is needed
        % Downsample iN trials to match non-iN trial count if configured
        % This prevents trial count imbalance from affecting statistics

        downsample_enabled = false;

        if isfield(stat_params, 'downsample_iN_trials')
            downsample_enabled = stat_params.downsample_iN_trials;
        end

        downsampling_occurred = false;
        downsampling_info = struct();

        % Check if we're comparing iN with non-iN beats
        is_iN_comparison = strcmp(beat_comparison, 'iN');
        is_iN_reference = strcmp(beat_reference, 'iN');
        should_downsample = downsample_enabled && (is_iN_comparison || is_iN_reference) && ~(is_iN_comparison && is_iN_reference);

        if should_downsample
            fprintf('Trial downsampling enabled for iN vs non-iN comparison...\n');

            % Determine which condition has iN and which has non-iN
            if is_iN_comparison && ~is_iN_reference
                % comparison is iN, reference is not
                iN_data = comparison_data;
                non_iN_data = reference_data;
                iN_is_comparison = true;

            elseif ~is_iN_comparison && is_iN_reference
                % reference is iN, comparison is not
                iN_data = reference_data;
                non_iN_data = comparison_data;
                iN_is_comparison = false;
            end

            % Calculate target trial count (minimum across all subjects in non-iN condition)
            non_iN_trial_counts = zeros(length(non_iN_data), 1);

            for i = 1:length(non_iN_data)

                if isfield(non_iN_data{i}, 'trial')
                    non_iN_trial_counts(i) = size(non_iN_data{i}.trial, 1);
                end

            end

            % Also get iN trial counts for comparison
            iN_trial_counts = zeros(length(iN_data), 1);

            for i = 1:length(iN_data)

                if isfield(iN_data{i}, 'trial')
                    iN_trial_counts(i) = size(iN_data{i}.trial, 1);
                end

            end

            fprintf('  Original trial counts - iN: mean=%.1f, range=[%d-%d]\n', ...
                mean(iN_trial_counts), min(iN_trial_counts), max(iN_trial_counts));
            fprintf('  Original trial counts - non-iN: mean=%.1f, range=[%d-%d]\n', ...
                mean(non_iN_trial_counts), min(non_iN_trial_counts), max(non_iN_trial_counts));

            % Downsample iN trials to match non-iN for each subject
            downsampled_iN_data = cell(size(iN_data));
            subject_downsampling_info = struct();

            for i = 1:length(iN_data)
                target_n_trials = non_iN_trial_counts(i);

                [downsampled_iN_data{i}, was_ds, orig_n, final_n] = ...
                    downsample_trials_randomly(iN_data{i}, target_n_trials, i);

                % Store info for this subject
                subject_downsampling_info(i).subject_idx = i;
                subject_downsampling_info(i).was_downsampled = was_ds;
                subject_downsampling_info(i).original_n_trials = orig_n;
                subject_downsampling_info(i).final_n_trials = final_n;
                subject_downsampling_info(i).target_n_trials = target_n_trials;

                if was_ds
                    downsampling_occurred = true;
                end

            end

            % CRITICAL: Recalculate avg for downsampled data
            % The avg field was calculated with all trials in a_5_epoch_timedomain
            % We need to recalculate it with the downsampled trials
            fprintf('Recalculating averages for downsampled trials...\n');

            for i = 1:length(downsampled_iN_data)

                if ~isempty(downsampled_iN_data{i}) && isfield(downsampled_iN_data{i}, 'trial')
                    % Recalculate avg from downsampled trials
                    downsampled_iN_data{i}.avg = squeeze(mean(downsampled_iN_data{i}.trial, 1));
                    downsampled_iN_data{i}.dimord = 'chan_time';

                    fprintf('  Subject %d: Recalculated avg from %d downsampled trials\n', ...
                        i, subject_downsampling_info(i).final_n_trials);
                end

            end

            % Update the appropriate data variable with downsampled and recalculated data
            if iN_is_comparison
                comparison_data = downsampled_iN_data;
            else
                reference_data = downsampled_iN_data;
            end

            % Store overall downsampling info
            downsampling_info.enabled = true;
            downsampling_info.occurred = downsampling_occurred;

            if iN_is_comparison
                downsampling_info.iN_condition = 'comparison';
            else
                downsampling_info.iN_condition = 'reference';
            end

            downsampling_info.beat_comparison = beat_comparison;
            downsampling_info.beat_reference = beat_reference;
            downsampling_info.subject_details = subject_downsampling_info;

            fprintf('Trial downsampling and avg recalculation complete. Downsampling occurred: %s\n', mat2str(downsampling_occurred));

        else

            if downsample_enabled && is_iN_comparison && is_iN_reference
                fprintf('Trial downsampling disabled: both conditions are iN\n');
            elseif downsample_enabled
                fprintf('Trial downsampling disabled: neither condition is iN\n');
            else
                fprintf('Trial downsampling not enabled in config\n');
            end

            downsampling_info.enabled = false;
            downsampling_info.occurred = false;
            downsampling_info.reason = 'Not configured or not applicable';
        end

        %% Remove trial field if present (required for ft_timelockstatistics)
        fprintf('Preparing data for statistical analysis...\n');

        % Process comparison data - remove trial field
        for i = 1:length(comparison_data)

            if isfield(comparison_data{i}, 'trial')
                fprintf('  Removing trial field from comparison data subject %d\n', i);
                comparison_data{i} = rmfield(comparison_data{i}, 'trial');
            end

            % Also remove sampleinfo if present
            if isfield(comparison_data{i}, 'sampleinfo')
                comparison_data{i} = rmfield(comparison_data{i}, 'sampleinfo');
            end

        end

        % Process reference data - remove trial field
        for i = 1:length(reference_data)

            if isfield(reference_data{i}, 'trial')
                fprintf('  Removing trial field from reference data subject %d\n', i);
                reference_data{i} = rmfield(reference_data{i}, 'trial');
            end

            % Also remove sampleinfo if present
            if isfield(reference_data{i}, 'sampleinfo')
                reference_data{i} = rmfield(reference_data{i}, 'sampleinfo');
            end

        end

        fprintf('Data preparation complete.\n');

        %% Configure statistical analysis
        cfg = struct();
        cfg.parameter = stat_params.parameter;
        cfg.method = stat_params.method;
        cfg.statistic = stat_params.statistic;
        cfg.correctm = stat_params.correctm;
        cfg.clusteralpha = stat_params.clusteralpha;
        cfg.clusterstatistic = stat_params.clusterstatistic;
        cfg.minnbchan = stat_params.minnbchan;
        cfg.tail = stat_params.tail;
        cfg.clustertail = stat_params.clustertail;
        cfg.alpha = stat_params.alpha;
        cfg.numrandomization = stat_params.numrandomization;
        cfg.channel = stat_params.channel;
        cfg.latency = stat_params.latency;
        cfg.neighbours = neighbours;
        cfg.layout = layout;

        % Design matrix - different for independent vs dependent samples
        if is_control_analysis || is_pac_pvc_comparison
            % Independent samples t-test (PC vs Control OR PAC vs PVC)
            n_comp = length(comparison_data);
            n_ref = length(reference_data);
            cfg.design = [ones(1, n_comp), 2 * ones(1, n_ref)];
            cfg.ivar = 1; % Independent variable

            if is_pac_pvc_comparison
                fprintf('Design for independent samples (PAC vs PVC): %d PAC subjects, %d PVC subjects\n', n_comp, n_ref);
            else
                fprintf('Design for independent samples (PC vs Control): %d PC subjects, %d control subjects\n', n_comp, n_ref);
            end

        else
            % Dependent samples t-test (within-subject comparison)
            n_subj = length(comparison_data);
            cfg.design = [ones(1, n_subj), 2 * ones(1, n_subj); 1:n_subj, 1:n_subj];
            cfg.ivar = 1; % Independent variable (condition)
            cfg.uvar = 2; % Unit of observation variable (subject)
            fprintf('Design for dependent samples: %d subjects\n', n_subj);
        end

        %% Run statistical analysis
        fprintf('Running cluster-based permutation test...\n');
        [stat] = ft_timelockstatistics(cfg, comparison_data{:}, reference_data{:});

        %% Save results
        % Add suffix if downsampling was used
        downsample_suffix = '';

        if downsampling_info.occurred
            downsample_suffix = '_downsampled';
        end

        if is_pac_pvc_comparison
            output_filename = sprintf('stats_EEG_PACvsPVC_%s%s.mat', beat_comparison, downsample_suffix);
            comparison_desc = sprintf('PAC vs PVC (%s beats)', beat_comparison);
        elseif is_control_analysis
            output_filename = sprintf('stats_EEG_PCvsControl_%s_%s%s.mat', beat_type, beat_comparison, downsample_suffix);
            comparison_desc = sprintf('PC vs Control (%s beats)', beat_comparison);
        else
            output_filename = sprintf('stats_EEG_within_%s_%s_vs_%s%s.mat', beat_type, beat_comparison, beat_reference, downsample_suffix);
            comparison_desc = sprintf('%s vs %s', beat_comparison, beat_reference);
        end

        output_file_path = fullfile(output_path, output_filename);

        % Save statistical results and metadata
        save_data = struct();
        save_data.stat = stat;
        save_data.config_used = stats_config;
        save_data.comparison = comparison_desc;
        save_data.beat_type = beat_type;
        save_data.beat_comparison = beat_comparison;
        save_data.beat_reference = beat_reference;
        save_data.is_control_analysis = is_control_analysis;
        save_data.is_pac_pvc_comparison = is_pac_pvc_comparison;
        save_data.downsampling_info = downsampling_info;
        save_data.analysis_date = datestr(now);

        save(output_file_path, 'save_data');
        fprintf('Results saved to: %s\n', output_file_path);

        %% Display results summary
        if isfield(stat, 'posclusters') && ~isempty(stat.posclusters)
            sig_pos = find([stat.posclusters.prob] < stat_params.alpha);
            fprintf('Found %d significant positive clusters\n', length(sig_pos));
        end

        if isfield(stat, 'negclusters') && ~isempty(stat.negclusters)
            sig_neg = find([stat.negclusters.prob] < stat_params.alpha);
            fprintf('Found %d significant negative clusters\n', length(sig_neg));
        end

        %% Save cluster specifications
        fprintf('Saving cluster specifications...\n');
        base_filename = strrep(output_filename, '.mat', '');

        % Prepare metadata for CSV export
        metadata = struct();
        metadata.comparison_desc = comparison_desc;
        metadata.modality = 'EEG';
        metadata.beat_comparison = beat_comparison;
        metadata.beat_reference = beat_reference;
        metadata.beat_type = beat_type;
        metadata.n_subjects = length(comparison_data);
        metadata.analysis_date = datestr(now);

        % HEP/Preprocessing parameters from statistical_analysis config (inherited from base)
        if isfield(stat_params, 'hep_params')
            hep = stat_params.hep_params;
            metadata.baseline_option = hep.baseline_option;
            metadata.baseline_start = hep.baseline_time(1);
            metadata.baseline_end = hep.baseline_time(2);
            metadata.epoch_start = hep.epoch_length(1);
            metadata.epoch_end = hep.epoch_length(2);
            metadata.ica_status = hep.ica_status;
        end

        % Statistical parameters
        metadata.stat_method = stat_params.method;
        metadata.correctm = stat_params.correctm;
        metadata.alpha = stat_params.alpha;
        metadata.clusteralpha = stat_params.clusteralpha;
        metadata.numrandomization = stat_params.numrandomization;
        metadata.statistic = stat_params.statistic;
        metadata.latency_start = stat_params.latency(1);
        metadata.latency_end = stat_params.latency(2);

        % Downsampling information
        metadata.downsampling_enabled = downsampling_info.enabled;
        metadata.downsampling_occurred = downsampling_info.occurred;

        if isfield(downsampling_info, 'iN_condition')
            metadata.downsampling_iN_condition = downsampling_info.iN_condition;
        else
            metadata.downsampling_iN_condition = 'N/A';
        end

        save_cluster_specifications(stat, output_path, base_filename, metadata);

        %% Generate plots
        fprintf('Generating plots...\n');

        % Generate automatic labels
        [comparison_label, reference_label] = create_condition_labels(beat_comparison, beat_reference, ...
            group_select, is_control_analysis, is_pac_pvc_comparison);

        % Compute grand averages for plotting
        cfg_ga = [];
        cfg_ga.latency = stat_params.latency;
        cfg_ga.parameter = 'avg';
        cfg_ga.channel = {'all', '-ECG'};

        comparison_data_ga = ft_timelockgrandaverage(cfg_ga, comparison_data{:});
        reference_data_ga = ft_timelockgrandaverage(cfg_ga, reference_data{:});

        % Compute difference (for topoplots)
        cfg_diff = [];
        cfg_diff.operation = 'subtract';
        cfg_diff.parameter = 'avg';
        difference_data_ga = ft_math(cfg_diff, comparison_data_ga, reference_data_ga);

        % Get number of subjects for SEM calculation
        n_subjects = length(comparison_data);

        % Get time ROI for plotting
        time_roi_plot = stat_params.latency;

        % 1. Create multiplot with statistical results
        fprintf('  Creating multiplot...\n');
        plot_multiplot_stats(stat, comparison_data_ga, reference_data_ga, ...
            comparison_label, reference_label, layout, time_roi_plot, ...
            output_path, base_filename);

        % 2. Plot cluster-averaged ERPs for positive and negative clusters
        cluster_num = 1; % Default to first cluster

        if isfield(stats_config, 'cluster_num')
            cluster_num = stats_config.cluster_num;
        end

        fprintf('  Creating cluster-averaged plots...\n');
        % Positive clusters
        plot_cluster_averaged(stat, comparison_data_ga, reference_data_ga, ...
            comparison_label, reference_label, time_roi_plot, output_path, ...
            base_filename, 'pos', cluster_num, n_subjects);

        % Negative clusters
        plot_cluster_averaged(stat, comparison_data_ga, reference_data_ga, ...
            comparison_label, reference_label, time_roi_plot, output_path, ...
            base_filename, 'neg', cluster_num, n_subjects);

        % 3. Plot topographies for both cluster polarities
        fprintf('  Creating topographical plots...\n');
        % Positive clusters
        plot_topomap_comparison(stat, comparison_data_ga, reference_data_ga, ...
            difference_data_ga, comparison_label, reference_label, ...
            comparison_data_ga.time, output_path, base_filename, 'pos', cluster_num, layout);

        % Negative clusters
        plot_topomap_comparison(stat, comparison_data_ga, reference_data_ga, ...
            difference_data_ga, comparison_label, reference_label, ...
            comparison_data_ga.time, output_path, base_filename, 'neg', cluster_num, layout);

        fprintf('Plots completed successfully.\n');
        fprintf('Time domain statistical analysis completed successfully.\n');

    catch ME
        error_msg = sprintf('Error in a_6_stats_timedomain_EEG: %s\n%s', ME.message, getReport(ME));
        fprintf('%s\n', error_msg); % Log error
        error_file = fullfile(error_log_path, sprintf('stats_timedomain_error_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
        fid = fopen(error_file, 'w');

        if fid > 0
            fprintf(fid, '%s\n', error_msg);
            fclose(fid);
        end

        rethrow(ME);
    end

end
