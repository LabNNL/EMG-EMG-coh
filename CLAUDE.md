# CLAUDE.md

MATLAB pipeline for EMG-EMG wavelet coherence during gait (stages a→h; see README.md, docs/reproduce.md). Work on branch `repo-cleanup`; nothing is pushed without the user's say-so.

## Working rules

- Repo path (since 2026-10-24, OneDrive renamed the mount): `~/Library/CloudStorage/OneDrive-UniversitedeMontreal–YosraCherni-LioGrienenberger-MScepfl/Codes/EMG-EMG-coh`. Data and `mat_data/` live outside OneDrive, set in the git-ignored `config/local_paths.m`.
- `core.fileMode` is `false` in this repo: OneDrive flips permission bits.
- Run MATLAB with `/Applications/MATLAB_R2025b.app/bin/matlab -batch`, using script files (multi-line `-batch` strings get mangled). Start MATLAB from the repo root, or run `startup`.
- Cleanup work must not change which cycles are analysed unless that change is the point of the work. Archive outputs (move, never delete) before a rerun, and verify against the archive.
- One commit per phase, ending with the `Co-Authored-By` line.
- d_a has an interactive `pause`, so stages a–e are not rerun unattended.

## Key decisions

- **Band set toggle** `C.analysis.band_set` (top of the config): `highbeta_gamma` (primary), `beta_gamma`, `alpha_beta_gamma`. Each set has its own f/g/h outputs: `mat_data/<stage>/bands_<set>/`, `Results/bands_<set>/`, own regression reference. All three were run on 2026-10-25; comparison in `docs/acquisition.md` ("Other band sets").
- **The primary analysis uses only ≥ 20 Hz**: bands HighBeta [20 30] and Gamma [31 60] Hz, decided 2026-10-24. The Delsys high-pass (10 or 20 Hz) cannot be confirmed for every participant, and below 20 Hz cycle-locked movement artifact inflates coherence. Every stage loops over the band list; band names have no underscore (they prefix columns such as `HighBeta_AUC_norm`). Stage b's 8–450 Hz band-pass stays.
- Primary model: `AUC_norm ~ AgeYears_z * condition + (1|subject)` per pair (TAprox_TAdist, SOL_GM) and band, POI scope, `equalized` source, legs averaged.
- Effects coding, REML and Satterthwaite DF for every stage-h model (`C.h_stats.lme`, `fit_h_lme`, `get_lme_term_stats`). The interaction is kept.
- Holm correction per term across the pair × band models (currently 4).
- Wavelet transforms run per trial run (`C.g_coherence.params.transform_scope = "per_trial"`, `context_policy = "trial_run_safe"`, `min_pad_sec = 0.6`), not over the glued kept cycles.
- Vendored toolboxes stay as they are (BTK, spm1d, wtc-r16).

## What each phase changed

Repo cleanup (tag `results-final-2026-10` → `5851876`; results unchanged):

| Phase | Change |
|---|---|
| 1 | Made the repo runnable on a clean MATLAB; added `Tools/check_repo` |
| 2 | Retired dead code and tidied the layout (`attic/`) |
| 3 | Removed debug leftovers and global side effects |
| 4 | Resolved duplicate filenames; added detection of shadowing copies |
| 5a, 5b | Deleted overridden and unread config settings (the `C` struct is identical) |
| 6 | Fixed latent bugs in switched-off stages |

Follow-ups:
- `ae69497`: SPM spectrum tests, stale metadata, plot guards.
- `c61ccbb`: cluster p-values (were all NaN).
- `b5fcf1d`, `27cf7fd`, `b88268b`: acquisition audit and docs. The native sampling rate is unknown; the 963 Hz feature is a harmonic of the sensors' 74 Hz auxiliary-channel comb.

Correctness round, 2026-10-24 (plan: `~/.claude/plans/ok-good-now-to-melodic-puffin.md`):

| Commit | Change |
|---|---|
| `6fb92c9` | Stage f stores `cycle_trial_id` / `cycle_run_id` (masks identical; 927/927 pairs have run ids) |
| `bc1cc4d` | Stage g per-trial transforms. Audit: old scope reproduces old g exactly; fix shifts TA Alpha by about −1%, Beta and Gamma by nothing measurable |
| `ce113d5` | Stage h statistics: effects coding, REML, Satterthwaite, Holm, figures read the primary table, age post hoc per subject, Bonferroni SPM follow-ups, sensitivity table, `_stale_*/` archiving |
| `515d7b0` | ≥ 20 Hz bands; Alpha/Beta/Gamma hard-coding removed from f, g, h, i |
| (docs) | `docs/acquisition.md` results and rationale, README, `docs/reproduce.md`, this file, baselines |

Rerun f → g → h (21 min) verified:
- Gamma cycle masks and analysed cycles are identical.
- FULL and HighBeta only gained cycles (+395 cycles, 394 → 411 signals).
- N_common is still 10.
- A hand refit reproduces the table (≤ 1e-13), as does Holm recomputed by hand.
- The mean of the per-condition slopes equals the age estimate.

Results (Holm):
- TA HighBeta age p = 0.0005.
- TA Gamma age p = 0.028 and condition p = 0.0006.
- SOL_GM HighBeta age p = 0.028: holds with log(age) (0.025), not with quadratic age (0.08).
- No interactions.

`Results/` holds only current outputs; everything older is in `attic/ResultsArchive/` (git-ignored, with MANIFEST.csv). Previous outputs are in `mat_data/_archive_before_20hz_2026-10/` and `attic/ResultsArchive/_archive_before_20hz_2026-10/` (and the older `_archive_before_junction_fix_2026-10/`, `_archive_before_correctness_round/`).

## Open

1. Stages a–e were all rerun on 2026-10-24 between 08:05 and 08:52, probably from all-on switches. Not yet confirmed with the user that this was intended; the archives and every result since build on that run.
2. Optional: run `surrogate_delta` to test how much HighBeta/Gamma coherence is cycle-locked commonality.
3. Junction residual: stage b filters across trial boundaries (would need a rerun of a–e to fix).
