function a_5_stats_timedomain(epochs_path, error_log_path, output_path, stats_config, input_filename, epochs_path_control)
    % A_5_STATS_TIMEDOMAIN - Statistical analysis of HEP in time domain
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
        group_select = stats_config.group_select;
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
        settings_path = stats_config.paths.settings_path;
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
        if is_pac_pvc_comparison
            output_filename = sprintf('stats_GroupComparison_%s_PACvsPVC.mat', beat_comparison);
            comparison_desc = sprintf('PAC vs PVC (%s beats)', beat_comparison);
        elseif is_control_analysis
            output_filename = sprintf('stats_GroupComparison_%s_%s_PCvsControl.mat', beat_type, beat_comparison);
            comparison_desc = sprintf('PC vs Control (%s beats)', beat_comparison);
        else
            output_filename = sprintf('stats_%s_%s_vs_%s.mat', beat_type, beat_comparison, beat_reference);
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

        save_cluster_specifications(stat, output_path, base_filename);

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
        error_msg = sprintf('Error in a_5_stats_timedomain: %s\n%s', ME.message, getReport(ME));
        fprintf('%s\n', error_msg);

        % Log error
        error_file = fullfile(error_log_path, sprintf('stats_timedomain_error_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
        fid = fopen(error_file, 'w');

        if fid > 0
            fprintf(fid, '%s\n', error_msg);
            fclose(fid);
        end

        rethrow(ME);
    end

end
