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
    config.paths.raw_pc_data = [config.paths.base_data, 'raw/PC/'];
    config.paths.raw_control_data = [config.paths.base_data, 'raw/control/'];
    config.paths.crop_marker_path = [config.paths.base_data, 'raw/crop_marker/'];
    config.paths.event_data = [config.paths.base_data, 'raw/event_marker/'];
    config.paths.no_ica_pc_path = [config.paths.base_data, 'ICA/noICA/PC/'];
    config.paths.no_ica_control_path = [config.paths.base_data, 'ICA/noICA/control/'];
    config.paths.pre_ica_pc_path = [config.paths.base_data, 'ICA/pre/PC/'];
    config.paths.pre_ica_control_path = [config.paths.base_data, 'ICA/pre/control/'];
    config.paths.post_ica_pc_path = [config.paths.base_data, 'ICA/post/PC/'];
    config.paths.post_ica_control_path = [config.paths.base_data, 'ICA/post/control/'];
    config.paths.epochs_pc_path = [config.paths.base_data, 'epochs/PC/'];
    config.paths.epochs_control_path = [config.paths.base_data, 'epochs/control/'];
    config.paths.output_path = [config.paths.base_data, 'output/'];
    config.paths.qa_path = [config.paths.base_data, 'QA/'];
    config.paths.error_log_path = [config.paths.base_data, 'Logfiles/'];
    config.paths.settings_path = [config.paths.base_code, 'settings/'];

    %% External toolbox paths
    config.paths.eeglab = '/data/pt_02584/Patty/Toolboxes/eeglab2021.1/';
    config.paths.heplab = '/HEPLAB-master/HEPLAB-master/Functions';
    config.paths.fieldtrip = '/data/pt_02584/Patty/Toolboxes/fieldtrip-20220422/';
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
    config.hep.reference_beat = 'PC-3'; % Reference beat type for baseline correction ('iN', 'PC-4', 'PC-3', 'iPC', etc.)

    %% Beat type definitions
    config.beat_types.raw_file_labels = {'N'; 'S'; 'V'; 'badECG'}; % Beat types as they appear in raw table; S=PAC, V=PVC
    config.beat_types.analysis_labels = {'iPAC'; 'PAC-1'; 'PAC-2'; 'PAC-3'; 'PAC-4'; ...
                                             'PAC+1'; 'PAC+2'; 'PAC+3'; 'iPVC'; 'PVC-1'; 'PVC-2'; ...
                                             'PVC-3'; 'PVC-4'; 'PVC+1'; 'PVC+2'; 'PVC+3'}; % Beat types used in analysis (excluding N and iN)

    %% Analysis constants
    config.analysis.min_trials_required = 5; % Minimum number of trials required for analysis

    %% Electrode configuration
    config.electrodes.file = [config.paths.eeglab, '/plugins/dipfit/standard_BESA/standard-10-5-cap385.elp'];
    config.electrodes.exclude_channels = {'Fp1', 'Fp2'};
    config.electrodes.eeg_channels = 1:31;

    %% Statistics configuration for time domain analysis
    % Main configuration - can be manually adjusted for different analyses
    config.stats.time_hep = [-0.2, 0.8]; % Time window for HEP analysis
    config.stats.time_stat = [-0.2, 0.8]; % Time window for statistical analysis
    config.stats.beat_type = 'PAC'; % Beat type to analyze: 'PAC', 'PVC', 'N'
    config.stats.beat_comparison = 'PAC-1'; % Beat to compare (change as needed)
    config.stats.beat_reference = 'PAC-3'; % Reference beat for comparison (change as needed)
    config.stats.min_trials_required = 5; % Minimum number of trials required for analysis
    config.stats.group_comparison = 0; % 1 = PC vs Control groups, 0 = within-subject comparison

    % Statistical analysis parameters (following Fieldtrip conventions)
    config.stats.statistical_analysis.parameter = 'avg';
    config.stats.statistical_analysis.method = 'montecarlo';
    config.stats.statistical_analysis.statistic = 'ft_statfun_depsamplesT';
    config.stats.statistical_analysis.correctm = 'cluster';
    config.stats.statistical_analysis.clusteralpha = 0.05;
    config.stats.statistical_analysis.clusterstatistic = 'maxsum';
    config.stats.statistical_analysis.minnbchan = 2;
    config.stats.statistical_analysis.tail = 0;
    config.stats.statistical_analysis.clustertail = 0;
    config.stats.statistical_analysis.alpha = 0.025;
    config.stats.statistical_analysis.numrandomization = 5000;
    config.stats.statistical_analysis.channel = {'all', '-ECG'};
    config.stats.statistical_analysis.latency = [-0.2, 0.8];

    %% Predefined configs for specific analyses (examples)
    % PC vs Control group comparison (N beats)
    config.stats.pc_vs_control_n = config.stats; % Copy base config
    config.stats.pc_vs_control_n.beat_type = 'N';
    config.stats.pc_vs_control_n.beat_comparison = 'N';
    config.stats.pc_vs_control_n.beat_reference = 'N'; % Ignored in group comparison
    config.stats.pc_vs_control_n.group_comparison = 1;
    config.stats.pc_vs_control_n.statistical_analysis.statistic = 'ft_statfun_indepsamplesT';

    fprintf('Project configuration setup complete.\n');

end
