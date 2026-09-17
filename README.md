# EMG Gait Analysis

MATLAB workflow for surface EMG processing during gait, with a focus on burst extraction, quality control, wavelet coherence, and time-domain muscle activation analysis.

---

## Overview

This repository contains the active analysis pipeline used to process gait EMG recordings from raw acquisition files to cleaned datasets ready for downstream statistical analysis.

The project is organized around two main goals:

- extracting physiologically plausible muscle activation bursts from gait EMG
- studying age- and condition-related differences through coherence and time-domain analyses

The current cohort configuration in [config/config_emg.m](config/config_emg.m) includes control participants distributed across four age groups:

- JeunesEnfants
- Enfants
- Adolescents
- Adultes

Muscles currently tracked in the pipeline are:

- TAprox and TAdist
- SOL and GM
- VL and RF
- ST
- GMED

Experimental condition labels are not yet fully standardized across the
pipeline:

- raw-file parsing and coherence helpers use `Plat`
- the general design, time-domain analysis, and plotting settings use `Flat`
- `Medium` and `High` are used in both branches

When adding or adapting data, use the label expected by the stage being run.

---

## Active Pipeline

The workflow is now orchestrated by three root entry scripts:

- [main_coherence_analysis.m](main_coherence_analysis.m)
- [main_time_domain_analysis.m](main_time_domain_analysis.m)
- [main_kinematics_analysis.m](main_kinematics_analysis.m)

### Main coherence pipeline

[main_coherence_analysis.m](main_coherence_analysis.m) runs the end-to-end EMG pipeline based on switches defined in [config/config_emg.m](config/config_emg.m):

1. data extraction
2. preprocessing
3. burst extraction
4. clustering-based cleaning
5. rule-based cleaning
6. final burst QC merge
7. final paired signal rebuild
8. wavelet coherence extraction
9. coherence statistics

Each stage is conditionally executed through flags in `C.parameters_running`.
Path injection for each stage is done through `C.paths.functions.*`.

### Main time-domain pipeline

[main_time_domain_analysis.m](main_time_domain_analysis.m) runs:

1. time-domain dataset build through `j_build_time_domain_analysis_datasets()`
2. activation-profile plotting through `k_plot_activation_profiles()`
3. SPM envelope analysis through `l_spm_envelope_analysis()`
4. an optional temporal coherence link step through `i_temporal_coherence_link()`

This branch uses `C.paths.functions.time_domain_analysis`. The first three
steps currently run whenever this entry script is launched. The temporal
coherence link is the only step controlled by a switch in this entry script:
`C.parameters_running.run_temporal_coherence_link`.

The time-domain analyses use the final burst-QC data, produce normalized
activation profiles, and run SPM analyses for age, condition, pooled effects,
age-condition interaction, and optional symmetry analyses according to the
settings under `C.k_activation_profiles` and `C.l_spm`.

### Main kinematics pipeline

[main_kinematics_analysis.m](main_kinematics_analysis.m) runs the kinematics branch for coherence-cycle analysis:

1. `build_kinematics_for_coherence_cycles()`
2. `analyze_kinematics_for_coherence_cycles()`

This branch uses `C.paths.functions.kinematics_analysis`.

### Main files by stage

- Configuration and run flags:
  [config/config_emg.m](config/config_emg.m)

- Data extraction:
  [Functions/a_data_extraction/a_extract_raw_cycles_concat.m](Functions/a_data_extraction/a_extract_raw_cycles_concat.m)

- Preprocessing:
  [Functions/b_preprocessing/b_preprocess_emg.m](Functions/b_preprocessing/b_preprocess_emg.m)

- Burst extraction:
  [Functions/c_burst_extraction/c_extract_bursts_from_preproc.m](Functions/c_burst_extraction/c_extract_bursts_from_preproc.m)

- Clustering-based cleaning:
  [Functions/d_a_clustering_cleaning/d_a_clustering_cleaning.m](Functions/d_a_clustering_cleaning/d_a_clustering_cleaning.m)

- Rule-based cleaning:
  [Functions/d_b_rule_based_cleaning/d_b_rule_based_cleaning.m](Functions/d_b_rule_based_cleaning/d_b_rule_based_cleaning.m)

- Final burst QC merge:
  [Functions/e_burst_qc/e_final_burst_qc_combination.m](Functions/e_burst_qc/e_final_burst_qc_combination.m)

- Final paired signal rebuild:
  [Functions/f_final_data_qc/f_build_final_paired_signals_from_burst_qc.m](Functions/f_final_data_qc/f_build_final_paired_signals_from_burst_qc.m)

- Coherence extraction:
  [Functions/g_coherence/g_emg_emg_wavelet_coherence.m](Functions/g_coherence/g_emg_emg_wavelet_coherence.m)

- Coherence statistics:
  [Functions/h_stats/h_coherence_stats.m](Functions/h_stats/h_coherence_stats.m)

- Time-domain dataset/statistics/plots:
  [Functions/time_domain_analysis/j_build_time_domain_analysis_datasets.m](Functions/time_domain_analysis/j_build_time_domain_analysis_datasets.m),
  [Functions/time_domain_analysis/k_plot_activation_profiles.m](Functions/time_domain_analysis/k_plot_activation_profiles.m),
  [Functions/time_domain_analysis/l_spm_envelope_analysis.m](Functions/time_domain_analysis/l_spm_envelope_analysis.m)

- Optional temporal coherence link:
  [Functions/time_domain_analysis/i_temporal_coherence_link.m](Functions/time_domain_analysis/i_temporal_coherence_link.m)

- Kinematics analysis branch:
  [Functions/kinematics_analysis/build_kinematics_for_coherence_cycles.m](Functions/kinematics_analysis/build_kinematics_for_coherence_cycles.m),
  [Functions/kinematics_analysis/analyze_kinematics_for_coherence_cycles.m](Functions/kinematics_analysis/analyze_kinematics_for_coherence_cycles.m)

---

## How to Run the Project

The recommended usage is to run one of the three main entry scripts depending on your analysis target.

### Minimal setup

Before running the pipeline:

1. Open [config/config_emg.m](config/config_emg.m)
2. Update the local paths for:
   - the raw project data root
   - the MATLAB code directory
   - any toolbox paths if needed
3. Verify that the metadata files in [Metadata](Metadata) match your dataset
4. Ensure the required dependencies are available in MATLAB

### Typical execution order

1. Open [config/config_emg.m](config/config_emg.m) and set paths, flags, and analysis options.
2. For EMG extraction/QC/coherence, run [main_coherence_analysis.m](main_coherence_analysis.m).
3. For time-domain outcomes, run [main_time_domain_analysis.m](main_time_domain_analysis.m). This runs dataset construction, activation-profile plotting, and SPM analysis in sequence.
4. For kinematics on coherence cycles, run [main_kinematics_analysis.m](main_kinematics_analysis.m).

Tip: run the coherence pipeline first when downstream scripts depend on final paired signals or coherence outputs.

---

## Repository Structure

The main folders currently used by the workflow are:

- [config](config)  
  Central configuration, cohort definitions, analysis parameters, and path settings.

- [Functions](Functions)  
  Helper modules for preprocessing, burst extraction, clustering, rule-based QC, coherence analysis, and plotting.

- [Metadata](Metadata)  
  Participant information, group definitions, and channel-to-muscle mapping resources.

- [Results](Results)  
  Output figures, summaries, statistical tables, and intermediate reporting products.

The root directory contains the main entry scripts used to launch each analysis branch.

---

## Inputs

The pipeline expects the following main inputs:

- raw gait acquisition files in C3D format
- participant and group metadata
- EMG channel mapping information
- project-specific path and parameter configuration in [config/config_emg.m](config/config_emg.m)

Important metadata resources in this repository include:

- [Metadata/participants_metadata_EMG.csv](Metadata/participants_metadata_EMG.csv)
- [Metadata/PhysicalActivity_EMG.csv](Metadata/PhysicalActivity_EMG.csv)
- [Metadata/Mapping-EMG.xlsm](Metadata/Mapping-EMG.xlsm)

---

## Outputs

The project generates both intermediate and final outputs, including:

- raw-cycle extraction summaries
- preprocessed EMG datasets
- burst detection results
- clustering and rule-based QC tables
- final paired signals for coherence analysis
- time-domain feature tables
- wavelet coherence results
- statistical summaries and visualizations

Most figures and recap files are written under [Results](Results), with dedicated subfolders for each stage of the pipeline.

When the time-domain branch is run, its outputs are written under:

- `Results/j_time_domain_data`
- `Results/k_activation_profiles`
- `Results/l_spm_envelope_analysis`

---

## Methods in Brief

### Burst detection

Burst detection is based on the EMG envelope computed from the preprocessed signal, followed by thresholding and binary-mask cleanup.

### Multi-step quality control

The pipeline uses complementary QC strategies:

- clustering-based burst selection
- rule-based artifact rejection
- final decision merging across QC sources

### Downstream analyses

After final signal reconstruction, the workflow branches into:

- wavelet coherence analysis between muscle pairs
- time-domain feature extraction and activation profile analysis
- SPM-based statistical testing on normalized envelopes

---

## Dependencies

This project is designed for MATLAB and relies on standard signal-processing and statistics functionality.

Additional external resources used by the current codebase include:

- BTK or compatible C3D-reading bridge for biomechanical files
- bundled SPM1D, available in [Functions/toolboxes/spm1dmatlab-master](Functions/toolboxes/spm1dmatlab-master)
- bundled wavelet coherence tools, available in [Functions/toolboxes/wtc-r16](Functions/toolboxes/wtc-r16)

If a script fails at startup, first verify that your local MATLAB path and the toolbox paths in [config/config_emg.m](config/config_emg.m) are correct.

---

## Notes for Collaboration and Reproducibility

- Each processing stage saves outputs incrementally, which makes reruns and quality checks easier.
- The configuration file acts as the main source of truth for paths, cohort definitions, colors, frequency bands, and analysis defaults.
- The repository contains results folders from multiple stages, so collaborators can inspect intermediate outputs without rerunning the full pipeline.

---

## Troubleshooting

Common issues when starting on a new machine are:

- incorrect local paths in [config/config_emg.m](config/config_emg.m)
- missing C3D reading dependencies
- metadata or channel-mapping mismatch with the raw files
- missing gait events or unexpected file naming conventions

If you adapt the pipeline to a new dataset, update the configuration and metadata first before changing the analysis scripts.
