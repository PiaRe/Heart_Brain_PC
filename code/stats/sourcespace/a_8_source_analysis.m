function a_8_source_analysis(epochs_path, error_log_path, output_path, source_config, input_filename)
    % A_8_SOURCE_ANALYSIS - eLORETA source reconstruction and statistical analysis
    %
    % This function performs eLORETA-based source reconstruction of heartbeat-evoked
    % potentials (HEP) and calculates the percentage of analysis pipelines leading
    % to significant differences across ROIs for publication.
    %
    % Inputs:
    %   epochs_path      - Path to the epoched data directory
    %   error_log_path   - Path to save error logs
    %   output_path      - Path to save output results
    %   source_config    - Structure containing source analysis settings
    %   input_filename   - Name of the input file to load
    %
    % Required fields in source_config:
    %   beat_comparison         - Beat type to compare (e.g., 'PVC', '0')
    %   beat_reference          - Reference beat type (e.g., 'PVC-3', '-3')
    %   group_select            - Group selection: 'PAC', 'PVC', or 'PC' (both combined)
    %   regularization_values   - Cell array of regularization parameters: {0.5, 0.05, 0.001}
    %   agg_methods             - Cell array of aggregation methods: {'avg', 'avg-sf'}
    %   time_window             - Time window for analysis in seconds [start, end]
    %   statistical_alpha       - Alpha level for statistical testing (default: 0.05)
    %   fdr_correction          - Whether to apply FDR correction (default: true)
    %   paths                   - Paths structure from config
    %   hep_params              - HEP parameters for metadata
    %
    % Outputs:
    %   - Brain visualization showing percentage of significant pipelines per ROI
    %   - CSV file with statistical results and metadata
    %
    % Author: Pia Reinfeld
    % Date: 2025

    fprintf('\n=== Starting eLORETA Source Analysis ===\n');

    try
        %% Validate required configuration fields
        required_fields = {'beat_comparison', 'beat_reference', 'group_select', ...
                               'regularization_values', 'agg_methods', 'time_window', 'paths', 'hep_params'};

        for i = 1:length(required_fields)

            if ~isfield(source_config, required_fields{i})
                error('Missing required field in source_config: %s', required_fields{i});
            end

        end

        %% Extract configuration parameters
        beat_comparison = source_config.beat_comparison;
        beat_reference = source_config.beat_reference;
        group_select = source_config.group_select;
        regularization_values = source_config.regularization_values;
        agg_methods = source_config.agg_methods;
        time_window = source_config.time_window;
        statistical_alpha = source_config.statistical_alpha;
        fdr_correction = source_config.fdr_correction;

        fprintf('Configuration:\n');
        fprintf('  Beat comparison: %s\n', beat_comparison);
        fprintf('  Beat reference: %s\n', beat_reference);
        fprintf('  Group: %s\n', group_select);
        fprintf('  Regularization values: %s\n', mat2str([regularization_values{:}]));
        fprintf('  Aggregation methods: %s\n', strjoin(agg_methods, ', '));
        fprintf('  Time window: [%.3f, %.3f] s\n', time_window(1), time_window(2));
        fprintf('  Statistical alpha: %.3f\n', statistical_alpha);
        fprintf('  FDR correction: %s\n', mat2str(fdr_correction));

        %% Load required files
        fprintf('Loading eLORETA forward models...\n');
        precomputed_path = source_config.paths.precomputed_path;

        % Load eLORETA matrices and anatomical data
        source_atlas = load(fullfile(precomputed_path, 'source_atlas_eloreta.mat'));
        roi_atlas = load(fullfile(precomputed_path, 'roi_labels_harvard_oxford.mat'));
        colormap_data = load(fullfile(precomputed_path, 'cm17.mat'));

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

        % Use smart loading function to avoid redundant loading
        [allsubj_PC, ~] = load_allsubj_data(full_data_path);

        %% Select group data
        group_data = allsubj_PC.(group_select);

        % Convert beat types to valid MATLAB field names
        beat_comparison_field = beattype_to_fieldname(beat_comparison);
        beat_reference_field = beattype_to_fieldname(beat_reference);

        comparison_data = group_data.(beat_comparison_field);
        reference_data = group_data.(beat_reference_field);

        if isempty(comparison_data) || isempty(reference_data)
            error('No data found for the specified beat comparison or reference.');
        end

        n_subjects = length(comparison_data);
        fprintf('Loaded data for %d subjects\n', n_subjects);

        %% Initialize storage for all pipeline results
        n_regularization = length(regularization_values);
        n_agg = length(agg_methods);
        n_pipelines = n_regularization * n_agg;
        n_rois = length(hep_roi_indices);

        % Clean ROI labels (remove special characters)
        roi_labels_clean = cellfun(@(x) strrep(x, ',', ''), roi_labels, 'UniformOutput', false);
        roi_labels_clean = cellfun(@(x) strrep(x, ' (formerly Supplementary Motor Cortex)', ''), ...
            roi_labels_clean, 'UniformOutput', false);
        roi_labels_hep = roi_labels_clean(hep_roi_indices);

        % Storage for p-values from all pipelines
        all_pipeline_pvalues = zeros(n_pipelines, n_rois);
        pipeline_info = cell(n_pipelines, 2); % regularization_value, agg_method

        fprintf('\nRunning %d analysis pipelines...\n', n_pipelines);

        %% Loop through all pipeline combinations
        pipeline_idx = 0;

        for i_reg = 1:n_regularization
            regularization_value = regularization_values{i_reg};

            % Select appropriate forward model based on regularization value
            forward_model = select_eloreta_forward_model(regularization_value, ...
                forward_model_smooth, forward_model_standard, forward_model_focal);

            for i_agg = 1:n_agg
                agg_method = agg_methods{i_agg};
                pipeline_idx = pipeline_idx + 1;

                fprintf('\nPipeline %d/%d: regularization=%.3f, agg=%s\n', ...
                    pipeline_idx, n_pipelines, regularization_value, agg_method);

                % Store pipeline information
                pipeline_info{pipeline_idx, 1} = regularization_value;
                pipeline_info{pipeline_idx, 2} = agg_method;

                %% Perform source reconstruction for this pipeline
                [source_comparison_ROI, source_reference_ROI] = ...
                    reconstruct_sources_eloreta(comparison_data, reference_data, ...
                    forward_model, centering_matrix, channels_to_remove, roi_voxel_indices, ...
                    hep_roi_indices, roi_signflip, time_window, agg_method);

                %% Statistical testing
                [~, p_values, ~, ~] = ttest(source_comparison_ROI, source_reference_ROI, ...
                    'Dim', 2, 'Alpha', statistical_alpha, 'Tail', 'both');

                % Apply FDR correction if requested
                if fdr_correction
                    p_values_corrected = mafdr(p_values, 'BHFDR', true);
                else
                    p_values_corrected = p_values;
                end

                % Store p-values for this pipeline
                all_pipeline_pvalues(pipeline_idx, :) = p_values_corrected;

                % Report significant ROIs for this pipeline
                sig_rois = find(p_values_corrected < statistical_alpha);
                fprintf('  Found %d significant ROIs (p < %.3f)\n', ...
                    length(sig_rois), statistical_alpha);
            end

        end

        %% Calculate percentage of pipelines showing significance per ROI
        fprintf('\nCalculating percentage of significant pipelines per ROI...\n');

        sig_pipeline_count = sum(all_pipeline_pvalues < statistical_alpha, 1);
        sig_pipeline_percentage = (sig_pipeline_count / n_pipelines) * 100;

        fprintf('ROI significance summary:\n');

        for i = 1:n_rois

            if sig_pipeline_percentage(i) > 0
                fprintf('  %s: %.1f%% of pipelines significant\n', ...
                    roi_labels_hep{i}, sig_pipeline_percentage(i));
            end

        end

        %% Create source space visualization
        fprintf('\nCreating source space visualization...\n');

        % Map HEP ROI percentages to full brain volume
        source_sig_visualization = zeros(n_voxels, 1);

        for i = 1:n_rois
            roi_idx = hep_roi_indices(i);
            voxel_indices = roi_voxel_indices{roi_idx};
            source_sig_visualization(voxel_indices) = sig_pipeline_percentage(i);
        end

        % Create title for visualization
        % Generate automatic labels
        [comparison_label, reference_label] = create_condition_labels(beat_comparison, beat_reference, ...
            group_select, false, false);
        title_name = sprintf('$\\textrm{HEP}_{\\textrm{%s}}\\textrm{ vs. }\\textrm{HEP}_{\\textrm{%s}}$', ...
            comparison_label, reference_label);

        % Generate source space plot
        visualize_hep_source_brain(cortex_surface, source_sig_visualization(cortex_surface.cortex5K.in_to_cortex75K_geod), ...
            [0 100], colormap_brain, 'xx', 1, 'views', [1, 2, 3, 4, 5, 8], 'save', 0);

        % Save figure with consistent naming convention (source space is always within-subject)
        output_filename_base = sprintf('sourcespace_within_%s_%s_vs_%s', ...
            group_select, beat_comparison, beat_reference);
        save_multiverse_source_figure(title_name, output_path, output_filename_base);

        fprintf('Brain visualization saved\n');

        %% Export results to CSV
        fprintf('Exporting results to CSV...\n');

        % Add metadata
        metadata = create_source_metadata(source_config, n_subjects, n_pipelines, ...
            statistical_alpha, fdr_correction);

        % Create comprehensive results table with metadata integrated
        results_table = create_source_results_table(all_pipeline_pvalues, pipeline_info, ...
            roi_labels_hep, statistical_alpha);

        % Save CSV file with metadata header
        csv_filename = sprintf('%s_results.csv', output_filename_base);
        save_source_results_with_metadata(results_table, metadata, output_path, csv_filename);

        fprintf('Results exported to: %s\n', csv_filename);

        %% Save MATLAB workspace
        save_filename = sprintf('%s.mat', output_filename_base);
        save_data = struct();
        save_data.all_pipeline_pvalues = all_pipeline_pvalues;
        save_data.sig_pipeline_percentage = sig_pipeline_percentage;
        save_data.pipeline_info = pipeline_info;
        save_data.roi_labels_hep = roi_labels_hep;
        save_data.config_used = source_config;
        save_data.metadata = metadata;
        save_data.analysis_date = datestr(now);

        save(fullfile(output_path, save_filename), 'save_data');
        fprintf('MATLAB results saved to: %s\n', save_filename);

        fprintf('\n=== eLORETA Source Analysis completed successfully ===\n\n');

    catch ME
        %% Error handling
        error_msg = sprintf('Error in a_8_source_analysis: %s\n%s', ME.message, getReport(ME));
        fprintf(2, '%s\n', error_msg);

        % Log error
        error_log_file = fullfile(error_log_path, sprintf('source_eloreta_error_%s.txt', ...
            datestr(now, 'yyyymmdd_HHMMSS')));
        fid = fopen(error_log_file, 'w');
        fprintf(fid, '%s', error_msg);
        fclose(fid);

        rethrow(ME);
    end

end
