%% MAIN_PROCESSING_PIPELINE - Heart Brain Premature Contractions analysis
%
% This script implements the complete analysis pipeline for investigating the effects of premature
% contractions on the Heartbeat Evoked Potential (HEP). The pipeline is structured into sequential
% steps, progressing from preprocessing to statistical analysis and control analyses.
%
% Pipeline Structure:
%   STEPS 1-7: PC Group - Main Analysis
%     1. Initial preprocessing and ICA (filtering, downsampling)
%     2. Import ECG events (R-peak timepoints)
%     3. Run ICA and remove artifactual components
%     4. Reintegrate ECG channel (ICA-corrected and non-ICA data)
%     5. Epoch data for time domain HEP analysis
%     6. EEG statistics in time domain (within-group and PAC vs PVC)
%     7. ECG statistics in time domain (within-group and PAC vs PVC)
%
%   STEP 8: Source Space Analysis
%     - Source reconstruction and statistical analysis
%
%   STEP 9: Control Analysis - Correlation Analysis (CFA)
%     - Controlling for cardiac field artifacts through correlation analysis
%
%   STEP 10: Control Analysis - T-Wave Amplitude
%     - Control analysis for T-wave amplitude effects
%
%   STEP 11: Control Group - Complete Preprocessing and Statistics
%     - Full preprocessing pipeline for control subjects (steps 1-2c, 3-5)
%     - Step 2c: R-peak detection from EOG_EKG channel (no external ECG files)
%     - PC vs Control group comparisons (EEG and ECG)
%
% Requirements:
%   - EEGLAB toolbox with bva_io, erp_lab plugins
%   - HEPLAB and Fieldtrip toolboxes
%   - EEG data in BrainVision format (.vhdr, .vmrk, .eeg)
%   - ECG event files with R-peak annotations
%
% Outputs:
%   - Preprocessed EEG data (filtered, ICA-applied) in project directories
%   - Epoched data for HEP analysis
%   - Statistical results (time domain, source space)
%   - Quality assurance reports and error logs
%
% Authors:
%   Pia Reinfeld, Paul Steinfath
%
% Usage:
%   1. Configure paths and parameters in setup_project_config.m
%   2. Uncomment desired analysis steps in this script
%   3. Run the script to execute the complete pipeline

%% Initialize workspace
clc; clear; close all; % Clear command window, variables, and figures.

%% Initialize configuration
% Load centralized configuration
config = setup_project_config();

% Add required paths
addpath(config.paths.eeglab);
addpath([config.paths.base_code, 'functions']);
addpath([config.paths.base_code, 'preprocessing/']);
addpath([config.paths.base_code, 'timedomain/']);
addpath([config.paths.base_code, 'sourcespace/']);
addpath([config.paths.base_code, 'controlanalysis/']);
addpath(config.paths.precomputed_path);

addpath(config.paths.heplab);
addpath(config.paths.fieldtrip);
addpath(genpath(config.paths.boundedline));
addpath(config.paths.inpaintnan)
addpath(config.paths.tensor)
addpath(config.paths.brewermap)
addpath(config.paths.meth)

% Create all task directories - both PC and control groups
dirs_to_create = {config.paths.raw_pc_data, config.paths.raw_control_data, ...
                      config.paths.crop_marker_path, config.paths.event_data, ...
                      config.paths.no_ica_pc_path, config.paths.no_ica_control_path, ...
                      config.paths.pre_ica_pc_path, config.paths.pre_ica_control_path, ...
                      config.paths.post_ica_pc_path, config.paths.post_ica_control_path, ...
                      config.paths.epochs_pc_path, config.paths.epochs_control_path, ...
                      config.paths.output_path, config.paths.qa_path, config.paths.error_log_path, ...
                      config.paths.precomputed_path};
create_dirs(dirs_to_create);

% Initialize EEGLAB
eeglab; close;

%% Step 1: Initial preprocessing
fprintf('Running step 1a: Initial preprocessing of PC data for ICA');
a_1_preprocessing(config.paths.raw_pc_data, config.paths.pre_ica_pc_path, config.prepro.ica);

fprintf('Running step 1b: Initial preprocessing of PC analysis data');
a_1_preprocessing(config.paths.raw_pc_data, config.paths.no_ica_pc_path, config.prepro.analysis);

%% Step 2: Import events (timepoints of R-peaks)
fprintf('Running step 2a: Importing ECG events and beats for PC ICA data');
a_2b_import_events(config.paths.pre_ica_pc_path, config.paths.pre_ica_pc_path, config.import_events);

fprintf('Running step 2b: Importing ECG events and beats for PC analysis data');
a_2b_import_events(config.paths.no_ica_pc_path, config.paths.no_ica_pc_path, config.import_events);

%% Step 3: Run ICA and remove artifactual components
fprintf('Running step 3: Running ICA and removing components for PC subjects');
a_3_run_ICA(config.paths.no_ica_pc_path, config.paths.pre_ica_pc_path, config.paths.post_ica_pc_path, config.ica_cleaning);

%% Step 4: Reintegrate ECG channel into EEG data
fprintf('Running step 4a: Reintegrate ECG channel for PC subjects (ICA-corrected)\n');
a_4_reintegrate_ecg(config.paths.post_ica_pc_path, config.paths.error_log_path);

fprintf('Running step 4b: Reintegrate ECG channel for PC subjects (non-ICA)\n');
a_4_reintegrate_ecg(config.paths.no_ica_pc_path, config.paths.error_log_path);

%% Step 5: Epoch data for time domain HEP analysis
fprintf('Running step 5a: Time domain HEP analysis for PC subjects (ICA-corrected)\n');
output_filename_pc_ica = config.hep.get_output_filename('PC', config.hep.baseline_option, 'post');
a_5_epoch_timedomain(config.paths.post_ica_pc_path, config.paths.epochs_pc_path, config.epoching.pc, output_filename_pc_ica);

fprintf('Running step 5b: Time domain HEP analysis for PC subjects (data not ICA corrected)\n');
output_filename_pc_no_ica = config.hep.get_output_filename('PC', config.hep.baseline_option, 'no');
a_5_epoch_timedomain(config.paths.no_ica_pc_path, config.paths.epochs_pc_path, config.epoching.pc, output_filename_pc_no_ica);

%% Step 6: Run statistics in time domain for EEG channel
fprintf('Running step 6a: Running EEG statistics in time domain (within-group) with ica_status=%s\n', config.hep.ica_status);
a_6_stats_timedomain_EEG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.eeg.within_group, config.hep.output_filename_pc);

fprintf('Running step 6b: EEG PAC vs PVC comparison analysis with ica_status=%s\n', config.hep.ica_status);
a_6_stats_timedomain_EEG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.eeg.pac_vs_pvc, config.hep.output_filename_pc);

%% Step 7: Run statistics in time domain for ECG channel
fprintf('Running step 7a: Running ECG statistics in time domain (within-group) with ica_status=%s\n', config.hep.ica_status);
a_7_stats_timedomain_ECG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.ecg.within_group, config.hep.output_filename_pc);

fprintf('Running step 7b: ECG PAC vs PVC comparison analysis with ica_status=%s\n', config.hep.ica_status);
a_7_stats_timedomain_ECG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.ecg.pac_vs_pvc, config.hep.output_filename_pc);

%% Step 8: Source Space Analysis
fprintf('Running step 8a: Source space analysis - PVC -3 vs 0 (time window 0.22-0.35) with ica_status=%s\n', config.hep.ica_status);
a_8_source_analysis(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.source.pvc_m3_vs_0, ...
    config.hep.output_filename_pc);

fprintf('Running step 8b: Source space analysis - PC -3 vs +1 (time window 0.13-0.2) with ica_status=%s\n', config.hep.ica_status);
a_8_source_analysis(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.source.pc_m3_vs_p1, ...
    config.hep.output_filename_pc);

fprintf('Running step 8c: Time-resolved source space analysis - PC +1 vs -3 (sliding windows) with ica_status=%s\n', config.hep.ica_status);
a_9_source_analysis_timewise(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.source.timewise_pc_p1_vs_m3, ...
    config.hep.output_filename_pc);

%% Step 9: Control Analysis - Cluster-Based Correlation (CFA)
% fprintf('Running step 9: CFA cluster-based correlation analysis - Delta HEP and delta ECG with ica_status=%s\n', config.hep.ica_status);
% a_9_cfa_cluster_correlation(config.paths.epochs_pc_path, config.paths.error_log_path, ...
%     config.paths.output_path, config.cfa.delta_hep_ecg, config.hep.output_filename_pc);

%% Step 10: Control Analysis - Time Window Correlation (CFA)
% fprintf('Running step 10: CFA time window correlation analysis - Averaged time window with ica_status=%s\n', config.hep.ica_status);
% a_10_cfa_timewindow_correlation(config.paths.epochs_pc_path, config.paths.error_log_path, ...
%     config.paths.output_path, config.cfa.avg_timewindow, config.hep.output_filename_pc);

%% Step 11: Control Analysis - T-Wave Amplitude
% fprintf('Running step 11: Control analysis for T-Wave Amplitude\n');
% a_11_twave_control(config.paths.epochs_pc_path, config.paths.error_log_path, ...
%     config.paths.output_path, config.twave.settings);

%% Step 12: Control Group - Complete Preprocessing and Statistics
fprintf('Running step 12a: Initial preprocessing of control data for ICA\n');
a_1_preprocessing(config.paths.raw_control_data, config.paths.pre_ica_control_path, config.prepro.ica)

fprintf('Running step 12b: Initial preprocessing of control analysis data\n');
a_1_preprocessing(config.paths.raw_control_data, config.paths.no_ica_control_path, config.prepro.analysis)

fprintf('Running step 12c: Detecting R-peaks for control ICA data\n');
a_2b_detect_rpeaks_control(config.paths.pre_ica_control_path, config.paths.pre_ica_control_path, config.rpeak_detection)

fprintf('Running step 12d: Detecting R-peaks for control analysis data\n');
a_2b_detect_rpeaks_control(config.paths.no_ica_control_path, config.paths.no_ica_control_path, config.rpeak_detection)

fprintf('Running step 12e: Running ICA and removing components for control subjects\n');
a_3_run_ICA(config.paths.no_ica_control_path, config.paths.pre_ica_control_path, config.paths.post_ica_control_path, config.ica_cleaning)

fprintf('Running step 12f: Reintegrate ECG channel for control subjects (ICA-corrected)\n');
a_4_reintegrate_ecg(config.paths.post_ica_control_path, config.paths.error_log_path);

fprintf('Running step 12g: Reintegrate ECG channel for control subjects (non-ICA)\n');
a_4_reintegrate_ecg(config.paths.no_ica_control_path, config.paths.error_log_path);

fprintf('Running step 12h: Time domain HEP analysis for control subjects\n');
a_5_epoch_timedomain(config.paths.post_ica_control_path, config.paths.epochs_control_path, config.epoching.control, config.hep.output_filename_control);

fprintf('Running step 12i: EEG PC vs Control comparison analysis\n');
a_6_stats_timedomain_EEG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.eeg.pc_vs_control, config.hep.output_filename_pc, config.paths.epochs_control_path);

fprintf('Running step 12j: ECG PC vs Control comparison analysis\n');
a_7_stats_timedomain_ECG(config.paths.epochs_pc_path, config.paths.error_log_path, ...
    config.paths.output_path, config.stats.ecg.pc_vs_control, config.hep.output_filename_pc, config.paths.epochs_control_path);
