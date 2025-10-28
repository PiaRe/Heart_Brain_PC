function save_source_results_with_metadata(results_table, metadata, save_path, filename)
    % SAVE_SOURCE_RESULTS_WITH_METADATA - Save source analysis results with metadata header
    %
    % This function saves source reconstruction multiverse analysis results to a CSV file
    % with comprehensive metadata included as comments at the top of the file.
    %
    % Inputs:
    %   results_table - Table containing p-values and significance flags for all pipelines and ROIs
    %   metadata      - Structure containing analysis metadata (config, parameters, etc.)
    %   save_path     - Directory path where CSV file should be saved
    %   filename      - Filename for the CSV file (with or without .csv extension)
    %
    % Output:
    %   Creates a CSV file with metadata header followed by analysis results
    %
    % Example:
    %   save_source_results_with_metadata(results_table, metadata, '/output/', 'source_results.csv')
    %
    % See also: create_source_metadata, create_source_results_table
    %
    % Author: Pia Reinfeld
    % Date: 2025
    % Project: Heart_Brain_PC (HEP_ES Analysis)

    % Ensure save path exists
    if ~exist(save_path, 'dir')
        mkdir(save_path);
        fprintf('Created output directory: %s\n', save_path);
    end

    % Ensure filename has .csv extension
    if ~endsWith(filename, '.csv')
        filename = [filename, '.csv'];
    end

    % Full file path
    csv_file = fullfile(save_path, filename);

    % Open CSV file for writing
    fid = fopen(csv_file, 'w');

    if fid == -1
        error('save_source_results_with_metadata:FileError', ...
            'Could not create CSV file: %s', csv_file);
    end

    try
        %% Write metadata header
        fprintf(fid, '# ====== SOURCE ANALYSIS METADATA ======\n');
        fprintf(fid, '# Analysis Type: eLORETA Source Reconstruction - Multiverse Analysis\n');
        fprintf(fid, '# Date: %s\n', getfield_or_default(metadata, 'analysis_date', datestr(now)));
        fprintf(fid, '#\n');

        % Comparison details
        fprintf(fid, '# --- Comparison Details ---\n');
        fprintf(fid, '# Beat Comparison: %s\n', getfield_or_default(metadata, 'beat_comparison', 'N/A'));
        fprintf(fid, '# Beat Reference: %s\n', getfield_or_default(metadata, 'beat_reference', 'N/A'));
        fprintf(fid, '# Group: %s\n', getfield_or_default(metadata, 'group_select', 'N/A'));
        fprintf(fid, '# N Subjects: %d\n', getfield_or_default(metadata, 'n_subjects', 0));
        fprintf(fid, '#\n');

        % Preprocessing parameters
        fprintf(fid, '# --- Preprocessing Parameters ---\n');
        fprintf(fid, '# ICA Applied: %s\n', getfield_or_default(metadata, 'ica_status', 'N/A'));
        fprintf(fid, '# Baseline Correction: %s (%.0f to %.0f ms)\n', ...
            getfield_or_default(metadata, 'baseline_option', 'N/A'), ...
            getfield_or_default(metadata, 'baseline_start', 0), ...
            getfield_or_default(metadata, 'baseline_end', 0));
        fprintf(fid, '# Epoch Length: %.0f to %.0f ms\n', ...
            getfield_or_default(metadata, 'epoch_start', 0), ...
            getfield_or_default(metadata, 'epoch_end', 0));
        fprintf(fid, '#\n');

        % Source reconstruction parameters
        fprintf(fid, '# --- Source Reconstruction Parameters ---\n');
        fprintf(fid, '# Method: eLORETA (exact low resolution electromagnetic tomography)\n');
        fprintf(fid, '# Forward Model: Perpendicular dipoles\n');
        fprintf(fid, '# Atlas: Harvard-Oxford cortical/subcortical atlas\n');
        fprintf(fid, '# ROIs Analyzed: HEP-relevant ROIs only\n');
        fprintf(fid, '# Time Window: %.3f to %.3f s\n', ...
            getfield_or_default(metadata, 'time_window_start', 0), ...
            getfield_or_default(metadata, 'time_window_end', 0));
        fprintf(fid, '#\n');

        % Multiverse analysis parameters
        fprintf(fid, '# --- Multiverse Analysis Parameters ---\n');
        fprintf(fid, '# N Pipelines: %d\n', getfield_or_default(metadata, 'n_pipelines', 0));
        fprintf(fid, '# Regularization Values: %s\n', getfield_or_default(metadata, 'regularization_values_str', 'N/A'));
        fprintf(fid, '# Aggregation Methods: %s\n', getfield_or_default(metadata, 'agg_methods_str', 'N/A'));
        fprintf(fid, '#\n');

        % Statistical parameters
        fprintf(fid, '# --- Statistical Parameters ---\n');
        fprintf(fid, '# Test: Paired t-test (within-subject comparison)\n');
        fprintf(fid, '# Tail: Two-tailed\n');
        fprintf(fid, '# Alpha: %.3f\n', getfield_or_default(metadata, 'statistical_alpha', 0.05));
        fprintf(fid, '# FDR Correction: %s\n', getfield_or_default(metadata, 'fdr_correction', 'N/A'));
        fprintf(fid, '#\n');

        % Results interpretation
        fprintf(fid, '# --- Results Interpretation ---\n');
        fprintf(fid, '# Each row represents one analysis pipeline (alpha + aggregation method combination)\n');
        fprintf(fid, '# P-values shown are FDR-corrected (if enabled) for multiple comparisons across ROIs\n');
        fprintf(fid, '# Significant flag = 1 indicates p < %.3f for that ROI in that pipeline\n', ...
            getfield_or_default(metadata, 'statistical_alpha', 0.05));
        fprintf(fid, '# Percentage of significant pipelines per ROI indicates robustness across analysis choices\n');
        fprintf(fid, '# ================================\n');
        fprintf(fid, '#\n');

        %% Write table data
        % Get variable names
        var_names = results_table.Properties.VariableNames;

        % Write column headers
        fprintf(fid, '%s\n', strjoin(var_names, ','));

        % Write data rows
        n_rows = height(results_table);

        for i = 1:n_rows
            row_data = cell(1, length(var_names));

            for j = 1:length(var_names)
                value = results_table{i, j};

                if iscell(value)
                    value = value{1};
                end

                if ischar(value) || isstring(value)
                    row_data{j} = char(value);
                elseif islogical(value)
                    row_data{j} = num2str(double(value));
                elseif isnumeric(value)

                    if isnan(value)
                        row_data{j} = 'NaN';
                    else
                        row_data{j} = num2str(value, '%.6f');
                    end

                else
                    row_data{j} = '';
                end

            end

            fprintf(fid, '%s\n', strjoin(row_data, ','));
        end

        % Close file
        fclose(fid);

        fprintf('Source results with metadata saved to: %s\n', csv_file);

    catch ME
        % Make sure file is closed even if error occurs
        if fid > 0
            fclose(fid);
        end

        rethrow(ME);
    end

end

%% Helper function to safely get field or return default
function value = getfield_or_default(s, fieldname, default_value)

    if isfield(s, fieldname)
        value = s.(fieldname);

        % Convert logical to string for display
        if islogical(value)

            if value
                value = 'yes';
            else
                value = 'no';
            end

        end

    else
        value = default_value;
    end

end
