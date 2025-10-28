function a_9_source_analysis_timewise(epochs_path, error_log_path, output_path, source_config, input_filename)
    % A_9_SOURCE_ANALYSIS_TIMEWISE - Time-resolved eLORETA source reconstruction
    %
    % This function performs eLORETA-based source reconstruction comparing
    % PC+1 (fixed time window) against PC-3 across multiple sliding time windows.
    % It calculates the percentage of analysis pipelines showing significant
    % differences per ROI for each time window comparison.
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   source_config    - Structure containing source analysis settings
    %   input_filename   - Name of the input file to load
    %
    % Required fields in source_config:
    %   pc_plus1_window         - Fixed time window for PC+1 [start, end] in seconds
    %   pc_minus3_windows       - Cell array of time windows for PC-3 {[s1,e1], [s2,e2], ...}
    %   group_select            - Group selection: 'PC' (both PAC and PVC combined)
    %   regularization_values   - Cell array of regularization parameters: {0.5, 0.05, 0.001}
    %   agg_methods             - Cell array of aggregation methods: {'avg', 'avg-sf'}
    %   statistical_alpha       - Alpha level for statistical testing (default: 0.05)
    %   fdr_correction          - Whether to apply FDR correction (default: true)
    %   paths                   - Paths structure from config
    %   hep_params              - HEP parameters for metadata
    %
    % Outputs:
    %   - Multiple brain visualizations (one per time window)
    %   - CSV file with statistical results for all time windows
    %   - Combined visualization showing all time window comparisons
    %
    % Author: Pia Reinfeld
    % Date: 2025

    fprintf('\n=== Starting Time-Resolved eLORETA Source Analysis ===\n');

    try
        %% Validate required configuration fields
        required_fields = {'pc_plus1_window', 'pc_minus3_windows', 'group_select', ...
                               'regularization_values', 'agg_methods', 'paths', 'hep_params'};

        for i = 1:length(required_fields)

            if ~isfield(source_config, required_fields{i})
                error('Missing required field in source_config: %s', required_fields{i});
            end

        end

        %% Extract configuration parameters
        pc_plus1_window = source_config.pc_plus1_window;
        pc_minus3_windows = source_config.pc_minus3_windows;
        group_select = source_config.group_select;
        regularization_values = source_config.regularization_values;
        agg_methods = source_config.agg_methods;
        statistical_alpha = source_config.statistical_alpha;
        fdr_correction = source_config.fdr_correction;

        n_time_windows = length(pc_minus3_windows);

        fprintf('Configuration:\n');
        fprintf('  PC+1 fixed window: [%.3f, %.3f] s\n', pc_plus1_window(1), pc_plus1_window(2));
        fprintf('  Number of PC-3 time windows: %d\n', n_time_windows);
        fprintf('  Group: %s\n', group_select);
        fprintf('  Regularization values: %s\n', mat2str([regularization_values{:}]));
        fprintf('  Aggregation methods: %s\n', strjoin(agg_methods, ', '));
        fprintf('  Statistical alpha: %.3f\n', statistical_alpha);
        fprintf('  FDR correction: %s\n', mat2str(fdr_correction));

        %% Load required files
        fprintf('Loading eLORETA forward models...\n');
        eloreta_path = source_config.paths.base_code;

        % Load eLORETA matrices and anatomical data
        source_atlas = load(fullfile(eloreta_path, 'settings', 'source_atlas_eloreta.mat'));
        roi_atlas = load(fullfile(eloreta_path, 'settings', 'roi_labels_harvard_oxford.mat'));
        colormap_data = load(fullfile(eloreta_path, 'settings', 'colormap_17.mat'));

        % Extract needed variables
        cortex_surface = source_atlas.sa;
        forward_model_smooth = source_atlas.A_eloreta_normal_smooth;
        forward_model_standard = source_atlas.A_eloreta_normal;
        forward_model_focal = source_atlas.A_eloreta_normal_focal;
        centering_matrix = source_atlas.H;
        channels_to_remove = source_atlas.rem_chan;
        roi_voxel_indices = source_atlas.ind_ROI;
        hep_roi_indices = source_atlas.ROI_HEP;
        roi_signflip = source_atlas.signflip;
        n_voxels = source_atlas.n_voxels;
        roi_labels = roi_atlas.HO_labels;
        colormap_brain = colormap_data.cm17;

        fprintf('Loaded eLORETA forward models and anatomical atlases\n');

        %% Load epoched data
        full_data_path = fullfile(epochs_path, input_filename);

        if ~exist(full_data_path, 'file')
            error('Data file not found: %s', full_data_path);
        end

        load(full_data_path, 'allsubj_PC');
        fprintf('Loaded PC group data from: %s\n', input_filename);

        %% Select group data
        group_data = allsubj_PC.(group_select);

        % Get PC+1 and PC-3 data
        pc_plus1_data = group_data.plus1;
        pc_minus3_data = group_data.minus3;

        if isempty(pc_plus1_data) || isempty(pc_minus3_data)
            error('No data found for PC+1 or PC-3.');
        end

        n_subjects = length(pc_plus1_data);
        fprintf('Loaded data for %d subjects\n', n_subjects);

        %% Initialize storage
        n_regularization = length(regularization_values);
        n_agg = length(agg_methods);
        n_pipelines = n_regularization * n_agg;
        n_rois = length(hep_roi_indices);

        % Clean ROI labels
        roi_labels_clean = cellfun(@(x) strrep(x, ',', ''), roi_labels, 'UniformOutput', false);
        roi_labels_clean = cellfun(@(x) strrep(x, ' (formerly Supplementary Motor Cortex)', ''), ...
            roi_labels_clean, 'UniformOutput', false);
        roi_labels_hep = roi_labels_clean(hep_roi_indices);

        % Storage for all time windows
        all_time_windows_pvalues = cell(n_time_windows, 1);
        all_time_windows_percentages = zeros(n_time_windows, n_rois);
        pipeline_info = cell(n_pipelines, 2); % regularization_value, agg_method

        fprintf('\nAnalyzing %d time windows with %d pipelines each...\n', n_time_windows, n_pipelines);

        %% Loop through each PC-3 time window
        for tw = 1:n_time_windows
            pc_minus3_window = pc_minus3_windows{tw};

            fprintf('\n=== Time Window %d/%d: PC+1 [%.0f-%.0f ms] vs PC-3 [%.0f-%.0f ms] ===\n', ...
                tw, n_time_windows, ...
                pc_plus1_window(1) * 1000, pc_plus1_window(2) * 1000, ...
                pc_minus3_window(1) * 1000, pc_minus3_window(2) * 1000);

            % Storage for this time window
            all_pipeline_pvalues = zeros(n_pipelines, n_rois);

            %% Loop through all pipeline combinations
            pipeline_idx = 0;

            for i_reg = 1:n_regularization
                regularization_value = regularization_values{i_reg};

                % Select forward model
                forward_model = select_eloreta_forward_model(regularization_value, ...
                    forward_model_smooth, forward_model_standard, forward_model_focal);

                for i_agg = 1:n_agg
                    agg_method = agg_methods{i_agg};
                    pipeline_idx = pipeline_idx + 1;

                    fprintf('  Pipeline %d/%d: reg=%.3f, agg=%s\n', ...
                        pipeline_idx, n_pipelines, regularization_value, agg_method);

                    % Store pipeline info (only once)
                    if tw == 1
                        pipeline_info{pipeline_idx, 1} = regularization_value;
                        pipeline_info{pipeline_idx, 2} = agg_method;
                    end

                    %% Perform source reconstruction
                    % PC+1 always uses the fixed time window
                    % PC-3 uses the current sliding time window
                    [source_pc_plus1_ROI, source_pc_minus3_ROI] = ...
                        reconstruct_sources_eloreta(pc_plus1_data, pc_minus3_data, ...
                        forward_model, centering_matrix, channels_to_remove, roi_voxel_indices, ...
                        hep_roi_indices, roi_signflip, pc_plus1_window, agg_method, pc_minus3_window);

                    %% Statistical testing
                    [~, p_values, ~, ~] = ttest(source_pc_plus1_ROI, source_pc_minus3_ROI, ...
                        'Dim', 2, 'Alpha', statistical_alpha, 'Tail', 'both');

                    % Apply FDR correction
                    if fdr_correction
                        p_values_corrected = mafdr(p_values, 'BHFDR', true);
                    else
                        p_values_corrected = p_values;
                    end

                    % Store p-values
                    all_pipeline_pvalues(pipeline_idx, :) = p_values_corrected;

                    % Report significant ROIs
                    sig_rois = find(p_values_corrected < statistical_alpha);
                    fprintf('    Found %d significant ROIs\n', length(sig_rois));
                end

            end

            %% Calculate percentage of significant pipelines per ROI
            sig_pipeline_count = sum(all_pipeline_pvalues < statistical_alpha, 1);
            sig_pipeline_percentage = (sig_pipeline_count / n_pipelines) * 100;

            % Store results for this time window
            all_time_windows_pvalues{tw} = all_pipeline_pvalues;
            all_time_windows_percentages(tw, :) = sig_pipeline_percentage;

            fprintf('  Time window %d: Max %.1f%% pipelines significant across ROIs\n', ...
                tw, max(sig_pipeline_percentage));
        end

        %% Generate visualizations for each time window
        fprintf('\nGenerating source analysis visualizations...\n');

        for tw = 1:n_time_windows
            close all;

            pc_minus3_window = pc_minus3_windows{tw};
            sig_pipeline_percentage = all_time_windows_percentages(tw, :);

            % Map percentages to rois
            source_sig_visualization = zeros(n_voxels, 1);

            for i = 1:n_rois
                roi_idx = hep_roi_indices(i);
                voxel_indices = roi_voxel_indices{roi_idx};
                source_sig_visualization(voxel_indices) = sig_pipeline_percentage(i);
            end

            % Create title
            title_name = sprintf(['$\\textrm{HEP}_{\\textrm{PC+1, %.0f-%.0f ms}}' ...
                                  '\\textrm{ vs. }\\textrm{HEP}_{\\textrm{PC-3, %.0f-%.0f ms}}$'], ...
                pc_plus1_window(1) * 1000, pc_plus1_window(2) * 1000, ...
                pc_minus3_window(1) * 1000, pc_minus3_window(2) * 1000);

            % Generate source analysis  plot
            visualize_hep_source_brain(cortex_surface, ...
                source_sig_visualization(cortex_surface.cortex5K.in_to_cortex75K_geod), ...
                [0 100], colormap_brain, 'xx', 1, 'views', [1, 2, 3, 4, 5, 8], 'save', 0);

            % Save figure
            output_filename_base = sprintf('sourcespace_timewise_%s_+1_vs_-3_tw%d', ...
                group_select, tw);
            save_multiverse_source_figure(title_name, output_path, output_filename_base);

            fprintf('  Saved visualization for time window %d\n', tw);
        end

        %% Export results to CSV
        fprintf('\nExporting results to CSV...\n');

        % Create comprehensive results table for all time windows
        results_table = create_timewise_source_results_table(all_time_windows_pvalues, ...
            pipeline_info, roi_labels_hep, pc_minus3_windows, statistical_alpha);

        % Create metadata
        metadata = create_timewise_source_metadata(source_config, n_subjects, n_pipelines, ...
            n_time_windows, statistical_alpha, fdr_correction);

        % Save CSV
        csv_filename = sprintf('sourcespace_timewise_%s_+1_vs_-3_results.csv', group_select);
        save_source_results_with_metadata(results_table, metadata, output_path, csv_filename);

        fprintf('Results exported to: %s\n', csv_filename);

        %% Save MATLAB workspace
        save_filename = sprintf('sourcespace_timewise_%s_+1_vs_-3.mat', group_select);
        save_data = struct();
        save_data.all_time_windows_pvalues = all_time_windows_pvalues;
        save_data.all_time_windows_percentages = all_time_windows_percentages;
        save_data.pipeline_info = pipeline_info;
        save_data.roi_labels_hep = roi_labels_hep;
        save_data.pc_plus1_window = pc_plus1_window;
        save_data.pc_minus3_windows = pc_minus3_windows;
        save_data.config_used = source_config;
        save_data.metadata = metadata;
        save_data.analysis_date = datestr(now);

        save(fullfile(output_path, save_filename), 'save_data');
        fprintf('MATLAB results saved to: %s\n', save_filename);

        fprintf('\n=== Time-Resolved eLORETA Source Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_9_source_analysis_timewise: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('source_timewise_error_%s.txt', ...
            datestr(now, 'yyyymmdd_HHMMSS')));
        fid = fopen(error_log_file, 'w');
        fprintf(fid, '%s', error_msg);
        fclose(fid);

        rethrow(ME);
    end

end
