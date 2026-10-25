function g_emg_emg_wavelet_coherence()
% G_EMG_EMG_WAVELET_COHERENCE  Stage g: wavelet coherence for every included
% muscle pair.
%
% Reads   mat_final_paired_signals/FINAL_PAIRED_SIGNALS.mat and _<BAND>.mat (stage f)
% Writes  mat_coherence_data/COHERENCE_RESULTS_<DATASET>.mat,
%         Results/g_emg_emg_wavelet_coherence/COHERENCE_SUMMARY_TABLE_<DATASET>.csv,
%         optional QC and group figures
% Settings  C.g_coherence (config/config_emg.m)
%
% Runs once per dataset in C.g_coherence.io.input_sets: FULL (all bands, the
% overall cycle mask) and one per band (that band's cycle mask). For each
% pair, each stretch of continuous recording is wavelet-transformed
% (Morlet), each kept cycle is interpolated to 0-100% of the gait cycle, and
% coherence is computed from cycle-averaged spectra. "equalized" coherence
% uses the same number of cycles (N_common) for every signal of a pair.
%
% Steps: g_run_dataset (one dataset) and g_compute_pair_coherence (one pair),
% in Functions/g_coherence/g_coherence_steps/.

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.coherence));
    addpath(genpath(C.paths.toolboxes.wtc));

    inputSets = C.g_coherence.io.input_sets;

    %% ===================== WAVELET / COI RECAP =====================

    print_wavelet_coi_recap(C.g_coherence.params);

    %% ==================== ONE DATASET AT A TIME =====================

    for iSet = 1:numel(inputSets)
        g_run_dataset(inputSets{iSet}, C);
    end
end
