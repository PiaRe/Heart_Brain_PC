function a_11_twave_control(epochs_path, error_log_path, output_path, twave_settings, input_filename)
    % A_11_TWAVE_CONTROL - T-Wave amplitude matching control analysis
    %
    % This function performs T-peak amplitude matching between PC+1 and N/PC-3 beats
    % to control for T-wave amplitude effects on the heartbeat-evoked potential (HEP).
    % Only PC+1 beats are matched based on T-peak amplitude within 200-400ms window.
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   twave_settings   - Structure containing T-wave analysis settings:
    %       .beat_comparison       - Beat type for comparison (typically '+1')
    %       .beat_reference        - Beat type for reference (typically '-3')
    %       .group_select          - Group to analyze ('PC', 'PAC', 'PVC')
    %       .t_wave_window         - Time window for T-wave [start, end] in seconds
    %       .cost_unmatched        - Cost for unmatched epochs in matching algorithm
    %       .ecg_channel_idx       - (Optional) ECG channel index from config
    %       .stats_config          - Statistical analysis configuration
    %   input_filename   - Name of input .mat file with epoched data
    %
    % Outputs:
    %   - Matched epoched data saved to output_path
    %   - T-wave matching statistics table
    %   - Statistical results after cluster-based permutation tests
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Initialize
    fprintf('\n=== Starting T-Peak Amplitude Matching Control Analysis ===\n');

    try
        %% Extract configuration
        beat_comparison = twave_settings.beat_comparison; % '+1'
        beat_reference = twave_settings.beat_reference; % '-3'
        group_select = twave_settings.group_select; % 'PC'
        t_window = twave_settings.t_wave_window; % [0.2, 0.4]
        cost_unmatched = twave_settings.cost_unmatched; % 20

        ecg_chan_idx = twave_settings.ecg_channel_idx;

        % Convert beat types to field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group select: %s\n', group_select);
        fprintf('  T-wave window: [%.3f, %.3f] s\n', t_window(1), t_window(2));
        fprintf('  Cost unmatched: %d\n', cost_unmatched);

        %% Load epoched data
        full_data_path = fullfile(epochs_path, input_filename);

        [allsubj_PC, ~] = load_allsubj_data(full_data_path);

        % Select group data
        group_data = allsubj_PC.(group_select);
        comparison_data = group_data.(beat_comparison_field); % PC+1
        reference_data = group_data.(beat_reference_field); % PC-3
        iN_data = group_data.iN; % Normal beats

        n_subj = length(comparison_data);
        fprintf('Loaded data for %d subjects\n', n_subj);

        %% Initialize matched data and statistics
        matched_comparison_data = cell(size(comparison_data));
        matched_reference_data = cell(size(reference_data));

        % Statistics arrays
        all_t_peak_comparison_unmatched = [];
        all_t_peak_comparison_matched = [];
        all_t_peak_reference_unmatched = [];
        all_t_peak_reference_matched = [];
        n_epochs_per_subject = zeros(n_subj, 1);

        %% Loop over subjects for matching
        fprintf('\nPerforming T-peak amplitude matching...\n');

        for subj = 1:n_subj

            if isempty(comparison_data{subj}) || ~isfield(comparison_data{subj}, 'trial')
                fprintf('  Subject %d: No data available, skipping\n', subj);
                matched_comparison_data{subj} = [];
                matched_reference_data{subj} = [];
                continue
            end

            % Find time indices for T-wave window
            time_vec = comparison_data{subj}.time;
            t_idx = time_vec >= t_window(1) & time_vec <= t_window(2);

            % Extract T-peak amplitudes (maximum absolute value in T-wave window)
            % PC+1 trials
            comparison_trials = comparison_data{subj}.trial;
            n_comparison = size(comparison_trials, 1);
            t_peak_comparison = max(abs(comparison_trials(:, ecg_chan_idx, t_idx)), [], 3);

            % PC-3 trials
            reference_trials = reference_data{subj}.trial;
            t_peak_reference_pc3 = max(abs(reference_trials(:, ecg_chan_idx, t_idx)), [], 3);

            % iN trials
            iN_trials = iN_data{subj}.trial;
            t_peak_reference_iN = max(abs(iN_trials(:, ecg_chan_idx, t_idx)), [], 3);

            % Combine PC-3 and iN as reference pool
            reference_trials_combined = cat(1, iN_trials, reference_trials);
            t_peak_reference = [t_peak_reference_iN; t_peak_reference_pc3];
            n_reference = length(t_peak_reference);

            % Calculate distances between each PC+1 and all reference trials
            distances = zeros(n_comparison, n_reference);

            for i = 1:n_comparison

                for j = 1:n_reference
                    distances(i, j) = abs(t_peak_comparison(i) - t_peak_reference(j));
                end

            end

            % Solve linear assignment problem
            [matching, ~] = matchpairs(distances, cost_unmatched);
            n_matched = size(matching, 1);

            if n_matched < 1
                fprintf('  Subject %d: No matches found, skipping\n', subj);
                matched_comparison_data{subj} = [];
                matched_reference_data{subj} = [];
                continue
            end

            % Extract matched indices
            matched_comparison_idx = matching(:, 1);
            matched_reference_idx = matching(:, 2);

            % Store statistics (before matching)
            all_t_peak_comparison_unmatched = [all_t_peak_comparison_unmatched; t_peak_comparison];
            all_t_peak_reference_unmatched = [all_t_peak_reference_unmatched; t_peak_reference_pc3];

            % Store statistics (after matching)
            all_t_peak_comparison_matched = [all_t_peak_comparison_matched; t_peak_comparison(matched_comparison_idx)];
            all_t_peak_reference_matched = [all_t_peak_reference_matched; t_peak_reference(matched_reference_idx)];

            n_epochs_per_subject(subj) = n_matched;

            % Create matched data structures
            % Matched PC+1
            matched_comparison_data{subj} = comparison_data{subj};
            matched_comparison_data{subj}.trial = comparison_trials(matched_comparison_idx, :, :);

            % Matched N/PC-3 (combined reference)
            matched_reference_data{subj} = reference_data{subj}; % Use PC-3 structure as template
            matched_reference_data{subj}.trial = reference_trials_combined(matched_reference_idx, :, :);

            % Recalculate averages with matched trials
            matched_comparison_data{subj}.avg = squeeze(mean(matched_comparison_data{subj}.trial, 1));
            matched_reference_data{subj}.avg = squeeze(mean(matched_reference_data{subj}.trial, 1));
            matched_comparison_data{subj}.dimord = 'chan_time';
            matched_reference_data{subj}.dimord = 'chan_time';

            fprintf('  Subject %d: Matched %d trials (from %d PC+1 trials)\n', subj, n_matched, n_comparison);
        end

        %% Generate statistics table
        fprintf('\nGenerating T-peak matching statistics table...\n');

        % Calculate statistics
        stats_table = table();

        % Row labels
        stats_table.Statistic = {'Mean'; 'Std'; 'Min'; 'Max'; 'Cohen''s d'};

        % Unmatched PC-3
        stats_table.Unmatched_PCminus3 = [
                                          mean(all_t_peak_reference_unmatched);
                                          std(all_t_peak_reference_unmatched);
                                          min(all_t_peak_reference_unmatched);
                                          max(all_t_peak_reference_unmatched);
                                          NaN
                                          ];

        % Unmatched PC+1
        stats_table.Unmatched_PCplus1 = [
                                         mean(all_t_peak_comparison_unmatched);
                                         std(all_t_peak_comparison_unmatched);
                                         min(all_t_peak_comparison_unmatched);
                                         max(all_t_peak_comparison_unmatched);
                                         NaN
                                         ];

        % Matched PC-3
        stats_table.Matched_PCminus3 = [
                                        mean(all_t_peak_reference_matched);
                                        std(all_t_peak_reference_matched);
                                        min(all_t_peak_reference_matched);
                                        max(all_t_peak_reference_matched);
                                        NaN
                                        ];

        % Matched PC+1
        stats_table.Matched_PCplus1 = [
                                       mean(all_t_peak_comparison_matched);
                                       std(all_t_peak_comparison_matched);
                                       min(all_t_peak_comparison_matched);
                                       max(all_t_peak_comparison_matched);
                                       NaN
                                       ];

        % Number of epochs
        stats_table.N_Epochs = [
                                mean(n_epochs_per_subject(n_epochs_per_subject > 0));
                                std(n_epochs_per_subject(n_epochs_per_subject > 0));
                                min(n_epochs_per_subject(n_epochs_per_subject > 0));
                                max(n_epochs_per_subject(n_epochs_per_subject > 0));
                                NaN
                                ];

        % Calculate effect sizes (Cohen's d) to show matching effectiveness
        % Cohen's d: small = 0.2, medium = 0.5, large = 0.8
        mean_diff_unmatched = mean(all_t_peak_comparison_unmatched) - mean(all_t_peak_reference_unmatched);
        pooled_std_unmatched = sqrt((std(all_t_peak_comparison_unmatched) ^ 2 + std(all_t_peak_reference_unmatched) ^ 2) / 2);
        cohens_d_unmatched = mean_diff_unmatched / pooled_std_unmatched;

        mean_diff_matched = mean(all_t_peak_comparison_matched) - mean(all_t_peak_reference_matched);
        pooled_std_matched = sqrt((std(all_t_peak_comparison_matched) ^ 2 + std(all_t_peak_reference_matched) ^ 2) / 2);
        cohens_d_matched = mean_diff_matched / pooled_std_matched;

        % Add Cohen's d to table instead of p-values
        stats_table.Unmatched_PCminus3(5) = cohens_d_unmatched;
        stats_table.Unmatched_PCplus1(5) = cohens_d_unmatched;
        stats_table.Matched_PCminus3(5) = cohens_d_matched;
        stats_table.Matched_PCplus1(5) = cohens_d_matched;

        % Display table
        fprintf('\nT-Peak Amplitude Matching Results:\n');
        disp(stats_table);

        % Save table to CSV
        table_filename = sprintf('twave_matching_stats_%s_%s_vs_%s.csv', group_select, beat_comparison, beat_reference);
        writetable(stats_table, fullfile(output_path, table_filename));
        fprintf('Statistics table saved to: %s\n', fullfile(output_path, table_filename));

        %% Save matched data
        fprintf('\nSaving matched epoched data...\n');

        % Remove empty cells from matched data (subjects without matches)
        matched_comparison_data = matched_comparison_data(~cellfun('isempty', matched_comparison_data));
        matched_reference_data = matched_reference_data(~cellfun('isempty', matched_reference_data));

        % Report how many subjects have valid matched data
        n_subjects_with_matches = length(matched_comparison_data);
        fprintf('Number of subjects with matched data: %d (out of %d total)\n', n_subjects_with_matches, n_subj);

        % Create output structure with matched data
        allsubj_PC = struct();
        allsubj_PC.(group_select).(beat_comparison_field) = matched_comparison_data;
        allsubj_PC.(group_select).(beat_reference_field) = matched_reference_data;

        % Save matched data
        output_filename_matched = strrep(input_filename, '.mat', '_tpeak_matched.mat');
        save(fullfile(epochs_path, output_filename_matched), 'allsubj_PC');
        fprintf('Matched data saved to: %s\n', fullfile(epochs_path, output_filename_matched));

        %% Run cluster-based permutation test on matched ECG data (T-wave window)
        fprintf('\n=== Running cluster-based permutation test on matched ECG data ===\n');
        fprintf('Testing ECG differences between %s and %s in T-wave window [%.1f-%.1f ms]\n', ...
            beat_comparison, beat_reference, t_window(1) * 1000, t_window(2) * 1000);

        % Create ECG-specific stats config with T-wave window
        stats_config_matched_ecg = twave_settings.stats_config_ecg;
        stats_config_matched_ecg.beat_comparison = beat_comparison;
        stats_config_matched_ecg.beat_reference = beat_reference;
        stats_config_matched_ecg.group_select = group_select;
        stats_config_matched_ecg.time_window = t_window; % For metadata

        % Use T-wave window [0.2, 0.4] instead of full epoch
        stats_config_matched_ecg.statistical_analysis.latency = t_window;

        % Run ECG statistics on matched data (calls a_7_stats_timedomain_ECG)
        a_7_stats_timedomain_ECG(epochs_path, error_log_path, output_path, ...
            stats_config_matched_ecg, output_filename_matched);

        fprintf('ECG cluster-based permutation test completed.\n');

        %% Run cluster-based permutation test on matched EEG data
        fprintf('\nRunning cluster-based permutation test on T-peak matched data...\n');

        % Create EEG-specific stats config (uses original time window from config)
        stats_config_matched_eeg = twave_settings.stats_config_eeg;
        stats_config_matched_eeg.beat_comparison = beat_comparison;
        stats_config_matched_eeg.beat_reference = beat_reference;
        stats_config_matched_eeg.group_select = group_select;

        % Run statistics on matched data (uses original latency from config, not T-wave window)
        a_6_stats_timedomain_EEG(epochs_path, error_log_path, output_path, ...
            stats_config_matched_eeg, output_filename_matched);

        fprintf('\n=== T-Peak Amplitude Matching Control Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_11_twave_control: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('twave_control_error_%s.txt', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
        fid = fopen(error_log_file, 'w');
        fprintf(fid, '%s', error_msg);
        fclose(fid);

        rethrow(ME);
    end

end
