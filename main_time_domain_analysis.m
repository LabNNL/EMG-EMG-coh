% main_time_domain_analysis.m
% Time-domain branch: activation envelopes, SPM, and link with coherence.
%
% Each step runs only if its switch in C.parameters_running (config/config_emg.m)
% is true. Requires stage e outputs (FINAL_BURST_QC.mat); the temporal
% coherence link also requires stage g outputs (COHERENCE_RESULTS_*.mat).

clc; clear; close all;

C = config_emg();
R = C.parameters_running;
F = C.paths.functions;

% {run switch, function folder, step function, label}
stages = {
    R.run_build_time_domain_analysis_datasets, F.time_domain_analysis, 'j_build_time_domain_analysis_datasets', 'j  time-domain datasets'
    R.run_activation_profiles,                 F.time_domain_analysis, 'k_plot_activation_profiles',            'k  activation profiles'
    R.run_spm,                                 F.time_domain_analysis, 'l_spm_envelope_analysis',               'l  SPM envelope analysis'
    R.run_temporal_coherence_link,             F.time_domain_analysis, 'i_temporal_coherence_link',             'i  temporal-coherence link'
};

run_pipeline_stages(stages, 'Time-domain branch', {C.paths.results_dir, C.paths.mat_dir});
