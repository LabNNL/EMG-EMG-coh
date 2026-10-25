# What is inside the saved files

The stages pass data to each other as `.mat` files in `mat_data/` (see the README for the folder of each). Stages f, g and h write into a subfolder per band set, e.g. `mat_coherence_data/bands_highbeta_gamma/`. Almost all of them hold one **nested struct** with the same shape:

```
S.(subject).(condition).(leg).(muscle or pair)
   CTL_01     Flat        left    EMG_TAprox_Concat   (stages a–e: one entry per muscle)
              Medium      right   TAprox_TAdist       (stages f–g: one entry per muscle pair)
              High
```

Loop over it with `fieldnames` at each level (the stages do exactly that). Some files also have a `meta` field next to the subjects; skip anything that is not a subject.

Two index spaces appear everywhere, and mixing them up is the most common mistake:

- **original indices** point into the concatenation of *all* cycles built by stage a (`signal`, `original_signal_1/2`);
- **final indices** point into the signal rebuilt from the *kept* cycles only (`final_concatenated_signal_1/2`).

The segment table `Tseg` (below) maps one to the other.

Field lists below are from real files (CTL_01, Flat, left). Fields not listed are diagnostics.

---

## Stages a–c: one entry per muscle

`<subj>_EMG_BURSTS.mat` → `BURSTS_DET.CTL_01.Flat.left.EMG_TAprox_Concat` (stage a and b files have the same core fields):

| Field | Size | Meaning |
|---|---|---|
| `signal` | n × 1 | band-passed EMG (stage b), all cycles of all trials glued |
| `signal_raw` | n × 1 | the same before filtering |
| `fs` | 1 | 2000 Hz |
| `cycle_starts`, `cycle_ends` | cycles × 1 | where each cycle sits in `signal` |
| `cycle_lengths` | cycles × 1 | samples |
| `trial_id` | cycles × 1 | the trial each cycle came from |
| `orig_start`, `orig_end` | cycles × 1 | where each cycle sat in its own trial recording |
| `toe_off_concat`, `toe_off_in_cycle` | cycles × 1 | toe-off, in `signal` and within the cycle |
| `envelope`, `burst_mask` | n × 1 | activation envelope and on/off mask |
| `bursts_idx` | bursts × 2 | start and end of each burst in `signal` |
| `bursts_table` | bursts × 18 | burst features |

Stage e (`FINAL_BURST_QC.mat`) adds a good/bad decision per burst, with the same nesting.

---

## Stage f: one entry per muscle pair

`FINAL_PAIRED_SIGNALS.mat` (all bands, overall cycle mask), `FINAL_PAIRED_SIGNALS_OVERALL.mat`, and one `FINAL_PAIRED_SIGNALS_<BAND>.mat` per band. A band file is the same struct, with the masks and signals of that band. Entry: `FINAL_PAIRED_SIGNALS_GAMMA.CTL_01.Flat.left.TAprox_TAdist`.

**Signals and cycles**

| Field | Size | Meaning |
|---|---|---|
| `muscles` | 1 × 2 | e.g. `{'EMG_TAprox_Concat','EMG_TAdist_Concat'}`; signal 1 is the first |
| `original_signal_1`, `original_signal_2` | n × 1 | the two muscles, all cycles (original indices) |
| `cycle_starts`, `cycle_ends` | cycles × 1 | cycles common to both muscles, original indices |
| `cycle_trial_id`, `cycle_run_id` | cycles × 1 | trial of each cycle; run = stretch of consecutive cycles with no gap |
| `final_concatenated_signal_1`, `_2` | m × 1 | the kept cycles only, glued (final indices) |
| `final_cycle_segments_table` | kept × 15 | **Tseg**, see below |

**Which cycles are kept**

| Field | Size | Meaning |
|---|---|---|
| `pair_cycle_keep_mask`, `pair_cycle_reason` | cycles × 1 | kept in both muscles, and why not |
| `valid_cycle_numbers`, `removed_cycle_numbers` | | the same as cycle numbers |
| `general_keep_mask_muscle1/2`, `general_reason_muscle1/2` | cycles × 1 | per-muscle checks that do not depend on the band |
| `muscle1_cycle_qc`, `muscle2_cycle_qc` | struct | everything per cycle and muscle: bursts in it, bad-burst segments (cycle-local samples), per-band contamination |
| `band_specific.<Band>` | struct | the mask, valid cycles and rebuilt signals of every band (in every file; a band file copies its own band's into the top-level fields) |
| `n_valid_cycles`, `included_for_analysis`, `exclusion_reason` | 1 | ≥ 10 kept cycles? |
| `excluded_by_crosstalk`, `included_after_crosstalk` | 1 | final inclusion, used by stage g |
| `overall_contamination_half_width_sec` | 1 | the COI half-width used to judge contamination |

### Tseg: the segment table

One row per **kept** cycle:

| Column | Meaning |
|---|---|
| `cycle_number` | index into the pair's cycles (`cycle_starts`) |
| `original_cycle_start_idx`, `original_cycle_end_idx` | where it is in `original_signal_*` |
| `cycle_length_samples` | |
| `final_concat_start_idx_signal1`, `final_concat_end_idx_signal1` (and `_signal2`) | where it is in `final_concatenated_signal_*` |
| `run_id`, `trial_id` | its run and trial |
| `has_toe_off`, `toe_off_original_idx`, `toe_off_relative_idx_in_cycle`, `toe_off_rebuilt_idx_signal1/2` | toe-off of the cycle, in each index space |

```matlab
% the k-th kept cycle of muscle 1
Tseg = P.final_cycle_segments_table;
x = P.final_concatenated_signal_1(Tseg.final_concat_start_idx_signal1(k) : Tseg.final_concat_end_idx_signal1(k));
% the same samples, from the all-cycles signal
x = P.original_signal_1(Tseg.original_cycle_start_idx(k) : Tseg.original_cycle_end_idx(k));
```

---

## Stage g: one result per pair

`COHERENCE_RESULTS_<DATASET>.mat` (FULL, HIGHBETA, GAMMA) → `COHERENCE_RESULTS.CTL_01.Flat.left.TAprox_TAdist`, usually called `R`. Only included pairs have an entry.

**Coherence maps**: all are frequency × time, `numel(R.Freq)` × 1000, time in % of the gait cycle (`R.Time_percent`):

| Field | Meaning |
|---|---|
| `Freq` | frequencies (1 Hz grid, e.g. 31–60 for GAMMA) |
| `Coherence` | from all kept cycles |
| `Coherence_equalized` | from `N_common` cycles: **the one the statistics use** |
| `Coherence_sig`, `Coherence_sig_equalized` | minus the significance threshold, floored at 0 |
| `Coherence_cycle_bias_corrected`, `Coherence_zcoh_bokil` | other variants (see README) |
| `PowSpec_signal1`, `PowSpec_signal2` | cycle-averaged power |

**Scalar metrics**: `R.Metrics.<source>.<scope>.<metric>.<Band>`, for example:

```matlab
R.Metrics.equalized.poi.auc_norm.Gamma     % the number that goes into the statistics
```

- `source`: `equalized`, `raw`, `cycle_bias_corrected` (as listed in `metric_sources_to_save`)
- `scope`: `full`, `stance`, `swing`, `poi`
- `metric`: `mean`, `auc_raw`, `auc_norm`, `peak` (per band), and `fullband_*`

**Which cycles and how**

| Field | Meaning |
|---|---|
| `n_cycles_used`, `valid_cycle_numbers` | cycles available after QC |
| `equalized_cycle_numbers` | the `N_common` cycles used for `Coherence_equalized` |
| `cycle_equalization` | `N_common`, mode, selection |
| `POI` | start and end % of the phase of interest, its indices |
| `transform_scope`, `transform_info` | `per_trial`, number of segments transformed, context cycles |
| `CycleBandCoherence` | mean coherence per band and per cycle (diagnostic) |

---

## Stage h: tables

h flattens the results into tables in `Results/bands_<set>/h_coherence_stats_pair_phase_main/tables/`, which are easier to work with than the structs:

| Table | One row per |
|---|---|
| `T_row_before_leg_average.csv` | subject × condition × leg × pair, with `<Band>_AUC_norm`, cycle counts, power |
| `T_subject_after_leg_average.csv` | subject × condition × pair (legs averaged), plus age: the input of the models |
| `CONTINUOUS_AGE_LME_TABLE.csv` | pair × band: the primary model, with F, DF, p, Holm p, age slope and CI |
| `SENSITIVITY_CONTINUOUS_AGE.csv` | pair × band × model variant |
| `DESCRIPTIVE_TABLE_ALL.csv` | pair × age group × condition × metric |
| `spectrum_curves/*.csv` | spectra and SPM results |

`mat_stats_data/bands_<set>/COHERENCE_STATS_PAIR_PHASE_MAIN.mat` holds `T_row` and `T_subj` as MATLAB tables.
