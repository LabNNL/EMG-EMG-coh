% main_kinematics_analysis.m
% Kinematics branch: stride metrics for the gait cycles kept for coherence.
%
% Each step runs only if its switch in C.parameters_running (config/config_emg.m)
% is true. Requires stage a outputs (*_RAW_CYCLES_CONCAT.mat, with markers)
% and stage f outputs (FINAL_PAIRED_SIGNALS.mat).

clc; clear; close all;

C = config_emg();
R = C.parameters_running;
F = C.paths.functions;

% {run switch, function folder, step function, label}
stages = {
    R.run_kinematics_build,    F.kinematics_analysis, 'build_kinematics_for_coherence_cycles',   'build kinematics for coherence cycles'
    R.run_kinematics_analysis, F.kinematics_analysis, 'analyze_kinematics_for_coherence_cycles', 'analyze kinematics (condition effects)'
};

run_pipeline_stages(stages, 'Kinematics branch', {C.paths.results_dir, C.paths.mat_dir});
