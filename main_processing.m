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
%   Pia Reinfeld
%
% Example:
%   Run the script to process task and rest EEG data:
%     1. Filter and preprocess data.
%     2. Perform ICA and correct artifacts.
%     3. Perform statistical analysis.

%% Initialize workspace
clc; clear all; close all; % Clear command window, variables, and figures.

%% Initialize paths
% Base paths
eeglab_path = '/data/pt_02584/Patty/Toolboxes/eeglab2021.1/'; % TODO: remove
code_path = '/data/pt_02778/HEP_ES/Heart_Brain_PC/'; % TODO: remove

% Add required paths
addpath(eeglab_path);
addpath([code_path, 'functions']);
addpath([code_path, 'Preprocessing/']);
addpath([code_path, 'Stats/Timedomain/']);
addpath([code_path, 'Stats/SourceSpace/']);
addpath([code_path, 'Stats/ControlAnalysis/']);

addpath('/HEPLAB-master/HEPLAB-master/Functions'); % HEPLAB path
addpath('/fieldtrip-20230822/'); % Fieldtrip path
addpath(genpath([code_path, 'functions/boundedline'])); % Bounded lines path

% Project paths
basedir = [code_path, 'final/'];
raw_path = [basedir, 'raw/']; % combined EEG + ECG data
crop_marker_path = [basedir, 'raw/crop_marker/'];
pre_ica_path = [basedir, 'ICA/'];
post_ica_path = [basedir, 'postICA/'];
filtered_path = [basedir, 'postICA_05_20Hz/'];
epochs_path = [basedir, 'epochs/'];
output_path = [basedir, 'output/'];
qa_path = [basedir, 'QA/'];
error_path = [basedir, 'Logfiles/'];
settings_path = [code_path, 'settings/'];

% Create all task directories
dirs_to_create = {pre_ica_path, post_ica_path, filtered_path, ...
                      epochs_path, output_path, qa_path, error_path};
create_dirs(dirs_to_create);

% Initialize EEGLAB
eeglab; close;

%% Preprocessing settings
% Down-sampling frequency in Hz
fs = 500;

% Location of standard electrode positions
elecfile = [eeglab_path, '/plugins/dipfit/standard_BESA/standard-10-5-cap385.elp'];
% High- and Low-pass filtering cutoffs, in Hz
highpass_cu = 0.5;
lowpass_cu = 20;
% Criterion for cleaning flat channel
flatline_crit = 5; % in s
% Threshold to exclude artefacts
artefact_thresh = 80; % in mV

%% ICA cleaning settings
% Filtering for ICA decomposition, in Hz
ica_highpass_cu = 1;
ica_lowpass_cu = lowpass_cu;
% Notch filtering
line_noise_f = 50; % line noise, in Hz
% ICA and ECG epoching for ECG-related artifact detection, in s
ica_window = [-0.050 0.600];

% SD threshold for ECG-related artifact detection
sd_ecg_thresh = 1.5; % ica_thresh
% threshold for correlation between ECG and ICA components
ecg_tresh = 0.8;
% threshold probability for IClabeling - muscle
muscle_thresh = 0.5;
% threshold probability for IClabeling - eye
eye_thresh = 0.6;
% threshold probability for IClabeling - line noise
ln_thresh = 0.5;
% threshold probability for IClabeling - channel noise
chann_thresh = 0.4;
% threshold probability for IClabeling - other
other_thresh = 0.5;

% Create a dictionary using containers.Map
thresholds = containers.Map( ...
    {'sd_ecg', 'ecg', 'muscle', 'eye', ...
     'ln', 'chann', 'other'}, ...
    {sd_ecg_thresh, ecg_tresh, muscle_thresh, eye_thresh, ...
     ln_thresh, chann_thresh, other_thresh});

%% Time domain settings
% timewindow of HEP epochs with the R-peak at 0 ms
epoch_length = [-200, 800]; % in ms
% timewindow of basline before HEP
basline_time = [-150, -50]; % in ms
%% Multiverse Setting - time domain
% baseline setting: choose between 'no': no baseline applied, 'ref': baseline before reference
% condition and 'int': baseline before condition of interest
baseline_option = 'ref';
% ICA setting: choose between 'no': no ICA components rejected and 'yes': ICA components rejected
ica_option = 'yes';

%% Step 1: Initial preprocessing and ICA
fprintf('Running step 1: Initial preprocessing and ICA\n');
a_1_preprocessing(raw_path, crop_marker_path, pre_ica_path, error_path, fs, elecfile, ica_highpass_cu, ica_lowpass_cu, line_noise_f, flatline_crit, artefact_thresh)

%% Step 2: Select ICA components
fprintf('Running step 2: ICA component selection\n');
a_2_select_ICA_components(pre_ica_path, post_ica_path, error_path, qa_path, ica_window, thresholds)

%% Step 3: Apply ICA to filtered data
fprintf('Running step 3: Applying ICA to filtered data\n');
a_3_apply_ICA_components_to_filtered_data(raw_path, filtered_path, pre_ica_path, post_ica_path, error_path, qa_path, fs, elecfile, highpass_cu, lowpass_cu, line_noise_f, flatline_crit)

%% Step 4: Run time domain analysis
fprintf('Running step 4: Analysing the HEP in the time domain\n');
a_4_run_timedomain(filtered_path, epoch_length, baseline_time, baseline_option, ica_option)
