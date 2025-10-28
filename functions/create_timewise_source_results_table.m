function results_table = create_timewise_source_results_table(all_time_windows_pvalues, ...
        pipeline_info, roi_labels, pc_minus3_windows, significance_threshold)
    % CREATE_TIMEWISE_SOURCE_RESULTS_TABLE - Create results table for time-resolved source analysis
    %
    % Inputs:
    %   all_time_windows_pvalues - Cell array of p-value matrices, one per time window
    %   pipeline_info            - Cell array with pipeline details (reg_value, agg_method)
    %   roi_labels               - Cell array of ROI labels
    %   pc_minus3_windows        - Cell array of PC-3 time windows
    %   significance_threshold   - Alpha threshold for significance
    %
    % Outputs:
    %   results_table - Table containing all results with p-values and significance flags
    %
    % Author: Pia Reinfeld
    % Date: 2025

    n_time_windows = length(all_time_windows_pvalues);
    n_pipelines = size(pipeline_info, 1);
    n_rois = length(roi_labels);

    % Create time window labels
    time_window_labels = cell(n_time_windows, 1);

    for tw = 1:n_time_windows
        window = pc_minus3_windows{tw};
        time_window_labels{tw} = sprintf('%.3f_%.3f', window(1), window(2));
    end

    % Initialize table with all rows (n_time_windows * n_pipelines)
    n_total_rows = n_time_windows * n_pipelines;

    % Pre-allocate cell arrays for table columns
    time_window_col = cell(n_total_rows, 1);
    regularization_values_col = cell(n_total_rows, 1);
    regularization_labels_col = cell(n_total_rows, 1);
    agg_methods_col = cell(n_total_rows, 1);

    % Create regularization labels
    regularization_values_num = cell2mat(pipeline_info(:, 1));
    regularization_labels = cell(n_pipelines, 1);

    for i = 1:n_pipelines

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

    % Fill in metadata columns and collect ROI data
    roi_pvalues = zeros(n_total_rows, n_rois);
    row_idx = 0;

    for tw = 1:n_time_windows
        pipeline_pvalues = all_time_windows_pvalues{tw};

        for p = 1:n_pipelines
            row_idx = row_idx + 1;

            time_window_col{row_idx} = time_window_labels{tw};
            regularization_values_col{row_idx} = num2str(pipeline_info{p, 1});
            regularization_labels_col{row_idx} = regularization_labels{p};
            agg_methods_col{row_idx} = pipeline_info{p, 2};

            roi_pvalues(row_idx, :) = pipeline_pvalues(p, :);
        end

    end

    % Create base table
    results_table = table(time_window_col, regularization_values_col, regularization_labels_col, ...
        agg_methods_col, 'VariableNames', ...
        {'time_window_PCm3', 'regularization_value', 'regularization_label', 'agg_method'});

    % Add p-values for each ROI
    for i = 1:n_rois
        results_table.(roi_labels{i}) = roi_pvalues(:, i);
    end

    % Add significance flags for each ROI
    for i = 1:n_rois
        sig_label = [roi_labels{i}, '_significant'];
        results_table.(sig_label) = roi_pvalues(:, i) < significance_threshold;
    end

end
