# EMG-EMG Coherence During Gait

MATLAB pipeline for intra- and intermuscular (EMG-EMG) wavelet coherence during gait in control participants from early childhood to adulthood, walking in three conditions (`Flat`, `Medium`, `High`). It goes from raw `.c3d` acquisitions to cleaned, cycle-aligned muscle-pair signals, time-frequency coherence over the normalized gait cycle, and mixed-model / SPM statistics on age and surface effects.

Two secondary branches reuse the same cleaned data:

- a **time-domain branch** (activation envelopes + SPM1D), and
- a **kinematics branch** (stride metrics for the exact cycles used for coherence).

---

## Contents

- [Study design encoded in the config](#study-design-encoded-in-the-config)
- [Repository structure](#repository-structure)
- [Setup](#setup)
- [How to run](#how-to-run)
- [Coherence pipeline, stage by stage](#coherence-pipeline-stage-by-stage)
- [Time-domain branch](#time-domain-branch)
- [Kinematics branch](#kinematics-branch)
- [Standalone scripts](#standalone-scripts)
- [Data and output locations](#data-and-output-locations)
- [Dependencies](#dependencies)
- [Known issues](#known-issues)

---

## Study design encoded in the config

Everything below is defined in [config/config_emg.m](config/config_emg.m), which is the single source of truth for paths, cohort, parameters and run switches.

**Participants**: 80 controls (`CTL_01` … `CTL_79`, `CTL_81`), split into four age groups through hard-coded lists in `C.participants.*`, exposed as the `C.groups` map (subject → group):

| Group | n |
|---|---|
| `JeunesEnfants` | 15 |
| `Enfants` | 24 |
| `Adolescents` | 17 |
| `Adultes` | 24 |

Continuous age, sex and anthropometrics come from [Metadata/participants_metadata_EMG.csv](Metadata/participants_metadata_EMG.csv) / `.xlsx`.

**Conditions**: `Flat`, `Medium`, `High` (walking surface).
Raw files and the visual-QC spreadsheet use `Plat` instead of `Flat`; stage a renames `Plat` → `Flat` when it saves its outputs. All downstream code uses `Flat`. Do not rename raw `Plat` files unless `C.a_extract_raw.input.filename_regex` and the visual-QC parser are updated too.

**Legs**: `left`, `right` (averaged per participant at the statistics stage).

**Muscles extracted**: `TAprox`, `TAdist`, `SOL`, `GM`, `VL`, `RF`, `ST`, `GMED` (internally `EMG_<name>_Concat`).

**Muscle pairs analysed for coherence** (`C.f_final_signals.params.pairs`, `C.h_stats.analysis.pairs_to_analyze`):

| Pair | Phase of interest (POI, % gait cycle) |
|---|---|
| `TAprox_TAdist` | 60 → 20 (swing + loading, wraps around 100 %) |
| `SOL_GM` | 0 → 60 (stance) |
| `VL_RF` | 90 → 30 — *defined but currently commented out of the pair lists* |

POI windows live in `C.physio.phase_windows_pct`.

**Frequency bands** (`C.shared_wavelet.FreqBands`): Alpha 8–12 Hz, Beta 13–30 Hz, Gamma 31–60 Hz. Morlet wave number 7.

---

## Repository structure

```
EMG-EMG-coh/
├── main_coherence_analysis.m        # entry point: stages a → h
├── main_time_domain_analysis.m      # entry point: j → k → l (+ optional i)
├── main_kinematics_analysis.m       # entry point: kinematics on coherence cycles
├── diagnostic_plot_heel_marker_axes.m   # standalone marker-axis check
├── participant_summary_matlab.m     # standalone cohort descriptives
├── config/
│   └── config_emg.m                 # all paths, cohort, parameters, run flags
├── Functions/
│   ├── a_data_extraction/           # .c3d → concatenated raw gait cycles
│   ├── b_preprocessing/             # filtering + envelopes
│   ├── c_burst_extraction/          # envelope-threshold burst detection
│   ├── d_a_clustering_cleaning/     # burst features + k-means + manual keep map
│   ├── d_b_rule_based_cleaning/     # signal- and burst-level artifact rules
│   ├── e_burst_qc/                  # merge of d_a, d_b (+ optional visual QC)
│   ├── f_final_data_qc/             # cycle-level QC, cross-talk QC, paired signal rebuild
│   ├── g_coherence/                 # wavelet coherence over the gait cycle
│   ├── h_stats/                     # LMMs, post hocs, spectrum SPM
│   ├── time_domain_analysis/        # i, j, k, l modules
│   ├── kinematics_analysis/         # build + analyse stride metrics
│   ├── general/                     # small shared utilities (colors, safe getters, …)
│   ├── simulations_helpers/         # coherence-bias simulation helpers (not called by the pipeline)
│   └── toolboxes/                   # vendored: BTK bridge, spm1d, wtc-r16
├── Metadata/                        # participant metadata, channel mapping (git-ignored)
└── Results/                         # tables, CSV/XLSX recaps, PNG figures (git-ignored except PNGs)
```

Each stage folder has one entry function named after the folder plus a `*_helpers/` subfolder. `config_emg()` adds the whole `Functions/` tree to the MATLAB path, and some stages rely on helpers that live in other stage folders (for example `get_fs_from_entry_or_config` in `g_coherence_helpers` is used by stages c and d_a).

---

## Setup

1. **Set your data folder.** Copy [config/local_paths.template.m](config/local_paths.template.m) to `config/local_paths.m` and set `project_data_root` to the folder holding your raw data and intermediate `.mat` files. That file is git-ignored, so your paths stay local. The code directory needs no configuration — `config_emg()` derives it from its own location.
2. **Start MATLAB in the repository root.** [startup.m](startup.m) runs automatically and puts `config/`, `Functions/`, `scripts/` and `Tools/` on the path. If you started MATLAB elsewhere, `cd` here and run `startup` once. Nothing else adds `config/` to the path, so `config_emg()` will not resolve until this has run.
3. **Raw `.c3d` files** go under `<project_data_root>/Reworked_Data/` (`C.paths.data_dir`), searched recursively. Filenames must match
   `^(?<subjID>[^_]+_[^_]+)_(?<cond>Plat|Medium|High)_(?<ess>\d{2})(?:_NEW)?\.c3d$`, for example `CTL_01_Plat_03.c3d`. Duplicate filenames anywhere in the tree raise an error.
4. **Metadata files** go in `Metadata/`:
   - `Association.m`: per-participant sensor → muscle mapping (`sensor_association_left/right`), used by stage a.
   - `participants_metadata_EMG.csv` (`;`-separated) and `.xlsx`: age in months, sex, height, weight, etc. Used by stages f and h.
   - `Mapping-EMG.xlsm` (sheet `Mapping-ALL`): optional visual QC scores, used by stage e only when `use_visual_mapping = true`.

`Metadata/` and `Results/` are git-ignored, so a fresh clone has neither.

### Checking the repository

`Tools/check_repo.m` runs static checks over the project code and prints a report:

```matlab
startup
check_repo                                  % full report
check_repo('Checks', {'config_missing'})    % one check
check_repo('Save', 'report.txt')            % also write it to a file
```

It reports config settings read by code but not defined, config fields assigned twice or never read, duplicate `.m` filenames (which shadow each other depending on path order), functions called but not resolvable, and Code Analyzer messages. `Tools/baseline/CHECK_REPO_BASELINE.txt` holds the reference output to compare against. It lives outside `Functions/` on purpose, since `config_emg()` genpaths that whole tree.

---

## How to run

All three entry scripts work the same way. Each one loads `C = config_emg()` and defines a short table of steps, one row per step: the on/off switch, the function folder, the function to call and a label. The table goes to [Functions/general/run_pipeline_stages.m](Functions/general/run_pipeline_stages.m), which runs the enabled steps in order, prints a run/skip log with timings, and stops at the first error.

To turn a step on or off, set its switch in `C.parameters_running`.

### 1. Coherence pipeline: `main_coherence_analysis.m`

| Order | Switch | Function |
|---|---|---|
| a | `run_data_extraction` | `a_extract_raw_cycles_concat()` |
| b | `run_preprocessing` | `b_preprocess_emg()` |
| c | `run_burst_extraction` | `c_extract_bursts_from_preproc()` |
| d_a | `run_burst_clustering` | `d_a_clustering_cleaning()` |
| d_b | `run_burst_rule_based` | `d_b_rule_based_cleaning()` |
| e | `run_burst_qc` | `e_final_burst_qc_combination()` |
| f | `run_final_signals_creation` | `f_build_final_paired_signals_from_burst_qc()` |
| g | `run_coherence_extraction` | `g_emg_emg_wavelet_coherence()` |
| h | `run_coherence_stats` | `h_coherence_stats()` |

Every stage reads the previous stage's `.mat` output from disk, so you can rerun any subset as long as the upstream files exist. In the current config only f, g and h are switched on.

**Interactive step:** d_a stops at a `pause` after clustering. Inspect the cluster plots, edit `C.d_cluster_manual.keep.<groupVar>` in the config, save it, then press a key. Also note that `C.d_features.params.run_feature_extraction = false` makes d_a reload an existing `BURST_FEATURES.mat` instead of recomputing features.

### 2. Time-domain branch: `main_time_domain_analysis.m`

| Switch | Function |
|---|---|
| `run_build_time_domain_analysis_datasets` | `j_build_time_domain_analysis_datasets()` |
| `run_activation_profiles` | `k_plot_activation_profiles()` |
| `run_spm` | `l_spm_envelope_analysis()` |
| `run_temporal_coherence_link` | `i_temporal_coherence_link()` |

Needs stage e outputs; `i_` also needs stage g outputs. All four switches are currently `false`.

### 3. Kinematics branch: `main_kinematics_analysis.m`

| Switch | Function |
|---|---|
| `run_kinematics_build` | `build_kinematics_for_coherence_cycles()` |
| `run_kinematics_analysis` | `analyze_kinematics_for_coherence_cycles()` |

Needs stage a and stage f outputs.

---

## Coherence pipeline, stage by stage

Intermediate files go to `<project_data_root>/mat_data/<subfolder>` (see [Data and output locations](#data-and-output-locations)). Tables go to `Results/<stage>/` and figures to `Results/png_visualisation/<stage>/`.

### a: Raw cycle extraction (`a_extract_raw_cycles_concat`)

- Reads `.c3d` files with BTK and maps analog channels to muscles. The mapping mode is `C.a_extract_raw.mapping.mode`: `association_script` (default, runs `Metadata/Association.m`), `fixed_names` or `auto` (keyword matching).
- Reads heel-strike and toe-off events from the first matching event name in `C.a_extract_raw.events.*`.
  - If toe-off is missing it is placed at 60 % of the cycle (`allow_missing_to`, `to_fallback_ratio`).
  - Legs with fewer than 2 heel strikes are skipped.
- Cuts EMG from heel strike to heel strike for every muscle and concatenates the cycles across trials per subject × condition × leg × muscle. It stores cycle starts and ends, toe-off positions, trial provenance and `fs`.
- Extracts heel and toe marker trajectories (`RAW_MARKERS`) for the kinematics branch.
- **Output:** `mat_raw_EMG_data/<subj>_RAW_CYCLES_CONCAT.mat` (`CYCLES_SIGNAL_RAW`, `RAW_MARKERS`).
- **Recaps** in `Results/a_raw_signal_summary/`: `RAW_SIGNAL_SUMMARY.csv`, `RAW_PARTICIPANT_SUMMARY.csv`, `RAW_RECAP_*.csv`, processing logs, trial recap and marker recap.

### b: Preprocessing (`b_preprocess_emg`)

- Removes the mean, then band-passes at 8–450 Hz (4th-order IIR, zero-phase). Notch, rectification and z-scoring are optional and off by default.
- Also stores a time-domain branch for each signal: band-passed, rectified, and a 10 Hz 2nd-order low-pass envelope.
- **Output:** `mat_preproc_EMG_data/<subj>_EMG_PREPROC.mat`.
- **Figures:** raw vs. preprocessed signals, plus random time/PSD QC plots.

### c: Burst detection (`c_extract_bursts_from_preproc`)

- Envelope: 50 Hz low-pass of the rectified signal.
- Threshold: the 50th percentile of the envelope, recomputed in 1-minute windows. Locally flat stretches are removed.
- Mask cleanup: runs shorter than 100 samples are removed and gaps of 200 samples or less are filled. A second minimum-length pass and a maximum-length pass exist but are off.
- Each burst is linked to its gait cycle(s).
- **Output:** `mat_bursts_data/<subj>_EMG_BURSTS.mat` (`BURSTS_DET`, `BURSTS_SUMMARY`). Burst IDs have the form `subj__cond__leg__muscle__NNNN`.

### d_a: Clustering-based cleaning (`d_a_clustering_cleaning`)

- Computes features for each burst:
  - median frequency (Morlet CWT, 1–400 Hz)
  - amplitude and shape statistics: max, skewness, kurtosis, SD
  - complexity on the z-scored burst: sample entropy, fuzzy entropy, Higuchi FD
  - duration, RMS and derivative measures
- Clusters bursts with k-means, separately for each `groupVar` (currently `muscle`):
  - features used: `MedFreq`, `SampEntr`, `FuzzyEntr`, `HFD`, `duration_s`, `MaxDeriv`, z-scored and weighted
  - k is tried from 2 to 10, with 20 replicates
  - k is selected by `elbow` (silhouette, Calinski-Harabasz, Davies-Bouldin, manual and mixed are also available)
- **Manual step:** you choose which clusters to keep per group in `C.d_cluster_manual.keep`, which produces `cluster_good`.
- **Outputs:**
  - `mat_burst_features/BURST_FEATURES.mat`
  - `mat_clustering_data/CLUSTER_RESULTS.mat`
  - CSVs in `Results/d_a_clustering_cleaning/`
  - histogram, correlation, score and decision plots

### d_b: Rule-based cleaning (`d_b_rule_based_cleaning`)

- **Signal-level checks** (PASS / WARN / FAIL): NaN fraction, flatline blocks, 50/60 Hz line-noise ratio, and spectral shape (low/mid and high/mid power ratios). If a signal FAILs, all of its bursts are rejected.
- **Burst-level rules** currently active:
  - global spike: robust z of the burst peak against the other bursts in the same signal is above 5
  - median frequency below 20 Hz
  - absolute amplitude: peak-to-peak above 8 mV or RMS above 1.5 mV
- Duration, local spike, plateau/rail and spectral-ratio rules are implemented but disabled.
- **Outputs:** `mat_rule_based_data/QC_bursts.mat` and `Results/d_b_rule_based_cleaning/csv_burst_qc/QC_bursts_summary.csv`, plus decision plots and plots of failed signals.

### e: Final burst decision (`e_final_burst_qc_combination`)

- Joins the d_a and d_b decisions on `burst_id` and applies them in this order:
  1. Optional visual score 3: the whole signal is rejected.
  2. d_b signal FAIL: all bursts are rejected.
  3. Per burst: if d_a and d_b agree, their decision is kept. If they disagree, `decision_rule` decides: `"conservative"` (current) rejects the burst, `"inclusive"` keeps it.
- **Outputs:** `mat_final_burst_decision/FINAL_BURST_QC.mat`, `Results/e_final_burst_qc_combination/csv/FINAL_BURST_QC_summary.csv`, random decision plots and per-reason burst examples.

### f: Cycle-level QC and paired-signal rebuild (`f_build_final_paired_signals_from_burst_qc`)

- **Per-muscle cycle QC** (`C.f_final_signals.params.cycle_policy`). A cycle is rejected if any of these holds:
  - it has no burst, or no good burst
  - it is flat, or more than 1 % of it is flatline
  - a bad burst, padded by the Morlet cone-of-influence half-width of the lowest analysed frequency, overlaps the pair's POI (`reject_if_in_phase_of_interest_padded_for_wavelet_analysis`)
- **Band-specific cycle masks:** the padding check is repeated with the Alpha, Beta and Gamma half-widths, which gives one cycle mask per band.
- **Pair mask:** a cycle is kept only if it is valid in both muscles. A pair signal needs at least 10 valid cycles (`min_cycles_required`).
- **Cross-talk QC** (currently `TAprox_TAdist`, overall mode). A pair signal is excluded when the cumulant density has a narrow central peak (width ≤ 5 ms, |lag| ≤ 5 ms) **and** either broadband coherence ≥ 0.3 or |zero-lag correlation| ≥ 0.7.
- **Signal rebuild:** the kept cycles are concatenated into synchronised pair signals, with a segment table that maps them back to the original indices.
- **Recap and statistics outputs:** cycle-retention tables, recap tables per band, Kruskal-Wallis tests and LMMs on cycle counts, a recoverability score, and a readable summary workbook.
- **Outputs:**
  - `mat_final_paired_signals/FINAL_PAIRED_SIGNALS.mat` and `FINAL_PAIRED_SIGNALS_{OVERALL,ALPHA,BETA,GAMMA}.mat`
  - many XLSX tables in `Results/f_cycle_level_qc_and_signal_rebuild/` (including `recap_tables/`, `crosstalk_qc/`, `cycle_count_stat_tests/`)
  - QC figures

### g: Wavelet coherence (`g_emg_emg_wavelet_coherence`)

Runs once per input dataset: `FULL` (8–60 Hz), `ALPHA`, `BETA` and `GAMMA`. Each band dataset uses its own band-specific cycle mask from stage f.

1. **Wavelet transform.** Each whole concatenated signal is padded (`mirror` by default), transformed with a Morlet CWT (the `wavelet.m` from `wtc-r16`, modified for a linear 1 Hz grid), and the padding is cropped off.
2. **Per-cycle spectra.** Each cycle's transform is interpolated to 1000 points. Auto- and cross-spectra are averaged across cycles, and coherence is computed once: `C = |Sxy|² / (Sxx·Syy)`.
3. **Cycle equalization.** This is the primary coherence source, `"equalized"`. Every signal of a pair uses the same number of cycles, `N_common`, which is the minimum across the dataset (`global_min`). The cycles are chosen `evenly_spaced`.
4. **Other coherence variants**, computed on request:
   - `raw`
   - `sig`: Rosenberg threshold `1 − α^(1/(N−1))`
   - `sig_equalized`
   - `sig_common_threshold`
   - `zcoh_bokil`: Fisher z with a DoF correction
   - `cycle_bias_corrected`: `C − a(1/N − 1/Nref)`
   - `surrogate_delta`: shuffled cycle order, 95th percentile; off by default
   - Which variants are summarised is set by `metric_sources_to_save` (currently `["equalized"]`).
5. **Scalar metrics** for each band and each scope (full cycle, stance, swing, POI): mean, raw AUC, bandwidth-normalized AUC (`*_AUC_norm`) and peak. POI log power is also computed.
6. **Outputs:**
   - `mat_coherence_data/COHERENCE_RESULTS_{FULL,ALPHA,BETA,GAMMA}.mat`
   - `Results/g_emg_emg_wavelet_coherence/COHERENCE_SUMMARY_TABLE_<DS>.csv`
   - edge, padding and COI QC
   - Individual, group and final-comparison plots are made only when `C.g_coherence.plot.enable` is `true` (currently `false`, which is much faster).

### h: Coherence statistics (`h_coherence_stats`)

- **Primary analysis.** For each pair separately and each band, the DV is the bandwidth-normalized AUC in the POI of the `equalized` coherence. Each band's value comes from its own band-specific dataset, and legs are averaged per participant. The model is fitted with `fitlme`:

  ```
  AUC_norm ~ AgeYears_z * condition + (1|subject)
  ```

  Optional covariates are quadratic age, band log-power and `log(n_cycles)`; all are off.
- **Other analyses** (all off in the current config):
  - categorical-age LMM with post hocs (Wilcoxon / Mann-Whitney, FDR)
  - power-control models
  - age correlations and coherence-power correlations
- **Coherence spectra (SPM1D / SnPM, 5000 iterations).** Spectra are averaged over the POI and tested for:
  - age (`anova1`)
  - condition (`anova1rm`, complete cases)
  - age × condition (`anova2onerm`)
  - follow-up tests of condition within each age group and age within each condition
- **Outputs:**
  - in `Results/h_coherence_stats_pair_phase_main/`:
    - `tables/`: row- and subject-level tables, descriptives, `CONTINUOUS_AGE_LME_TABLE__<TAG>.csv`, spectrum tables
    - `models/`: text reports of the models
  - figures in `Results/png_visualisation/h_coherence_stats_pair_phase_main/`: band triplets, continuous-age LMM plots, spectrum curves
  - workspaces in `mat_stats_data/`
  - `TAG` encodes the source, scope, metric family and covariate, e.g. `equalized_poi_auc_nocyclecov`.

---

## Time-domain branch

Run with [main_time_domain_analysis.m](main_time_domain_analysis.m); the code is in [Functions/time_domain_analysis/](Functions/time_domain_analysis/).

- **`j_build_time_domain_analysis_datasets`**
  - Builds single-muscle and pairwise cycle datasets from `FINAL_BURST_QC` and the stage b envelopes.
  - Applies its own cycle policy (bad-burst fraction ≤ 10 %, flatline checks) and requires at least 7 valid cycles.
  - Stores band-passed, rectified and envelope cycles, plus 1000-point time-normalized versions.
  - Output: `mat_time_domain_data/TIME_DOMAIN_DATA.mat` and CSVs in `Results/j_time_domain_data/`.
- **`k_plot_activation_profiles`**
  - Plots mean ± SEM envelopes per muscle, by age and condition. Envelopes are normalized to each subject's 95th percentile in the Flat condition by default.
  - Output: `Results/png_visualisation/k_activation_profiles/`.
- **`l_spm_envelope_analysis`**
  - Normalizes amplitude (`flat_percentile` for condition analyses, `subject_percentile` for age analyses).
  - Excludes cycles with adaptive amplitude QC (median + 8·MAD).
  - Runs SPM1D/SnPM: condition within each age group, age within each condition, pooled analyses, and age × condition interaction, with Bonferroni-corrected post hocs. An optional symmetry index is available.
  - Outputs: figures under `png_visualisation/l_spm_envelope_analysis/`, CSVs under `Results/l_spm_envelope_analysis/`.
- **`i_temporal_coherence_link`** (optional)
  - Uses the same cycles as coherence to compute envelope correlation, co-activation IoU, peak lag and amplitude.
  - Relates these to POI coherence with correlations and LMMs (`coh ~ age_group*condition + predictor + amplitude + (1|subject)`).
  - Output: `Results/i_temporal_coherence_link/`.

---

## Kinematics branch

Run with [main_kinematics_analysis.m](main_kinematics_analysis.m); the code is in [Functions/kinematics_analysis/](Functions/kinematics_analysis/).

- **`build_kinematics_for_coherence_cycles`**
  - For exactly the cycles kept by stage f (overall and per band), computes stride length, stride speed, cycle duration, step duration and step length.
  - Uses heel marker displacement along `C.kinematics_coherence.params.forward_dim` (= 2, the Y axis), with units in mm.
  - Output: `Results/kinematics_coherence_cycles/`.
- **`analyze_kinematics_for_coherence_cycles`**
  - Summarizes the metrics per signal, then per leg, then across pairs.
  - Tests condition effects with an LMM against a null model (LRT), a Friedman test, and Holm-corrected paired Wilcoxon tests.
  - Output: `Results/g2_kinematics_coherence_analysis/` (tables and plots).

---

## Standalone scripts

- [diagnostic_plot_heel_marker_axes.m](diagnostic_plot_heel_marker_axes.m)
  - A visual check of which marker axis is the walking direction; this justifies `forward_dim`.
  - Set the subject, leg, pair and band at the top of the file.
  - Writes to `Results/kinematics_coherence_cycles/heel_marker_axis_diagnostics/`.
- [participant_summary_matlab.m](participant_summary_matlab.m)
  - Cohort descriptives (overall and by age group) from `participants_metadata_EMG.csv`.
  - Writes to `Results/participant_summary_outputs/` and `Results/png_visualisation/participant_summary_plots/`.

---

## Data and output locations

**Intermediate `.mat` files** live outside the repo, in `C.paths.mat_dir = <project_data_root>/mat_data/`:

| Subfolder | Produced by | Main file(s) |
|---|---|---|
| `mat_raw_EMG_data/` | a | `<subj>_RAW_CYCLES_CONCAT.mat` |
| `mat_preproc_EMG_data/` | b | `<subj>_EMG_PREPROC.mat` |
| `mat_bursts_data/` | c | `<subj>_EMG_BURSTS.mat` |
| `mat_burst_features/` | d_a | `BURST_FEATURES.mat` |
| `mat_clustering_data/` | d_a | `CLUSTER_RESULTS.mat` |
| `mat_rule_based_data/` | d_b | `QC_bursts.mat` |
| `mat_final_burst_decision/` | e | `FINAL_BURST_QC.mat` |
| `mat_final_paired_signals/` | f | `FINAL_PAIRED_SIGNALS[_OVERALL/_ALPHA/_BETA/_GAMMA].mat` |
| `mat_coherence_data/` | g | `COHERENCE_RESULTS_{FULL,ALPHA,BETA,GAMMA}.mat` |
| `mat_stats_data/` | h | `COHERENCE_STATS_PAIR_PHASE_MAIN.mat`, `workspace__<TAG>.mat` |
| `mat_time_domain_data/` | j | `TIME_DOMAIN_DATA.mat` |

**Tables and figures** go to `Results/` inside the repo: one folder per stage for CSV/XLSX outputs, and `Results/png_visualisation/<stage>/` for figures.

---

## Dependencies

- MATLAB with the Signal Processing Toolbox (`designfilt`, `filtfilt`, `cpsd`, `mscohere`) and the Statistics and Machine Learning Toolbox (`kmeans`, `fitlme`, `signrank`, `ranksum`, `kruskalwallis`).
- Vendored in [Functions/toolboxes/](Functions/toolboxes/):
  - `moveck_bridge_btk`: BTK for reading `.c3d` files (stage a only).
  - `spm1dmatlab-master`: spm1d, used by h (spectrum SPM) and l (envelope SPM).
  - `wtc-r16`: Grinsted's wavelet toolbox. Only `wavelet.m` (modified), `wave_bases.m` and `reverse.m` are used.

---

## Known issues

These are the problems in the current code that affect running it.

- `j_build_time_domain_analysis_datasets` reads `C.i_time_domain`, but the config defines `C.j_time_domain`, so `main_time_domain_analysis.m` fails at its first step.
- Stage a reads `C.a_extract_raw.input.generate_example_figures`, but the config defines it under `output.`. The error is caught per file and logged as `FILE_READ_ERROR`, so every trial would be skipped silently.
- In h_stats, `infer_spm_object_switch` is defined only inside `run_spm_mixed_age_condition_on_spectrum.m`. As a result the one-way age and condition spectrum SPMs fall into their `catch` branch and no significance bars are drawn.
- d_a needs a key press (`pause`), so the full pipeline cannot run unattended.
- c, d_a, d_b and e always plot one hard-coded example signal (for example `CTL_79 / Flat / right`). These plots fail if that subject is missing.
- `Metadata/ParticipantGroup.m`, `Metadata/PhysicalActivity_EMG.csv` and `Functions/simulations_helpers/` are not used by any code.
