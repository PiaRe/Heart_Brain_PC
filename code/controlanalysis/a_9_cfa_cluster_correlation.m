function a_9_cfa_cluster_correlation(epochs_path, error_log_path, output_path, cfa_config, input_filename)
    % A_9_CFA_CLUSTER_CORRELATION - Cluster-based correlation analysis for CFA control
    %
    % This function performs cluster-based correlation analysis between delta HEP
    % (change in EEG) and delta ECG to control for cardiac field artifacts.
    % The analysis compares empirical correlations against chance-level correlations
    % obtained through time permutation.
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   cfa_config       - Structure containing CFA analysis settings
    %   input_filename   - Name of the input file to load
    %
    % Outputs:
    %   Multiplot showing empirical vs chance correlations with cluster statistics
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Initialize
    fprintf('\n=== Starting CFA Cluster-Based Correlation Analysis ===\n');

    try
        %% Extract configuration parameters
        beat_comparison = cfa_config.beat_comparison;
        beat_reference = cfa_config.beat_reference;
        group_select = cfa_config.group_select;
        stat_params = cfa_config.statistical_analysis;
        corr_type = cfa_config.corr_type;
        corr_n_permu = cfa_config.corr_n_permu;

        % Convert beat types to valid MATLAB field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group select: %s\n', group_select);
        fprintf('  Correlation type: %s\n', corr_type);
        fprintf('  Number of permutations: %d\n', corr_n_permu);

        %% Load layout and neighbours
        precomputed_path = stat_params.paths.precomputed_path;
        load(fullfile(precomputed_path, 'layout.mat'), 'layout');
        load(fullfile(precomputed_path, 'neighbours.mat'), 'neighbours');
        fprintf('Loaded layout and neighbours from: %s\n', precomputed_path);

        %% Load data
        full_data_path = fullfile(epochs_path, input_filename);
        [allsubj_PC, ~] = load_allsubj_data(full_data_path);

        % Select group data
        group_data = allsubj_PC.(group_select);
        comparison_data = group_data.(beat_comparison_field);
        reference_data = group_data.(beat_reference_field);

        if isempty(comparison_data) || isempty(reference_data)
            error('No data found for the specified beat comparison or reference.');
        end

        fprintf('Loaded data for %d subjects\n', length(comparison_data));

        %% Cluster-Based Correlation between Delta HEP and Delta ECG
        fprintf('\n--- Computing correlations between Delta HEP and Delta ECG ---\n');

        % Remove avg field to work with trials
        comparison_data = cellfun(@(x) rmfield_safe(x, 'avg'), comparison_data, 'UniformOutput', false);
        reference_data = cellfun(@(x) rmfield_safe(x, 'avg'), reference_data, 'UniformOutput', false);

        % Extract dimensions from data
        n_timepoints = size(comparison_data{1}.trial, 3);
        n_eeg_channels = 31;
        ecg_channel_idx = 32; % Index of ECG channel

        fprintf('Data dimensions: %d timepoints, %d EEG channels\n', n_timepoints, n_eeg_channels);

        % Prepare random time permutations for chance level
        random_time_permutations = zeros(corr_n_permu, n_timepoints);

        for i_perm = 1:corr_n_permu
            random_time_permutations(i_perm, :) = randperm(n_timepoints);
        end

        % Compute differences and correlations
        delta_hep_ecg = comparison_data;
        fisher_z_empirical = comparison_data;
        fisher_z_chance = comparison_data;

        for subj = 1:length(comparison_data)
            % Compute delta EEG and delta ECG
            cfg = [];
            cfg.operation = 'subtract';
            cfg.parameter = 'trial';
            delta_hep_ecg{1, subj} = ft_math(cfg, comparison_data{1, subj}, reference_data{1, subj});

            % Compute empirical and chance correlations
            fisher_z_emp_subj = zeros(n_eeg_channels, n_timepoints);
            fisher_z_chance_subj = zeros(n_eeg_channels, n_timepoints);

            for elec = 1:n_eeg_channels

                for time = 1:n_timepoints
                    % Empirical correlation
                    r_empirical = corr(delta_hep_ecg{1, subj}.trial(:, elec, time), ...
                        delta_hep_ecg{1, subj}.trial(:, ecg_channel_idx, time), 'Type', corr_type);
                    fisher_z_emp_subj(elec, time) = atanh(r_empirical);

                    % Chance level correlation (time-permuted)
                    fisher_z_perm = zeros(1, corr_n_permu);

                    for i_perm = 1:corr_n_permu
                        r_chance = corr(delta_hep_ecg{1, subj}.trial(:, elec, time), ...
                            delta_hep_ecg{1, subj}.trial(:, ecg_channel_idx, random_time_permutations(i_perm, time)), ...
                            'Type', corr_type);
                        fisher_z_perm(i_perm) = atanh(r_chance);
                    end

                    fisher_z_chance_subj(elec, time) = median(fisher_z_perm);
                end

            end

            % Store fisher z values as 'fisher_transf' field
            fisher_z_empirical{1, subj}.fisher_transf = fisher_z_emp_subj;
            fisher_z_chance{1, subj}.fisher_transf = fisher_z_chance_subj;

            % Remove trial field
            fisher_z_empirical{1, subj} = rmfield_safe(fisher_z_empirical{1, subj}, 'trial');
            fisher_z_chance{1, subj} = rmfield_safe(fisher_z_chance{1, subj}, 'trial');
        end

        %% Statistical comparison: empirical vs chance
        fprintf('Running cluster-based permutation test...\n');

        cfg = [];
        cfg.parameter = stat_params.parameter;
        cfg.method = stat_params.method;
        cfg.statistic = stat_params.statistic;
        cfg.correctm = stat_params.correctm;
        cfg.clusteralpha = stat_params.clusteralpha;
        cfg.clusterstatistic = stat_params.clusterstatistic;
        cfg.minnbchan = stat_params.minnbchan;
        cfg.layout = layout;
        cfg.tail = stat_params.tail;
        cfg.clustertail = stat_params.clustertail;
        cfg.alpha = stat_params.alpha;
        cfg.numrandomization = stat_params.numrandomization;
        cfg.neighbours = neighbours;
        cfg.channel = stat_params.channel;
        cfg.latency = stat_params.latency;

        Nsubj = length(fisher_z_empirical);
        design = zeros(2, Nsubj * 2);
        design(1, :) = [1:Nsubj 1:Nsubj];
        design(2, :) = [ones(1, Nsubj) ones(1, Nsubj) * 2];
        cfg.design = design;
        cfg.uvar = 1;
        cfg.ivar = 2;

        stat_corr = ft_timelockstatistics(cfg, fisher_z_empirical{1, :}, fisher_z_chance{1, :});

        %% Create grand averages for plotting
        cfg = [];
        cfg.parameter = 'fisher_transf';
        cfg.channel = {'all', '-ECG'};
        GA_fisher_z_empirical = ft_timelockgrandaverage(cfg, fisher_z_empirical{1, :});
        GA_fisher_z_chance = ft_timelockgrandaverage(cfg, fisher_z_chance{1, :});
        GA_fisher_z_empirical.mask = stat_corr.mask;
        GA_fisher_z_chance.mask = stat_corr.mask;

        %% Create multiplot
        figure('Position', [100 100 1200 1000]);
        cfg = [];
        cfg.parameter = 'avg';
        cfg.layout = layout;
        cfg.channel = {'all', '-ECG'};
        cfg.graphcolor = [[0, 0.4470, 0.7410]; [0.8500, 0.3250, 0.0980]];
        cfg.linewidth = 1;
        cfg.maskparameter = 'mask';
        cfg.maskstyle = 'box';
        cfg.maskfacealpha = 0.5;
        cfg.showlabels = 'yes';
        cfg.showcomment = 'no';

        ft_multiplotER(cfg, GA_fisher_z_empirical, GA_fisher_z_chance);

        [beat_ldg, beatNorm_ldg] = format_beat_labels(beat_comparison, beat_reference, group_select, false);
        title(['CFA Control: ', beat_ldg, ' - ', beatNorm_ldg]);
        legend('Empirical Correlation \Delta EEG - \Delta ECG', '', '', 'Chance Level Correlation \Delta EEG - \Delta ECG', ...
            'location', 'southwest');

        %% Save
        file_name = generate_filename('cfa_cluster_correlation', beat_comparison, beat_reference, group_select, ...
            stat_params.hep_params.baseline_option, stat_params.hep_params.ica_status);
        set(gcf, 'units', 'centimeters', 'pos', [0 0 30 25]);
        exportgraphics(gcf, fullfile(output_path, [file_name, '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');
        close(gcf);

        fprintf('Saved multiplot: %s.pdf\n', file_name);
        fprintf('=== CFA Cluster-Based Correlation Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_9_cfa_cluster_correlation: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('cfa_cluster_correlation_error_%s.txt', ...
            char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
        fid = fopen(error_log_file, 'w');
        fprintf(fid, '%s', error_msg);
        fclose(fid);

        rethrow(ME);
    end

end

function x = rmfield_safe(x, field)
    % Safely remove a field if it exists
    if isfield(x, field)
        x = rmfield(x, field);
    end

end
