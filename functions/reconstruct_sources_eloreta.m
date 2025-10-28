function [source_comparison_ROI, source_reference_ROI] = ...
        reconstruct_sources_eloreta(comparison_data, reference_data, forward_model, ...
        centering_matrix, channels_to_remove, roi_voxel_indices, hep_roi_indices, ...
        roi_signflip, time_window, aggregation_method, reference_time_window)
    % RECONSTRUCT_SOURCES_ELORETA - Perform eLORETA source reconstruction
    %
    % Inputs:
    %   comparison_data          - Cell array of comparison condition data (one per subject)
    %   reference_data           - Cell array of reference condition data (one per subject)
    %   forward_model            - eLORETA forward model matrix
    %   centering_matrix         - Centering matrix for data preprocessing
    %   channels_to_remove       - Channels to exclude from analysis
    %   roi_voxel_indices        - Cell array of voxel indices for each ROI
    %   hep_roi_indices          - Indices of HEP-relevant ROIs
    %   roi_signflip             - Sign flip information for ROIs
    %   time_window              - Time window for comparison [start, end] in seconds
    %   aggregation_method       - Aggregation method ('avg' or 'avg-sf')
    %   reference_time_window    - (Optional) Different time window for reference [start, end]
    %                              If not provided, uses same as comparison
    %
    % Outputs:
    %   source_comparison_ROI - Source activity in HEP ROIs for comparison (n_ROI x n_subjects)
    %   source_reference_ROI  - Source activity in HEP ROIs for reference (n_ROI x n_subjects)
    %
    % Author: Pia Reinfeld
    % Date: 2025

    % Handle optional reference time window
    if nargin < 11 || isempty(reference_time_window)
        reference_time_window = time_window;
    end

    n_subjects = length(comparison_data);
    n_roi_hep = length(hep_roi_indices);

    % Initialize output matrices
    source_comparison_ROI = zeros(n_roi_hep, n_subjects);
    source_reference_ROI = zeros(n_roi_hep, n_subjects);

    % Process each subject
    for subj = 1:n_subjects

        % Get time indices for comparison window
        time_vector_comp = comparison_data{subj}.time;
        time_idx_comp = time_vector_comp >= time_window(1) & time_vector_comp <= time_window(2);

        % Get time indices for reference window (may be different)
        time_vector_ref = reference_data{subj}.time;
        time_idx_ref = time_vector_ref >= reference_time_window(1) & time_vector_ref <= reference_time_window(2);

        % Extract and average data over time windows
        comparison_subj = mean(comparison_data{subj}.avg(:, time_idx_comp), 2);
        reference_subj = mean(reference_data{subj}.avg(:, time_idx_ref), 2);

        % Remove excluded channels
        comparison_subj(channels_to_remove, :) = [];
        reference_subj(channels_to_remove, :) = [];

        % Apply centering matrix
        comparison_subj = centering_matrix * comparison_subj;
        reference_subj = centering_matrix * reference_subj;

        % Apply forward model (eLORETA)
        source_comparison_subj = double(ttm(tensor(forward_model), comparison_subj', 1));
        source_reference_subj = double(ttm(tensor(forward_model), reference_subj', 1));

        % Extract ROI values
        for i_roi = 1:n_roi_hep
            roi_idx = hep_roi_indices(i_roi);
            voxel_indices = roi_voxel_indices{roi_idx};

            % Aggregate voxels within ROI
            source_comparison_ROI(i_roi, subj) = voxel2roi(source_comparison_subj(voxel_indices), ...
                aggregation_method, 1, roi_signflip(voxel_indices));
            source_reference_ROI(i_roi, subj) = voxel2roi(source_reference_subj(voxel_indices), ...
                aggregation_method, 1, roi_signflip(voxel_indices));
        end

    end

end
