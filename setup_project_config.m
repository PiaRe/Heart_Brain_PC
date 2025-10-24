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
    config.paths.base_data = [config.paths.base_code, 'data/'];

    %% Data paths (using consistent naming)
    config.paths.raw_pc_data = [config.paths.base_data, 'raw/PC/'];
    config.paths.raw_control_data = [config.paths.base_data, 'raw/control/'];
    config.paths.crop_marker_path = [config.paths.base_data, 'raw/crop_marker/'];
    config.paths.event_data = [config.paths.base_data, 'raw/event_marker/'];
    config.paths.no_ica_pc_path = [config.paths.base_data, 'ICA/no/PC/'];
    config.paths.no_ica_control_path = [config.paths.base_data, 'ICA/no/control/'];
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
    config.hep.ica_status = 'post'; % 'no', 'post' (choose ICA correction level)

    %% Dynamic output filename helper and generated filenames
    config.hep.get_output_filename = @(subject_type, baseline_option, ica_status) sprintf('allsubj_timedomain_%s_%s_%s.mat', subject_type, baseline_option, ica_status);

    % Pre-generated filenames for current analysis
    config.hep.output_filename_pc = config.hep.get_output_filename('PC', config.hep.baseline_option, config.hep.ica_status);
    config.hep.output_filename_control = config.hep.get_output_filename('control', config.hep.baseline_option, config.hep.ica_status);

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

    %% Statistical configuration for within group comparison
    % Main configuration - can be manually adjusted for different analyses
    config.stats.paths = config.paths; % Include paths in stats config
    config.stats.time_hep = [-0.2, 0.8];
    config.stats.time_stat = [-0.2, 0.8];
    config.stats.beat_comparison = '+1'; % z.B. -3, +1, iN, 0 (0 = PC itself)
    config.stats.beat_reference = '-3'; % z.B. -3, +1, iN, 0
    config.stats.group_select = 'PC'; % 'PAC', 'PVC', 'PC' (PC = beide kombiniert)

    %% Statistical configuration for between control group analysis
    % PC vs Control group comparison (N beats)
    % For control group comparison, we compare iN beats from PC group with iN beats from control group
    config.stats.pc_vs_control_n = config.stats; % Copy base config
    config.stats.pc_vs_control_n.beat_comparison = 'iN'; % iN beats from PC group (or PAC/PVC when group_select is PAC/PVC)
    config.stats.pc_vs_control_n.beat_reference = 'iN'; % iN beats from control group
    config.stats.pc_vs_control_n.is_control_analysis = true; % Flag to indicate this is a control group comparison
    config.stats.pc_vs_control_n.group_select = 'PC'; % 'PAC', 'PVC', 'PC' (PC = both groups combined)
    config.stats.pc_vs_control_n.statistical_analysis.statistic = 'ft_statfun_indepsamplesT'; % Independent samples for group comparison
    config.stats.pc_vs_control_n.control_filename = config.hep.output_filename_control; % Filename for control group data

    % Additional configurations for PAC and PVC specific control comparisons
    config.stats.pac_vs_control_n = config.stats.pc_vs_control_n;
    config.stats.pac_vs_control_n.group_select = 'PAC'; % Compare PAC group iN with control iN

    config.stats.pvc_vs_control_n = config.stats.pc_vs_control_n;
    config.stats.pvc_vs_control_n.group_select = 'PVC'; % Compare PVC group iN with control iN

    %% Statistical configuration for PAC vs PVC between comparison
    % Compare the same beat type between PAC and PVC groups (e.g., PAC+1 vs PVC+1)
    config.stats.pac_vs_pvc = config.stats; % Copy base config
    config.stats.pac_vs_pvc.beat_comparison = '+1'; % Beat type to compare (can be changed to any beat type: iN, -1, -2, -3, +1, +2, +3, etc.)
    config.stats.pac_vs_pvc.beat_reference = '+1'; % Same beat type for reference group
    config.stats.pac_vs_pvc.is_pac_pvc_comparison = true; % Flag to indicate this is a PAC vs PVC comparison
    config.stats.pac_vs_pvc.statistical_analysis.statistic = 'ft_statfun_indepsamplesT'; % Independent samples for group comparison

end
