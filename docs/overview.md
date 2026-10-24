# The pipeline on one page

Start here if you are new to this repository. Then run `scripts/tour_one_pair.m`, which follows one muscle pair through every stage in about a minute. Read [data_structures.md](data_structures.md) when you need to open the saved files, and [reproduce.md](reproduce.md) to regenerate the results.

## The question

How does the coupling between two muscles of the same leg change with age, and with walking surface? Coupling is measured as **EMG-EMG coherence**: how consistently two EMG signals oscillate together at a given frequency, over repeated gait cycles. Coherence in the beta and gamma range (here 20–60 Hz) is read as a sign of common neural drive to the two muscles.

- **Participants:** 80 controls from early childhood to adulthood, in four age groups. The models use age in years as a continuous variable; the groups are for display.
- **Conditions:** three walking surfaces, `Flat`, `Medium` and `High` (`Plat`, `Medium`, `High` in the file names).
- **Pairs analysed:** `TAprox_TAdist` (two sites on tibialis anterior) and `SOL_GM` (soleus and gastrocnemius medialis), each in the part of the gait cycle where that pair is active (its *phase of interest*).

## The stages

Each stage reads the previous stage's `.mat` files from `mat_data/` and writes its own, so any stage can be rerun alone. `main_coherence_analysis.m` runs them in order, as switched on in `config/config_emg.m`.

```
 .c3d recordings
     │
 a   cut every muscle into gait cycles (heel strike to heel strike),        <subj>_RAW_CYCLES_CONCAT.mat
     glue the cycles of all trials together per subject/condition/leg
 b   band-pass 8–450 Hz                                                      <subj>_EMG_PREPROC.mat
 c   detect EMG bursts (activation periods)                                  <subj>_EMG_BURSTS.mat
 d_a cluster burst features, keep the plausible clusters  (manual step)      CLUSTER_RESULTS.mat
 d_b rule-based burst checks                                                 QC_bursts.mat
 e   combine d_a and d_b into one good/bad decision per burst                FINAL_BURST_QC.mat
     │
 f   decide which gait cycles to keep, per muscle pair and per band;         FINAL_PAIRED_SIGNALS*.mat
     rebuild the two signals of each pair from the kept cycles
 g   wavelet coherence per pair, averaged over cycles,                       COHERENCE_RESULTS_*.mat
     scalar metrics (e.g. normalized area in the phase of interest)
 h   statistics (mixed models on age and condition, SPM on spectra),         tables/, models/, figures
     tables and figures
```

Stages a–e clean the signals. They are slow and d_a needs a person, so they are rarely rerun. Most analysis changes start at f.

### What each analysis stage decides

- **f: which cycles count.** A cycle is rejected if a muscle has no good burst in it, if it is flat, or if a bad burst lies close enough to the phase of interest to contaminate the wavelet there. Closeness is the cone-of-influence half-width of the lowest frequency of the band. Because that width depends on the band, each band gets its own cycle mask. A pair signal needs at least 10 kept cycles.
- **g: coherence.** Each stretch of continuous recording is wavelet-transformed (Morlet, 20–60 Hz). Each kept cycle is stretched to 1000 points (0–100% of the gait cycle). Auto- and cross-spectra are averaged over cycles, and coherence is computed from the averages. Every signal uses the same number of cycles (`N_common`, currently 10) so that signals are comparable, because coherence is biased upward with fewer cycles.
- **h: statistics.** For each pair and band, one value per participant and condition (legs averaged) goes into `AUC_norm ~ AgeYears_z * condition + (1|subject)`. p-values are Holm-adjusted across pairs × bands. Coherence spectra are also compared with SPM. Results are summarised in [acquisition.md](acquisition.md#what-the-coherence-results-actually-show).

## Glossary

| Term | Meaning |
|---|---|
| **cycle** | One gait cycle, heel strike to the next heel strike of the same leg. |
| **concatenated signal** | All cycles of all trials of one subject × condition × leg, glued end to end. Stage a builds it; stage f rebuilds it from the kept cycles only. |
| **trial / run** | A trial is one recording. A *run* is a stretch of consecutive cycles within a trial, with no gap (`cycle_run_id`). The wavelet is computed per run, so it never sees the artificial jump where two non-consecutive cycles were glued. |
| **burst** | A period where a muscle is active, from stage c. Stages d_a, d_b and e label each burst good or bad. |
| **POI** | Phase of interest: the part of the gait cycle analysed for a pair. TAprox_TAdist uses 60% → 20%, wrapping through heel strike (swing and early stance). SOL_GM uses 0% → 60% (stance). `C.physio.phase_windows_pct`. |
| **band** | HighBeta 20–30 Hz, Gamma 31–60 Hz (`C.shared_wavelet.FreqBands`). Below 20 Hz is not analysed; see [acquisition.md](acquisition.md#why-the-analysis-starts-at-20-hz). |
| **dataset (FULL, HIGHBETA, GAMMA)** | Stage g runs once per dataset. FULL uses the cycle mask valid for all bands. Each band dataset uses that band's own mask, which keeps more cycles. The statistics take each band from its own dataset. |
| **COI** | Cone of influence: how far (in time) a wavelet at a given frequency reaches. 0.080 s at 20 Hz, 0.051 s at 31 Hz. |
| **equalized** | Coherence computed from exactly `N_common` cycles per signal, picked evenly spaced. This is the coherence the statistics use. |
| **AUC_norm** | Area under the coherence over the band and the POI, divided by the bandwidth. One number per signal and band. |
| **effects coding** | How the categorical condition enters the model, so that the age term is the age slope averaged over conditions (not the slope on flat ground only). |
| **Holm** | Correction for testing several models; `*_holm` columns. |
| **SPM / SnPM** | Statistical parametric mapping on whole curves (here coherence spectra); SnPM is its permutation version. |

## Where things are

| You want to... | Look at |
|---|---|
| change a parameter | `config/config_emg.m`, the only place settings live |
| see how a stage works | `Functions/<stage>/<stage main>.m` and its `*_helpers/` folder |
| read the results | `Results/h_coherence_stats_pair_phase_main/tables/CONTINUOUS_AGE_LME_TABLE.csv` and `SENSITIVITY_CONTINUOUS_AGE.csv` |
| see the figures | `Results/png_visualisation/h_coherence_stats_pair_phase_main/` |
| know how the data was recorded and why only ≥ 20 Hz | [acquisition.md](acquisition.md) |
| check that a change did not alter results | `check_against_baseline` ([reproduce.md](reproduce.md#checking-a-rerun)) |
| check the code | `check_repo` |
