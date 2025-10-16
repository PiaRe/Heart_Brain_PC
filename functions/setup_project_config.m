function config = setup_project_config()
    % SETUP_PROJECT_CONFIG - Central configuration for Heart-Brain analysis
    %
    % This function creates a unified configuration structure for the entire
    % Heart-Brain premature contractions analysis pipeline.
    %
    % Returns:
    %   config - Structure containing all project configurations
    %
    % Author: Pia Reinfeld

    fprintf('Setting up project configuration...\n');

    %% Initialize configuration structure
    config = struct();

    %% Base paths
    config.paths.base_code = '/data/pt_02778/HEP_ES/Heart_Brain_PC/';
    config.paths.base_data = [config.paths.base_code, 'final/'];

    %% Data paths (using consistent naming)
    config.paths.raw_data = [config.paths.base_data, 'raw/'];
    config.paths.crop_marker_path = [config.paths.base_data, 'raw/crop_marker/'];
    config.paths.event_data = [config.paths.base_data, 'raw/event_marker/'];
    config.paths.no_ica_path = [config.paths.base_data, 'ICA/noICA/'];
    config.paths.pre_ica_path = [config.paths.base_data, 'ICA/pre/'];
    config.paths.post_ica_path = [config.paths.base_data, 'ICA/post/'];
    config.paths.epochs_path = [config.paths.base_data, 'epochs/'];
    config.paths.output_path = [config.paths.base_data, 'output/'];
    config.paths.qa_path = [config.paths.base_data, 'QA/'];
    config.paths.error_log_path = [config.paths.base_data, 'Logfiles/'];
    config.paths.settings_path = [config.paths.base_code, 'settings/'];

    %% External toolbox paths
    config.paths.eeglab = '/data/pt_02584/Patty/Toolboxes/eeglab2021.1/';
    config.paths.heplab = '/HEPLAB-master/HEPLAB-master/Functions';
    config.paths.fieldtrip = '/fieldtrip-20230822/';
    config.paths.boundedline = [config.paths.base_code, 'functions/boundedline'];

    %% Processing parameters
    config.processing.sampling_rate = 500;
    config.processing.highpass_cutoff = 20;
    config.processing.lowpass_cutoff = 0.5;
    config.processing.ica_highpass_cutoff = 20;
    config.processing.ica_lowpass_cutoff = 1;
    config.processing.line_noise_frequency = 50;
    config.processing.flatline_criterion = 5;
    config.processing.artifact_threshold = 80;

    %% ICA cleaning thresholds (unified structure)
    config.thresholds.ecg_std_deviation = 1.5;
    config.thresholds.ecg_correlation = 0.8;
    config.thresholds.muscle_artifact = 0.5;
    config.thresholds.eye_artifact = 0.6;
    config.thresholds.line_noise = 0.5;
    config.thresholds.channel_noise = 0.4;
    config.thresholds.other_artifact = 0.5;

    %% ICA analysis parameters
    config.ica.analysis_window = [-0.200 0.200];

    %% HEP analysis parameters
    config.hep.epoch_length = [-200, 800]; % in ms
    config.hep.baseline_time = [-150, -50]; % in ms
    config.hep.baseline_option = 'ref'; % 'no', 'ref', 'int'
    config.hep.ica_option = 'yes'; % 'yes', 'no'

    %% Beat type definitions
    config.beat_types.raw_file_labels = {'N'; 'S'; 'V'; 'badECG'}; % Beat types as they appear in raw table; S=PAC, V=PVC
    config.beat_types.analysis_labels = {'N'; 'iPAC'; 'PAC-1'; 'PAC-2'; 'PAC-3'; 'PAC-4'; ...
                                             'PAC+1'; 'PAC+2'; 'PAC+3'; 'iPVC'; 'PVC-1'; 'PVC-2'; ...
                                             'PVC-3'; 'PVC-4'; 'PVC+1'; 'PVC+2'; 'PVC+3'; 'iN'}; % Beat types used in analysis

    %% Electrode configuration
    config.electrodes.file = [config.paths.eeglab, '/plugins/dipfit/standard_BESA/standard-10-5-cap385.elp'];
    config.electrodes.exclude_channels = {'Fp1', 'Fp2'};
    config.electrodes.eeg_channels = 1:31;

    fprintf('Project configuration setup complete.\n');

end
