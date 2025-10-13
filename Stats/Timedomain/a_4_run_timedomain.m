function a_4_run_timedomain(filtered_path, epoch_length, baseline_time, baseline_option, ica_option)
% A_4_RUN_TIMEDOMAIN - Run time domain HEP analysis
%
% This function performs time domain analysis of the Heartbeat Evoked Potential:
%   - Band-pass filtering (high-pass and low-pass)
%   - Notch filtering for line noise
%   - Downsampling to a specified sampling rate
%   - Channel selection and removal of bad channels
%   - Artifact removal and interpolation
%   - Independent Component Analysis (ICA)
%
% Inputs:
%   filtered_path    - Path to filtered data
%   epoch_length     - Time window for epochs [start, end] in ms
%   baseline_time    - Baseline time window [start, end] in ms
%   baseline_option  - Baseline option ('no', 'ref', 'int')
%   ica_option       - ICA option ('yes', 'no')
% Outputs:
%   No direct outputs. Preprocessed EEG data is saved to `savepath` in `.set` format.
%
% Author: Pia Reinfeld

fprintf('Starting time domain HEP analysis...\n');

% TODO: Implement time domain analysis
% - Load data
% - Create epochs
% - Apply baseline correction
% - Calculate HEP
% - Perform statistics

fprintf('Time domain HEP analysis completed.\n');

end
