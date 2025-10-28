function metadata = create_timewise_source_metadata(source_config, n_subjects, n_pipelines, ...
        n_time_windows, statistical_alpha, fdr_correction)
    % CREATE_TIMEWISE_SOURCE_METADATA - Create metadata for time-resolved source analysis
    %
    % Inputs:
    %   source_config     - Source configuration structure
    %   n_subjects        - Number of subjects analyzed
    %   n_pipelines       - Number of analysis pipelines
    %   n_time_windows    - Number of time windows analyzed
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
    metadata.analysis_type = 'eLORETA_source_reconstruction_timewise';
    metadata.analysis_date = datestr(now);
    metadata.n_subjects = n_subjects;
    metadata.n_pipelines = n_pipelines;
    metadata.n_time_windows = n_time_windows;

    % Comparison details
    metadata.beat_comparison = 'PC+1';
    metadata.beat_reference = 'PC-3';
    metadata.group_select = source_config.group_select;

    % Pipeline parameters
    metadata.regularization_values_str = strjoin(cellfun(@num2str, source_config.regularization_values, ...
        'UniformOutput', false), ', ');
    metadata.agg_methods_str = strjoin(source_config.agg_methods, ', ');

    % Time windows
    metadata.pc_plus1_window_start = source_config.pc_plus1_window(1);
    metadata.pc_plus1_window_end = source_config.pc_plus1_window(2);

    % PC-3 time windows as string
    pc_minus3_windows_str = cell(n_time_windows, 1);

    for i = 1:n_time_windows
        window = source_config.pc_minus3_windows{i};
        pc_minus3_windows_str{i} = sprintf('[%.3f, %.3f]', window(1), window(2));
    end

    metadata.pc_minus3_windows_str = strjoin(pc_minus3_windows_str, '; ');

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
