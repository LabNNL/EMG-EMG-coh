# Reproducing the results

How to regenerate the coherence results from the recordings, and how to check that what you got matches what was reported.

## What you need

- MATLAB (developed on R2025b) with the Signal Processing and the Statistics and Machine Learning toolboxes. The other toolboxes are vendored in `Functions/toolboxes/`.
- The data folder: the raw `.c3d` files under `Reworked_Data/`, plus `mat_data/` if you want to start from an intermediate stage.
- `Metadata/` (association, participant metadata), which is not in git.
- About 60 GB free for `mat_data/`. The stage-f and stage-g files are 2–3 GB each.

## Setup (once)

1. Copy `config/local_paths.template.m` to `config/local_paths.m` and set `project_data_root`.
2. Start MATLAB in the repository root so that `startup.m` runs, or `cd` there and run `startup`.
3. Run `check_repo`. The `shadowed` check must be empty. A copy of an older version of this project on your saved MATLAB path will otherwise run instead of these files; remove it with `pathtool`.

## Which stages to run

Every stage reads the previous stage's `.mat` files from `mat_data/`, so you only rerun from the first stage whose inputs or code changed. The switches are `C.parameters_running.run_*` at the top of `config/config_emg.m`; then run `main_coherence_analysis`.

| Starting point | Switches on | Time (M-series Mac) | Notes |
|---|---|---|---|
| From the `.c3d` files | a, b, c, d_a, d_b, e, f, g, h | ~1 h 10 | **d_a stops at a `pause`**: inspect the cluster plots, check `C.d_cluster_manual.keep` in the config, press a key. The kept clusters are already in the config, so normally you only confirm. |
| From the burst decisions (`FINAL_BURST_QC.mat`) | f, g, h | ~21 min (f 9, g 9, h 3) | The usual starting point for analysis changes, including any change to the bands. |
| From the coherence results | h | ~3 min | Statistics and figures only. |

## Settings that define the reported results

All in `config/config_emg.m`. Changing any of these changes the results.

| Setting | Value | Meaning |
|---|---|---|
| `C.shared_wavelet.FreqBands` | HighBeta [20 30], Gamma [31 60] Hz | Only ≥ 20 Hz is analysed (see `docs/acquisition.md`, "Why the analysis starts at 20 Hz"). Before 2026-10: Alpha [8 12], Beta [13 30], Gamma [31 60]. Changing the bands needs a rerun from f: stage f's cycle-rejection boundaries depend on the lowest band. |
| `C.b_preproc.bandpass` | 8–450 Hz, 4th-order Butterworth, zero phase | Does not bias coherence (see `docs/acquisition.md`). |
| `C.f_final_signals.params.cycle_policy` | see config | Which cycles are kept, per band. |
| `C.g_coherence.params.transform_scope` | `"per_trial"` | One wavelet transform per stretch of continuous recording. Before 2026-10 it was one transform over the glued kept cycles (`"concatenated"`), which put artificial jumps into the signal at every trial boundary and every rejected cycle. |
| `C.g_coherence.params.per_trial.context_policy` | `"trial_run_safe"` | Rejected cycles stay in as real context only if they pass the general QC in both muscles and have no bad burst within the contamination half-width of a kept sample. |
| `C.shared_wavelet.WaveNumber` | 7 | Morlet, 20–60 Hz, 1 Hz grid. |
| `C.g_coherence.params.cycle_equalization` | `global_min`, `evenly_spaced` | Every signal of a pair uses the same number of cycles (`N_common`, 10 for both pairs). |
| `C.h_stats.analysis.coherence_source` | `"equalized"` | |
| `C.h_stats.lme` | effects coding, REML, Satterthwaite | Every mixed model in stage h goes through `fit_h_lme` / `get_lme_term_stats`. |

## The primary analysis

For each muscle pair (TAprox–TAdist, SOL–GM) and band (HighBeta 20–30 Hz, Gamma 31–60 Hz), the outcome is the bandwidth-normalized area under the equalized coherence in the pair's phase of interest. Legs are averaged per participant. The model is:

```
AUC_norm ~ AgeYears_z * condition + (1|subject)
```

It is fitted with effects coding, REML and Satterthwaite degrees of freedom. Under effects coding, the `AgeYears_z` row is the age slope averaged over the three conditions. Under MATLAB's default reference coding, which earlier versions used, it was the slope on flat ground only. The p-values for age, condition and age × condition are Holm-adjusted across the 4 models (2 pairs × 2 bands), in the `*_holm` columns. The current numbers, and how they differ from the earlier 8–60 Hz results, are in `docs/acquisition.md`.

Results: `Results/h_coherence_stats_pair_phase_main/tables/CONTINUOUS_AGE_LME_TABLE.csv`, with one model report per pair and band in `models/continuous_age_models/` and residual QQ plots in `models/continuous_age_lmm_diagnostics/`.

`tables/SENSITIVITY_CONTINUOUS_AGE.csv` refits the same model with quadratic age, Fisher-z coherence, raw coherence plus log(number of cycles), and cycle-bias-corrected coherence. A conclusion that only holds in the primary row should be reported with that caveat.

Figures: the band-triplet and continuous-age plots print the Holm-adjusted p-values of the primary model and name it in a footer. Age groups in the boxplots are for display only. The pairwise bars are Mann-Whitney or Wilcoxon tests with FDR correction, on one value per participant. The spectrum SPM follow-ups (condition within each age group, age within each condition) are Bonferroni-corrected over the strata of each figure.

## Checking a rerun

- Previous outputs:
  - `mat_data/_archive_before_20hz_2026-10/` and `Results/_archive_before_20hz_2026-10/`: the 8–60 Hz run with stage-f run ids, just before the ≥ 20 Hz rerun. The `Results` one also holds the transform-scope audit CSVs.
  - `mat_data/_archive_before_junction_fix_2026-10/` and `Results/_archive_before_correctness_round/`: from before the 2026-10 correctness round.
- **`check_against_baseline`** compares every table of stages f, g and h (each CSV, each XLSX sheet) number by number against a saved reference: same columns, same rows, numbers within 1e-10, text identical. Run `check_against_baseline('MakeReference', true)` before a change that should not alter results, rerun the stages, then `check_against_baseline()`. Everything is deterministic: a rerun of unchanged code gives "same" on all tables, since the SPM permutation tests are seeded (`C.h_stats.spectrum.nonparam_seed`).
- `Tools/baseline/RESULTS_BASELINE_<date>.sha256` lists the checksum of every table and figure of the reported run. From the repository root, `shasum -a 256 -c Tools/baseline/RESULTS_BASELINE_<date>.sha256 | grep -v OK$` lists what differs. Figures can differ byte-wise across MATLAB versions; compare the CSVs first.
- `Tools/test_compute_pair_tfr` checks the wavelet transform scopes on synthetic data (seconds).
- `Tools/audit_wavelet_transform_scope` recomputes the equalized coherence of every pair under the old and new transform scopes and reports the differences (~30 min per dataset; `'FromRows'` rebuilds the summary from a saved run).
- Stage h moves tables and figures it did not rewrite into `_stale_<time>/` folders (with a `MANIFEST.csv`), so whatever sits directly in `tables/`, `models/` and the figure folders comes from the last run.
