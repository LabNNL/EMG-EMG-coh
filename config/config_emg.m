function C = config_emg()

%% ===================== PIPELINE TOGGLING PARAMETERS =====================

%Frequency domain
C.parameters_running.run_data_extraction = false;  % If true, run a_extract_raw_cycles_concat.m
C.parameters_running.run_preprocessing = false;   % If true, run b_preprocess_emg.m
C.parameters_running.run_burst_extraction = false; % If true, run c_extract_bursts_from_preproc.m
C.parameters_running.run_burst_clustering = false;  % If true, run d_a_clustering_cleaning.m
C.parameters_running.run_burst_rule_based = false;  % If true, run d_b_rule_based_cleaning.m
C.parameters_running.run_burst_qc = false;         % If true, run e_final_burst_qc_combination.m
C.parameters_running.run_final_signals_creation = true; % If true, run f_build_final_paired_signals_from_burst_qc.m 
C.parameters_running.run_coherence_extraction = true; % If true, run g_emg_emg_wavelet_coherence.m
C.parameters_running.run_coherence_stats = true; % If true, run h_coherence_stats.m

% Time domain : main_time_domain_analysis.m
C.parameters_running.run_build_time_domain_analysis_datasets = false; % If true, run j_build_time_domain_analysis_datasets.m
C.parameters_running.run_activation_profiles = false; % If true, run k_plot_activation_profiles.m
C.parameters_running.run_spm = false; % If true, run l_spm_envelope_analysis.m
C.parameters_running.run_temporal_coherence_link = false; % If true, run i_temporal_coherence_link.m

% Kinematics : main_kinematics_analysis.m
C.parameters_running.run_kinematics_build = true;    % If true, run build_kinematics_for_coherence_cycles.m
C.parameters_running.run_kinematics_analysis = true; % If true, run analyze_kinematics_for_coherence_cycles.m

%% ===================== PHYSIOLOGICAL CONSTANTS =====================

C.physio = struct();
C.physio.phase_windows_pct = struct();
C.physio.phase_windows_pct.TAprox_TAdist = struct( ...
    'start_pct', 60, ...
    'end_pct', 20);
C.physio.phase_windows_pct.SOL_GM = struct( ...
    'start_pct', 0, ...
    'end_pct', 60);
C.physio.phase_windows_pct.VL_RF = struct( ...
    'start_pct', 90, ...
    'end_pct', 30);


%% ===================== PATHS =====================

% The data location is machine-specific and lives in config/local_paths.m,
% which is git-ignored. Copy config/local_paths.template.m to create it.
% The code directory is derived from this file's own location.

if exist('local_paths', 'file') ~= 2
    error('config_emg:missingLocalPaths', ...
        ['config/local_paths.m not found.\n' ...
         'Copy config/local_paths.template.m to config/local_paths.m ' ...
         'and set project_data_root to your data folder.']);
end

LP = local_paths();
C.paths.project_data_root = LP.project_data_root;
C.paths.code_dir      = fileparts(fileparts(mfilename('fullpath')));
C.paths.functions_dir = fullfile(C.paths.code_dir, 'Functions');

if exist(C.paths.functions_dir, 'dir')
    addpath(genpath(C.paths.functions_dir));
else
    warning('Functions directory not found: %s', C.paths.functions_dir);
end

rehash;

% The data you want to analyze should be the folder of data_dir.
C.paths.data_dir = fullfile(C.paths.project_data_root, 'Reworked_Data');
% This path is only used for the summarize_reworked_data.m script, to find the old data for comparison.
C.paths.old_data_dir     = fullfile(C.paths.project_data_root, 'Data');

C.paths.mat_dir      = fullfile(C.paths.project_data_root, 'mat_data');
C.paths.metadata_dir = fullfile(C.paths.code_dir, 'Metadata');
C.paths.raw_dir     = fullfile(C.paths.mat_dir, 'mat_raw_EMG_data');
C.paths.preproc_dir = fullfile(C.paths.mat_dir, 'mat_preproc_EMG_data');
C.paths.bursts_dir   = fullfile(C.paths.mat_dir, 'mat_bursts_data');
C.paths.features_dir = fullfile(C.paths.mat_dir, 'mat_burst_features');
C.paths.clustering_dir = fullfile(C.paths.mat_dir, 'mat_clustering_data');
C.paths.rule_based_dir = fullfile(C.paths.mat_dir, 'mat_rule_based_data');
C.paths.burst_decision_dir = fullfile(C.paths.mat_dir, 'mat_final_burst_decision');
C.paths.final_signals_dir = fullfile(C.paths.mat_dir, 'mat_final_paired_signals');
C.paths.coherence_dir = fullfile(C.paths.mat_dir, 'mat_coherence_data');
C.paths.stats_dir = fullfile(C.paths.mat_dir, 'mat_stats_data');

% The results will be saved in a "Results" folder within the code directory, with subfolders for plots and other outputs.
C.paths.results_dir   = fullfile(C.paths.code_dir, 'Results');
C.paths.plot_dir  = fullfile(C.paths.results_dir, 'png_visualisation');
C.paths.raw_plot_dir = fullfile(C.paths.plot_dir, 'a_extract_raw_cycles_concat');
C.paths.preproc_plot_dir = fullfile(C.paths.plot_dir, 'b_preprocess_emg');
C.paths.preproc_qc_plot_dir = fullfile(C.paths.preproc_plot_dir, 'QC_RawVsPreproc');

C.paths.functions.data_extraction = fullfile(C.paths.functions_dir,'a_data_extraction');
C.paths.functions.preprocessing = fullfile(C.paths.functions_dir, 'b_preprocessing');
C.paths.functions.burst_extraction = fullfile(C.paths.functions_dir, 'c_burst_extraction');
C.paths.functions.clustering_cleaning = fullfile(C.paths.functions_dir, 'd_a_clustering_cleaning');
C.paths.functions.rule_based_cleaning = fullfile(C.paths.functions_dir, 'd_b_rule_based_cleaning');
C.paths.functions.burst_qc = fullfile(C.paths.functions_dir, 'e_burst_qc');
C.paths.functions.final_data_qc = fullfile(C.paths.functions_dir, 'f_final_data_qc');
C.paths.functions.coherence = fullfile(C.paths.functions_dir, 'g_coherence');
C.paths.functions.stats = fullfile(C.paths.functions_dir, 'h_stats');

C.paths.functions.kinematics_analysis = fullfile(C.paths.functions_dir, 'kinematics_analysis');
C.paths.functions.time_domain_analysis = fullfile(C.paths.functions_dir, 'time_domain_analysis');

C.paths.helpers.data_extraction = fullfile(C.paths.functions.data_extraction,'a_data_extraction_helpers');
C.paths.helpers.preprocessing = fullfile(C.paths.functions.preprocessing, 'b_preprocessing_helpers');
C.paths.helpers.burst_extraction = fullfile(C.paths.functions.burst_extraction, 'c_burst_extraction_helpers');
C.paths.helpers.clustering_cleaning = fullfile(C.paths.functions.clustering_cleaning, 'd_a_clustering_cleaning_helpers');
C.paths.helpers.rule_based_cleaning = fullfile(C.paths.functions.rule_based_cleaning, 'd_b_rule_based_cleaning_helpers');
C.paths.helpers.burst_qc = fullfile(C.paths.functions.burst_qc, 'e_burst_qc_helpers');
C.paths.helpers.final_data_qc = fullfile(C.paths.functions.final_data_qc, 'f_final_data_qc_helpers');
C.paths.helpers.coherence = fullfile(C.paths.functions.coherence, 'g_coherence_helpers');
C.paths.helpers.stats = fullfile(C.paths.functions.stats, 'h_stats_helpers');
C.paths.helpers.general = fullfile(C.paths.functions_dir, 'general');

C.paths.toolboxes = struct();
C.paths.toolboxes.dir = fullfile(C.paths.functions_dir, 'toolboxes');
C.paths.toolboxes.spm1d = fullfile(C.paths.toolboxes.dir,'spm1dmatlab-master'); % <-- UPDATE THIS TO YOUR SPM1D PATH0
C.paths.toolboxes.btk = fullfile(C.paths.toolboxes.dir, 'moveck_bridge_btk'); % <-- UPDATE THIS TO YOUR BTK PATH
C.paths.toolboxes.wtc = fullfile(C.paths.toolboxes.dir, 'wtc-r16'); % <-- UPDATE THIS TO YOUR WAVELET TOOLBOX PATH

%% ===================== DESIGN (EXPECTED) =====================
C.design.conditions = {'Flat','Medium','High'};
C.design.legs       = {'left','right'};
C.design.muscles    = {'EMG_TAprox','EMG_TAdist','EMG_SOL','EMG_GM','EMG_VL','EMG_RF','EMG_ST','EMG_GMED'};
C.design.muscleFields = strcat(C.design.muscles, "_Concat");
C.design.trials     = {'01','02','03','04', '05','06','07','08','09','10'};

%% ===================== PARTICIPANTS =====================
C.participants.all = { ...
    'CTL_01','CTL_02','CTL_03','CTL_04','CTL_05','CTL_06','CTL_07','CTL_08','CTL_09','CTL_10', ...
    'CTL_11','CTL_12','CTL_13','CTL_14','CTL_15','CTL_16','CTL_17','CTL_18','CTL_19','CTL_20', ...
    'CTL_21','CTL_22','CTL_23','CTL_24','CTL_25','CTL_26','CTL_27','CTL_28','CTL_29','CTL_30', ...
    'CTL_31','CTL_32','CTL_33','CTL_34','CTL_35','CTL_36','CTL_37','CTL_38','CTL_39','CTL_40', ...
    'CTL_41','CTL_42','CTL_43','CTL_44','CTL_45','CTL_46','CTL_47','CTL_48','CTL_49','CTL_50', ...
    'CTL_51','CTL_52','CTL_53','CTL_54','CTL_55','CTL_56','CTL_57','CTL_58','CTL_59','CTL_60', ...
    'CTL_61','CTL_62','CTL_63','CTL_64','CTL_65','CTL_66','CTL_67','CTL_68','CTL_69','CTL_70', ...
    'CTL_71','CTL_72','CTL_73','CTL_74','CTL_75','CTL_76','CTL_77', 'CTL_78','CTL_79', 'CTL_81'};


C.participants.jeunesEnfants = { ...
    'CTL_14','CTL_15','CTL_23','CTL_37','CTL_40','CTL_53','CTL_63','CTL_65','CTL_67','CTL_70','CTL_75','CTL_77', 'CTL_78','CTL_79', 'CTL_81'};

C.participants.enfants = { ...
    'CTL_01','CTL_02','CTL_06','CTL_09','CTL_10','CTL_11','CTL_16','CTL_19','CTL_20','CTL_31', ...
    'CTL_34','CTL_38','CTL_39','CTL_44','CTL_46','CTL_49','CTL_51','CTL_52','CTL_54','CTL_55', ...
    'CTL_57','CTL_58','CTL_59','CTL_74'};

C.participants.adolescents = { ...
    'CTL_17','CTL_26','CTL_35','CTL_47','CTL_48','CTL_50','CTL_56','CTL_60','CTL_61','CTL_62', ...
    'CTL_66','CTL_68','CTL_69','CTL_71','CTL_72','CTL_73','CTL_76'};

C.participants.adultes = { ...
    'CTL_03','CTL_04','CTL_05','CTL_07','CTL_08','CTL_12','CTL_13','CTL_18','CTL_21','CTL_22', ...
    'CTL_24','CTL_25','CTL_27','CTL_28','CTL_29','CTL_30','CTL_32','CTL_33','CTL_36','CTL_41', ...
    'CTL_42','CTL_43','CTL_45','CTL_64'};

%% ===================== GROUP MAP (handy helper) =====================
% If you want an easy "subject -> group" lookup later:
C.groups = containers.Map('KeyType','char','ValueType','char');
add_group(C.groups, C.participants.jeunesEnfants, 'JeunesEnfants');
add_group(C.groups, C.participants.enfants,       'Enfants');
add_group(C.groups, C.participants.adolescents,   'Adolescents');
add_group(C.groups, C.participants.adultes,       'Adultes');

%% ===================== Plotting settings =====================
C.plotting = struct();
C.plotting.colors = struct();
C.plotting.colors.JeunesEnfants = [0.84 0.73 0.92];
C.plotting.colors.Enfants        = [0.72 0.55 0.86];
C.plotting.colors.Adolescents    = [0.56 0.37 0.75];
C.plotting.colors.Adultes        = [0.38 0.20 0.54];

C.plotting.colors.Femmes  = [0.2980 0.4706 0.6588];
C.plotting.colors.Hommes  = [0.9608 0.5216 0.1294];

C.plotting.colors.Full = [0.63 0.82 0.95];   % light blue
C.plotting.colors.Stance = [0.32 0.62 0.88];   % medium blue
C.plotting.colors.Swing = [0.10 0.32 0.62];  % dark blue

C.plotting.colors.Alpha = [0.98 0.84 0.40];   % warm yellow
C.plotting.colors.Beta = [0.95 0.63 0.22];  % orange
C.plotting.colors.Gamma = [0.82 0.42 0.08];   % dark orange

C.plotting.colors.Flat = [0.95 0.66 0.66];   % light red
C.plotting.colors.Medium = [0.87 0.36 0.36];   % medium red
C.plotting.colors.High = [0.66 0.10 0.10];   % dark red

C.plotting.age_order = ["JeunesEnfants", "Enfants", "Adolescents", "Adultes"];
C.plotting.sex_order = ["Femmes", "Hommes"];
C.plotting.phase_order = ["Full", "Stance", "Swing"];
C.plotting.band_order = ["Alpha", "Beta", "Gamma"];
C.plotting.condition_order = ["Flat", "Medium", "High"];

C.plotting.AlphaTransparency = 0.5; % 

C.plotting.colors.exclude = [1 0 0]; % very intense red for excluded bursts (set in config_emg.m)
C.plotting.colors.include = [0.6 0.9 1]; % cyan
C.plotting.colors.exclude_rule_based = [1 1 0]; % yellow for bursts excluded by rule-based QC (set in config_emg.m)
C.plotting.colors.exclude_cluster_based = [1 0.5 0]; % orange for bursts excluded by cluster-based QC (set in config_emg.m)

C.plotting.colors.exclude_visual = [0.55 0.55 0.55];   % medium/dark gray for visual exclusion
C.plotting.colors.exclude_signal_rule = [0.50 0.00 0.00]; % dark red for whole-signal rule-based failure

% reason-specific colors for rule-based QC
C.plotting.colors.reason = struct();
C.plotting.colors.reason.spike       = [0.85 0.20 0.20];  % red
C.plotting.colors.reason.plateau     = [0.95 0.55 0.15];  % orange
C.plotting.colors.reason.spec        = [0.55 0.35 0.80];  % purple
C.plotting.colors.reason.medfreq     = [1.00 0.00 0.49];  % pink
C.plotting.colors.reason.abs_amp     = [0.85 0.20 0.65];  % magenta
C.plotting.colors.reason.too_short   = [0.90 0.90 0.10];  % yellow
C.plotting.colors.reason.too_long    = [0.55 0.27 0.07];  % brown
C.plotting.colors.reason.bad_bounds  = [0.15 0.15 0.15];  % almost black
C.plotting.colors.reason.exclude     = [0.40 0.40 0.40];  % grey: excluded by both methods
C.plotting.colors.reason.signal_fail = [0.50 0.00 0.00];  % dark red
C.plotting.colors.reason.flatline    = [0.60 0.60 0.60];  % gray
C.plotting.colors.reason.other       = [0.60 0.60 0.60];  % fallback

C.plotting.colors.EMG_TAprox_Concat = [0.20 0.60 0.80];
C.plotting.colors.EMG_TAdist_Concat = [0.30 0.70 0.90];
C.plotting.colors.EMG_SOL_Concat    = [0.85 0.45 0.15];
C.plotting.colors.EMG_GM_Concat     = [0.75 0.25 0.25];
C.plotting.colors.EMG_VL_Concat     = [0.40 0.70 0.40];
C.plotting.colors.EMG_RF_Concat     = [0.20 0.50 0.20];
C.plotting.colors.EMG_ST_Concat     = [0.60 0.40 0.75];
C.plotting.colors.EMG_GMED_Concat   = [0.50 0.30 0.65];

C.plotting.colors.envColor = [0 0 1]; % blue 'b'

% Extra colors for the retention script
C.plotting.colors.entries  = C.plotting.colors.Full;
C.plotting.colors.subjects = C.plotting.colors.Swing;
C.plotting.colors.left     = C.plotting.colors.Stance;
C.plotting.colors.right    = C.plotting.colors.Swing;
C.plotting.colors.other    = [0.45 0.45 0.45];


%% ===================== EMG Settings =====================

C.general.fs_vicon = 100;  % Hz (for synchronizing with EMG if needed)
C.general.fs_emg = 2000;   % Hz (default sampling rate for EMG, can be overridden in specific analyses)

%% ===================== SHARED COHERENCE / WAVELET SETTINGS =====================
C.shared_wavelet = struct();
C.shared_wavelet.WaveNumber = 7;
C.shared_wavelet.FreqBands = struct( ...
    'Alpha', [8 12], ...
    'Beta',  [13 30], ...
    'Gamma', [31 60]);
C.shared_wavelet.FreqMin = C.shared_wavelet.FreqBands.Alpha(1); %8 Hz
C.shared_wavelet.FreqMax = C.shared_wavelet.FreqBands.Gamma(2); %60 Hz

%% a_extract_raw_cycles_concat settings

C.a_extract_raw = struct();
C.a_extract_raw.participant_mode = 'auto';   % 'auto', 'manual_name', 'from_file_dialog'
C.a_extract_raw.manual_subjID = {'CTL_49', 'CTL_50', 'CTL_51', 'CTL_52', 'CTL_53', 'CTL_54', 'CTL_55', 'CTL_56', 'CTL_57', 'CTL_58', ...
    'CTL_59', 'CTL_60', 'CTL_61', 'CTL_62', 'CTL_63', 'CTL_64', 'CTL_65', 'CTL_66', 'CTL_67', 'CTL_68', ...
    'CTL_69', 'CTL_70', 'CTL_71', 'CTL_72', 'CTL_73', 'CTL_74', 'CTL_75', 'CTL_76', 'CTL_77'
};
% If participant_mode is 'manual_name', only these IDs will be processed.
C.a_extract_raw.save_recaps = true;

C.a_extract_raw.files = struct();
C.a_extract_raw.results_dir = fullfile(C.paths.results_dir, 'a_raw_signal_summary');
C.a_extract_raw.plot_dir = fullfile(C.paths.plot_dir, 'a_extract_raw_cycles_concat');

C.a_extract_raw.files.raw_signal_summary_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_SIGNAL_SUMMARY.csv');
C.a_extract_raw.files.raw_participant_summary_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_PARTICIPANT_SUMMARY.csv');
C.a_extract_raw.files.recap_by_age_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_BY_AGE.csv');
C.a_extract_raw.files.recap_by_condition_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_BY_CONDITION.csv');
C.a_extract_raw.files.recap_by_age_condition_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_BY_AGE_CONDITION.csv');
C.a_extract_raw.files.recap_participants_by_age_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_PARTICIPANTS_BY_AGE.csv');
C.a_extract_raw.files.recap_participants_by_condition_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_PARTICIPANTS_BY_CONDITION.csv');
C.a_extract_raw.files.recap_participants_by_age_condition_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION.csv');
C.a_extract_raw.files.recap_signals_per_participant_age_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE.csv');
C.a_extract_raw.files.recap_conditions_per_participant_age_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE.csv');
C.a_extract_raw.files.recap_cycles_per_participant_age_csv = fullfile(C.a_extract_raw.results_dir, 'RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE.csv');

% TO DO : CHANGE THE FOLLOWING TO ADAPT TO YOUR FOLDER STRUCTURE AND NAMING CONVENTIONS
C.a_extract_raw.input = struct();
% 'regex', 'table', 'custom_function'
C.a_extract_raw.input.filename_regex = ...
    '^(?<subjID>[^_]+_[^_]+)_(?<cond>Plat|Medium|High)_(?<ess>\d{2})(?:_NEW)?\.c3d$';
C.a_extract_raw.input.prefer_standard_over_new = false; % If true and multiple files match (e.g. both *_RAW_CYCLES_CONCAT.mat and *_RAW_CYCLES_CONCAT_NEW.mat exist), it will prefer the one without _NEW. Set to false if you want to prefer the _NEW version instead.
C.a_extract_raw.input.ignore_unmatched_files = true;   % but log them
C.a_extract_raw.design = struct();
C.a_extract_raw.design.conditions = {'Plat','Medium','High'};
C.a_extract_raw.design.legs = {'left','right'};
C.a_extract_raw.design.trials = {'01','02','03','04','05','06','07','08','09','10'};
C.a_extract_raw.design.muscles = {'EMG_TAprox','EMG_TAdist','EMG_SOL','EMG_GM','EMG_VL','EMG_RF','EMG_ST','EMG_GMED'};

C.a_extract_raw.events = struct();
% Names of events in the C3D file
C.a_extract_raw.events.hs = struct();
C.a_extract_raw.events.to = struct();
% Possible field names (priority order)
C.a_extract_raw.events.hs.left_candidates  = ["Left_Foot_Strike","LHS","Foot Strike Left"];
C.a_extract_raw.events.hs.right_candidates = ["Right_Foot_Strike","RHS","Foot Strike Right"];
C.a_extract_raw.events.to.left_candidates  = ["Left_Foot_Off","LTO","Foot Off Left"];
C.a_extract_raw.events.to.right_candidates = ["Right_Foot_Off","RTO","Foot Off Right"];

% Behavior if missing
C.a_extract_raw.events.allow_missing_to = true; 
C.a_extract_raw.events.to_fallback_ratio = 0.6;
% If true → use 60% gait cycle fallback for TO
% If false → exclude the entire trial when TO is missing

C.a_extract_raw.mapping = struct();
C.a_extract_raw.mapping.mode = 'association_script';
% 'association_script', 'fixed_names', 'mapping_table', 'custom_function'
C.a_extract_raw.mapping.association_script = fullfile(C.paths.code_dir, 'Metadata', 'Association.m');

% Used only when mapping.mode is 'fixed_names'; filled in per project.
C.a_extract_raw.mapping.fixed_names.left  = struct();
C.a_extract_raw.mapping.fixed_names.right = struct();


C.a_extract_raw.output = struct();
C.a_extract_raw.output.generate_example_figures = true; % If true, will generate example figures for each subject showing the raw signal with detected events and extracted cycles. Saved in RAW_PLOT_DIR.

%% ===================== EMG CHANNEL DETECTION =====================

C.a_extract_raw.channels = struct();
C.a_extract_raw.channels.muscle_keywords = struct();

% Possible keywords in the channel names for each muscle (used for automatic detection)
C.a_extract_raw.channels.muscle_keywords.EMG_TAprox = ["TAprox","tib_ant_dist"];
C.a_extract_raw.channels.muscle_keywords.EMG_TAdist = ["TAdist", "tib_ant_dist"];
C.a_extract_raw.channels.muscle_keywords.EMG_SOL    = ["SOL","soleus"];
C.a_extract_raw.channels.muscle_keywords.EMG_GM     = ["GM","gastro"];
C.a_extract_raw.channels.muscle_keywords.EMG_VL     = ["VL", "vastus"];
C.a_extract_raw.channels.muscle_keywords.EMG_RF     = ["RF", "rectus_femoris"];
C.a_extract_raw.channels.muscle_keywords.EMG_ST     = ["ST", "semitendinosus"];
C.a_extract_raw.channels.muscle_keywords.EMG_GMED   = ["GMED", "gluteus_medius"];

% LEFT / RIGHT detection
C.a_extract_raw.channels.left_keywords  = ["_L"," L","Left","left"];
C.a_extract_raw.channels.right_keywords = ["_R"," R","Right","right"];

% Behavior
C.a_extract_raw.missing = struct();
% Minimum required per muscle to keep it
C.a_extract_raw.missing.min_cycles_per_muscle = 0; % set to 0 to keep all muscles regardless of number of cycles, or set to a higher number if you want to exclude muscles with too few cycles (e.g. due to missing channels)
% Minimum required per pair (important later)

%% ===================== MARKER EXTRACTION =====================
C.a_extract_raw.markers = struct();
C.a_extract_raw.markers.enable = true;
C.a_extract_raw.markers.left.toe_candidates   = ["LTOE","Left_Toe","LTO"];
C.a_extract_raw.markers.left.heel_candidates  = ["LHEE","Left_Heel","LHE"];
C.a_extract_raw.markers.right.toe_candidates  = ["RTOE","Right_Toe","RTO"];
C.a_extract_raw.markers.right.heel_candidates = ["RHEE","Right_Heel","RHE"];

%% b_preprocess_emg

C.b_preproc = struct();
C.b_preproc.fs = C.general.fs_emg; % according to btk                    % if empty, try to infer later; otherwise set manually
C.b_preproc.bandpass = [8 450]; % Hz (8 so that we can include alpha band if needed, 450 is a common upper limit for EMG)
C.b_preproc.use_notch = false;          % set true if you have strong mains noise
C.b_preproc.notch_hz = 60;             % 50 or 60 depending on mains (USA / Canada vs Europe)
C.b_preproc.rectify = false;           % full-wave rectification (off by default, as it can distort coherence; set true if you want to analyze amplitude features later on)
C.b_preproc.normalize = "none";   % "none" | "zscore"

C.b_preproc.save_preproc_png = true;  % If true, saves a quick raw vs preproc plot for each subject in PNG_DIR (overwrites if already exists)
C.b_preproc.plot_random_examples = true; % If true, will plot a few random examples of raw vs preproc signals for quick QC. Plots are saved in PNG_QC_DIR.
C.b_preproc.n_random_examples = 10;  % Number of random examples to plot for QC. If you have many subjects, you might want to reduce this to avoid generating too many plots.
C.b_preproc.plot_seconds = 10; % When plotting random examples for QC, how many seconds of the signal to plot? (e.g. 10 will plot the first 10 seconds of the concatenated signal)

C.b_preproc.input_pattern = '*_RAW_CYCLES_CONCAT.mat';
C.b_preproc.output_suffix = '_EMG_PREPROC.mat';

C.b_preproc.inspect_one_output = true;
C.b_preproc.inspect_depth = 3;

C.b_preproc.time_domain = struct();
C.b_preproc.time_domain.save_bandpassed = true;
C.b_preproc.time_domain.save_rectified  = true;
C.b_preproc.time_domain.save_envelope   = true;

C.b_preproc.time_domain.envelope = struct();
C.b_preproc.time_domain.envelope.enable = true;
C.b_preproc.time_domain.envelope.lowpass_hz = 10;
C.b_preproc.time_domain.envelope.lowpass_order = 2;
C.b_preproc.time_domain.clip_negative_envelope = true;

%% c_extract_bursts_from_preproc

C.c_bursts = struct();

% ---------- I/O ----------
C.c_bursts.io = struct();
C.c_bursts.io.in_dir = C.paths.preproc_dir;
C.c_bursts.io.out_dir = C.paths.bursts_dir;
C.c_bursts.io.png_dir = fullfile(C.paths.plot_dir, 'c_burst_detection');

C.c_bursts.io.input_pattern = '*_EMG_PREPROC.mat';
C.c_bursts.io.output_suffix = '_EMG_BURSTS.mat';

% ---------- Detection parameters ----------
C.c_bursts.params = struct();

C.c_bursts.params.env_lowpass_hz = 50;
C.c_bursts.params.env_lowpass_order = 2;

C.c_bursts.params.flat_global_std_thr = 1e-8;
C.c_bursts.params.flat_local_std_thr = 1e-8;

C.c_bursts.params.window_minutes = 1;
C.c_bursts.params.threshold_prctile = 50;

C.c_bursts.params.min_run_1 = 100; % Should be 200 to match Fabien's parameters (100ms at 2000Hz), but set to 100 for now to be more inclusive and avoid excluding too many bursts in this first iteration. We can always increase it later if we find that we have too many false positives.
C.c_bursts.params.fill_zero_gap = 200; % Should be 300 to match Fabien's parameters (150ms at 2000Hz), but set to 200 for now to be more inclusive and avoid splitting bursts that are close together into multiple shorter bursts. We can always increase it later if we find that we have too many false positives.
C.c_bursts.params.min_run_2 = 200; % Deactivated below, but 400 if we want to match Fabien
C.c_bursts.params.max_run = 500;

C.c_bursts.params.local_std_window_sec = 0.05;

C.c_bursts.params.apply_remove_short_1 = true;
C.c_bursts.params.apply_fill_short_zeros = true;
C.c_bursts.params.apply_remove_short_2 = false;
C.c_bursts.params.apply_remove_long_runs = false;

% ---------- QC / plots ----------
C.c_bursts.qc = struct();
C.c_bursts.qc.save_png = false;
C.c_bursts.qc.max_png_per_subject = 8;

C.c_bursts.qc.save_random_burst_plots = true;
C.c_bursts.qc.n_random_burst_plots = 10;  % number of random bursts to plot for QC
C.c_bursts.qc.random_seed = 1;
C.c_bursts.qc.delete_old_png = true;

% ---------- Inspection ----------
C.c_bursts.inspect = struct();
C.c_bursts.inspect.inspect_one_output = true;
C.c_bursts.inspect.inspect_depth = 3;

%% d_a_extract_burst_features_for_clustering

C.d_features = struct();

% ---------- I/O ----------
C.d_features.io = struct();
C.d_features.io.in_dir = C.paths.bursts_dir;
C.d_features.io.out_dir = C.paths.features_dir;
C.d_features.io.csv_dir = fullfile(C.paths.results_dir, 'd_a_clustering_cleaning', 'csv_burst_features');
C.d_features.io.plot_dir = fullfile(C.paths.plot_dir, 'd_a_clustering_cleaning', 'feature_extraction');

C.d_features.io.input_pattern = '*_EMG_BURSTS.mat';
C.d_features.io.output_mat = 'BURST_FEATURES.mat';
C.d_features.io.output_csv = 'BURST_FEATURES.csv';

% ---------- Feature extraction parameters ----------
C.d_features.params = struct();
C.d_features.params.FreqMin = 1;
C.d_features.params.FreqMax = 400;
C.d_features.params.Resolution = 1;
C.d_features.params.WaveNumber = 7;
C.d_features.params.SampleEntropy_m = 2;
C.d_features.params.SampleEntropy_r = 0.2;
C.d_features.params.FuzzyEn_m = 2;
C.d_features.params.FuzzyEn_r = 0.5;
C.d_features.params.FuzzyEn_n = 2;
C.d_features.params.HFD_kmax = 8;

% IMPORTANT: If you set this to false, it will skip the actual feature extraction. This can be useful for testing the later steps (clustering, etc.) without having to wait for the feature extraction to run. 
% Just remember to set it back to true when you want to run the full pipeline!

C.d_features.params.run_feature_extraction = false;

% ---------- Plot settings ----------
C.d_features.plot = struct();
C.d_features.plot.nbins = 70;
C.d_features.plot.featureVars = {'MedFreq','Maxim','Skew','Kurt','Variance','SampEntr','FuzzyEntr','HFD','duration_s', 'MeanAbs','RMS','MaxDeriv','MeanAbsDeriv'};

%% d_clustering

C.d_clustering = struct();

% ---------- I/O ----------
C.d_clustering.io = struct();
C.d_clustering.io.in_dir = C.paths.features_dir;
C.d_clustering.io.cluster_dir = C.paths.clustering_dir;
C.d_clustering.io.csv_dir = fullfile(C.paths.results_dir, 'd_a_clustering_cleaning', 'csv_clustering_results');
C.d_clustering.io.plot_dir = fullfile(C.paths.plot_dir, 'd_a_clustering_cleaning', 'cluster_decision_plots');

C.d_clustering.io.output_clustered_csv = 'BURST_FEATURES_WITH_CLUSTERS.csv';
C.d_clustering.io.output_results_mat = 'CLUSTER_RESULTS.mat';

% ---------- Clustering parameters ----------
C.d_clustering.params = struct();
C.d_clustering.params.groupVar = "muscle";   % "ALL", "muscle", "age_group", "condition"
% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Variance','SampEntr','FuzzyEntr','HFD','duration_s', 'RMS', 'MaxDeriv'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.
% C.d_clustering.params.featureVars = {'MedFreq','SampEntr','FuzzyEntr','HFD','duration_s','MaxDeriv'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.
% 
% Best combination yet (more inclusive)
% C.d_clustering.params.featureVars = {'MedFreq', 'Maxim', 'SampEntr','FuzzyEntr','HFD'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

% This is bad for clustering (because it includes a lot of amplitude features that are likely to dominate the clustering and hide more subtle differences in the spectral/entropy features), but good for visualizing the clusters in a radar plot and understanding what features are driving the cluster separation. So we can use this for the final visualization after we have done the clustering with a more limited set of features.y
% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt','Variance','SampEntr','FuzzyEntr','HFD','duration_s', 'MeanAbs','RMS','MaxDeriv','MeanAbsDeriv'};

% This is not too bad 
% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt','SampEntr','FuzzyEntr','HFD','duration_s'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt','Variance','FuzzyEntr','duration_s'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt','Variance','FuzzyEntr'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

% C.d_clustering.params.featureVars = {'MedFreq','Maxim','Skew','Kurt','SampEntr','FuzzyEntr','HFD','duration_s'}; % List of feature variable names to use for clustering. Must match the variable names in the BURST_FEATURES.mat structure. You can choose a subset of features if you want (e.g. just spectral features, or just temporal features), or use them all.

C.d_clustering.params.featureVars = {'MedFreq','SampEntr','FuzzyEntr','HFD','duration_s','MaxDeriv'};

C.d_clustering.params.featureWeights = struct();
C.d_clustering.params.featureWeights.MedFreq = 1.0;
C.d_clustering.params.featureWeights.Maxim = 1.0;
C.d_clustering.params.featureWeights.Skew = 1.0;
C.d_clustering.params.featureWeights.Kurt = 1.0;
C.d_clustering.params.featureWeights.SampEntr = 1.0;
C.d_clustering.params.featureWeights.FuzzyEntr = 1.0;
C.d_clustering.params.featureWeights.HFD = 1.0;
C.d_clustering.params.featureWeights.duration_s = 1.0;
C.d_clustering.params.featureWeights.MaxDeriv = 1.0;
C.d_clustering.params.featureWeights.MeanAbs = 1.0;
C.d_clustering.params.featureWeights.RMS = 1.0;
C.d_clustering.params.featureWeights.MeanAbsDeriv = 1.0;

C.d_clustering.params.kList = 2:10;
C.d_clustering.params.replicates = 20;
C.d_clustering.params.distance = 'sqeuclidean';
C.d_clustering.params.maxIter = 1000;

C.d_clustering.params.maxSilhouetteN = 30000;
C.d_clustering.params.randomSeed = 1;
C.d_clustering.params.minBurstsPerGroup = 50;

C.d_clustering.params.k_selection_method = 'elbow'; % "silhouette", "calinski_harabasz", "davies_bouldin", "manual"
C.d_clustering.params.manual_k = 2;
% ---------- Inspection ----------
C.d_clustering.inspect = struct();
C.d_clustering.inspect.disp_tree_depth = 3;

%% d_cluster_manual

C.d_cluster_manual = struct();

% ---------- Manual KEEP mappings ----------
C.d_cluster_manual.keep = struct();

C.d_cluster_manual.keep.ALL = [1];

C.d_cluster_manual.keep.muscle = struct();
C.d_cluster_manual.keep.muscle.EMG_GMED_Concat   = [1 3];
C.d_cluster_manual.keep.muscle.EMG_GM_Concat     = [1 4];
C.d_cluster_manual.keep.muscle.EMG_RF_Concat     = [2];
C.d_cluster_manual.keep.muscle.EMG_SOL_Concat    = [3];
C.d_cluster_manual.keep.muscle.EMG_ST_Concat     = [2];
C.d_cluster_manual.keep.muscle.EMG_TAdist_Concat = [1 2 5];
C.d_cluster_manual.keep.muscle.EMG_TAprox_Concat = [1 3 5];
C.d_cluster_manual.keep.muscle.EMG_VL_Concat     = [4];

C.d_cluster_manual.keep.age_group = struct();
C.d_cluster_manual.keep.age_group.JeunesEnfants = [1];
C.d_cluster_manual.keep.age_group.Enfants       = [2];
C.d_cluster_manual.keep.age_group.Adolescents   = [1];
C.d_cluster_manual.keep.age_group.Adultes       = [3];

C.d_cluster_manual.keep.condition = struct();
C.d_cluster_manual.keep.condition.Flat   = [1];
C.d_cluster_manual.keep.condition.Medium = [2];
C.d_cluster_manual.keep.condition.High   = [1];

% ---------- Final QC random plots ----------
C.d_cluster_manual.qc = struct();
C.d_cluster_manual.qc.n_random_signals = 10;  % number of random signals to plot for final QC after manual cluster-based exclusions
C.d_cluster_manual.qc.random_seed = [];
C.d_cluster_manual.qc.delete_old_png = true;

C.d_cluster_manual.io = struct();
C.d_cluster_manual.io.final_plot_dir = fullfile(C.paths.plot_dir, 'd_a_clustering_cleaning', 'cluster_decision_plots', 'qc_final_cluster_decisions');

%% d_b_rule_based_cleaning

C.d_rule_based = struct();

% ---------- I/O ----------
C.d_rule_based.io = struct();
C.d_rule_based.io.preproc_dir = C.paths.preproc_dir;
C.d_rule_based.io.bursts_dir = C.paths.bursts_dir;
C.d_rule_based.io.out_dir = C.paths.rule_based_dir;

C.d_rule_based.io.plot_dir = fullfile(C.paths.plot_dir, 'd_b_rule_based_cleaning', 'rule_based_decision_plots');
C.d_rule_based.io.signal_fail_plot_dir = fullfile(C.paths.plot_dir, 'd_b_rule_based_cleaning', 'rule_based_decision_plots', 'signal_failures');
C.d_rule_based.io.csv_dir = fullfile(C.paths.results_dir, 'd_b_rule_based_cleaning', 'csv_burst_qc');

C.d_rule_based.io.preproc_pattern = '*_EMG_PREPROC.mat';
C.d_rule_based.io.bursts_pattern = '*_EMG_BURSTS.mat';
C.d_rule_based.io.output_csv = 'QC_bursts_summary.csv';
C.d_rule_based.io.output_mat = 'QC_bursts.mat';

% ---------- Plot / runner QC ----------
C.d_rule_based.qc = struct();
C.d_rule_based.qc.max_plot_signals = 30;
C.d_rule_based.qc.delete_old_plots = true;
C.d_rule_based.qc.random_seed = [];
C.d_rule_based.qc.inspect_saved_table = true;
C.d_rule_based.qc.plot_signal_fails = true;

% ---------- Core parameters ----------
C.d_rule_based.params = struct();

% Core checks
C.d_rule_based.params.min_seconds_per_signal = 0; % Not activated right now, but if you want to exclude bursts from signals that have very little data (e.g. due to a lot of visual artifact rejection), you can set this to a positive number (e.g. 10 or 30 seconds) and it will exclude bursts from any signal that has less than that amount of data after all the cleaning steps.
C.d_rule_based.params.max_nan_frac = 0.001;

% Flatline
C.d_rule_based.params.flatline_block_sec = 0.25;
C.d_rule_based.params.flatline_std_frac = 0.02;
C.d_rule_based.params.max_flatline_frac_fail = 0.1;
C.d_rule_based.params.max_flatline_frac_warn = 0;

% Line noise
C.d_rule_based.params.check_line_noise = true;
C.d_rule_based.params.line_hz_candidates = [50 60];
C.d_rule_based.params.line_bandwidth_hz = 1.0;
C.d_rule_based.params.max_line_ratio_fail = 0.20;
C.d_rule_based.params.max_line_ratio_warn = 0.10;

% Spectrum shape
C.d_rule_based.params.check_spectrum = true;
C.d_rule_based.params.spec_sec = 10;
C.d_rule_based.params.band_low = [0 5];
C.d_rule_based.params.band_mid = [10 250];
C.d_rule_based.params.band_high = [250 450];
C.d_rule_based.params.max_low_over_mid_fail = 2.5;
C.d_rule_based.params.max_low_over_mid_warn = 1.5;
C.d_rule_based.params.max_high_over_mid_fail = 1.2;
C.d_rule_based.params.max_high_over_mid_warn = 0.7;
C.d_rule_based.params.spectrum_fail = true;

% Absolute amplitude
C.d_rule_based.params.units = "V";

% Whole-signal plotting behavior
C.d_rule_based.params.plot_seconds = NaN;

% Runner behavior

% Plateau detection
C.d_rule_based.params.plateau_eps_frac = 0.05;

% Rail detection
C.d_rule_based.params.rail_eps_frac = 0.005;

% Flatline absolute thresholds
C.d_rule_based.params.flatline_p2p_max = 1e-5;
C.d_rule_based.params.flatline_rms_max = 1e-6;

% ===== Burst-level QC =====
C.d_rule_based.params.burst = struct();
C.d_rule_based.params.burst.enable = true;

C.d_rule_based.params.burst.duration = struct();
C.d_rule_based.params.burst.duration.too_short_enable = false;  % If true, will exclude bursts that are too short based on the parameters below. If false, duration will not be considered in burst-level QC decisions.
C.d_rule_based.params.burst.duration.too_long_enable = false;  % If true, will exclude bursts that are too long based on the parameters below. If false, duration will not be considered in burst-level QC decisions.
C.d_rule_based.params.burst.duration.min_duration_ms = 50;
C.d_rule_based.params.burst.duration.max_duration_ms = 1000;

C.d_rule_based.params.burst.spike = struct();
C.d_rule_based.params.burst.spike.enable = false;
C.d_rule_based.params.burst.spike.amp_z_fail = 15;
C.d_rule_based.params.burst.spike.amp_z_warn = 11;
C.d_rule_based.params.burst.spike.deriv_z_warn = 15;

C.d_rule_based.params.burst.spike.global_enable = true;
C.d_rule_based.params.burst.spike.global_amp_z_fail = 5;     % decrease -> stricter, increase -> more permissive
C.d_rule_based.params.burst.spike.global_min_bursts = 15;     % only use this rule if enough bursts exist in the signal

C.d_rule_based.params.burst.plateau = struct();
C.d_rule_based.params.burst.plateau.enable = false;
C.d_rule_based.params.burst.plateau_eps_frac = 0.05;
C.d_rule_based.params.burst.plateau_frac_fail = 0.40;
C.d_rule_based.params.burst.rail_eps_frac = 0.005;
C.d_rule_based.params.burst.rail_frac_fail = 0.10;

C.d_rule_based.params.burst.spec = struct();
C.d_rule_based.params.burst.spec_low = [0 5];
C.d_rule_based.params.burst.spec_mid = [10 250];
C.d_rule_based.params.burst.spec_high = [250 450];
C.d_rule_based.params.burst.spec_low_over_mid_fail = 3.0;
C.d_rule_based.params.burst.spec_high_over_mid_fail = 1.3;

C.d_rule_based.params.burst.medfreq.enable = true;
C.d_rule_based.params.burst.medfreq.min_hz_fail = 20;   % increase -> stricter, decrease -> more permissive
C.d_rule_based.params.burst.spec.enable = false;        % disable old weird spectrum rule if replacing it

C.d_rule_based.params.burst.abs = struct();
C.d_rule_based.params.burst.abs.enable = true;
C.d_rule_based.params.burst.abs.units = "V";
C.d_rule_based.params.burst.abs.max_p2p_mV_fail = 8;
C.d_rule_based.params.burst.abs.max_rms_mV_fail = 1.5;


%% e_final_burst_qc_combination

C.e_final_burst_qc = struct();

% ---------- I/O ----------
C.e_final_burst_qc.io = struct();
C.e_final_burst_qc.io.rule_based_mat = fullfile(C.paths.rule_based_dir, 'QC_bursts.mat');
C.e_final_burst_qc.io.cluster_mat    = fullfile(C.paths.clustering_dir, 'CLUSTER_RESULTS.mat');

C.e_final_burst_qc.io.visual_xlsm  = fullfile(C.paths.code_dir, 'Metadata', 'Mapping-EMG.xlsm');
C.e_final_burst_qc.io.visual_sheet = 'Mapping-ALL';

C.e_final_burst_qc.io.bursts_dir = C.paths.bursts_dir;

C.e_final_burst_qc.io.out_dir = C.paths.burst_decision_dir;
C.e_final_burst_qc.io.csv_dir = fullfile(C.paths.results_dir, 'e_final_burst_qc_combination', 'csv');

C.e_final_burst_qc.io.out_mat = fullfile(C.e_final_burst_qc.io.out_dir, 'FINAL_BURST_QC.mat');
C.e_final_burst_qc.io.out_csv = fullfile(C.e_final_burst_qc.io.csv_dir, 'FINAL_BURST_QC_summary.csv');

% ---------- Decision parameters ----------
C.e_final_burst_qc.params = struct();
C.e_final_burst_qc.params.decision_rule = "conservative";   % "conservative" | "inclusive"
C.e_final_burst_qc.params.use_visual_mapping = false; % If true, will use the Visual Mapping XLSM file to determine final burst decisions for bursts that are missing cluster-based QC results. If false, will use the missing_cluster_policy instead.

% ---------- Plot settings ----------
C.e_final_burst_qc.plot = struct();
C.e_final_burst_qc.plot.enable = true;
C.e_final_burst_qc.plot.n_random_signals = 20;
C.e_final_burst_qc.plot.random_seed = [];
C.e_final_burst_qc.plot.out_dir = fullfile(C.paths.plot_dir, 'e_final_burst_decision');

% ---------- Display / inspection ----------
C.e_final_burst_qc.inspect = struct();
C.e_final_burst_qc.inspect.disp_tree_depth = 3;

% ---------- Bad burst histogram settings ----------
C.e_final_burst_qc.plot.bad_burst_hist = struct();
C.e_final_burst_qc.plot.bad_burst_hist.enable = false;
C.e_final_burst_qc.plot.bad_burst_hist.nbins = 20;
C.e_final_burst_qc.plot.bad_burst_hist.normalize = 'probability'; % 'count' or 'probability'
C.e_final_burst_qc.plot.bad_burst_hist.out_dir = fullfile(C.paths.plot_dir, 'e_final_burst_decision', 'bad_burst_histograms');
C.e_final_burst_qc.plot.bad_burst_hist.out_png = fullfile(C.e_final_burst_qc.plot.bad_burst_hist.out_dir, 'bad_burst_location_histograms.png');
C.e_final_burst_qc.plot.bad_burst_hist.out_csv = fullfile(C.e_final_burst_qc.plot.bad_burst_hist.out_dir, 'bad_burst_location_table.csv');

% ---------- Burst example plots ----------
C.e_final_burst_qc.plot.burst_examples = struct();
C.e_final_burst_qc.plot.burst_examples.enable = true;
C.e_final_burst_qc.plot.out_dir_examples = fullfile(C.paths.plot_dir, 'e_final_burst_decision', 'burst_examples');

C.e_final_burst_qc.plot.burst_examples.window_ms = 2000;   % total window
C.e_final_burst_qc.plot.burst_examples.n_per_reason = 1;  % one random example per reason
C.e_final_burst_qc.plot.burst_examples.random_seed = [];
C.e_final_burst_qc.plot.burst_examples.delete_old_png = true;

C.e_final_burst_qc.plot.burst_examples.good_color = C.plotting.colors.include;
C.e_final_burst_qc.plot.burst_examples.rule_color = C.plotting.colors.exclude_rule_based;
C.e_final_burst_qc.plot.burst_examples.cluster_color = C.plotting.colors.exclude_cluster_based;
C.e_final_burst_qc.plot.burst_examples.both_color = C.plotting.colors.exclude;

C.e_final_burst_qc.plot.burst_examples.visual_color = C.plotting.colors.exclude_visual;
C.e_final_burst_qc.plot.burst_examples.signal_rule_color = C.plotting.colors.exclude_signal_rule;

C.e_final_burst_qc.plot.burst_examples.use_fixed_ylim = false;


%% f_final_signals

C.f_final_signals = struct();

% ---------- I/O ----------
C.f_final_signals.io = struct();
C.f_final_signals.io.final_burst_mat = fullfile(C.paths.burst_decision_dir, 'FINAL_BURST_QC.mat');
C.f_final_signals.io.bursts_dir = C.paths.bursts_dir;

C.f_final_signals.io.out_dir = C.paths.final_signals_dir;
C.f_final_signals.io.out_mat = fullfile(C.f_final_signals.io.out_dir, 'FINAL_PAIRED_SIGNALS.mat');

C.f_final_signals.io.xlsx_dir = fullfile(C.paths.results_dir, 'f_cycle_level_qc_and_signal_rebuild');
C.f_final_signals.io.recap_xlsx_dir = fullfile(C.f_final_signals.io.xlsx_dir, 'recap_tables');
C.f_final_signals.io.cycle_qc_xlsx = fullfile(C.f_final_signals.io.xlsx_dir, 'CYCLE_QC_TABLE.xlsx');
C.f_final_signals.io.pair_cycle_xlsx = fullfile(C.f_final_signals.io.xlsx_dir, 'PAIR_CYCLE_QC_TABLE.xlsx');
C.f_final_signals.io.signal_sum_xlsx = fullfile(C.f_final_signals.io.xlsx_dir, 'FINAL_SIGNAL_SUMMARY.xlsx');


C.f_final_signals.io.excluded_burst_position_xlsx = fullfile(C.f_final_signals.io.xlsx_dir, 'EXCLUDED_CYCLE_BURST_POSITION_TABLE.xlsx');
C.f_final_signals.io.excluded_burst_position_plot_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'excluded_burst_position_plots');


% ---------- Pair definitions ----------
C.f_final_signals.params = struct();

% C.f_final_signals.params.pairs = {
%     struct('name',"TAprox_TAdist", 'muscles',{{'EMG_TAprox_Concat','EMG_TAdist_Concat'}})
%     struct('name',"SOL_GM", 'muscles',{{'EMG_SOL_Concat','EMG_GM_Concat'}})
%     struct('name',"VL_RF",  'muscles',{{'EMG_VL_Concat','EMG_RF_Concat'}})
% };
C.f_final_signals.params.pairs = {
    struct('name',"TAprox_TAdist", 'muscles',{{'EMG_TAprox_Concat','EMG_TAdist_Concat'}})
    struct('name',"SOL_GM", 'muscles',{{'EMG_SOL_Concat','EMG_GM_Concat'}})
};

% ---------- Cycle policy ----------
C.f_final_signals.params.cycle_policy = struct();
C.f_final_signals.params.cycle_policy.require_at_least_one_burst = true;
C.f_final_signals.params.cycle_policy.require_at_least_one_good_burst = true;

% Choose one policy for how to handle cycles with some bad bursts:
C.f_final_signals.params.cycle_policy.reject_if_any_bad_burst = false;
C.f_final_signals.params.cycle_policy.reject_if_bad_burst_fraction_over = false;
C.f_final_signals.params.cycle_policy.parameters.max_bad_burst_fraction = 0.10;
C.f_final_signals.params.cycle_policy.reject_if_in_phase_of_interest = false;
C.f_final_signals.params.cycle_policy.reject_if_in_phase_of_interest_padded_for_wavelet_analysis = true;

C.f_final_signals.params.cycle_policy.reject_flatline_cycles = true;
C.f_final_signals.params.cycle_policy.parameters.flatline_method = "ptp";
C.f_final_signals.params.cycle_policy.parameters.flatline_min_ptp = 1e-8;
C.f_final_signals.params.cycle_policy.parameters.flatline_min_std = 1e-8;

C.f_final_signals.params.cycle_policy.reject_if_flatline_fraction_over = true;
C.f_final_signals.params.cycle_policy.parameters.max_flatline_fraction = 0.01;

C.f_final_signals.params.cycle_policy.parameters.flatline_diff_thresh = 1e-8;
C.f_final_signals.params.cycle_policy.parameters.flatline_min_run_samples = 20;

% ---------- Pair policy ----------

% ---------- Minimum valid cycles ----------
C.f_final_signals.params.min_cycles_required = 10; % Minimum number of valid cycles required for a signal to be included in the final dataset. If a signal has fewer than this number of valid cycles after applying the cycle-level QC policies, it will be excluded from the final paired signals dataset.

% ---------- Cycle field candidates ----------
C.f_final_signals.params.cycle_field_candidates = { ...
    'cycle_starts', ...
    'cycle_start_idx', ...
    'gc_start_idx', ...
    'gait_cycle_starts', ...
    'heel_strikes', ...
    'hs_idx', ...
    'cycleStartIdx', ...
    'starts_idx'};

C.f_final_signals.params.cycle_end_field_candidates = { ...
    'cycle_ends', ...
    'cycle_end_idx', ...
    'gc_end_idx', ...
    'gait_cycle_ends', ...
    'cycleEndIdx', ...
    'ends_idx'};

% ---------- Plot settings ----------
C.f_final_signals.plot = struct();

C.f_final_signals.plot.hist_cycles_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'hist_cycles_per_signal');

C.f_final_signals.plot.excluded = struct();
C.f_final_signals.plot.excluded.enable = true;
C.f_final_signals.plot.excluded.n_random_pairs = 10;
C.f_final_signals.plot.excluded.random_seed = [];
C.f_final_signals.plot.excluded.out_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'qc_excluded_pair_plots');

C.f_final_signals.plot.rebuilt = struct();
C.f_final_signals.plot.rebuilt.enable = true;
C.f_final_signals.plot.rebuilt.n_random = 10;
C.f_final_signals.plot.rebuilt.random_seed = [];
C.f_final_signals.plot.rebuilt.out_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'final_rebuilt_signal_examples');
C.f_final_signals.plot.rebuilt.delete_old_png = false;

C.f_final_signals.plot.manual.enable = true;
C.f_final_signals.plot.manual.out_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'manual_pair_plots');
C.f_final_signals.plot.manual.requests = {
    struct('subject',"CTL_79",'condition',"Flat",'leg',"right",'pair_name',"TAprox_TAdist")
    %struct('subject',"CTL_37",'condition',"High",'leg',"left",'pair_name',"TAprox_TAdist")
    % struct('subject',"CTL_63",'condition',"High",'leg',"right",'pair_name',"SOL_GM")
};

% ---------- Wavelet ROI exclusion example plots ----------
C.f_final_signals.plot.wavelet_roi = struct();
C.f_final_signals.plot.wavelet_roi.enable = true;
C.f_final_signals.plot.wavelet_roi.n_random_pairs = 10;
C.f_final_signals.plot.wavelet_roi.random_seed = [];
C.f_final_signals.plot.wavelet_roi.delete_old_png = true;
C.f_final_signals.plot.wavelet_roi.out_dir = fullfile(C.paths.plot_dir, ...
    'f_cycle_level_qc_and_signal_rebuild', 'wavelet_roi_exclusion_examples');

% % ---------- Wavelet-aware contamination QC ----------
% C.f_final_signals.params.wavelet_contamination_qc = struct();

% % start simple: one overall conservative boundary
C.f_final_signals.params.wavelet_contamination_qc.mode = "overall";
% % options: "overall" | "per_band"

C.f_final_signals.params.wavelet_contamination_qc.boundary_type = "classical_coi"; % "classical_coi or amplitude_based
C.f_final_signals.params.wavelet_contamination_qc.amplitude_tol = 0.05;

C.f_final_signals.params.wavelet_contamination_qc.overall_rule = "max_band"; % or "alpha", have to implement for the others if we want to have separate datasets for each band
C.f_final_signals.params.wavelet_contamination_qc.extra_buffer_sec = 0;

C.f_final_signals.params.wavelet_contamination_qc.wave_number = C.shared_wavelet.WaveNumber;
C.f_final_signals.params.wavelet_contamination_qc.freq_bands  = C.shared_wavelet.FreqBands;

C.f_final_signals.params.wavelet_contamination_qc.phase_windows_pct = struct();

C.f_final_signals.params.wavelet_contamination_qc.phase_windows_pct.TAprox_TAdist = C.physio.phase_windows_pct.TAprox_TAdist;

C.f_final_signals.params.wavelet_contamination_qc.phase_windows_pct.SOL_GM = C.physio.phase_windows_pct.SOL_GM;

C.f_final_signals.params.wavelet_contamination_qc.phase_windows_pct.VL_RF = C.physio.phase_windows_pct.VL_RF;

C.f_final_signals.plot.rebuilt_band = struct();
C.f_final_signals.plot.rebuilt_band.enable = true;
C.f_final_signals.plot.rebuilt_band.n_random_per_band = 10;
C.f_final_signals.plot.rebuilt_band.random_seed = [];
C.f_final_signals.plot.rebuilt_band.out_dir = fullfile( ...
    C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'band_specific_rebuilt_examples');


C.f_final_signals.plot.excluded_band = struct();
C.f_final_signals.plot.excluded_band.enable = true;
C.f_final_signals.plot.excluded_band.n_random_per_band = 10;
C.f_final_signals.plot.excluded_band.random_seed = [];
C.f_final_signals.plot.excluded_band.out_dir = fullfile( ...
    C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'band_specific_excluded_examples');

C.f_final_signals.io.out_mat_overall = fullfile(C.f_final_signals.io.out_dir, 'FINAL_PAIRED_SIGNALS_OVERALL.mat');
C.f_final_signals.io.out_mat_alpha   = fullfile(C.f_final_signals.io.out_dir, 'FINAL_PAIRED_SIGNALS_ALPHA.mat');
C.f_final_signals.io.out_mat_beta    = fullfile(C.f_final_signals.io.out_dir, 'FINAL_PAIRED_SIGNALS_BETA.mat');
C.f_final_signals.io.out_mat_gamma   = fullfile(C.f_final_signals.io.out_dir, 'FINAL_PAIRED_SIGNALS_GAMMA.mat');

% ---------- Signal recap per band ----------


% ---------- Participant recap per band ----------


% ---------- Participant-by-pair recap per band ----------


%% ---------- Cross-talk QC integration ----------
C.f_final_signals.crosstalk = struct();

C.f_final_signals.crosstalk.enable = true;

% Run cross-talk QC on this/these modes.
% If any checked mode is suspicious, the pair signal is excluded.
C.f_final_signals.crosstalk.analysis_modes = ["overall"]; 
% later possible: ["overall","Alpha","Beta","Gamma"]

C.f_final_signals.crosstalk.target_pairs = ["TAprox_TAdist"];
C.f_final_signals.crosstalk.target_age_groups = "all";
C.f_final_signals.crosstalk.target_conditions = "all";
C.f_final_signals.crosstalk.target_legs = "all";


C.f_final_signals.crosstalk.max_lag_ms = 300;
C.f_final_signals.crosstalk.zero_lag_window_ms = 1;

C.f_final_signals.crosstalk.central_spike = struct();
C.f_final_signals.crosstalk.central_spike.broad_smooth_window_ms = 25;
C.f_final_signals.crosstalk.central_spike.search_window_ms = 5;
C.f_final_signals.crosstalk.central_spike.min_prominence = 0.00005;
C.f_final_signals.crosstalk.central_spike.max_width_ms = 5;

C.f_final_signals.crosstalk.coh_fmax = 100;
C.f_final_signals.crosstalk.coh_window_sec = 1.0;
C.f_final_signals.crosstalk.coh_overlap_fraction = 0.5;
C.f_final_signals.crosstalk.coh_nfft_sec = 2.0;

C.f_final_signals.crosstalk.freq_bands = struct();
C.f_final_signals.crosstalk.freq_bands.Alpha = [8 12];
C.f_final_signals.crosstalk.freq_bands.Beta  = [13 30];
C.f_final_signals.crosstalk.freq_bands.Gamma = [31 80];
C.f_final_signals.crosstalk.freq_bands.Broad = [10 80];

C.f_final_signals.crosstalk.thresholds = struct();
C.f_final_signals.crosstalk.thresholds.rectified_zero_lag_corr = 0.70;
C.f_final_signals.crosstalk.thresholds.raw_zero_lag_corr = 0.70;
C.f_final_signals.crosstalk.thresholds.max_abs_cumulant_around_zero = 0.75;
C.f_final_signals.crosstalk.thresholds.peak_abs_lag_ms = 5.0;
C.f_final_signals.crosstalk.thresholds.peak_width_ms = 4.0;
C.f_final_signals.crosstalk.thresholds.mean_coh_broad = 0.30;
C.f_final_signals.crosstalk.thresholds.mean_coh_alpha = 0.30;
C.f_final_signals.crosstalk.thresholds.mean_coh_beta = 0.30;
C.f_final_signals.crosstalk.thresholds.mean_coh_gamma = 0.30;

C.f_final_signals.crosstalk.out_dir = fullfile(C.f_final_signals.io.xlsx_dir, 'crosstalk_qc');
C.f_final_signals.crosstalk.plot_dir = fullfile(C.paths.plot_dir, 'f_cycle_level_qc_and_signal_rebuild', 'crosstalk_qc');

C.f_final_signals.crosstalk.out_xlsx = fullfile(C.f_final_signals.crosstalk.out_dir, 'CROSSTALK_QC_TABLE.xlsx');
C.f_final_signals.crosstalk.out_suspicious_xlsx = fullfile(C.f_final_signals.crosstalk.out_dir, 'CROSSTALK_QC_SUSPICIOUS.xlsx');

C.f_final_signals.crosstalk.plot.enable = true;
C.f_final_signals.crosstalk.plot.only_suspicious = true;
C.f_final_signals.crosstalk.plot.max_plots = inf;
C.f_final_signals.crosstalk.plot.random_seed = 1;

%% g_emg_emg_wavelet_coherence_from_final_signals

C.g_coherence = struct();

% ===================== I/O =====================
C.g_coherence.io = struct();
C.g_coherence.io.final_paired_mat = fullfile(C.paths.final_signals_dir, 'FINAL_PAIRED_SIGNALS.mat'); % fichier d'entrée principal
C.g_coherence.io.out_dir = C.paths.coherence_dir;                                                    % dossier de sortie principal
C.g_coherence.io.out_mat = fullfile(C.g_coherence.io.out_dir, 'COHERENCE_RESULTS.mat');             % fichier .mat final
C.g_coherence.io.summary_csv_dir = fullfile(C.paths.results_dir, 'g_emg_emg_wavelet_coherence');    % dossier pour les csv/résumés éventuels

% ===================== Plot settings =====================
C.g_coherence.plot = struct();
C.g_coherence.plot.enable = false;   % setting to false makes it much faster                                                                  % true = faire les plots individuels
C.g_coherence.plot.save_png = true;                                                                  % true = sauvegarder les figures en png
C.g_coherence.plot.dir = fullfile(C.paths.plot_dir, 'g_emg_emg_wavelet_coherence');                 % dossier global des plots
C.g_coherence.plot.individual_plots_dir = fullfile(C.g_coherence.plot.dir, 'individual_plots');     % cartes de cohérence par signal
C.g_coherence.plot.before_after_plots_dir = fullfile(C.g_coherence.plot.dir, 'before_after_plots'); % plots raw vs thresholded / avant-après
C.g_coherence.plot.delete_old_png = false;                                                           % true si tu veux supprimer les anciens plots à chaque run

% ===================== Wavelet parameters =====================
C.g_coherence.params = struct();
C.g_coherence.params.FreqMin = C.shared_wavelet.FreqMin;            % borne basse de fréquence analysée
C.g_coherence.params.FreqMax = C.shared_wavelet.FreqMax;          % borne haute de fréquence analysée
C.g_coherence.params.Resolution = 1;         % résolution fréquentielle pour WaveletParameters
C.g_coherence.params.WaveNumber = C.shared_wavelet.WaveNumber;         % compromis résolution temps / fréquence

% ===================== Metric sources to save =====================
% Options:
%   "raw"           = unthresholded coherence, all retained cycles
%   "equalized" = unthresholded coherence but after equalizing N cycles (for fair comparison with sig_equalized)
%   "sig"           = thresholded/significant coherence, all retained cycles
%   "sig_equalized" = thresholded/significant coherence after equalizing N cycles
%   "sig_common_threshold" = thresholded/significant coherence but using a common threshold across all signals
%   "zcoh_bokil" = z-scored coherence using Bokil's method, which is designed to be more robust to differences in number of cycles across signals
%   "surrogate_delta" = difference between actual coherence and surrogate coherence, using the same number of cycles for both
%   "cycle_bias_corrected" = coherence after correcting for bias due to different number of cycles, using a formula derived from simulations

% C.g_coherence.params.metric_sources_to_save = ["raw", "equalized", "sig", "sig_equalized", "sig_common_threshold", "zcoh_bokil"];
C.g_coherence.params.metric_sources_to_save = ["equalized"];

% Which source is used by default for summary tables / group plots
% Options: "raw", "equalized", "sig", "sig_equalized", "sig_common_threshold", "zcoh_bokil", "surrogate_delta"
C.g_coherence.params.default_metric_source_for_tables = "equalized";

C.g_coherence.params.store_sig_common_threshold_coherence = true;
C.g_coherence.params.store_equalized_coherence = true;

% ===================== Cycle equalization for significant coherence =====================
C.g_coherence.params.cycle_equalization = struct();

% Master switch for sig_equalized
C.g_coherence.params.cycle_equalization.enable = true;

% How to choose the common number of cycles
% Options:
%   "global_min"  = use the minimum N cycles across all included entries in this dataset
%   "manual"      = use manual_n_cycles
C.g_coherence.params.cycle_equalization.mode = "global_min";

% Used only if mode = "manual"
C.g_coherence.params.cycle_equalization.manual_n_cycles = 20; % ignored if mode is not "manual"

% How to select cycles when a signal has more than N_common
% Options:
%   "evenly_spaced" = deterministic, spread across available cycles
%   "first"         = first N_common retained cycles
%   "last"          = last N_common retained cycles
%   "random_once"   = one random subset
C.g_coherence.params.cycle_equalization.selection = "evenly_spaced";

% Used only for random_once
C.g_coherence.params.cycle_equalization.random_seed = 1;

C.g_coherence.params.store_sig_equalized_coherence = true;

% ===================== Bokil-style z-coherence =====================
C.g_coherence.params.zcoh_bokil = struct();

% Enable computation if metric_sources_to_save includes "zcoh_bokil" or "all"
C.g_coherence.params.zcoh_bokil.enable = true;

% Input transform:
%   "coherence"      = atanh(C)
%   "sqrt_coherence" = atanh(sqrt(C))
%
% IMPORTANT:
% Your current C is magnitude-squared coherence.
% Some formulas use atanh(sqrt(C)); the text you pasted appears to use atanh(C).
% Start with "coherence" to match the pasted text.
C.g_coherence.params.zcoh_bokil.input_transform = "coherence";

% Degrees of freedom convention:
%   "n_cycles" = df = number of retained cycles
%   "2n_cycles" = df = 2 * number of retained cycles
%
% The pasted text says df = epochs x tapers.
% Since we do not use tapers, start with n_cycles.
C.g_coherence.params.zcoh_bokil.df_mode = "n_cycles";

% Whether to store the actual z-coherence map
% Set false if files get too large.
C.g_coherence.params.store_zcoh_bokil_map = true;

% ===================== Cycle bias correction =====================

C.g_coherence.params.cycle_bias_correction = struct();
C.g_coherence.params.cycle_bias_correction.enable = true;
C.g_coherence.params.cycle_bias_correction.a = 0.772565;
C.g_coherence.params.cycle_bias_correction.Nref = 200;
C.g_coherence.params.cycle_bias_correction.clip_to_01 = true;
C.g_coherence.params.store_cycle_bias_corrected_coherence = true;

% ===================== COI example plots =====================
C.g_coherence.plot.coi_examples = struct();
C.g_coherence.plot.coi_examples.enable = true;
C.g_coherence.plot.coi_examples.n_random = 10;
C.g_coherence.plot.coi_examples.random_seed = 1;
C.g_coherence.plot.coi_examples.dir = fullfile(C.g_coherence.plot.dir, 'coi_examples');
C.g_coherence.plot.coi_examples.delete_old_png = true;

C.g_coherence.plot.individual.enable = true;
C.g_coherence.plot.individual.max_plots = 10;

C.g_coherence.plot.before_after.enable = true;
C.g_coherence.plot.before_after.max_plots = 10;

C.g_coherence.plot.outer_cycle_diag.enable = true;
C.g_coherence.plot.outer_cycle_diag.max_plots = 10;

C.g_coherence.plot.cycle_band_qc.enable = true;
C.g_coherence.plot.cycle_band_qc.max_examples = 10;
C.g_coherence.plot.cycle_band_qc.max_pooled = 20;

% ===================== Edge-effect QC =====================
C.g_coherence.params.qc_edge.enable = true;
C.g_coherence.params.qc_edge.dir = fullfile(C.g_coherence.plot.dir, 'edge_effect_qc');
C.g_coherence.params.qc_edge.csv_dir = fullfile(C.paths.results_dir, 'g_emg_emg_wavelet_coherence', 'edge_effect_qc');


% ===================== Frequency bands =====================
C.g_coherence.params.FreqBands = C.shared_wavelet.FreqBands;

% ===================== Cycle normalization =====================
C.g_coherence.params.n_interp_time = 1000;   % chaque cycle est interpolé à 1000 points temporels

% ===================== Significance =====================
C.g_coherence.params.alpha = 0.05;           % alpha pour le seuil de significativité Rosenberg
C.g_coherence.params.store_raw_coherence = true;      % true = garde aussi la matrice de cohérence brute
C.g_coherence.params.store_sig_coherence = true;      % true = garde aussi la cohérence thresholdée

% ===================== Toe-off / phase segmentation =====================
C.g_coherence.params.use_toeoff_segmentation = true; % true = stance/swing basés sur toe-off moyen
C.g_coherence.params.default_toeoff_percent = 60;    % utilisé si pas de toe-off disponible

% ===================== Padding for wavelet edge effects =====================
C.g_coherence.params.padding = struct();

% Options: 'zero', 'cycle_wrap', 'mirror'
C.g_coherence.params.padding.mode = 'mirror';

% How many cycles to add on each side for cycle_wrap
C.g_coherence.params.padding.n_cycles_each_side = 1;

% Safety: require these fields in Tseg

% 
C.g_coherence.params.store_final_concatenated_signals = true;
C.g_coherence.params.store_analysis_concatenated_signals = true;

% ===================== Surrogate / randomized coherence (https://www.biorxiv.org/content/10.1101/2023.07.21.550018v1.full.pdf+html) Charalambous et al., 2023 preprint =====================
C.g_coherence.params.surrogate_delta = struct();

% Enable computation if metric_sources_to_save includes "surrogate_delta" or "all"
C.g_coherence.params.surrogate_delta.enable = false;

% Number of random epoch/cycle shuffles
C.g_coherence.params.surrogate_delta.n_surrogates = 100;

% Percentile of randomized coherence used as chance level
C.g_coherence.params.surrogate_delta.percentile = 95;

% Random seed for reproducibility
C.g_coherence.params.surrogate_delta.random_seed = 1;

% Shuffle strategy:
% "cycle_order_signal2" = shuffle cycle order of signal 2 only
C.g_coherence.params.surrogate_delta.shuffle_mode = "cycle_order_signal2";

% Store maps? Can make files heavy.
C.g_coherence.params.store_surrogate_delta_maps = true;

% ===================== Group plots =====================
C.g_coherence.group_plot = struct();
C.g_coherence.group_plot.enable = false;                                                        % true = générer les plots de groupe
C.g_coherence.group_plot.dir = fullfile(C.g_coherence.plot.dir, 'coherencegroup_plots');      % dossier plots de groupe
C.g_coherence.group_plot.make_scalar_bars = true;                                              % true = barplots des métriques scalaires

C.g_coherence.group_plot.scalar_plot_sets = { ...
    {'Alpha','Beta','Gamma'}, ...                                                               % moyennes significatives par bande
    {'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm'} ...                                     % AUC normalisées par bande
};

C.g_coherence.group_plot.summaryScalarVars = { ...
    'Alpha','Beta','Gamma', ...                                                                 % moyenne par bande
    'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm', ...                                      % AUC normalisée par bande
    'FullBand_Mean', 'FullBand_AUC_norm' ...                                                    % métriques full-band
};

% ===================== Final comparison plots =====================
C.g_coherence.final_plot = struct();
C.g_coherence.final_plot.enable = true;                                                         % true = plots comparatifs finaux
C.g_coherence.final_plot.dir = fullfile(C.g_coherence.group_plot.dir, 'final_comparison_plots'); % dossier des plots finaux
C.g_coherence.final_plot.condition_order = C.plotting.condition_order;                            % ordre fixe des conditions

C.g_coherence.final_plot.make_raw_spectra = true;
C.g_coherence.final_plot.make_sig_spectra = true;

C.g_coherence.final_plot.make_raw_maps = true;
C.g_coherence.final_plot.make_sig_maps = true;

% ---------- Input datasets for coherence ----------
C.g_coherence.io.input_sets = { ...
    struct( ...
        'name', 'FULL', ...
        'mat_file', fullfile(C.paths.final_signals_dir, 'FINAL_PAIRED_SIGNALS.mat'), ...
        'enabled', true), ...
    struct( ...
        'name', 'ALPHA', ...
        'mat_file', fullfile(C.paths.final_signals_dir, 'FINAL_PAIRED_SIGNALS_ALPHA.mat'), ...
        'enabled', true), ...
    struct( ...
        'name', 'BETA', ...
        'mat_file', fullfile(C.paths.final_signals_dir, 'FINAL_PAIRED_SIGNALS_BETA.mat'), ...
        'enabled', true), ...
    struct( ...
        'name', 'GAMMA', ...
        'mat_file', fullfile(C.paths.final_signals_dir, 'FINAL_PAIRED_SIGNALS_GAMMA.mat'), ...
        'enabled', true) ...
    };

C.g_coherence.params.exclude_edge_cycles_after_wavelet = false; % honestly unnecessary with good padding, but change in case, exclude the first and last cycle of each signal after wavelet transformation to avoid any residual edge effects
C.g_coherence.params.n_edge_cycles_excluded_each_side = 1;

C.g_coherence.plot.whole_signal_qc = struct();
C.g_coherence.plot.whole_signal_qc.enable = true;

% Leave empty = no filtering
C.g_coherence.plot.whole_signal_qc.subjects = {};
C.g_coherence.plot.whole_signal_qc.conditions = {};
C.g_coherence.plot.whole_signal_qc.legs = {};
C.g_coherence.plot.whole_signal_qc.pairs = {};

% Limit number of plots so it stays reasonable
C.g_coherence.plot.whole_signal_qc.max_plots = 12;

C.g_coherence.plot.concat_signal_qc = struct();
C.g_coherence.plot.concat_signal_qc.enable = true;
C.g_coherence.plot.concat_signal_qc.max_examples = 10;

% leave empty = no filtering
C.g_coherence.plot.concat_signal_qc.subjects = {};
C.g_coherence.plot.concat_signal_qc.conditions = {};
C.g_coherence.plot.concat_signal_qc.legs = {};
C.g_coherence.plot.concat_signal_qc.pairs = {'TAprox_TAdist','SOL_GM'};
%C.g_coherence.plot.concat_signal_qc.pairs = {'TAprox_TAdist','SOL_GM','VL_RF'};

C.g_coherence.plot.edge_cycle_compare = struct();
C.g_coherence.plot.edge_cycle_compare.enable = true;

% Use at most one signal per subject and limit total examples pooled
C.g_coherence.plot.edge_cycle_compare.max_signals = 20;

% Use the same object as your downstream analysis:
% true  = compare thresholded coherence maps
% false = compare raw coherence maps
C.g_coherence.plot.edge_cycle_compare.use_significant = true;

% ===================== Padding comparison QC =====================
C.g_coherence.plot.padding_qc = struct();
C.g_coherence.plot.padding_qc.enable = true;

% Base folder; dataset subfolders will be created automatically
C.g_coherence.plot.padding_qc.dir = fullfile(C.g_coherence.plot.dir, 'padding_qc');

% Limit number of plots
C.g_coherence.plot.padding_qc.max_plots = 6;

% Compare current padding mode against this reference mode
C.g_coherence.plot.padding_qc.reference_mode = 'zero';

% Only signal 1, signal 2, or both
C.g_coherence.plot.padding_qc.which_signals = 'signal1';   % 'signal1', 'signal2', or 'both'

%% h_emg_emg_coherence_stats

C.h_stats = struct();

% ===================== I/O =====================
C.h_stats.io = struct();
C.h_stats.io.coh_mat = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_FULL.mat');

C.h_stats.io.mat_dir = C.paths.stats_dir;
C.h_stats.io.out_dir = fullfile(C.paths.results_dir, 'h_coherence_stats_pair_phase_main');
C.h_stats.io.tables_dir = fullfile(C.h_stats.io.out_dir, 'tables');
C.h_stats.io.models_dir = fullfile(C.h_stats.io.out_dir, 'models');
C.h_stats.io.plots_dir = fullfile(C.paths.plot_dir, 'h_coherence_stats_pair_phase_main');
C.h_stats.io.workspace_mat = fullfile(C.h_stats.io.mat_dir, 'COHERENCE_STATS_PAIR_PHASE_MAIN.mat');
C.h_stats.io.band_triplet_dir = fullfile(C.h_stats.io.plots_dir, 'band_triplets');

% ===================== ANALYSIS =====================
C.h_stats.analysis = struct();
C.h_stats.analysis.min_cycles_required = 1;

C.h_stats.analysis.pairs_to_analyze = {'TAprox_TAdist','SOL_GM'};
%C.h_stats.analysis.pairs_to_analyze = {'TAprox_TAdist','SOL_GM','VL_RF'};

% ===================== METRIC SELECTION =====================
% Choose one or several scalar metric families for the whole h_stats script:
%   "mean" = Alpha / Beta / Gamma
%   "auc"  = Alpha_AUC_norm / Beta_AUC_norm / Gamma_AUC_norm
%   "peak" = Alpha_Peak / Beta_Peak / Gamma_Peak
%
% Examples:
%   {'auc'}
%   {'mean','auc'}
%   {'auc','peak'}
%   {'mean','auc','peak'}

C.h_stats.analysis.scalar_metric_families = {'auc'};   % choose any subset of {'mean','auc','peak'}

metricFamilies = lower(string(C.h_stats.analysis.scalar_metric_families));

C.h_stats.analysis.dv_list = {};
C.h_stats.analysis.metric_type_for_plots = {};
C.h_stats.analysis.correlation_pairs = {};
C.h_stats.analysis.power_pairs = {};

for iMF = 1:numel(metricFamilies)

    mf = metricFamilies(iMF);

    switch mf

        case "mean"
            thisDV = {'Alpha','Beta','Gamma'};
            thisPlotType = {'mean'};
            thisPairs = { ...
                'Alpha', 'Alpha_LogPower'; ...
                'Beta',  'Beta_LogPower'; ...
                'Gamma', 'Gamma_LogPower'};

        case "auc"
            thisDV = {'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm'};
            thisPlotType = {'auc'};
            thisPairs = { ...
                'Alpha_AUC_norm', 'Alpha_LogPower'; ...
                'Beta_AUC_norm',  'Beta_LogPower'; ...
                'Gamma_AUC_norm', 'Gamma_LogPower'};

        case "peak"
            thisDV = {'Alpha_Peak','Beta_Peak','Gamma_Peak'};
            thisPlotType = {'peak'};
            thisPairs = { ...
                'Alpha_Peak', 'Alpha_LogPower'; ...
                'Beta_Peak',  'Beta_LogPower'; ...
                'Gamma_Peak', 'Gamma_LogPower'};

        otherwise
            error('Unknown scalar metric family: %s. Use "mean", "auc", or "peak".', mf);
    end

    C.h_stats.analysis.dv_list = [C.h_stats.analysis.dv_list, thisDV]; %#ok<AGROW>
    C.h_stats.analysis.metric_type_for_plots = [C.h_stats.analysis.metric_type_for_plots, thisPlotType]; %#ok<AGROW>
    C.h_stats.analysis.correlation_pairs = [C.h_stats.analysis.correlation_pairs; thisPairs]; %#ok<AGROW>
    C.h_stats.analysis.power_pairs = [C.h_stats.analysis.power_pairs; thisPairs]; %#ok<AGROW>
end

% Remove accidental duplicates while preserving order
C.h_stats.analysis.dv_list = unique(C.h_stats.analysis.dv_list, 'stable');
C.h_stats.analysis.metric_type_for_plots = unique(C.h_stats.analysis.metric_type_for_plots, 'stable');

[~, iaCorr] = unique(strcat(C.h_stats.analysis.correlation_pairs(:,1), "__", C.h_stats.analysis.correlation_pairs(:,2)), 'stable');
C.h_stats.analysis.correlation_pairs = C.h_stats.analysis.correlation_pairs(iaCorr,:);

[~, iaPow] = unique(strcat(C.h_stats.analysis.power_pairs(:,1), "__", C.h_stats.analysis.power_pairs(:,2)), 'stable');
C.h_stats.analysis.power_pairs = C.h_stats.analysis.power_pairs(iaPow,:);

% Use the same selected metrics for age correlations by default
C.h_stats.analysis.age_corr_metrics = C.h_stats.analysis.dv_list;

C.h_stats.analysis.average_legs_first = true;

C.h_stats.analysis.metric_scope = 'POI';
% 'POI', 'Full', 'Stance', 'Swing'
C.h_stats.analysis.coherence_source = "equalized";   % "sig" or "raw" or "sig_equalized" or "sig_common_threshold" or "zcoh_bokil"

% ---------- Bokil-inspired cycle-count covariate ----------
% false = main raw model without cycle covariate
% true  = raw model controlling for log(n_cycles_used)
C.h_stats.analysis.include_cycle_count_covariate = false;

C.h_stats.analysis.include_cycle_count_in_correlations = false;

% ===================== PLOT =====================
C.h_stats.plot = struct();
% Shared coherence y-axis limits
C.h_stats.plot.use_fixed_coherence_ylim = false;
C.h_stats.plot.coherence_ylim = [0 0.7];

C.h_stats.plot.enable = true;
C.h_stats.plot.visible = 'off';

C.h_stats.plot.cycle_triplets = struct();
C.h_stats.plot.cycle_triplets.visible = 'off';
C.h_stats.plot.cycle_triplets.show_sem = true;
C.h_stats.plot.cycle_triplets.line_width = 2.2;
C.h_stats.plot.cycle_triplets.poi_face_alpha = 0.08;
C.h_stats.plot.cycle_triplets.plots_dir = fullfile(C.h_stats.io.plots_dir, 'cycle_triplets');

C.h_stats.analysis.make_cycle_triplets = false;

% use raw coherence or significant coherence for cycle-resolved curves
C.h_stats.analysis.cycle_triplet_source = C.h_stats.analysis.coherence_source;   % "raw" | "sig" | "sig_equalized" | "sig_common_threshold" | "zcoh_bokil"

% average legs first before plotting
C.h_stats.analysis.cycle_triplet_average_legs = true;

% frequency bands used for cycle triplets

% Correlation plot y-axis control
C.h_stats.plot.correlation_use_fixed_ylim = C.h_stats.plot.use_fixed_coherence_ylim;

% Can be one global ylim:
C.h_stats.plot.correlation_ylim = C.h_stats.plot.coherence_ylim;


% ===================== POST HOC =====================
C.h_stats.posthoc = struct();
C.h_stats.posthoc.mode = 'nonparametric';   % 'adaptive', 'parametric', 'nonparametric'
C.h_stats.posthoc.min_n_parametric = 8;
C.h_stats.posthoc.outlier_z_thresh = 3.5;
C.h_stats.posthoc.use_normality_test = false;
C.h_stats.posthoc.normality_alpha = 0.05;
C.h_stats.posthoc.correction = 'fdr';       % 'holm' or 'fdr'

% ===================== BAND-SPECIFIC DATASET SETTINGS =====================
C.h_stats.analysis.use_band_specific_datasets = true;   % easy on/off switch

C.h_stats.io.coh_mat_alpha = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_ALPHA.mat');
C.h_stats.io.coh_mat_beta  = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_BETA.mat');
C.h_stats.io.coh_mat_gamma = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_GAMMA.mat');
%% h_stats spectrum plots

C.h_stats.spectrum = struct();

% SPM / SnPM switch for all spectrum profile analyses
C.h_stats.spectrum.use_nonparametric = true;
C.h_stats.spectrum.nonparam_iterations = 5000;
C.h_stats.spectrum.two_tailed = true;

C.h_stats.spectrum.enable = true;
C.h_stats.spectrum.spectrum_source = C.h_stats.analysis.coherence_source;   % "raw" | "sig"
C.h_stats.spectrum.scope = C.h_stats.analysis.metric_scope;   % 'POI' | 'Full' | 'Stance' | 'Swing'

C.h_stats.spectrum.freq_min = C.shared_wavelet.FreqMin;
C.h_stats.spectrum.freq_max = C.shared_wavelet.FreqMax;
C.h_stats.analysis.spectrum_freq_range = [C.h_stats.spectrum.freq_min, C.h_stats.spectrum.freq_max];

C.h_stats.spectrum.run_spm_age = true;
C.h_stats.spectrum.run_spm_condition = true;
C.h_stats.spectrum.spm_alpha = 0.05;
C.h_stats.spectrum.show_spm_subplot = false; 

C.h_stats.spectrum.require_complete_case_for_condition = true;
C.h_stats.spectrum.min_subjects_per_group = 3;

C.h_stats.spectrum.show_cluster_stars = true;

C.h_stats.spectrum.show_individual_lines = false;   % true/false
C.h_stats.spectrum.show_sem = true;               % true/false
C.h_stats.spectrum.individual_line_alpha = 0.18;
C.h_stats.spectrum.individual_line_width = 0.6;

C.h_stats.spectrum.out_dir = fullfile(C.h_stats.io.plots_dir, 'spectrum_curves');
C.h_stats.spectrum.tables_dir = fullfile(C.h_stats.io.tables_dir, 'spectrum_curves');

C.h_stats.spectrum.run_spm_mixed_age_condition = true;

% For the mixed model, condition is repeated within subject,
% so subjects must have all required conditions.
C.h_stats.spectrum.mixed_require_complete_case = true;

% Start with parametric first. Switch true only if your toolbox has:
% spm1d.stats.nonparam.anova2onerm
% C.h_stats.spectrum.mixed_use_nonparametric = true;
% C.h_stats.spectrum.mixed_nonparam_iterations = 5000;

C.h_stats.spectrum.make_followup_subplot_spm = true;

% Minimum unique subjects for running subplot SPM.
% Plots are still shown if n is lower, but SPM is skipped.
C.h_stats.spectrum.subplot_spm_min_subjects = 3;

% Show SPM cluster bars on each subplot
C.h_stats.spectrum.subplot_show_cluster_stars = true;

C.h_stats.spectrum.use_fixed_ylim = false;
C.h_stats.spectrum.fixed_ylim = [0 1];

% Continuous-age LME sensitivity models
C.h_stats.analysis.run_continuous_age_lme = true;
C.h_stats.analysis.run_categorical_age_lme = false;
C.h_stats.analysis.run_power_control_models = false;
C.h_stats.analysis.run_age_correlations = false;
C.h_stats.analysis.run_power_correlations = false;

% If true: DV ~ AgeYears_z * condition
% If false: DV ~ AgeYears_z + condition
C.h_stats.analysis.continuous_age_condition_interaction = true;

% Add power covariate matching the band: Alpha_LogPower / Beta_LogPower / Gamma_LogPower
C.h_stats.analysis.continuous_age_include_power = false;

% Add log_n_cycles using the same band-specific helper as main models
C.h_stats.analysis.continuous_age_include_cycle_count = false;

% Optional nonlinear age sensitivity
C.h_stats.analysis.continuous_age_include_quadratic = false;

% ===================== Continuous-age LMM plots =====================
C.h_stats.plot.continuous_age_lmm.enable = true;
C.h_stats.plot.continuous_age_lmm.visible = C.h_stats.plot.visible;

C.h_stats.plot.continuous_age_lmm.n_grid = 100;
C.h_stats.plot.continuous_age_lmm.point_size = 40;
C.h_stats.plot.continuous_age_lmm.point_alpha = 0.70;

C.h_stats.plot.continuous_age_lmm.line_width = 2.2;
C.h_stats.plot.continuous_age_lmm.show_ci = true;
C.h_stats.plot.continuous_age_lmm.ci_alpha = 0.18;

C.h_stats.plot.continuous_age_lmm.use_fixed_ylim = false;
C.h_stats.plot.continuous_age_lmm.ylim = [0 0.40];   % utilisé seulement si use_fixed_ylim = true

% ===================== Continuous-age LMM 3-band plots =====================
C.h_stats.plot.continuous_age_lmm_3bands.enable = true;
C.h_stats.plot.continuous_age_lmm_3bands.visible = C.h_stats.plot.visible;

C.h_stats.plot.continuous_age_lmm_3bands.n_grid = 100;
C.h_stats.plot.continuous_age_lmm_3bands.point_size = 34;
C.h_stats.plot.continuous_age_lmm_3bands.point_alpha = 0.75;

C.h_stats.plot.continuous_age_lmm_3bands.line_width = 2.2;
C.h_stats.plot.continuous_age_lmm_3bands.show_ci = true;
C.h_stats.plot.continuous_age_lmm_3bands.ci_alpha = 0.12;

C.h_stats.plot.continuous_age_lmm_3bands.use_fixed_ylim = false;
C.h_stats.plot.continuous_age_lmm_3bands.ylim = [0 0.4];

C.h_stats.plot.continuous_age_lmm_3bands.show_significance = true;

%% i_temporal_coherence_link

C.temporal_coherence_link = struct();

TCroot = fullfile(C.paths.results_dir, 'i_temporal_coherence_link');

C.temporal_coherence_link.out_dir    = TCroot;
C.temporal_coherence_link.tables_dir = fullfile(TCroot, 'tables');
C.temporal_coherence_link.models_dir = fullfile(TCroot, 'models');
C.temporal_coherence_link.plots_dir  = fullfile(C.paths.plot_dir, 'i_temporal_coherence_link');

% ---------- Input coherence files ----------
C.temporal_coherence_link.coh_mat_default = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_FULL.mat');
C.temporal_coherence_link.coh_mat_alpha   = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_ALPHA.mat');
C.temporal_coherence_link.coh_mat_beta    = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_BETA.mat');
C.temporal_coherence_link.coh_mat_gamma   = fullfile(C.paths.coherence_dir, 'COHERENCE_RESULTS_GAMMA.mat');

% If true, Alpha/Beta/Gamma rows use the band-specific coherence files.
% This is recommended if your coherence stats already use band-specific datasets.
C.temporal_coherence_link.use_band_specific_datasets = true;

% ---------- Analysis choices ----------
% C.temporal_coherence_link.pairs_to_analyze = {'TAprox_TAdist','SOL_GM','VL_RF'};
C.temporal_coherence_link.pairs_to_analyze = {'TAprox_TAdist','SOL_GM'};
C.temporal_coherence_link.bands_to_analyze = {'Alpha','Beta','Gamma'};

% Recommended: POI, because your pair-specific interpretation is phase-dependent.
C.temporal_coherence_link.metric_scope = "POI";

% Options: "raw", "sig", "sig_equalized", "sig_common_threshold", "zcoh_bokil"
% Use the same source as your main coherence stats.
C.temporal_coherence_link.coherence_source = C.h_stats.analysis.coherence_source;

C.temporal_coherence_link.min_cycles_required = 10;

% ---------- Temporal envelope ----------
% Temporal metrics are computed from the same retained cycles as coherence.
% Signal is rectified + low-pass filtered to get an amplitude envelope.
C.temporal_coherence_link.n_interp_time = 1000;
C.temporal_coherence_link.envelope_lowpass_hz = 10;
C.temporal_coherence_link.envelope_lowpass_order = 2;

% Normalize each cycle before shape/overlap metrics?
% Recommended true, otherwise overlap is dominated by amplitude.
C.temporal_coherence_link.normalize_each_cycle_for_shape = true;

% Threshold for binary coactivation, expressed as fraction of each cycle's own max.
C.temporal_coherence_link.active_threshold_frac = 0.20;

% ---------- Stats ----------
C.temporal_coherence_link.run_correlations = true;
C.temporal_coherence_link.run_lme = true;

% Main temporal predictors to test.
C.temporal_coherence_link.temporal_predictors = { ...
    'temporal_corr', ...
    'coactivation_iou', ...
    'abs_peak_lag_pct', ...
    'mean_amp_pair'};

% Coherence metrics to link to temporal metrics.
% I would start with mean and AUC_norm. Peak is noisier.
% C.temporal_coherence_link.coherence_metrics = { ...
%     'coherence_mean', ...
%     'coherence_auc_norm', ...
%     'coherence_peak'};
C.temporal_coherence_link.coherence_metrics = { ...
    'coherence_auc_norm'};

% ---------- Plots ----------
C.temporal_coherence_link.make_plots = true;
C.temporal_coherence_link.visible = 'off';
C.temporal_coherence_link.max_scatter_plots = 200;

C.temporal_coherence_link.plot_by = "condition"; % "condition" or "age_group"

% Optional fixed ylim for coherence-like scatter y-axis.
C.temporal_coherence_link.use_fixed_coherence_ylim = true;
C.temporal_coherence_link.coherence_ylim = [0 0.20];

% ---------- Omnibus comparison ----------
% Tests whether age/condition effects remain after controlling for temporal metrics.
C.temporal_coherence_link.run_omnibus_control_comparison = true;

% Keep this focused. Start with mean and AUC, not peak.
C.temporal_coherence_link.omnibus_coherence_metrics = { ...
    'coherence_auc_norm'};

% Main temporal predictors to test one at a time.
C.temporal_coherence_link.omnibus_temporal_predictors = { ...
    'temporal_corr', ...
    'coactivation_iou', ...
    'abs_peak_lag_pct'};


%% i_build_time_domain_data_from_cycle_qc

C.j_time_domain = struct();

% ===================== I/O =====================
C.j_time_domain.io = struct();
C.j_time_domain.io.final_burst_mat = fullfile(C.paths.burst_decision_dir, 'FINAL_BURST_QC.mat');
C.j_time_domain.io.bursts_dir      = C.paths.bursts_dir;

C.j_time_domain.io.out_dir = fullfile(C.paths.mat_dir, 'mat_time_domain_data');
C.j_time_domain.io.out_mat = fullfile(C.j_time_domain.io.out_dir, 'TIME_DOMAIN_DATA.mat');

C.j_time_domain.io.csv_dir = fullfile(C.paths.results_dir, 'j_time_domain_data');

C.j_time_domain.io.single_cycle_csv  = fullfile(C.j_time_domain.io.csv_dir, 'TD_SINGLE_CYCLE_TABLE.csv');
C.j_time_domain.io.pair_cycle_csv    = fullfile(C.j_time_domain.io.csv_dir, 'TD_PAIR_CYCLE_TABLE.csv');
C.j_time_domain.io.single_sum_csv    = fullfile(C.j_time_domain.io.csv_dir, 'TD_SINGLE_SIGNAL_SUMMARY.csv');
C.j_time_domain.io.pair_sum_csv      = fullfile(C.j_time_domain.io.csv_dir, 'TD_PAIR_SIGNAL_SUMMARY.csv');

C.j_time_domain.io.single_analyzable_csv = fullfile(C.j_time_domain.io.csv_dir, 'TD_SINGLE_ANALYZABLE_SIGNALS.csv');
C.j_time_domain.io.pair_analyzable_csv   = fullfile(C.j_time_domain.io.csv_dir, 'TD_PAIR_ANALYZABLE_SIGNALS.csv');

% ===================== Pair definitions =====================
C.j_time_domain.params = struct();

% C.j_time_domain.params.pairs = {
%     struct('name',"TAprox_TAdist", 'muscles',{{'EMG_TAprox_Concat','EMG_TAdist_Concat'}})
%     struct('name',"SOL_GM",        'muscles',{{'EMG_SOL_Concat','EMG_GM_Concat'}})
%     struct('name',"VL_RF",         'muscles',{{'EMG_VL_Concat','EMG_RF_Concat'}})
% };
C.j_time_domain.params.pairs = {
    struct('name',"TAprox_TAdist", 'muscles',{{'EMG_TAprox_Concat','EMG_TAdist_Concat'}})
    struct('name',"SOL_GM",        'muscles',{{'EMG_SOL_Concat','EMG_GM_Concat'}})
};

% ===================== Modes =====================
C.j_time_domain.params.single.enable = true;
C.j_time_domain.params.pairwise.enable = true;

% ===================== Inclusion thresholds =====================
C.j_time_domain.params.single.min_cycles_required = 7;
C.j_time_domain.params.pairwise.min_cycles_required = 7;

% ===================== Storage options =====================
C.j_time_domain.params.store_raw_cycle_segments = true;
C.j_time_domain.params.store_time_normalized_cycles = true;
C.j_time_domain.params.n_normalized_points = 1000;

% ===================== Cycle field candidates =====================
C.j_time_domain.params.cycle_field_candidates = { ...
    'cycle_starts', ...
    'cycle_start_idx', ...
    'gc_start_idx', ...
    'gait_cycle_starts', ...
    'heel_strikes', ...
    'hs_idx', ...
    'cycleStartIdx', ...
    'starts_idx'};

C.j_time_domain.params.cycle_end_field_candidates = { ...
    'cycle_ends', ...
    'cycle_end_idx', ...
    'gc_end_idx', ...
    'gait_cycle_ends', ...
    'cycleEndIdx', ...
    'ends_idx'};

C.j_time_domain.params.toeoff_field_candidates = { ...
    'toe_off_concat', ...
    'toe_off_idx', ...
    'toe_offs', ...
    'to_idx'};

% ===================== Single-muscle time-domain cycle policy =====================
C.j_time_domain.params.single_cycle_policy = struct();

C.j_time_domain.params.single_cycle_policy.require_at_least_one_burst = true;
C.j_time_domain.params.single_cycle_policy.require_at_least_one_good_burst = true;

C.j_time_domain.params.single_cycle_policy.reject_if_any_bad_burst = false;
C.j_time_domain.params.single_cycle_policy.reject_if_bad_burst_fraction_over = true;
C.j_time_domain.params.single_cycle_policy.max_bad_burst_fraction = 0.10;

C.j_time_domain.params.single_cycle_policy.reject_flatline_cycles = true;
C.j_time_domain.params.single_cycle_policy.flatline_method = "ptp";
C.j_time_domain.params.single_cycle_policy.flatline_min_ptp = 1e-8;
C.j_time_domain.params.single_cycle_policy.flatline_min_std = 1e-8;

C.j_time_domain.params.single_cycle_policy.reject_if_flatline_fraction_over = true;
C.j_time_domain.params.single_cycle_policy.max_flatline_fraction = 0.01;

C.j_time_domain.params.single_cycle_policy.flatline_diff_thresh = 1e-8;
C.j_time_domain.params.single_cycle_policy.flatline_min_run_samples = 20;

% ===================== Pairwise time-domain policy =====================
C.j_time_domain.params.pairwise_policy = struct();
C.j_time_domain.params.pairwise_policy.require_same_cycle_number = true;
C.j_time_domain.params.pairwise_policy.use_harmonized_cycles = true;

% ===================== Plot settings =====================
C.j_time_domain.plot = struct();
C.j_time_domain.plot.enable = false;

C.j_time_domain.plot.random_single.enable = false;
C.j_time_domain.plot.random_single.n_random = 10;
C.j_time_domain.plot.random_single.random_seed = 1;
C.j_time_domain.plot.random_single.out_dir = fullfile(C.paths.plot_dir, 'j_time_domain_data', 'single_examples');

C.j_time_domain.plot.random_pair.enable = false;
C.j_time_domain.plot.random_pair.n_random = 10;
C.j_time_domain.plot.random_pair.random_seed = 1;
C.j_time_domain.plot.random_pair.out_dir = fullfile(C.paths.plot_dir, 'j_time_domain_data', 'pair_examples');

% ===================== Preprocessed EMG input =====================
C.j_time_domain.io.preproc_dir = C.paths.preproc_dir;

% ===================== Signal extraction settings =====================
C.j_time_domain.params.extract_signals = struct();
C.j_time_domain.params.extract_signals.bandpassed = true;
C.j_time_domain.params.extract_signals.rectified  = true;
C.j_time_domain.params.extract_signals.envelope   = true;


%% k_plot_activation_profiles
C.k_activation_profiles = struct();

C.k_activation_profiles.io = struct();
C.k_activation_profiles.io.in_mat  = fullfile(C.j_time_domain.io.out_dir, 'TIME_DOMAIN_DATA.mat');
C.k_activation_profiles.io.out_dir = fullfile(C.paths.plot_dir, 'k_activation_profiles');

C.k_activation_profiles.params = struct();
C.k_activation_profiles.params.use_only_included_signals = true; % if true, only plot signals that passed the single-cycle QC and were included in the time-domain dataset; if false, plot all available signals (including those that failed QC), but just uses the valid cycles of these signals

C.k_activation_profiles.params.profile_signal_name = "envelope";
C.k_activation_profiles.params.use_time_normalized = true;
C.k_activation_profiles.params.normalization_mode = "flat_subject_percentile";
% options:
%   "none"
%   "cycle_max"
%   "flat_subject_mean_peak"
%   "flat_subject_percentile"
C.k_activation_profiles.params.norm_reference_percentile = 95;

C.k_activation_profiles.params.show_participant_level_mean = true;
C.k_activation_profiles.params.show_cycle_level_mean = false;

C.k_activation_profiles.params.ylabel_text_raw = 'Envelope amplitude';

C.k_activation_profiles.params.muscles_to_plot = C.design.muscleFields;

C.k_activation_profiles.params.conditions_to_plot = C.plotting.condition_order;
C.k_activation_profiles.params.age_groups_to_plot = C.plotting.age_order;
C.k_activation_profiles.params.default_toeoff_fraction = 0.60;

%% l_spm_envelope_analysis
C.l_spm = struct();
C.l_spm.io = struct();
C.l_spm.io.in_mat  = fullfile(C.j_time_domain.io.out_dir, 'TIME_DOMAIN_DATA.mat');
C.l_spm.io.out_dir = fullfile(C.paths.plot_dir, 'l_spm_envelope_analysis');
C.l_spm.io.csv_dir = fullfile(C.paths.results_dir, 'l_spm_envelope_analysis');
C.l_spm.io.age_effects_csv = fullfile(C.l_spm.io.csv_dir, 'SPM_age_effects.csv');
C.l_spm.io.condition_effects_csv = fullfile(C.l_spm.io.csv_dir, 'SPM_condition_effects.csv');
C.l_spm.io.interaction_effects_csv = fullfile(C.l_spm.io.csv_dir, 'SPM_interaction_effects_NOT_COMPUTED.csv');

C.l_spm.params = struct();

% C.l_spm.params.muscles_to_run = [ ...
%     "EMG_TAprox_Concat", ...
%     "EMG_TAdist_Concat", ...
%     "EMG_SOL_Concat", ...
%     "EMG_GM_Concat", ...
%     "EMG_VL_Concat", ...
%     "EMG_RF_Concat" ...
% ];
C.l_spm.params.muscles_to_run = [ ...
    "EMG_TAprox_Concat", ...
    "EMG_TAdist_Concat", ...
    "EMG_SOL_Concat", ...
    "EMG_GM_Concat", ...
];

% C.l_spm.params.muscles_to_run = [ ...
%     "EMG_RF_Concat" ...
% ];

C.l_spm.params.age_groups_to_run = C.plotting.age_order;
C.l_spm.params.conditions_to_run = C.plotting.condition_order;

C.l_spm.params.run_age_within_condition = true;   % if true, test age effects within each condition separately; if false, test age effects across all conditions with condition as covariate
C.l_spm.params.run_condition_within_age = true; % if true, test condition effects within each age group separately; if false, test condition effects across all age groups with age group as covariate
C.l_spm.params.run_conditions_all_ages_pooled = true; 
C.l_spm.params.run_ages_all_conditions_pooled = true;
C.l_spm.params.run_symmetry_within_condition = false; % if true, test for left-right symmetry within each condition separately; if false, do not run symmetry tests
C.l_spm.params.run_age_condition_interaction = true;

% signal
C.l_spm.params.normalization_mode = "subject_percentile"; 
% "none" | "cyclemax" | "flatmax" | "flat_percentile" | "subject_percentile"
C.l_spm.params.normalization_mode_condition = "flat_percentile";
C.l_spm.params.normalization_mode_age = "subject_percentile";
C.l_spm.params.normalization_mode_symmetry = "subject_percentile";

C.l_spm.params.signal_name = "envelope";
C.l_spm.params.use_time_normalized = true;
C.l_spm.params.norm_reference_percentile = 95;
C.l_spm.params.show_spm_bottom_plot = false; 
% true  = top descriptive plot + bottom SPM/SnPM curve
% false = only top descriptive plot

% inference
C.l_spm.params.alpha = 0.05;
C.l_spm.params.two_tailed = true;

C.l_spm.params.use_nonparametric = true;  % false = parametric SPM, true = non-parametric SPM
C.l_spm.params.nonparam_iterations = 5000; % use 1000 for quick tests, 5000+ for final

% plotting
C.l_spm.params.show_sem = true;
C.l_spm.params.default_toeoff_fraction = 0.60;
C.l_spm.params.ylabel_text_raw = 'Envelope amplitude';
C.l_spm.params.ylabel_text_time_normalized = 'Time-normalized envelope amplitude';

% symmetry
C.l_spm.params.run_symmetry_indices = false;

C.l_spm.io.symmetry_csv = fullfile(C.l_spm.io.csv_dir, 'SYMMETRY_INDEX_TABLE.csv');
C.l_spm.io.symmetry_plot_dir = fullfile(C.l_spm.io.out_dir, 'symmetry_indices');

C.l_spm.io.outlier_plot_dir = fullfile(C.paths.plot_dir, ...
    'l_spm_envelope_analysis', 'normalized_outlier_examples');

C.l_spm.params.n_outlier_examples_to_plot = 10;
C.l_spm.params.outlier_plot_selection = "top";   % "top" | "random"
C.l_spm.params.outlier_plot_normalization_mode = "flat_percentile"; % or "subject_percentile" or "all"

C.l_spm.io.outlier_signal_plot_dir = fullfile( ...
    C.paths.plot_dir, 'l_spm_envelope_analysis', 'normalized_outlier_signal_examples');

C.l_spm.params.outlier_signal_plot_random_seed = [];   % [] = random every run
C.l_spm.params.outlier_signal_plot_mode = "all";       % "all" | "flat_percentile" | "subject_percentile"


% Normalization to use for age × condition interaction
% I recommend flat_percentile here because the question is:
% "does the surface effect differ by age?"
C.l_spm.params.normalization_mode_interaction = "flat_percentile";

C.l_spm.params.apply_amplitude_qc_exclusion = true; % if true, exclude cycles that fail amplitude QC from SPM analysis; if false, include all cycles regardless of amplitude QC

% normalized amplitude QC
C.l_spm.params.run_normalized_amplitude_qc = true;

% "none" | "fixed" | "adaptive" | "both"
C.l_spm.params.outlier_detection_mode = "adaptive";

% Fixed threshold QC
C.l_spm.params.fixed_outlier_threshold_percent = 250;

% Adaptive threshold QC: per subject × condition × leg × muscle
C.l_spm.params.adaptive_outlier_min_pct_points = 2;      % exclude candidate if >2% of gait cycle exceeds threshold
C.l_spm.params.adaptive_outlier_min_consecutive_pct = 1; % or if longest consecutive exceedance >1% cycle

% plotting
C.l_spm.params.plot_random_outlier_signal_examples = true;
C.l_spm.params.n_random_outlier_signal_examples = 10;

C.l_spm.params.adaptive_outlier_k_mad = 8;              % was 6
C.l_spm.params.adaptive_outlier_smooth_window = 100;     % in points, for 1000-point gait cycle
C.l_spm.params.adaptive_outlier_mad_floor_frac = 0.20;  % was 0.10

% signal-level rule after cycle exclusion
C.l_spm.params.min_cycles_after_amplitude_qc = 7;

%% analyze_kinematics_for_coherence_cycles

% The analysis step used to read C.g2_kinematics_analysis, which was never
% defined, so it always fell back to built-in defaults. These are those same
% defaults, now visible and editable. Everything else the step needs
% (statistical thresholds, metric lists) is still hard-coded in
% analyze_kinematics_for_coherence_cycles.m.
C.kinematics_analysis = struct();
C.kinematics_analysis.io = struct();
% The "g2_" prefix is historical: this branch was stage g2 at one point. The
% folder name is kept so new results land beside the existing ones.
C.kinematics_analysis.io.out_dir = fullfile( ...
    C.paths.results_dir, 'g2_kinematics_coherence_analysis');

%% kinematics_for_coherence_cycles

C.kinematics_coherence = struct();

C.kinematics_coherence.io = struct();
C.kinematics_coherence.io.final_paired_mat = C.f_final_signals.io.out_mat;
C.kinematics_coherence.io.raw_cycles_dir = C.paths.raw_dir;
C.kinematics_coherence.io.out_dir = fullfile( ...
    C.paths.results_dir, 'kinematics_coherence_cycles');

C.kinematics_coherence.params = struct();
C.kinematics_coherence.params.only_included_signals = true;
C.kinematics_coherence.params.include_bands = true;

% Usually 1 = X, 2 = Y, 3 = Z.
% Change this if your treadmill/progression direction is not marker column 1.
C.kinematics_coherence.params.forward_dim = 2;

% Vicon marker units are very often mm.
C.kinematics_coherence.params.marker_units = "mm";
C.kinematics_coherence.params.use_abs_lengths = true;

C.kinematics_coherence.markers = struct();
C.kinematics_coherence.markers.left_heel_candidates = ...
    C.a_extract_raw.markers.left.heel_candidates;
C.kinematics_coherence.markers.right_heel_candidates = ...
    C.a_extract_raw.markers.right.heel_candidates;

% Optional, only used as a future hook for pelvis/reference displacement.
C.kinematics_coherence.markers.reference_candidates = ...
    ["SACR","Sacrum","PELO","Pelvis","LASI","RASI"];

end


%% -------- local helper (kept inside this file) --------
function add_group(mapObj, subjList, groupName)
for i = 1:numel(subjList)
    mapObj(subjList{i}) = groupName;
end
end

