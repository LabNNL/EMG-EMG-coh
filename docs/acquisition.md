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
`C.general.fs_emg` is set to. The possible 1926 Hz native rate would only mean
that samples above ~963 Hz carry no information, which is irrelevant to an
analysis that stops at 60 Hz.

**Alpha is the weakest of the three bands.** The Alpha band (8–12 Hz) sits on
the rising flank of the EMG spectrum, roughly 1–4 dB below its peak, whereas
Beta and Gamma sit on the broad plateau and upper slope. Part of that deficit
is the sensor high-pass and part is the physiology; they cannot be separated
from a power spectrum. Either way the signal-to-noise ratio is lower there,
and since coherence is biased downward by noise, **alpha-band coherence is
systematically less reliable than beta or gamma**. This belongs in the
limitations rather than being discovered later.

A shared linear filter on both channels of a pair largely cancels in the
coherence estimate, so this is an SNR argument, not a claim that the filter
itself distorts coherence.
