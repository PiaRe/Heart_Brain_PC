function results_table = create_source_results_table(pipeline_pvalues, pipeline_info, ...
        roi_labels, significance_threshold)
    % CREATE_SOURCE_RESULTS_TABLE - Create comprehensive results table for source analysis
    %
    % Inputs:
    %   pipeline_pvalues       - Matrix of p-values (n_pipelines x n_rois)
    %   pipeline_info          - Cell array with pipeline details
    %   roi_labels             - Cell array of ROI labels
    %   significance_threshold - Alpha threshold for significance
    %
    % Outputs:
    %   results_table - Table containing all results with p-values and significance flags
    %
    % Author: Pia Reinfeld
    % Date: 2025

    n_rois = size(pipeline_pvalues, 2);

    % Create table columns from pipeline_info
    regularization_values_num = cell2mat(pipeline_info(:, 1));
    agg_methods = pipeline_info(:, 2);

    % Create regularization labels based on values
    regularization_labels = cell(size(regularization_values_num));

    for i = 1:length(regularization_values_num)

        if regularization_values_num(i) == 0.5
            regularization_labels{i} = 'smooth';
        elseif regularization_values_num(i) == 0.05
            regularization_labels{i} = 'standard';
        elseif regularization_values_num(i) == 0.001
            regularization_labels{i} = 'focal';
        else
            regularization_labels{i} = sprintf('reg_%.3f', regularization_values_num(i));
        end

    end

    % Convert regularization values to strings for table
    regularization_values_str = cellfun(@num2str, pipeline_info(:, 1), 'UniformOutput', false);

    % Add p-values for each ROI
    roi_data = cell(1, n_rois);

    for i = 1:n_rois
        roi_data{i} = pipeline_pvalues(:, i);
    end

    % Add significance flags for each ROI
    sig_data = cell(1, n_rois);
    sig_labels = cell(1, n_rois);

    for i = 1:n_rois
        sig_data{i} = pipeline_pvalues(:, i) < significance_threshold;
        sig_labels{i} = [roi_labels{i}, '_significant'];
    end

    % Combine into table
    results_table = table(regularization_values_str, regularization_labels, agg_methods, ...
        'VariableNames', {'regularization_value', 'regularization_label', 'agg_method'});

    % Add p-values
    for i = 1:n_rois
        results_table.(roi_labels{i}) = roi_data{i};
    end

    % Add significance flags
    for i = 1:n_rois
        results_table.(sig_labels{i}) = sig_data{i};
    end

end
