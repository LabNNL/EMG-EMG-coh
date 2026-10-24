# attic

MATLAB functions that nothing in the project calls any more, kept in case they
turn out to be useful again.

This folder sits outside `Functions/` on purpose. `config_emg()` runs
`addpath(genpath(Functions))`, so anything left under `Functions/` stays on the
MATLAB path and can shadow a live function with the same name. Nothing here is
on the path.

Each file was checked for callers across the project (excluding
`Functions/toolboxes/`) before being moved here. The subfolder names record
where each file used to live.

A few notes on the less obvious ones:

- `simulations_helpers/` — a coherence-bias simulation that was never wired
  into the pipeline. The five files only call each other.
- `d_b_rule_based_cleaning_helpers/longest_true_run.m` — a function of the same
  name is defined locally inside `l_spm_envelope_analysis.m`, and a local
  function always wins inside its own file, so this copy was never reached.
- `d_a_clustering_cleaning_helpers/HartigansDipTest.m` and
  `hartigansdipsigniftest.m` — a dip test for multimodality. Only called by
  each other. Note that `hartigansdipsigniftest.m` declares a function named
  `HartigansDipSignifTest`, which does not match its filename.
- `g_coherence_helpers/get_phase_color.M` — uppercase `.M` extension, which
  MATLAB's Code Analyzer will not even read.
