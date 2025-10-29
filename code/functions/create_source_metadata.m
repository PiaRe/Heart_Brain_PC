function metadata = create_source_metadata(source_config, n_subjects, n_pipelines, ...
        statistical_alpha, fdr_correction)
    % CREATE_SOURCE_METADATA - Create metadata structure for source analysis
    %
    % Inputs:
    %   source_config     - Source configuration structure
    %   n_subjects        - Number of subjects analyzed
    %   n_pipelines       - Number of analysis pipelines
    %   statistical_alpha - Alpha level used for significance testing
    %   fdr_correction    - Whether FDR correction was applied
    %
    % Outputs:
    %   metadata - Structure containing comprehensive analysis metadata
    %
    % Author: Pia Reinfeld
    % Date: 2025

    metadata = struct();

    % Analysis details
    metadata.analysis_type = 'eLORETA_source_reconstruction';
    metadata.analysis_date = datestr(now);
    metadata.n_subjects = n_subjects;
    metadata.n_pipelines = n_pipelines;

    % Comparison details
    metadata.beat_comparison = source_config.beat_comparison;
    metadata.beat_reference = source_config.beat_reference;
    metadata.group_select = source_config.group_select;

    % Pipeline parameters
    metadata.regularization_values_str = strjoin(cellfun(@num2str, source_config.regularization_values, ...
        'UniformOutput', false), ', ');
    metadata.agg_methods_str = strjoin(source_config.agg_methods, ', ');

    % Time window
    metadata.time_window_start = source_config.time_window(1);
    metadata.time_window_end = source_config.time_window(2);

    % Statistical parameters
    metadata.statistical_alpha = statistical_alpha;
    metadata.fdr_correction = fdr_correction;

    % HEP parameters
    if isfield(source_config, 'hep_params')
        hep = source_config.hep_params;
        metadata.baseline_option = hep.baseline_option;
        metadata.baseline_start = hep.baseline_time(1);
        metadata.baseline_end = hep.baseline_time(2);
        metadata.epoch_start = hep.epoch_length(1);
        metadata.epoch_end = hep.epoch_length(2);
        metadata.ica_status = hep.ica_status;
    end

end
