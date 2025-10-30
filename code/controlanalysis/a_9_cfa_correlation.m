function a_9_cfa_correlation(epochs_path, error_log_path, output_path, cfa_config, input_filename, analysis_type)
    % A_9_CFA_CORRELATION - Cardiac Field Artifact (CFA) correlation analysis
    %
    % This function performs correlation analysis to control for cardiac field artifacts
    % in the heartbeat-evoked potential (HEP) data. The analysis examines the relationship
    % between EEG signals and ECG signals to identify potential contamination from
    % cardiac electrical activity.
    %
    % Two analysis types are supported:
    %   1. delta_hep_ecg: Cluster-based correlation between delta HEP and delta ECG
    %   2. avg_timewindow: Interindividual correlation in averaged time windows
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   cfa_config       - Structure containing CFA analysis settings
    %   input_filename   - Name of the input file to load
    %   analysis_type    - Type of analysis: 'delta_hep_ecg' or 'avg_timewindow'
    %
    % Outputs:
    %   Correlation analysis results and visualizations saved to output_path
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Initialize
    fprintf('\n=== Starting CFA Correlation Analysis (%s) ===\n', analysis_type);

    try
        %% Extract configuration parameters
        beat_comparison = cfa_config.beat_comparison;
        beat_reference = cfa_config.beat_reference;
        group_select = cfa_config.group_select;
        stat_params = cfa_config.statistical_analysis;
        corr_type = cfa_config.corr_type;

        % Convert beat types to valid MATLAB field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group select: %s\n', group_select);
        fprintf('  Correlation type: %s\n', corr_type);
        fprintf('  Analysis type: %s\n', analysis_type);

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

        %% Perform analysis based on type
        if strcmp(analysis_type, 'delta_hep_ecg')
            %% Analysis 1: Cluster-Based Correlation between Delta HEP and Delta ECG
            fprintf('\n--- Cluster-Based Correlation Analysis: Delta HEP and Delta ECG ---\n');

            % Prepare random time permutations for chance level
            corr_n_permu = cfa_config.corr_n_permu;
            n_timepoints = 500; % Assuming 500 timepoints based on time window
            random_time_order = zeros(corr_n_permu, n_timepoints);

            for i_rand = 1:corr_n_permu
                random_time_order(i_rand, :) = randperm(n_timepoints);
            end

            % Remove avg field to work with trials
            comparison_data = cellfun(@(x) rmfield_safe(x, 'avg'), comparison_data, 'UniformOutput', false);
            reference_data = cellfun(@(x) rmfield_safe(x, 'avg'), reference_data, 'UniformOutput', false);

            % Compute differences and correlations
            diff = comparison_data;
            corr_empirical = comparison_data;
            corr_chance = comparison_data;

            parfor subj = 1:length(comparison_data)
                % Compute delta EEG and delta ECG
                cfg = [];
                cfg.operation = 'subtract';
                cfg.parameter = 'trial';
                diff{1, subj} = ft_math(cfg, comparison_data{1, subj}, reference_data{1, subj});

                % Compute empirical and chance correlations
                diff{1, subj}.empirical.fisher_transf = zeros(31, n_timepoints);
                diff{1, subj}.chance.fisher_transf = zeros(31, n_timepoints);

                for elec = 1:31

                    for time = 1:n_timepoints
                        % Empirical correlation
                        r_emp = corr(diff{1, subj}.trial(:, elec, time), diff{1, subj}.trial(:, 32, time), 'Type', corr_type);
                        diff{1, subj}.empirical.fisher_transf(elec, time) = atanh(r_emp);

                        % Chance level correlation (time-permuted)
                        diff_chance_loop = zeros(1, corr_n_permu);

                        for random_loop = 1:corr_n_permu
                            r_chance = corr(diff{1, subj}.trial(:, elec, time), ...
                                diff{1, subj}.trial(:, 32, random_time_order(random_loop, time)), 'Type', corr_type);
                            diff_chance_loop(random_loop) = atanh(r_chance);
                        end

                        diff{1, subj}.chance.fisher_transf(elec, time) = median(diff_chance_loop);
                    end

                end

                % Prepare for statistics
                corr_empirical{1, subj}.fisher_transf = diff{1, subj}.empirical.fisher_transf;
                corr_chance{1, subj}.fisher_transf = diff{1, subj}.chance.fisher_transf;
                corr_empirical{1, subj} = rmfield_safe(corr_empirical{1, subj}, 'trial');
                corr_chance{1, subj} = rmfield_safe(corr_chance{1, subj}, 'trial');
            end

            % Statistical comparison: empirical vs chance
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

            Nsubj = length(corr_empirical);
            design = zeros(2, Nsubj * 2);
            design(1, :) = [1:Nsubj 1:Nsubj];
            design(2, :) = [ones(1, Nsubj) ones(1, Nsubj) * 2];
            cfg.design = design;
            cfg.uvar = 1;
            cfg.ivar = 2;

            fprintf('Running cluster-based permutation test...\n');
            stat_corr = ft_timelockstatistics(cfg, corr_empirical{1, :}, corr_chance{1, :});

            % Create grand averages for plotting
            cfg = [];
            cfg.parameter = 'fisher_transf';
            cfg.channel = {'all', '-ECG'};
            diff_corr_empirical_GA = ft_timelockgrandaverage(cfg, corr_empirical{1, :});
            diff_corr_chance_GA = ft_timelockgrandaverage(cfg, corr_chance{1, :});
            diff_corr_empirical_GA.mask = stat_corr.mask;
            diff_corr_chance_GA.mask = stat_corr.mask;

            % Create multiplot
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

            ft_multiplotER(cfg, diff_corr_empirical_GA, diff_corr_chance_GA);

            [beat_ldg, beatNorm_ldg] = format_beat_labels(beat_comparison, beat_reference, group_select, false);
            title(['CFA Control: ', beat_ldg, ' - ', beatNorm_ldg]);
            legend('Empirical Correlation \Delta EEG - \Delta ECG', '', '', 'Chance Level Correlation \Delta EEG - \Delta ECG', ...
                'location', 'southwest');

            % Save
            file_name = generate_filename('cfa_delta_hep_ecg', beat_comparison, beat_reference, group_select, ...
                stat_params.hep_params.baseline_option, stat_params.hep_params.ica_status);
            set(gcf, 'units', 'centimeters', 'pos', [0 0 30 25]);
            exportgraphics(gcf, fullfile(output_path, [file_name, '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');
            close(gcf);

            fprintf('Saved multiplot: %s.pdf\n', file_name);

        elseif strcmp(analysis_type, 'avg_timewindow')
            %% Analysis 2: Interindividual Correlation in Averaged Time Window
            fprintf('\n--- Interindividual Correlation Analysis: Averaged Time Window ---\n');

            time_window = cfa_config.time_window;
            fprintf('Time window: [%.3f, %.3f] s\n', time_window(1), time_window(2));

            % Remove avg field to work with trials
            comparison_data = cellfun(@(x) rmfield_safe(x, 'avg'), comparison_data, 'UniformOutput', false);
            reference_data = cellfun(@(x) rmfield_safe(x, 'avg'), reference_data, 'UniformOutput', false);

            % Compute differences and average in time window
            mean_time_window = zeros(length(comparison_data), 32);
            diff = comparison_data;

            parfor subj = 1:length(comparison_data)
                % Compute delta EEG and delta ECG
                cfg = [];
                cfg.operation = 'subtract';
                cfg.parameter = 'trial';
                diff{1, subj} = ft_math(cfg, comparison_data{1, subj}, reference_data{1, subj});

                % Select time window
                cfg = [];
                cfg.latency = time_window;
                diff{1, subj} = ft_selectdata(cfg, diff{1, subj});

                % Average across time for each trial
                diff{1, subj}.mean_timewindow = mean(diff{1, subj}.trial, 3);

                % Average across trials for each subject
                mean_time_window(subj, :) = mean(diff{1, subj}.mean_timewindow, 1);
            end

            % Correlate mean time-window EEG with mean time-window ECG across subjects
            cfg = [];
            cfg.latency = stat_params.latency;
            cfg.parameter = 'avg';
            cfg.channel = {'all', '-ECG'};
            Beat = ft_timelockgrandaverage(cfg, comparison_data{1, :});

            correlation_time_window = Beat;
            [correlation_time_window.correl, correlation_time_window.pval] = ...
                corr(mean_time_window(:, 1:31), mean_time_window(:, 32), 'type', corr_type, 'tail', 'both');

            % Replicate correlation values across time for topoplot
            correlation_time_window.correl = repmat(correlation_time_window.correl, 1, 500);

            % FDR correction
            correlation_time_window.pval_fdr = mafdr(correlation_time_window.pval, 'BHFDR', true);
            sig_elec = correlation_time_window.elec.label(correlation_time_window.pval_fdr < 0.05);

            % Create topoplot
            figure('Position', [100 100 380 260]);
            cfg = [];
            cfg.xlim = [0, 0.1];
            cfg.parameter = 'correl';
            cfg.comment = 'no';
            cfg.layout = layout;

            if ~isempty(sig_elec)
                cfg.highlight = 'on';
                cfg.highlightcolor = 'k';
                cfg.highlightsymbol = '.';
                cfg.highlightsize = 14;
                cfg.highlightchannel = sig_elec;
            end

            ft_topoplotER(cfg, correlation_time_window);

            [beat_ldg, beatNorm_ldg] = format_beat_labels(beat_comparison, beat_reference, group_select, false);
            title(['CFA Control: corr(HEP_{', beat_ldg, '-', beatNorm_ldg, '}, ECG_{', beat_ldg, '-', beatNorm_ldg, '})'], ...
                'FontSize', 10);

            ft_hastoolbox('brewermap', 1);
            colormap(flipud(brewermap(1024, 'RdBu')));
            c = colorbar;
            clim([-1, 1]);
            c.FontSize = 10;
            c.Label.FontSize = 12;
            c.Label.String = 'Correlation';

            annotation('textbox', [0, 0.02, 1, 0.05], 'FontSize', 10, ...
                'String', sprintf('min(corr): %.2f; max(corr): %.2f', ...
                min(correlation_time_window.correl(1, :)), max(correlation_time_window.correl(1, :))), ...
                'EdgeColor', 'none', 'HorizontalAlignment', 'center');
            annotation('textbox', [0, 0.08, 1, 0.05], 'FontSize', 10, ...
                'String', sprintf('averaged time window: %.2f s - %.2f s', time_window(1), time_window(2)), ...
                'EdgeColor', 'none', 'HorizontalAlignment', 'center');

            % Save
            file_name = generate_filename('cfa_avg_timewindow', beat_comparison, beat_reference, group_select, ...
                stat_params.hep_params.baseline_option, stat_params.hep_params.ica_status);
            set(gcf, 'units', 'centimeters', 'pos', [0 0 9.5 6.5]);
            pos = get(gcf, 'Position');
            set(gcf, 'PaperPositionMode', 'Auto', 'PaperUnits', 'centimeters', 'PaperSize', [pos(3), pos(4)]);
            exportgraphics(gcf, fullfile(output_path, [file_name, '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');
            close(gcf);

            fprintf('Saved topoplot: %s.pdf\n', file_name);

        else
            error('Unknown analysis type: %s. Must be ''delta_hep_ecg'' or ''avg_timewindow''.', analysis_type);
        end

        fprintf('=== CFA Correlation Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_9_cfa_correlation: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('cfa_correlation_error_%s.txt', ...
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
