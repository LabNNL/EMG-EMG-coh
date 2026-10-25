# Code conventions

How code in this repository is organized, and how to change it without changing the results. New code follows these rules. Older code is being brought in line stage by stage; where it does not yet, the section **Not yet in line** says so.

## Where code goes

| Kind of code | Place |
|---|---|
| a pipeline stage | `Functions/<stage>/<stage>.m`, e.g. `Functions/g_coherence/g_emg_emg_wavelet_coherence.m` |
| a helper used by one stage only | `Functions/<stage>/<stage>_helpers/` |
| a helper used by several stages | `Functions/general/` |
| settings, paths, run switches | `config/config_emg.m`, nowhere else |
| your data folder | `config/local_paths.m` (git-ignored) |
| a one-off analysis or figure | `scripts/` |
| checks and audits of the code or the data | `Tools/` |
| retired code | `attic/` (off the path) |
| documentation | `docs/` |

`startup.m` puts all of `Functions/` on the path, so a helper is found wherever it sits in `Functions/`. Its folder says who uses it.

**One function per file**, named like the file. Local functions (several functions in one file) are fine when only that file uses them. Once a second file needs the function, move it to its own file; never copy it. Two functions with the same name in different files make the result depend on which one MATLAB finds first. `check_repo` flags duplicate file names.

## A stage function

```matlab
function g_emg_emg_wavelet_coherence()
% G_EMG_EMG_WAVELET_COHERENCE  Wavelet coherence for every included muscle pair.
%
% Reads   mat_final_paired_signals/FINAL_PAIRED_SIGNALS[_<BAND>].mat   (stage f)
% Writes  mat_coherence_data/COHERENCE_RESULTS_<DATASET>.mat
%         Results/g_emg_emg_wavelet_coherence/COHERENCE_SUMMARY_TABLE_<DATASET>.csv
% Settings  C.g_coherence (config/config_emg.m)
```

- A stage reads its inputs from the previous stage's files and writes its own; it does not call another stage.
- The header says what it reads, what it writes and which config block drives it.
- Settings come from `config_emg()` once, at the top of the stage. Helpers receive what they need as arguments (`C`, or better the sub-struct such as `W = C.g_coherence.params`). A helper should not call `config_emg()` itself.
- The parts of a stage, loading, computing, saving and plotting, are separate functions or at least separate sections. Plotting is switched by `C.<stage>.plot.enable` and never changes a number that is saved.

## A helper function

```matlab
function [trial_id, run_id, note] = get_pair_cycle_run_ids(E1, E2, cycle_starts, cycle_ends, alignment_note)
% Which trial each pair cycle came from, and which cycles are continuous
% recording. A new run starts at a trial change or a gap between cycles.
% Returns run_id = NaN, with a reason in note, when this cannot be told.
```

- The first comment lines say what it returns and anything surprising (units, index space, NaN cases). Skip what the name already says.
- Inputs are arguments, not globals or `evalin`. Outputs are return values, not edits to a struct nobody returns.
- It does not print unless that is its job, and it does not plot unless its name says so (`plot_*`, `make_*_figure`).

## Names

| Thing | Style | Example |
|---|---|---|
| functions, variables | `lower_snake_case` | `build_transform_segments`, `n_valid_cycles` |
| stage entry points | letter prefix in pipeline order | `f_build_final_paired_signals_from_burst_qc` |
| config blocks | `C.<stage>.params / .io / .plot` | `C.g_coherence.params.transform_scope` |
| frequency bands | `C.shared_wavelet.FreqBands`, CamelCase, no underscore | `HighBeta`, `Gamma` |
| per-band columns | `<Band>_<metric>` | `HighBeta_AUC_norm` |
| saved structs | upper case, as saved | `FINAL_PAIRED_SIGNALS`, `COHERENCE_RESULTS` |

Never hard-code a band name or a list of bands. Loop over `fieldnames(C.shared_wavelet.FreqBands)`, so that changing the bands is a config edit.

Comments and output messages are in English.

## Results must not change by accident

Any change that is not meant to change results (refactor, rename, clean-up, merging helpers) is checked like this:

1. `check_against_baseline('MakeReference', true)` before the change, if the current reference is not from the current commit.
2. Make the change. `check_repo` must report 0 errors, and `checkcode` no new messages in the files you touched.
3. Rerun the stages the change touches (switches in `config/config_emg.m`, then `main_coherence_analysis`).
4. `check_against_baseline()` must report every table "same".

A change that is meant to change results is archived first (move the affected `mat_data/` and `Results/` folders to `_archive_<what>_<date>/`, never delete), rerun, and its effect reported in the commit message.

The pipeline is deterministic: the cycle selection, the SPM permutations (`C.h_stats.spectrum.nonparam_seed`) and the surrogate tests are seeded, so an unchanged rerun reproduces every table.

## Commits

One commit per logical change, in the imperative, saying what changed and why, and for result-changing work what it did to the numbers. Do not mix a refactor and a result change in one commit.

## Not yet in line

Known places that do not follow these rules yet, to fix stage by stage:

- **Long stage functions.** `g_emg_emg_wavelet_coherence.m` (1,060 lines) and `l_spm_envelope_analysis.m` (4,450, off) still mix loading, computing, saving and plotting in one function. Stages f and h have been split into step functions (`*_steps/` folders) and are the model for the others.
- **Helpers that call `config_emg()` themselves**: three plotting helpers in stages c and d_a, and, as a fallback when no settings are passed, `write_lme_report` and `get_term_pvalue_from_lme_formula`. `h_coherence_stats.m` also reloads the config halfway through.
- **Missing header comments**: about two thirds of the files.
- **Same name in two files.** No function shadows a shared one any more. A few private local functions share a name across files and differ on purpose (`zscore_safe` in the f crosstalk QC and in i, `get_ylabel_text` in k and l, `get_marker_fs` and `get_marker_trial_struct` in the kinematics build and its diagnostic script, `parse_args` in Tools). Each is only visible inside its own file, so they cannot be confused at run time.
- **Repeated nested loops** over subject → condition → leg → pair in every stage.
