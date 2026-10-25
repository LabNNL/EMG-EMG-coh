% main_coherence_analysis.m
% EMG-EMG coherence pipeline, stages a -> h.
%
% Each stage runs only if its switch in C.parameters_running (config/config_emg.m)
% is true. Stages read the previous stage's saved .mat files, so any subset can
% be rerun as long as the upstream outputs exist.
% Note: d_a pauses for manual cluster selection (see C.d_cluster_manual.keep).

clc; clear; close all;

C = config_emg();
R = C.parameters_running;
F = C.paths.functions;

% {run switch, function folder, stage function, label}
stages = {
    R.run_data_extraction,        F.data_extraction,     'a_extract_raw_cycles_concat',                'a   raw cycle extraction'
    R.run_preprocessing,          F.preprocessing,       'b_preprocess_emg',                           'b   preprocessing'
    R.run_burst_extraction,       F.burst_extraction,    'c_extract_bursts_from_preproc',              'c   burst detection'
    R.run_burst_clustering,       F.clustering_cleaning, 'd_a_clustering_cleaning',                    'd_a clustering-based cleaning'
    R.run_burst_rule_based,       F.rule_based_cleaning, 'd_b_rule_based_cleaning',                    'd_b rule-based cleaning'
    R.run_burst_qc,               F.burst_qc,            'e_final_burst_qc_combination',               'e   final burst decision'
    R.run_final_signals_creation, F.final_data_qc,       'f_build_final_paired_signals_from_burst_qc', 'f   cycle QC + paired signal rebuild'
    R.run_coherence_extraction,   F.coherence,           'g_emg_emg_wavelet_coherence',                'g   wavelet coherence'
    R.run_coherence_stats,        F.stats,               'h_coherence_stats',                          'h   coherence statistics'
};

run_pipeline_stages(stages, 'Coherence pipeline', {C.paths.results_dir, C.paths.mat_dir});
