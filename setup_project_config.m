function config = setup_project_config()
    % SETUP_PROJECT_CONFIG - Central configuration for Heart-Brain analysis
    %
    % This function creates a unified configuration structure for the entire
    % Heart-Brain premature contractions analysis pipeline.
    %
    % NOTE: This is the public template version with placeholder paths.
    % To use this project, adapt the placeholder paths with your actual paths.
    %
    % Returns:
    %   config - Structure containing all configurations
    %
    % Author: Pia Reinfeld

    %% Initialize configuration structure with placeholders
    fprintf('Setting up project configuration with placeholder paths...\n');
    config = struct();

    %% Base paths - REPLACE THESE IN YOUR LOCAL CONFIG FILE
    config.paths.base = '/path/to/your/Heart_Brain_PC/';
    config.paths.base_code = [config.paths.base 'code/'];
    config.paths.base_data = [config.paths.base, 'data/'];

    %% Data paths
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
    config.paths.output_path = [config.paths.base, 'results/'];
    config.paths.qa_path = [config.paths.base_data, 'QA/'];
    config.paths.error_log_path = [config.paths.base_code, 'logfiles/'];
    config.paths.precomputed_path = [config.paths.base, 'precomputed/'];

    %% External toolbox paths - REPLACE THESE IN YOUR LOCAL CONFIG FILE
    config.paths.eeglab = '/path/to/eeglab/';
    config.paths.heplab = '/path/to/HEPLAB/';
    config.paths.fieldtrip = '/path/to/fieldtrip/';
    config.paths.boundedline = '/path/to/boundedline/';
    config.paths.inpaintnan = '/path/to/Inpaint_Nans/';
    config.paths.tensor = '/path/to/tensor_toolbox/';
    config.paths.brewermap = '/path/to/BrewerMap/';
    config.paths.meth = '/path/to/meth/';

    %% Processing parameters
    config.processing.sampling_rate = 500;
    config.processing.high_cutoff = 20;
    config.processing.low_cutoff = 0.5;
    config.processing.ica_high_cutoff = 20;
    config.processing.ica_low_cutoff = 1;
    config.processing.line_noise_frequency = 50;
    config.processing.flatline_criterion = 5;

    % ECG-specific filter parameters (to avoid edge artifacts around R-peaks)
    config.processing.ecg_high_cutoff = 45; % Higher cutoff for ECG to preserve R-peak morphology
    config.processing.ecg_low_cutoff = 0.5; % Same low cutoff as EEG

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
    config.electrodes.eeg_channels = 1:31; % EEG channel indices (excluding ECG/EOG)
    config.electrodes.ecg_channel_idx = 32; % ECG channel index (after reintegration)
    config.electrodes.n_eeg_channels = length(config.electrodes.eeg_channels); % Number of EEG channels

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
    config.hep.baseline_option = 'ref'; % 'no', 'ref', 'int' %its not very clear what these options refer to. perhaps you could clarify? 
    config.hep.ica_status = 'post'; % 'no', 'post' (choose ICA correction level)

    %% Dynamic output filename helper and generated filenames
    config.hep.get_output_filename = @(subject_type, baseline_option, ica_status) sprintf('allsubj_timedomain_%s_%s_%s.mat', subject_type, baseline_option, ica_status);

    % Pre-generated filenames for current analysis
    config.hep.output_filename_pc = config.hep.get_output_filename('PC', config.hep.baseline_option, config.hep.ica_status);
    config.hep.output_filename_control = config.hep.get_output_filename('control', config.hep.baseline_option, config.hep.ica_status);

    %% Preprocessing configuration structures
    % Base preprocessing configuration (shared parameters)
    config.prepro.base.crop_marker_path = config.paths.crop_marker_path;
    config.prepro.base.error_log_path = config.paths.error_log_path;
    config.prepro.base.sampling_rate = config.processing.sampling_rate;
    config.prepro.base.electrode_file = config.electrodes.file;
    config.prepro.base.ecg_high_cutoff = config.processing.ecg_high_cutoff;
    config.prepro.base.ecg_low_cutoff = config.processing.ecg_low_cutoff;
    config.prepro.base.line_noise_frequency = config.processing.line_noise_frequency;
    config.prepro.base.flatline_criterion = config.processing.flatline_criterion;
    config.prepro.base.eeg_channels = config.electrodes.eeg_channels;

    % Configuration for ICA preprocessing (higher cutoff for ICA)
    config.prepro.ica = config.prepro.base;
    config.prepro.ica.high_cutoff = config.processing.ica_high_cutoff;
    config.prepro.ica.low_cutoff = config.processing.ica_low_cutoff;

    % Configuration for analysis preprocessing (lower cutoff for analysis)
    config.prepro.analysis = config.prepro.base;
    config.prepro.analysis.high_cutoff = config.processing.high_cutoff;
    config.prepro.analysis.low_cutoff = config.processing.low_cutoff;

    % Configuration for a_2_import_events (PC group with external ECG event files)
    config.import_events.event_data_path = config.paths.event_data;
    config.import_events.error_log_path = config.paths.error_log_path;
    config.import_events.raw_file_labels = config.beat_types.raw_file_labels;

    % Configuration for a_2c_detect_rpeaks_control (control group without external ECG files)
    config.rpeak_detection.error_log_path = config.paths.error_log_path;
    config.rpeak_detection.sampling_rate = config.processing.sampling_rate;
    config.rpeak_detection.detection_method = 'heplab_slowdetect';

    % Configuration for a_3_run_ICA
    config.ica_cleaning.error_log_path = config.paths.error_log_path;
    config.ica_cleaning.qa_path = config.paths.qa_path;
    config.ica_cleaning.analysis_window = config.ica.analysis_window;
    config.ica_cleaning.thresholds = config.thresholds;
    config.ica_cleaning.analysis_beat_types = config.beat_types.analysis_labels;
    config.ica_cleaning.eeg_channels = config.electrodes.eeg_channels;

    % Configuration for a_5_epoch_timedomain
    % Base epoching configuration (shared parameters)
    config.epoching.base.error_log_path = config.paths.error_log_path;
    config.epoching.base.epoch_length = config.hep.epoch_length;
    config.epoching.base.baseline_time = config.hep.baseline_time;
    config.epoching.base.baseline_option = config.hep.baseline_option;
    config.epoching.base.analysis_beat_types = config.beat_types.analysis_labels;
    config.epoching.base.min_trials_required = config.analysis.min_trials_required;
    config.epoching.base.eeg_channels = config.electrodes.eeg_channels;

    % PC-specific epoching configuration
    config.epoching.pc = config.epoching.base;
    config.epoching.pc.subject_type = 'PC';

    % Control-specific epoching configuration
    config.epoching.control = config.epoching.base;
    config.epoching.control.subject_type = 'control';

    %% Statistics configuration - Base parameters shared by all analyses
    config.stats.statistical_analysis_base.parameter = 'avg';
    config.stats.statistical_analysis_base.method = 'montecarlo';
    config.stats.statistical_analysis_base.correctm = 'cluster';
    config.stats.statistical_analysis_base.clusteralpha = 0.05;
    config.stats.statistical_analysis_base.clusterstatistic = 'maxsum';
    config.stats.statistical_analysis_base.tail = 0;
    config.stats.statistical_analysis_base.correcttail = 'prob';
    config.stats.statistical_analysis_base.clustertail = 0;
    config.stats.statistical_analysis_base.alpha = 0.025;
    config.stats.statistical_analysis_base.numrandomization = 5000;
    config.stats.statistical_analysis_base.latency = [-0.2, 0.8]; % Time window for statistical analysis
    config.stats.statistical_analysis_base.downsample_iN_trials = true; % Whether to downsample iN trials to match non-iN trial count
    config.stats.statistical_analysis_base.paths = config.paths;
    config.stats.statistical_analysis_base.hep_params = config.hep; % Pass HEP parameters for metadata

    %% COMPARISON TYPE 1: Within-group comparison (e.g., PAC+1 vs PAC-3)
    config.stats.within_group.statistical_analysis = config.stats.statistical_analysis_base;
    config.stats.within_group.statistical_analysis.statistic = 'ft_statfun_depsamplesT'; % Dependent samples
    config.stats.within_group.beat_comparison = '-3'; % e.g., -3, +1, iN, 0 (0 = PC itself)
    config.stats.within_group.beat_reference = '0'; % e.g., -3, +1, iN, 0
    config.stats.within_group.group_select = 'PVC'; % 'PAC', 'PVC', 'PC' (PC = both combined)

    %% COMPARISON TYPE 2: PAC vs PVC
    config.stats.pac_vs_pvc.statistical_analysis = config.stats.statistical_analysis_base;
    config.stats.pac_vs_pvc.statistical_analysis.statistic = 'ft_statfun_indepsamplesT'; % Independent samples
    config.stats.pac_vs_pvc.beat_comparison = '+1';
    config.stats.pac_vs_pvc.beat_reference = '+1';
    config.stats.pac_vs_pvc.is_pac_pvc_comparison = true;

    %% COMPARISON TYPE 3: PC vs Control (N beats)
    config.stats.pc_vs_control.statistical_analysis = config.stats.statistical_analysis_base;
    config.stats.pc_vs_control.statistical_analysis.statistic = 'ft_statfun_indepsamplesT'; % Independent samples
    config.stats.pc_vs_control.beat_comparison = 'iN'; % iN beats from PC group
    config.stats.pc_vs_control.beat_reference = 'iN'; % iN beats from control group
    config.stats.pc_vs_control.is_control_analysis = true;
    config.stats.pc_vs_control.group_select = 'PVC'; % 'PAC', 'PVC', 'PC' (PC = both combined)
    config.stats.pc_vs_control.control_filename = config.hep.output_filename_control;

    %% COMPARISON TYPE 4: T-wave matched control analysis
    config.stats.twave.statistical_analysis = config.stats.statistical_analysis_base;
    config.stats.twave.statistical_analysis.statistic = 'ft_statfun_depsamplesT'; % Dependent samples
    config.stats.twave.beat_comparison = '+1'; % PC+1
    config.stats.twave.beat_reference = '-3'; % PC-3
    config.stats.twave.group_select = 'PC'; % Both PAC and PVC combined
    config.stats.twave.is_tpeak_matched = true; % Flag for T-peak matched analysis

    %% CHANNEL-SPECIFIC CONFIGURATIONS
    % Create separate namespaces for EEG and ECG analyses using inheritance
    comparison_types = {'within_group', 'pc_vs_control', 'pac_vs_pvc', 'twave'};

    % EEG channel configurations (uses all channels except ECG)
    for i = 1:length(comparison_types)
        comp_type = comparison_types{i};
        % Copy base comparison structure
        config.stats.eeg.(comp_type) = config.stats.(comp_type);
        % Override channel-specific parameters
        config.stats.eeg.(comp_type).statistical_analysis.channel = {'all', '-ECG'};
        config.stats.eeg.(comp_type).statistical_analysis.minnbchan = 2;
    end

    % ECG channel configurations (uses only ECG channel)
    for i = 1:length(comparison_types)
        comp_type = comparison_types{i};
        % Copy base comparison structure
        config.stats.ecg.(comp_type) = config.stats.(comp_type);
        % Override channel-specific parameters
        config.stats.ecg.(comp_type).statistical_analysis.channel = 'ECG';
        config.stats.ecg.(comp_type).statistical_analysis.minnbchan = 0;
    end

    %% SOURCE SPACE ANALYSIS (eLORETA)
    % Configuration for source reconstruction using eLORETA

    % Base source configuration
    config.source.base.paths = config.paths;
    config.source.base.hep_params = config.hep;
    config.source.base.statistical_alpha = 0.05;
    config.source.base.fdr_correction = true;

    % Available regularization parameters for eLORETA forward models
    % 0.5 = smooth (more distributed), 0.05 = standard (balanced), 0.001 = focal (more localized)
    config.source.base.regularization_values = {0.5, 0.05, 0.001};

    % Available aggregation methods for combining voxels within ROIs
    % 'avg' = simple average, 'avg-sf' = average with sign correction (signflip)
    config.source.base.agg_methods = {'avg', 'avg-sf'};

    % Configuration 1: PVC -3 vs 0 in time window 0.22-0.35
    config.source.pvc_m3_vs_0 = config.source.base;
    config.source.pvc_m3_vs_0.beat_comparison = '0'; % PVC itself
    config.source.pvc_m3_vs_0.beat_reference = '-3'; % PVC-3
    config.source.pvc_m3_vs_0.group_select = 'PVC';
    config.source.pvc_m3_vs_0.time_window = [0.220, 0.350]; %I think i commented this somewhere else, but you could extract these time windows from the stats output 

    % Configuration 2: PC -3 vs +1 in time window 0.13-0.2
    config.source.pc_m3_vs_p1 = config.source.base;
    config.source.pc_m3_vs_p1.beat_comparison = '+1'; % PC+1
    config.source.pc_m3_vs_p1.beat_reference = '-3'; % PC-3
    config.source.pc_m3_vs_p1.group_select = 'PC'; % Both PAC and PVC combined
    config.source.pc_m3_vs_p1.time_window = [0.130, 0.200];

    % Configuration 3: Time-resolved analysis - PC+1 vs PC-3 across sliding windows
    config.source.timewise_pc_p1_vs_m3 = config.source.base;
    config.source.timewise_pc_p1_vs_m3.group_select = 'PC';
    config.source.timewise_pc_p1_vs_m3.pc_plus1_window = [0.130, 0.200]; % Fixed window for PC+1
    config.source.timewise_pc_p1_vs_m3.pc_minus3_windows = {% Sliding windows for PC-3
                                                            [0.130, 0.200], ... % Same window (standard comparison)
                                                                [0.200, 0.270], ...
                                                                [0.270, 0.340], ...
                                                                [0.340, 0.410], ...
                                                                [0.410, 0.480], ...
                                                                [0.480, 0.550], ...
                                                                [0.550, 0.620]};

    %% CFA CORRELATION ANALYSIS
    % Configuration for cardiac field artifact correlation control analysis

    % Base CFA configuration
    config.cfa.base.paths = config.paths;
    config.cfa.base.hep_params = config.hep;
    config.cfa.base.corr_type = 'Spearman';
    config.cfa.base.corr_n_permu = 100;
    config.cfa.base.n_eeg_channels = config.electrodes.n_eeg_channels;
    config.cfa.base.ecg_channel_idx = config.electrodes.ecg_channel_idx;

    % Statistical analysis parameters for CFA correlation
    config.cfa.base.statistical_analysis = config.stats.statistical_analysis_base;
    config.cfa.base.statistical_analysis.parameter = 'fisher_transf';
    config.cfa.base.statistical_analysis.statistic = 'ft_statfun_depsamplesT';
    config.cfa.base.statistical_analysis.channel = {'all', '-ECG'};
    config.cfa.base.statistical_analysis.minnbchan = 2;

    % Configuration 1: Delta HEP and delta ECG cluster-based correlation analysis (PC: +1 vs -3)
    config.cfa.cluster_pc_p1_vs_m3 = config.cfa.base;
    config.cfa.cluster_pc_p1_vs_m3.beat_comparison = '+1';
    config.cfa.cluster_pc_p1_vs_m3.beat_reference = '-3';
    config.cfa.cluster_pc_p1_vs_m3.group_select = 'PC';

    % Configuration 2: Delta HEP and delta ECG cluster-based correlation analysis (PVC: 0 vs -3)
    config.cfa.cluster_pvc_0_vs_m3 = config.cfa.base;
    config.cfa.cluster_pvc_0_vs_m3.beat_comparison = '0';
    config.cfa.cluster_pvc_0_vs_m3.beat_reference = '-3';
    config.cfa.cluster_pvc_0_vs_m3.group_select = 'PVC';

    % Configuration 3: Averaged time-window correlation analysis (PC: +1 vs -3, tw: 0.13-0.2)
    config.cfa.timewindow_pc_p1_vs_m3 = config.cfa.base;
    config.cfa.timewindow_pc_p1_vs_m3.beat_comparison = '+1';
    config.cfa.timewindow_pc_p1_vs_m3.beat_reference = '-3';
    config.cfa.timewindow_pc_p1_vs_m3.group_select = 'PC';
    config.cfa.timewindow_pc_p1_vs_m3.time_window = [0.13, 0.2];

    % Configuration 4: Averaged time-window correlation analysis (PVC: 0 vs -3, tw: 0.22-0.35)
    config.cfa.timewindow_pvc_0_vs_m3 = config.cfa.base;
    config.cfa.timewindow_pvc_0_vs_m3.beat_comparison = '0';
    config.cfa.timewindow_pvc_0_vs_m3.beat_reference = '-3';
    config.cfa.timewindow_pvc_0_vs_m3.group_select = 'PVC';
    config.cfa.timewindow_pvc_0_vs_m3.time_window = [0.22, 0.35];

    %% T-WAVE AMPLITUDE MATCHING CONTROL ANALYSIS
    % Configuration for T-peak amplitude matching control analysis
    % Matches PC+1 epochs with N/PC-3 based on T-peak amplitude

    config.twave.settings.beat_comparison = '+1'; % PC+1
    config.twave.settings.beat_reference = '-3'; % PC-3 (will also use iN)
    config.twave.settings.group_select = 'PC'; % Both PAC and PVC combined
    config.twave.settings.t_wave_window = [0.2, 0.4]; % 200-400ms after R-peak
    config.twave.settings.cost_unmatched = 200; % Starting cost for unmatched epochs
    config.twave.settings.cost_decrement = 5; % Amount to decrease cost per iteration for stricter matching
    config.twave.settings.min_cost = 5; % Minimum cost threshold to prevent over-matching and too little remaining trials
    config.twave.settings.input_filename = config.hep.output_filename_pc;
    config.twave.settings.ecg_channel_idx = config.electrodes.ecg_channel_idx; % ECG channel index

    % Store both EEG and ECG specific twave configs for the two statistical analyses
    config.twave.settings.stats_config_eeg = config.stats.eeg.twave; % For EEG analysis
    % config.twave.settings.stats_config_eeg.statistical_analysis.latency = [0.13, 0.2];
    config.twave.settings.stats_config_ecg = config.stats.ecg.twave; % For ECG analysis
    config.twave.settings.stats_config_ecg.statistical_analysis.latency = [0.13, 0.2];

end
