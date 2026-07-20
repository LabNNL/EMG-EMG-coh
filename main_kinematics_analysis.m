C = config_emg();

addpath(genpath(C.paths.functions.kinematics_analysis));
build_kinematics_for_coherence_cycles()
analyze_kinematics_for_coherence_cycles()