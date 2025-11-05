function a_10_cfa_timewindow_correlation(epochs_path, error_log_path, output_path, cfa_config, input_filename)
    % A_10_CFA_TIMEWINDOW_CORRELATION - Interindividual correlation analysis for CFA control
    %
    % This function performs interindividual correlation analysis in an averaged time window
    % between delta HEP (change in EEG) and delta ECG to control for cardiac field artifacts.
    % The analysis correlates averaged EEG and ECG signals across subjects.
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   cfa_config       - Structure containing CFA analysis settings:
    %       .beat_comparison       - Beat type for comparison (e.g., '+1', '0')
    %       .beat_reference        - Beat type for reference (e.g., '-3')
    %       .group_select          - Group to analyze ('PC', 'PAC', 'PVC')
    %       .corr_type             - Correlation type (e.g., 'Spearman')
    %       .time_window           - Time window for averaging [start, end] in seconds
    %       .n_eeg_channels        - Number of EEG channels (from config)
    %       .ecg_channel_idx       - ECG channel index (from config)
    %       .statistical_analysis  - Statistical analysis parameters
    %   input_filename   - Name of the input file to load
    %
    % Outputs:
    %   Topoplot showing correlation coefficients with significant electrodes marked
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Initialize
    fprintf('\n=== Starting CFA Time Window Correlation Analysis ===\n');

    try
        %% Extract configuration parameters
        beat_comparison = cfa_config.beat_comparison;
        beat_reference = cfa_config.beat_reference;
        group_select = cfa_config.group_select;
        stat_params = cfa_config.statistical_analysis;
        corr_type = cfa_config.corr_type;
        time_window = cfa_config.time_window;

        n_eeg_channels = cfa_config.n_eeg_channels;
        ecg_channel_idx = cfa_config.ecg_channel_idx;

        % Convert beat types to valid MATLAB field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group select: %s\n', group_select);
        fprintf('  Correlation type: %s\n', corr_type);
        fprintf('  Time window: [%.3f, %.3f] s\n', time_window(1), time_window(2));

        %% Load layout and neighbours
        precomputed_path = stat_params.paths.precomputed_path;
        load(fullfile(precomputed_path, 'layout.mat'), 'layout');
        fprintf('Loaded layout from: %s\n', precomputed_path);

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

        %% Create Template for Plotting
        cfg = [];
        cfg.latency = stat_params.latency;
        cfg.parameter = 'avg';
        cfg.channel = {'all', '-ECG'};
        GA_template = ft_timelockgrandaverage(cfg, comparison_data{1, :});
        correlation_result = GA_template;

        %% Interindividual Correlation in Averaged Time Window
        fprintf('\n--- Computing interindividual correlations in time window ---\n');

        % Remove avg field to work with trials
        comparison_data = cellfun(@(x) rmfield_safe(x, 'avg'), comparison_data, 'UniformOutput', false);
        reference_data = cellfun(@(x) rmfield_safe(x, 'avg'), reference_data, 'UniformOutput', false);

        % Extract dimensions from data
        n_subjects = length(comparison_data);
        n_all_channels = size(comparison_data{1}.trial, 2);

        % Compute differences and average in time window
        subject_avg_eeg_ecg = zeros(n_subjects, n_all_channels);

        parfor subj = 1:n_subjects
            % Compute delta EEG and delta ECG
            cfg = [];
            cfg.operation = 'subtract';
            cfg.parameter = 'trial';
            delta_hep_ecg_subj = ft_math(cfg, comparison_data{1, subj}, reference_data{1, subj});

            % Select time window
            cfg = [];
            cfg.latency = time_window;
            delta_hep_ecg_tw = ft_selectdata(cfg, delta_hep_ecg_subj);

            % Average across time for each trial, then across trials
            trials_avg_across_time = mean(delta_hep_ecg_tw.trial, 3);
            subject_avg_eeg_ecg(subj, :) = mean(trials_avg_across_time, 1);
        end

        %% Correlate mean time-window EEG with mean time-window ECG across subject
        [correlation_result.correl, correlation_result.pval] = ...
            corr(subject_avg_eeg_ecg(:, 1:n_eeg_channels), subject_avg_eeg_ecg(:, ecg_channel_idx), ...
            'type', corr_type, 'tail', 'both');

        % Store min/max before replicating across time
        min_corr = min(correlation_result.correl);
        max_corr = max(correlation_result.correl);

        % Replicate correlation values across time for topoplot
        n_timepoints_plot = size(GA_template.avg, 2);
        correlation_result.correl = repmat(correlation_result.correl, 1, n_timepoints_plot);

        % FDR correction
        correlation_result.pval_fdr = mafdr(correlation_result.pval, 'BHFDR', true);
        sig_elec = correlation_result.elec.label(correlation_result.pval_fdr < 0.05);

        fprintf('Found %d significant electrodes (FDR corrected)\n', length(sig_elec));

        if ~isempty(sig_elec)
            fprintf('Significant electrodes: %s\n', strjoin(sig_elec, ', '));
        end

        %% Create topoplot
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

        ft_topoplotER(cfg, correlation_result);

        [beat_ldg, beatNorm_ldg] = create_condition_labels(beat_comparison, beat_reference, group_select, false, false, false);
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
            'String', sprintf('min(corr): %.2f; max(corr): %.2f', min_corr, max_corr), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center');
        annotation('textbox', [0, 0.08, 1, 0.05], 'FontSize', 10, ...
            'String', sprintf('averaged time window: %.2f s - %.2f s', time_window(1), time_window(2)), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center');

        %% Save
        % Generate filename (preprocessing is fixed for CFA, no need for baseline/ica in filename)
        file_name = sprintf('cfa_timewindow_correlation_%s_%s_vs_%s', ...
            group_select, beat_comparison, beat_reference);

        set(gcf, 'units', 'centimeters', 'pos', [0 0 9.5 6.5]);
        pos = get(gcf, 'Position');
        set(gcf, 'PaperPositionMode', 'Auto', 'PaperUnits', 'centimeters', 'PaperSize', [pos(3), pos(4)]);
        exportgraphics(gcf, fullfile(output_path, [file_name, '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');
        close(gcf);

        fprintf('Saved topoplot: %s.pdf\n', file_name);
        fprintf('=== CFA Time Window Correlation Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_10_cfa_timewindow_correlation: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('cfa_timewindow_correlation_error_%s.txt', ...
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
