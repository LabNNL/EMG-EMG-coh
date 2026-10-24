# EMG acquisition

What the recordings themselves say about how they were made. Nothing in this
project documented the hardware, so this was read back out of the `.c3d`
files. Regenerate any of it with:

```matlab
startup
audit_c3d_acquisition          % ~240 files, one per participant x condition
```

which writes `Results/acquisition_audit/` and two figures under
`Results/png_visualisation/acquisition_audit/`.

Statements below are grouped by how firm they are. The distinction matters:
some of this is written in the files, some is measured from the signals, and
some is an argument that could be wrong.

---

## Recorded in the files

Verified across **all 2379 `.c3d` files** in `Reworked_Data/`, 80 participants,
three conditions.

| | |
|---|---|
| Acquisition software | Vicon Nexus (`MANUFACTURER/COMPANY` = Vicon) |
| Nexus version | `2.14.0.139696h` for 2291 files; `2.8.1.111866h` for 88 |
| Analog sample rate | **2000 Hz**, every file without exception |
| Point (camera) rate | 100 Hz, so 20 analog samples per video frame |
| EMG sensors | 16 |
| Analog channels | 224 (242 where force plates are present) |
| Marker set | PlugInGait FullBody |

Four Vicon device plugins supply the analog channels, all at firmware 2.2.0:

| Plugin | Channels | Units |
|---|---|---|
| `Delsys EMG 2.2.0` | 16, `Sensor N.EMGN` | V |
| `Delsys IM EMG 2.2.0` | 16, `Sensor N.IM EMGN` | V |
| `Delsys Accelerometers 2.2.0` | ACC X/Y/Z | mm/s² (see note) |
| `Delsys IM AUX 2.2.0` | ACC, GYRO, MAG X/Y/Z | — |

So the sensors are Delsys Trigno-family with an inertial measurement unit.

### Three configuration signatures, none affecting EMG

| | files | difference |
|---|---|---|
| 1 | 1843 | the baseline above |
| 2 | 88 | older Nexus build 2.8.1 — **CTL_08, CTL_30, CTL_32** (CTL_30 and CTL_32 are mixed: 29 of 30 trials each) |
| 3 | 448 | three AMTI force plates present, 242 channels — **CTL_57-62, 69-76, 81** |

The EMG chain is **identical in all three**: same rate, same 16+16 channels,
same plugin version. The force plates add 18 channels (3 plates x Fx,Fy,Fz,
Mx,My,Mz) that nothing in this pipeline reads.

---

## Measured from the signals

| Finding | Evidence | Confidence |
|---|---|---|
| EMG input range **±11 mV** | Peaks reach 11.157 mV; 42 of 240 files exceed 5.5 mV, which is impossible on the ±5.5 mV setting | High |
| Accelerometer range **2 g** | Saturates at exactly 20.227 (= 2.063 g) in every file. An identical maximum across files is a clipping rail, not coincidence | High |
| Gyroscope and magnetometer **unused** | All 48 GYRO and 48 MAG channels are identically zero in every file | High |
| `EMG` and `IM EMG` are near-duplicates | Max difference 1.5–4.5 µV against signals of ~190 µV std. Same sensors through two plugin paths | High |
| **35 EMG channels hit the ±11 mV rail** | Clipping does occur. Stage d_b rejects bursts above 8 mV peak-to-peak, so these should already be excluded — worth confirming if you revisit artifact QC | High |

`Metadata/Association.m` maps all 80 participants to the plain
`Sensor_N_EMGN` family, so the pipeline uses the right channels and the
duplicate `IM EMG` copies cost nothing. The other 208 channels are ignored.

### Note on the accelerometer units

The c3d labels ACC as `mm/s²`, but the saturation value of 20.227 only makes
sense as m/s² (2.06 g). Treat the unit string as unreliable if you ever use
those channels.

---

## Inferred, and the reasoning

**Sensor bandwidth: probably 10–850 Hz rather than 20–450 Hz.**

The mean EMG spectrum (640 channel-spectra) peaks around 15–18 Hz and is only
about 4 dB below that peak at 8 Hz. A 20 Hz hardware high-pass would put 8 Hz
far further down — more than an octave below the corner. Substantial content
at 8–15 Hz therefore argues for the 10 Hz option.

This is an argument, not a measurement, and it has a real weakness: the
high-frequency end of the same spectrum steepens around 400–500 Hz, which
would be more consistent with a 450 Hz low-pass. That steepening is equally
explainable by surface EMG simply having little power up there, so it does not
settle the question either way. The low-frequency evidence is the more
diagnostic of the two, because the signal there is dominated by movement
artifact that the hardware either passes or does not.

**Auxiliary channel rate: 74 Hz.** This one is solid. The mean EMG spectrum
carries a comb of narrow lines at exact multiples of **74.22 Hz** — measured
at 4x, 5x, 6x, 7x, 8x, 9x, 10x, 12x and 13x (296, 371, 444, 519, 593, 666,
741, 889 and 963 Hz), spacings 73.7-74.2 Hz. That is the sensor streaming its
auxiliary channels at a lower rate than the EMG and leaking into the EMG
signal. 74 Hz is exactly the figure Delsys mode strings quote for skin check
and accelerometer, so the mode in use has a 74 Hz auxiliary stream.

All of those lines sit above 296 Hz, far outside the 8-60 Hz analysis band,
and they are 1.6-10.7 dB above the local baseline deep in the noise floor.
They do not affect the coherence results.

**Native sample rate: unknown, and do not quote one.** An earlier reading of
these files appeared to show content stopping at 963 Hz, which is exactly
half of 1926 Hz — a documented Delsys transmission rate — and that looked
like evidence of interpolation from 1926 Hz up to 2000 Hz. It is not. The
963 Hz feature is simply the **13th harmonic of the 74 Hz comb**. With that
explained away, nothing remains: the detected noise-floor onset moves by tens
of Hz with the sample and the threshold, and the whole region has a dynamic
range of about 1.4 dB. Nothing in these files records the native rate.

---

## Not known from the files

- Whether the Delsys "skin check" channel was enabled.
- Sensor firmware beyond the Vicon plugin version, and the sensor model
  (Trigno Avanti vs Trigno IM).
- The exact sensor mode string.

The definitive record is the Vicon Delsys plugin configuration on the
acquisition PC, which is not in this repository. If you can get it, that file
lists the mode in the form
`EMG raw (NNNN Hz), skin check (74 Hz), ACC Ng (74 Hz), +/-N mV, LO-HI Hz`,
and would settle the bandwidth and native rate directly. Ask for the
configuration as it was **at the time of recording** — a current export may
have been changed since.

---

## What this means for the analysis

**Use 2000 Hz.** That is the spacing of the stored samples and what
`C.general.fs_emg` is set to. No native rate is recoverable from these files,
and in any case it would only concern frequencies far above the 60 Hz ceiling
of this analysis.

### Filters and the Alpha band

Two filters act on the EMG before coherence is computed, and both have their
low corner close to the bottom of the Alpha band (8–12 Hz):

- **On the sensor**, the Delsys mode's high-pass, either 10 Hz or 20 Hz (the
  data cannot settle which, see above).
- **In the pipeline**, stage b's band-pass, `C.b_preproc.bandpass = [8 450]`:
  a 4th-order Butterworth with its −3 dB point at exactly 8 Hz, applied with
  `filtfilt` (so twice) in `pp_preprocess_signal.m`. Its output is what stages
  c, d_b, f and g all work on.

**In short: they reduce Alpha power, they do not bias Alpha coherence, and
neither should change.**

#### A filter fades a band out, it does not delete it

A filter corner is where the signal is reduced by about 30% in amplitude, not
a wall. Below the corner the signal shrinks gradually. Amplitude kept by the
pipeline's band-pass after `filtfilt`:

| Frequency | 4 Hz | 8 Hz | 10 Hz | 12 Hz | 15 Hz | 20 Hz |
|---|---|---|---|---|---|---|
| gain | −25.0 dB | −6.0 dB | −2.9 dB | −1.5 dB | −0.6 dB | −0.2 dB |
| amplitude kept | ~6% | ~50% | ~72% | ~84% | ~93% | ~98% |

The sensor filter did not delete 8 Hz either. The audit spectra are computed
on the raw `.c3d` signals — after the Delsys filter, before the pipeline's —
and there 8 Hz is only about 4–6 dB below the strongest frequencies, against a
numerical floor about 58 dB down. A deleted band would sit at that floor.

#### Why reducing a band does not change its coherence

Coherence measures how consistently the two signals move together at each
frequency, across cycles. It is in effect a correlation coefficient computed
frequency by frequency, and a correlation does not change when a variable is
scaled: multiply one variable by 0.5 and both its covariance with the other
and its own standard deviation halve, leaving the ratio as it was.

Formally, coherence is |Sxy|² / (Sxx·Syy). If the two channels pass through
filters H₁ and H₂, the cross-spectrum gains |H₁|²|H₂|² and the auto-spectra
gain |H₁|² and |H₂|², which cancel. This holds even if the two filters
differ, so small sensor-to-sensor differences in the hardware filter do not
matter either. A filter also shifts the phase, but by the same amount in every
cycle, which leaves the consistency of the relationship unchanged.

Checked on four real pairs from `CTL_01_Plat_03.c3d`, using `mscohere` (1 s
Hann windows, 50% overlap) on the raw signals and on the same signals passed
through the pipeline's band-pass. Mean coherence over each band:

| Pair | Alpha raw | Alpha band-passed | Beta raw | Beta band-passed |
|---|---|---|---|---|
| TAprox–TAdist right | 0.755 | 0.764 | 0.492 | 0.492 |
| TAprox–TAdist left | 0.107 | 0.104 | 0.369 | 0.369 |
| SOL–GM right | 0.217 | 0.220 | 0.217 | 0.216 |
| SOL–GM left | 0.306 | 0.313 | 0.244 | 0.244 |

Alpha moves by at most 0.01, in both directions; Beta does not move at all to
three decimals. The small Alpha differences come from strong sub-8 Hz content
in the raw signal leaking into the neighbouring bins, which the band-pass
removes — not from the attenuation itself.

#### Where it would break

The argument assumes the band stays well above noise added *after* the filter
(digitisation, the 74 Hz comb, resampling). Shrink a frequency into that noise
and coherence there becomes a correlation of noise, falling towards zero. That
is visible at 4 Hz, where the band-pass keeps only ~6% and coherence in the
check above fell from 0.38 to 0.25. Alpha is nowhere near this: after both
filters it sits about 55 dB above the numerical floor. This is also why the
unresolved 10 Hz vs 20 Hz question about the sensor filter does not matter for
the coherence results.

#### What the band-pass does still affect

- **Alpha power.** Anything computed on power — the `Alpha_LogPower`
  covariate, the POI power diagnostics — is reduced by up to 6 dB from the
  band-pass alone, plus whatever the sensor filter removed. Do not interpret
  absolute Alpha power. The power-covariate models are currently off
  (`run_power_control_models = false`, `continuous_age_include_power = false`),
  so no present result depends on it.
- **Leakage into Alpha.** Below 8 Hz the raw EMG carries strong movement
  artifact. The wavelet at 8 Hz also picks up energy from about 6–10 Hz, so
  without the high-pass that artifact would leak into the lowest Alpha bins.
  Being shared between neighbouring sensors and locked to the gait cycle, it
  would inflate coherence. The 8 Hz corner works against this.
- **Which data is analysed.** Burst detection (stage c) and the rule-based QC
  (stage d_b) run on the band-passed signal, so its settings decide which
  bursts and cycles survive into stage f.

#### Should the band-pass change?

No. Its gain has no effect on coherence; lowering the corner would let more
sub-8 Hz artifact leak into Alpha; raising it would discard signal; and either
would change which cycles are selected, and so every finalised result. If the
pipeline is ever rebuilt from scratch, a corner at about 5–6 Hz would put the
whole analysis band inside the passband, which is tidier practice — but it
would change Alpha power, not Alpha coherence.

### Signal available in each band

How much raw signal each band carries turns out to depend on how you average,
so the tool reports both. Typical values (dB relative to the strongest band):

| Band | median | mean |
|---|---|---|
| Alpha 8–12 Hz | −3.3 | −3.0 |
| Beta 13–30 Hz | 0 | 0 |
| Gamma 31–60 Hz | −1.0 | −6.8 |

The median describes a typical channel-trial. The mean is pulled around by a
minority of trials with extreme power, and the two diverge most in Gamma — so
Gamma's apparent weakness under a linear mean comes from a few outlying
trials, not from what a normal recording looks like.

**Do not rank the bands from this.** The ordering flips with the estimator,
and the curve mixes the sensor's high-pass with the EMG's own spectrum, which
a power spectrum cannot separate. An earlier draft of this document asserted
first that Alpha and then that Gamma was "the weakest band"; neither claim
was supportable.

### What the coherence results actually show

This is the evidence that settles whether a band is usable, and it is stable.
Mean `AUC_norm` from `DESCRIPTIVE_TABLE_ALL.csv`:

| Pair | Alpha | Beta | Gamma |
|---|---|---|---|
| SOL_GM | 0.163 | 0.144 | 0.172 |
| TAprox_TAdist | 0.213 | 0.204 | 0.215 |

The three bands come out at comparable magnitudes. And from
`CONTINUOUS_AGE_LME_TABLE__equalized_poi_auc_nocyclecov.csv`, Alpha carries
some of the strongest effects in the study:

| Pair | Effect | Alpha | Beta | Gamma |
|---|---|---|---|---|
| SOL_GM | age | **0.0012** | **0.00025** | 0.18 |
| TAprox_TAdist | age | 0.13 | 0.32 | **0.0021** |
| TAprox_TAdist | condition | **0.043** | 0.15 | **0.00016** |

**There is no case for discarding Alpha.** Doing so would throw away the
SOL_GM age effect at p = 0.0012.

### The caveat that does apply to Alpha

It runs the other way from an SNR argument. During walking, 8–12 Hz content
is not purely neural: it also contains movement artifact (footstrike
transients, cable and skin motion) and high-order stride harmonics. Anything
of that sort which is **shared between the two sensors on a limb, and locked
to the gait cycle, inflates coherence** rather than suppressing it, because
this pipeline interpolates each cycle to a common length and averages spectra
across cycles — exactly the operation that rewards cycle-locked components.

So the risk in the Alpha band is **false positives, not false negatives**, and
it applies most to the lowest frequencies in the band.

This is testable with machinery the pipeline already has.
`C.g_coherence.params.surrogate_delta` shuffles the cycle order of one signal
and subtracts the 95th percentile of the resulting null, which destroys
cycle-locked common modulation while preserving within-cycle structure. It is
currently `enable = false`. Turning it on for the Alpha band would show
whether alpha coherence survives once cycle-locked commonality is removed. If
it does, the artifact concern is answered; if it collapses, that is worth
knowing before the results are written up.
