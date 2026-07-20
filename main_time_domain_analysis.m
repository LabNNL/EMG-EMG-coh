C = config_emg();

addpath(C.paths.functions.time_domain_analysis);
j_build_time_domain_analysis_datasets()
k_plot_activation_profiles()
l_spm_envelope_analysis()

if C.parameters_running.run_temporal_coherence_link
    i_temporal_coherence_link()
end