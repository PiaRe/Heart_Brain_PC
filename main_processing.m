%% MAIN_PROCESSING_PIPELINE - Heart Brain Premature Contractions analysis
%
% This script implements the main preprocessing pipeline for analysing the effects of premature
% contractions on the Heartbeat Evoked Potential. The pipeline includes:
%   - Path initialization and directory setup.
%   - Preprocessing of the EEG and ECG data.
%   - Initial preprocessing steps: filtering, downsampling, and ICA.
%   - ICA component selection and application to filtered data.
%   - HEP analysis.
%   - Source Space analysis.
%   - Control Analysis
%
% Key steps:
% 1. Path setup and library initialization (e.g., EEGLAB, HEPLAB, Fieldtrip).
% 2. File management: ensuring the required directories exist.
% 3. Preprocessing of EEG data.
% 4. Artifact correction using ICA.
% 5. Statistical analysis of time-domain HEP.
% 6. Statistical analysis of HEP in source space.
% 7. Statistical analyses to control for artefacts.
%
% Requirements:
%   - EEGLAB toolbox with bva_io, erp_lab plugins, and HEPLAB and Fieldtrip dependencies.
%   - EEG data in BrainVision format (.vhdr, .vmrk, .eeg).
%
% Outputs:
%   - Preprocessed EEG data (filtered, ICA-applied) saved in project directories.
%   - Logfiles for errors encountered during preprocessing.
%   - Statistical results.
%
% Author:
%   Pia Reinfeld, Paul Steinfath
%
% Example:
%   Run the script to process task and rest EEG data:
%     1. Filter and preprocess data.
%     2. Perform ICA and correct artifacts.
%     3. Perform statistical analysis.

%% Initialize workspace
clc; clear all; close all; % Clear command window, variables, and figures.

%% Initialize configuration
% Load centralized configuration
config = setup_project_config();

% Add required paths
addpath(config.paths.eeglab);
addpath([config.paths.base_code, 'functions']);
addpath([config.paths.base_code, 'Preprocessing/']);
addpath([config.paths.base_code, 'Stats/Timedomain/']);
addpath([config.paths.base_code, 'Stats/SourceSpace/']);
addpath([config.paths.base_code, 'Stats/ControlAnalysis/']);

addpath(config.paths.heplab);
addpath(config.paths.fieldtrip);
addpath(genpath(config.paths.boundedline));

% Create all task directories
dirs_to_create = {config.paths.no_ica_path, config.paths.pre_ica_path, ...
                      config.paths.post_ica_path, config.paths.epochs_path, ...
                      config.paths.output_path, config.paths.qa_path, config.paths.error_log_path};
create_dirs(dirs_to_create);

% Initialize EEGLAB
eeglab; close;

%% Step 1: Initial preprocessing and ICA
% fprintf('Running step 1a: Initial preprocessing of data for ICA\n');
% a_1_preprocessing(config.paths.raw_data, config.paths.crop_marker_path, ...
%     config.paths.pre_ica_path, config.paths.error_log_path, ...
%     config.processing.sampling_rate, config.electrodes.file, ...
%     config.processing.ica_highpass_cutoff, config.processing.ica_lowpass_cutoff, ...
%     config.processing.line_noise_frequency, config.processing.flatline_criterion, ...
%     config.processing.artifact_threshold)

% fprintf('Running step 1b: Initial preprocessing of analysis data\n');
% a_1_preprocessing(config.paths.raw_data, config.paths.crop_marker_path, ...
%     config.paths.no_ica_path, config.paths.error_log_path, ...
%     config.processing.sampling_rate, config.electrodes.file, ...
%     config.processing.highpass_cutoff, config.processing.lowpass_cutoff, ...
%     config.processing.line_noise_frequency, config.processing.flatline_criterion, ...
%     config.processing.artifact_threshold)

%% Step 2: Import events (timepoints of R-peaks)
% fprintf('Running step 2a: Importing ECG events and beats for ICA data\n');
% a_2_import_events(config.paths.pre_ica_path, config.paths.event_data, ...
%     config.paths.pre_ica_path, config.paths.error_log_path, ...
%     config.beat_types.analysis_labels, config.beat_types.raw_file_labels)

% fprintf('Running step 2b: Importing ECG events and beats for analysis data\n');
% a_2_import_events(config.paths.no_ica_path, config.paths.event_data, ...
%     config.paths.no_ica_path, config.paths.error_log_path, ...
%     config.beat_types.analysis_labels, config.beat_types.raw_file_labels)

%% Step 3: Run ICA and remove artifactual components
fprintf('Running step 3: Running ICA and removing components\n');
a_3_run_ICA(config.paths.no_ica_path, config.paths.pre_ica_path, config.paths.post_ica_path, ...
    config.paths.error_log_path, config.paths.qa_path, ...
    config.ica.analysis_window, config.thresholds, ...
    config.beat_types.analysis_labels)

%% Step 4: Run time domain analysis
% fprintf('Running step 4: Analysing the HEP in the time domain\n');
% a_4_run_timedomain(config.paths.filtered_data_path, config.hep.epoch_length, ...
%                    config.hep.baseline_time, config.hep.baseline_option, config.hep.ica_option)
