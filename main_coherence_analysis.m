% Main script for EMG-EMG coherence analysis
% main_coherence_analysis.m

C = config_emg();

if C.parameters_running.run_data_extraction
    addpath(genpath(C.paths.functions.data_extraction));
    a_extract_raw_cycles_concat()
end

if C.parameters_running.run_preprocessing
    addpath(genpath(C.paths.functions.preprocessing));
    b_preprocess_emg()
end

if C.parameters_running.run_burst_extraction
    addpath(genpath(C.paths.functions.burst_extraction));
    c_extract_bursts_from_preproc()
end

if C.parameters_running.run_burst_clustering
    addpath(genpath(C.paths.functions.clustering_cleaning));
    d_a_clustering_cleaning()
end

if C.parameters_running.run_burst_rule_based
    addpath(genpath(C.paths.functions.rule_based_cleaning));
    d_b_rule_based_cleaning()
end

if C.parameters_running.run_burst_qc
    addpath(genpath(C.paths.functions.burst_qc));
    e_final_burst_qc_combination()
end

if C.parameters_running.run_final_signals_creation
    addpath(genpath(C.paths.functions.final_data_qc));
    f_build_final_paired_signals_from_burst_qc()
end

if C.parameters_running.run_coherence_extraction 
    addpath(genpath(C.paths.functions.coherence));
    g_emg_emg_wavelet_coherence()
end

if C.parameters_running.run_coherence_stats
    addpath(genpath(C.paths.functions.stats));
    h_coherence_stats()
end