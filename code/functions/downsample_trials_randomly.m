function [downsampled_data, was_downsampled, original_n_trials, final_n_trials] = downsample_trials_randomly(data, target_n_trials, subject_idx)
    % DOWNSAMPLE_TRIALS_RANDOMLY - Randomly downsample trials to match target number
    %
    % This function randomly downsamples the number of trials in a FieldTrip
    % data structure to match a target number. Useful for balancing trial counts
    % between conditions to avoid bias in statistical analysis.
    %
    % Inputs:
    %   data            - FieldTrip data structure with 'trial' field
    %   target_n_trials - Target number of trials to downsample to
    %   subject_idx     - Subject index (for logging purposes)
    %
    % Outputs:
    %   downsampled_data   - Data structure with randomly selected trials
    %   was_downsampled    - Boolean indicating if downsampling occurred
    %   original_n_trials  - Original number of trials
    %   final_n_trials     - Final number of trials after downsampling
    %
    % Example:
    %   [data_ds, was_ds, n_orig, n_final] = downsample_trials_randomly(data, 100, 1);
    %
    % Author: Pia Reinfeld
    % Date: October 2025

    downsampled_data = data;
    was_downsampled = false;
    original_n_trials = 0;
    final_n_trials = 0;

    % Check if data has trials
    if ~isfield(data, 'trial') || isempty(data.trial)
        warning('Subject %d: No trial field found or empty, skipping downsampling', subject_idx);
        return;
    end

    % Trials are in 3D matrix format: [trials × channels × timepoints]
    original_n_trials = size(data.trial, 1);

    % Check if downsampling is needed
    if original_n_trials <= target_n_trials
        % No downsampling needed
        final_n_trials = original_n_trials;
        fprintf('  Subject %d: No downsampling needed (%d trials <= %d target)\n', ...
            subject_idx, original_n_trials, target_n_trials);
        return;
    end

    % Perform random downsampling
    fprintf('  Subject %d: Downsampling from %d to %d trials\n', ...
        subject_idx, original_n_trials, target_n_trials);

    % Randomly select trials
    rng(42); % Set seed
    selected_indices = randperm(original_n_trials, target_n_trials);
    selected_indices = sort(selected_indices); % Sort to maintain temporal order

    % Downsample trial data (3D matrix format)
    downsampled_data.trial = data.trial(selected_indices, :, :);

    % Downsample sampleinfo if present
    if isfield(data, 'sampleinfo')
        downsampled_data.sampleinfo = data.sampleinfo(selected_indices, :);
    end

    % Downsample trialinfo if present
    if isfield(data, 'trialinfo')
        downsampled_data.trialinfo = data.trialinfo(selected_indices, :);
    end

    was_downsampled = true;
    final_n_trials = target_n_trials;

end
