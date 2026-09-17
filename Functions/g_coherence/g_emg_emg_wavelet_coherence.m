%% g_emg_emg_wavelet_coherence.m
% Compute EMG-EMG wavelet coherence from final paired cleaned signals
%
% INPUT:
%   FINAL_PAIRED_SIGNALS.mat
%
% OUTPUT:
%   COHERENCE_RESULTS.mat
%   optional plots per subject/condition/leg/pair
%
% Assumption:
%   FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName) contains:
%       - final_concatenated_signal_1
%       - final_concatenated_signal_2
%       - final_cycle_segments_table
%       - valid_cycle_numbers
%       - fs
%       - included_after_crosstalk
%       - muscles
%
% Inspired by the old coherence script:
%   - wavelet transform
%   - cycle-by-cycle interpolation to 1000 samples
%   - mean auto spectra and cross spectrum
%   - coherence map
% But adapted to the cleaned final paired signals pipeline.

function g_emg_emg_wavelet_coherence()

    clc; clear; close all;

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.coherence));
    addpath(genpath(C.paths.toolboxes.wtc));

    IO  = C.g_coherence.io;
    W   = C.g_coherence.params;
    PL  = C.g_coherence.plot;
    GP  = C.g_coherence.group_plot;
    FP  = C.g_coherence.final_plot;

    bandNames = fieldnames(W.FreqBands);
    allMins = zeros(numel(bandNames),1);
    allMaxs = zeros(numel(bandNames),1);
    for i = 1:numel(bandNames)
        allMins(i) = W.FreqBands.(bandNames{i})(1);
        allMaxs(i) = W.FreqBands.(bandNames{i})(2);
    end
    plot_freq_range = [min(allMins) max(allMaxs)];
    FullBandRange = [min(allMins) max(allMaxs)];

    inputSets = IO.input_sets;

    %% ===================== WAVELET / COI RECAP =====================

    print_wavelet_coi_recap(W);

    %% ==================== MAIN LOOP OVER DATASETS =====================

    for iSet = 1:numel(inputSets)

        % ---------------- Skip disabled datasets ----------------
        if ~inputSets{iSet}.enabled
            continue;
        end

        datasetName = upper(string(inputSets{iSet}.name));
        inFile      = inputSets{iSet}.mat_file;

        fprintf('\n====================================================\n');
        fprintf('Running coherence for dataset: %s\n', datasetName);
        fprintf('Input file: %s\n', inFile);
        fprintf('====================================================\n');

        if ~isfile(inFile)
            warning('Input file not found for dataset %s:\n%s', datasetName, inFile);
            continue;
        end

        % ---------------- Dataset-specific settings ----------------
        DS = get_dataset_specific_coherence_settings(datasetName, W, GP);
        datasetDirs = make_dataset_output_dirs(datasetName, IO, PL, GP, FP, W);

        if ~exist(IO.out_dir, 'dir')
            mkdir(IO.out_dir);
        end
        if ~exist(IO.summary_csv_dir, 'dir')
            mkdir(IO.summary_csv_dir);
        end
        datasetOutMat     = fullfile(IO.out_dir, sprintf('COHERENCE_RESULTS_%s.mat', datasetName));
        datasetSummaryCsv = fullfile(IO.summary_csv_dir, sprintf('COHERENCE_SUMMARY_TABLE_%s.csv', datasetName));

        if isfield(PL, 'padding_qc') && isfield(PL.padding_qc, 'dir')
            datasetDirs.paddingQcDir = fullfile(PL.padding_qc.dir, char(datasetName));
            if ~exist(datasetDirs.paddingQcDir, 'dir')
                mkdir(datasetDirs.paddingQcDir);
            end
        end

        % ---------------- Load paired signals ----------------
        FINAL_PAIRED_SIGNALS = load_final_paired_signals_file(inFile);

        % ---------------- Cycle equalization settings ----------------
        EQ = W.cycle_equalization;

        % Pair-specific common cycle counts will be computed on demand
        % and cached here.
        N_common_by_pair = struct();

        % ---------------- Initialize dataset outputs ----------------
        COHERENCE_RESULTS = struct();
        DIAG_ROWS = {};
        diag_i = 0;

        COI_EXAMPLES = struct( 'subject', {}, 'condition', {}, 'leg', {}, 'pair_name', {}, 'muscle1_name', {}, 'muscle2_name', {}, 'x1', {}, 'x2', {}, 'fs', {});

        QCP = PL.concat_signal_qc;
        CONCAT_SIGNAL_QC = struct( 'subject', {}, 'condition', {}, 'leg', {}, 'pair_name', {}, 'dataset_name', {}, 'muscles', {}, 'x1', {}, 'x2', {}, 'fs', {}, 'Tseg', {}, 'Freq', {}, 'TFR1', {}, 'TFR2', {}, 'coi1', {}, 'coi2', {}, 'padding_mode', {});
        n_concat_saved = 0;

        % ---------- Before-vs-after edge-cycle removal QC accumulator ----------
        EdgeCycleQC = struct();
        EdgeCycleQC.sum_before = [];
        EdgeCycleQC.sum_after  = [];
        EdgeCycleQC.Freq = [];
        EdgeCycleQC.n = 0;
        EdgeCycleQC.subjects = strings(0,1);

        plotTracker = struct();

        plotTracker.individual.count = 0;
        plotTracker.individual.subjects = strings(0,1);

        plotTracker.before_after.count = 0;
        plotTracker.before_after.subjects = strings(0,1);

        plotTracker.outer_cycle_diag.count = 0;
        plotTracker.outer_cycle_diag.subjects = strings(0,1);

        plotTracker.padding_qc.count = 0;
        plotTracker.padding_qc.subjects = strings(0,1);

        % ============================================================
        % 1) COMPUTE COHERENCE RESULTS
        % ============================================================

        subjects = fieldnames(FINAL_PAIRED_SIGNALS);

        for iS = 1:numel(subjects)
            subjID = subjects{iS};
            fprintf('\n=== Coherence: %s ===\n', subjID);

            conds = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));
            for ic = 1:numel(conds)
                cond = conds{ic};

                legs = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));
                for il = 1:numel(legs)
                    leg = legs{il};

                    pairNames = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));
                    for ip = 1:numel(pairNames)
                        pairName = pairNames{ip};

                        % ---------- Pair-specific cycle equalization ----------
                        N_common_equalized = NaN;

                        if isfield(EQ, 'enable') && EQ.enable

                            pairKey = matlab.lang.makeValidName(pairName);

                            % Compute only once per pair, then reuse for every subject/condition/leg
                            if ~isfield(N_common_by_pair, pairKey)

                                switch lower(string(EQ.mode))

                                    case "global_min"

                                        N_common_by_pair.(pairKey) = ...
                                            get_min_analysis_cycles_in_dataset( ...
                                                FINAL_PAIRED_SIGNALS, W, pairName);

                                    case "manual"

                                        if isempty(EQ.manual_n_cycles)
                                            error(['cycle_equalization.mode = "manual" ' ...
                                                'but manual_n_cycles is empty.']);
                                        end

                                        N_common_by_pair.(pairKey) = EQ.manual_n_cycles;

                                    otherwise
                                        error('Unknown cycle_equalization.mode: %s', ...
                                            string(EQ.mode));
                                end

                                fprintf('\n=== Cycle equalization: %s | %s ===\n', ...
                                    datasetName, pairName);
                                fprintf('Mode: %s\n', string(EQ.mode));
                                fprintf('Selection: %s\n', string(EQ.selection));
                                fprintf('N_common_equalized = %d cycles\n', ...
                                    N_common_by_pair.(pairKey));
                            end

                            N_common_equalized = N_common_by_pair.(pairKey);
                        end

                        P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                        P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                        % ---------- Basic inclusion check ----------
                        if ~isfield(P, 'included_after_crosstalk') || ~P.included_after_crosstalk
                            continue;
                        end

                        x1 = P.final_concatenated_signal_1(:);
                        x2 = P.final_concatenated_signal_2(:);
                        fs = P.fs;
                        Tseg = P.final_cycle_segments_table;

                        if isempty(x1) || isempty(x2) || isempty(Tseg)
                            warning('Empty signal or segments for %s | %s | %s | %s. Skipping.', subjID, cond, leg, pairName);
                            continue;
                        end

                        mus1 = P.muscles{1};
                        mus2 = P.muscles{2};

                        % ---------- Build analysis cycle mask ----------
                        [analysis_cycle_mask, mask_real_outer, mask_analysis_outer, mask_analysis_middle] = build_analysis_cycle_masks(Tseg, W, subjID, cond, leg, pairName);

                        % Mask using all cycles, for QC only
                        all_cycle_mask = true(height(Tseg),1);

                        if isempty(analysis_cycle_mask)
                            continue;
                        end

                        % ---------- Build equalized cycle mask for sig_equalized ----------
                        analysis_cycle_mask_equalized = [];

                        if isfield(W, 'cycle_equalization') && isfield(W.cycle_equalization, 'enable') && W.cycle_equalization.enable

                            analysis_cycle_mask_equalized = select_equalized_cycle_mask( analysis_cycle_mask, N_common_equalized, W.cycle_equalization, subjID, cond, leg, pairName);
                        end

                        % ---------- Toe-off summary ----------
                        [toeoff_percentages, toeoff_percent, toeoff_index, stance_phase_indices, swing_phase_indices] = compute_toeoff_segmentation(P, Tseg, W);

                        % ---------- Padding + wavelet ----------
                        [x1_for_wav, idx_orig_1, padInfo1] = build_padded_signal_for_wavelet(x1, Tseg, W.padding, 1);
                        [x2_for_wav, idx_orig_2, padInfo2] = build_padded_signal_for_wavelet(x2, Tseg, W.padding, 2);

                        Args = WaveletParameters( DS.FreqMin_this, DS.FreqMax_this, W.Resolution, W.WaveNumber, fs);

                        [TFR1_pad, period, ~, coi1_pad] = wavelet( x1_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

                        [TFR2_pad, ~, ~, coi2_pad] = wavelet( x2_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

                        TFR1 = TFR1_pad(:, idx_orig_1);
                        TFR2 = TFR2_pad(:, idx_orig_2);

                        coi1 = coi1_pad(idx_orig_1);
                        coi2 = coi2_pad(idx_orig_2);

                        Freq = 1 ./ period;
                        nFreq = numel(Freq);

                        % ---------- Optional padding-vs-no-padding wavelet QC ----------
                        if PL.enable && isfield(PL, 'padding_qc') && PL.padding_qc.enable

                            [doPlot, plotTracker.padding_qc] = should_make_limited_subject_plot( subjID, plotTracker.padding_qc, PL.padding_qc.max_plots);

                            if doPlot
                                refPadCfg = W.padding;
                                refPadCfg.mode = PL.padding_qc.reference_mode;

                                switch lower(string(PL.padding_qc.which_signals))

                                    case "signal1"
                                        outFile = fullfile(datasetDirs.paddingQcDir, sprintf('PADDING_QC__%s__%s__%s__%s__signal1.png', subjID, cond, leg, pairName));

                                        plot_wavelet_padding_comparison( x1, fs, Tseg, 1, W, refPadCfg, W.padding, sprintf('Reference: %s', refPadCfg.mode), sprintf('Current: %s', W.padding.mode), outFile, DS.plot_freq_range_this);

                                    case "signal2"
                                        outFile = fullfile(datasetDirs.paddingQcDir, sprintf('PADDING_QC__%s__%s__%s__%s__signal2.png', subjID, cond, leg, pairName));

                                        plot_wavelet_padding_comparison( x2, fs, Tseg, 2, W, refPadCfg, W.padding, sprintf('Reference: %s', refPadCfg.mode), sprintf('Current: %s', W.padding.mode), outFile, DS.plot_freq_range_this);

                                    case "both"
                                        outFile1 = fullfile(datasetDirs.paddingQcDir, sprintf('PADDING_QC__%s__%s__%s__%s__signal1.png', subjID, cond, leg, pairName));

                                        plot_wavelet_padding_comparison( x1, fs, Tseg, 1, W, refPadCfg, W.padding, sprintf('Reference: %s', refPadCfg.mode), sprintf('Current: %s', W.padding.mode), outFile1, DS.plot_freq_range_this);

                                        outFile2 = fullfile(datasetDirs.paddingQcDir, sprintf('PADDING_QC__%s__%s__%s__%s__signal2.png', subjID, cond, leg, pairName));

                                        plot_wavelet_padding_comparison( x2, fs, Tseg, 2, W, refPadCfg, W.padding, sprintf('Reference: %s', refPadCfg.mode), sprintf('Current: %s', W.padding.mode), outFile2, DS.plot_freq_range_this);

                                    otherwise
                                        warning('Unknown PL.padding_qc.which_signals: %s', string(PL.padding_qc.which_signals));
                                end
                            end
                        end

                        % ---------- Optional storage for concat-signal QC ----------
                        if should_save_concat_signal_qc(QCP, subjID, cond, leg, pairName, n_concat_saved)
                            n_concat_saved = n_concat_saved + 1;

                            CONCAT_SIGNAL_QC(n_concat_saved).subject = string(subjID);
                            CONCAT_SIGNAL_QC(n_concat_saved).condition = string(cond);
                            CONCAT_SIGNAL_QC(n_concat_saved).leg = string(leg);
                            CONCAT_SIGNAL_QC(n_concat_saved).pair_name = string(pairName);
                            CONCAT_SIGNAL_QC(n_concat_saved).dataset_name = string(datasetName);
                            CONCAT_SIGNAL_QC(n_concat_saved).muscles = {mus1, mus2};

                            CONCAT_SIGNAL_QC(n_concat_saved).x1 = x1;
                            CONCAT_SIGNAL_QC(n_concat_saved).x2 = x2;
                            CONCAT_SIGNAL_QC(n_concat_saved).fs = fs;
                            CONCAT_SIGNAL_QC(n_concat_saved).Tseg = Tseg;

                            CONCAT_SIGNAL_QC(n_concat_saved).Freq = Freq;
                            CONCAT_SIGNAL_QC(n_concat_saved).TFR1 = TFR1;
                            CONCAT_SIGNAL_QC(n_concat_saved).TFR2 = TFR2;
                            CONCAT_SIGNAL_QC(n_concat_saved).coi1 = coi1;
                            CONCAT_SIGNAL_QC(n_concat_saved).coi2 = coi2;
                            CONCAT_SIGNAL_QC(n_concat_saved).padding_mode = string(W.padding.mode);
                        end

                        % ---------- Optional storage for COI examples ----------
                        if isfield(PL, 'coi_examples') && PL.coi_examples.enable
                            ii = numel(COI_EXAMPLES) + 1;
                            COI_EXAMPLES(ii).subject = string(subjID);
                            COI_EXAMPLES(ii).condition = string(cond);
                            COI_EXAMPLES(ii).leg = string(leg);
                            COI_EXAMPLES(ii).pair_name = string(pairName);
                            COI_EXAMPLES(ii).muscle1_name = string(mus1);
                            COI_EXAMPLES(ii).muscle2_name = string(mus2);
                            COI_EXAMPLES(ii).x1 = x1;
                            COI_EXAMPLES(ii).x2 = x2;
                            COI_EXAMPLES(ii).fs = fs;
                        end

                        % ====================================================
                        % CORE COHERENCE COMPUTATION
                        % ====================================================
                        core = compute_cycle_interpolated_coherence_core( TFR1, TFR2, coi1, coi2, Tseg, Freq, analysis_cycle_mask, mask_real_outer, mask_analysis_outer, mask_analysis_middle, W, DS);

                        % ---------- QC version: same computation but BEFORE removing edge cycles ----------
                        core_allcycles = [];

                        if PL.enable && isfield(PL, 'edge_cycle_compare') && PL.edge_cycle_compare.enable
                            core_allcycles = compute_cycle_interpolated_coherence_core( TFR1, TFR2, coi1, coi2, Tseg, Freq, all_cycle_mask, mask_real_outer, mask_analysis_outer, mask_analysis_middle, W, DS);
                        end

                        if core.Ncycle == 0
                            warning('No valid cycles after interpolation for %s | %s | %s | %s', subjID, cond, leg, pairName);
                            continue;
                        end

                        % ---------- Equalized core for sig_equalized ----------
                        core_equalized = [];
                        Coherence_sig_equalized = [];
                        seuil_equalized = NaN;

                        if isfield(W, 'cycle_equalization') && isfield(W.cycle_equalization, 'enable') && W.cycle_equalization.enable && ~isempty(analysis_cycle_mask_equalized) && sum(analysis_cycle_mask_equalized) > 0

                            core_equalized = compute_cycle_interpolated_coherence_core( TFR1, TFR2, coi1, coi2, Tseg, Freq, analysis_cycle_mask_equalized, mask_real_outer, mask_analysis_outer, mask_analysis_middle, W, DS);

                            if core_equalized.Ncycle > 1
                                seuil_equalized = 1 - W.alpha^(1/(core_equalized.Ncycle - 1));

                                Coherence_sig_equalized = core_equalized.Coherence - seuil_equalized;
                                Coherence_sig_equalized(Coherence_sig_equalized < 0) = 0;
                            else
                                Coherence_sig_equalized = nan(size(core.Coherence));
                            end
                        end

                        % ---------- Common significance threshold across all signals (for fair comparison) ----------

                        seuil_common = NaN;

                        if isfield(W, 'cycle_equalization') && W.cycle_equalization.enable
                            if N_common_equalized > 1
                                seuil_common = 1 - W.alpha^(1/(N_common_equalized - 1));
                            else
                                warning('N_common_equalized <= 1. Cannot compute common significance threshold.');
                            end

                            %fprintf('Common significance threshold = %.6f\n', seuil_common);
                        end

                        % ---------- Significance threshold ----------
                        if core.Ncycle > 1
                            seuil = 1 - W.alpha^(1/(core.Ncycle - 1));
                        else
                            seuil = NaN;
                        end

                        if isnan(seuil)
                            Coherence_sig = nan(size(core.Coherence));
                        else
                            Coherence_sig = core.Coherence - seuil;
                            Coherence_sig(Coherence_sig < 0) = 0;
                        end

                        % ---------- Bokil-style z-normalized (Cao et al 2024, https://www.sciencedirect.com/science/article/pii/S0969996124002894) coherence ----------
                        Coherence_zcoh_bokil = [];

                        if isfield(W, 'zcoh_bokil') && isfield(W.zcoh_bokil, 'enable') && W.zcoh_bokil.enable

                            Coherence_zcoh_bokil = compute_bokil_zcoh( core.Coherence, core.Ncycle, W.zcoh_bokil);
                        end

                        % ---------- Cycle-bias-corrected coherence using formula derived from simulations ----------
                        Coherence_cycle_bias_corrected = [];

                        if isfield(W, 'cycle_bias_correction') && isfield(W.cycle_bias_correction, 'enable') && W.cycle_bias_correction.enable

                            Coherence_cycle_bias_corrected = apply_cycle_bias_correction( core.Coherence, core.Ncycle, W.cycle_bias_correction);
                        end

                        % ---------- Common-threshold significant coherence ----------
                        Coherence_sig_common_threshold = [];
                        seuil_common_used = seuil_common;

                        if ~isnan(seuil_common_used)
                            Coherence_sig_common_threshold = core.Coherence - seuil_common_used;
                            Coherence_sig_common_threshold(Coherence_sig_common_threshold < 0) = 0;
                        end

                        % ---------- Thresholded version for the all-cycles QC map ----------
                        Coherence_allcycles_sig = [];

                        if ~isempty(core_allcycles)
                            if core_allcycles.Ncycle > 1
                                seuil_all = 1 - W.alpha^(1/(core_allcycles.Ncycle - 1));
                            else
                                seuil_all = NaN;
                            end

                            if isnan(seuil_all)
                                Coherence_allcycles_sig = nan(size(core_allcycles.Coherence));
                            else
                                Coherence_allcycles_sig = core_allcycles.Coherence - seuil_all;
                                Coherence_allcycles_sig(Coherence_allcycles_sig < 0) = 0;
                            end
                        end

                        % ---------- Surrogate / randomized coherence ---------- (very expensive, so run if you have the time)
                        Coherence_surrogate_threshold = [];
                        Coherence_surrogate_delta = [];

                        if isfield(W, 'surrogate_delta') && isfield(W.surrogate_delta, 'enable') && W.surrogate_delta.enable

                            [Coherence_surrogate_threshold, Coherence_surrogate_delta] = compute_surrogate_delta_coherence( TFR1, TFR2, Tseg, Freq, analysis_cycle_mask, W, W.surrogate_delta, subjID, cond, leg, pairName);
                        end

                        % ---------- Accumulate pooled before-vs-after edge-cycle removal QC ----------
                        if PL.enable && isfield(PL, 'edge_cycle_compare') && PL.edge_cycle_compare.enable

                            [useForEdgeCycleQC, EdgeCycleQC] = should_make_limited_subject_plot( subjID, EdgeCycleQC, PL.edge_cycle_compare.max_signals);

                            if useForEdgeCycleQC && ~isempty(core_allcycles)

                                if PL.edge_cycle_compare.use_significant
                                    map_before = Coherence_allcycles_sig;
                                    map_after  = Coherence_sig;
                                else
                                    map_before = core_allcycles.Coherence;
                                    map_after  = core.Coherence;
                                end

                                if isempty(EdgeCycleQC.sum_before)
                                    EdgeCycleQC.sum_before = zeros(size(map_before));
                                    EdgeCycleQC.sum_after  = zeros(size(map_after));
                                    EdgeCycleQC.Freq = Freq(:);
                                end

                                EdgeCycleQC.sum_before = EdgeCycleQC.sum_before + map_before;
                                EdgeCycleQC.sum_after  = EdgeCycleQC.sum_after  + map_after;
                                EdgeCycleQC.n = EdgeCycleQC.n + 1;
                            end
                        end

                        % ---------- COI summary ----------
                        COI_period_mean = core.COI_period_accum / core.Ncycle;
                        COI_freq_mean   = core.COI_freq_accum   / core.Ncycle;

                        COI_mask = false(nFreq, W.n_interp_time);
                        for t = 1:W.n_interp_time
                            COI_mask(:,t) = Freq < COI_freq_mean(t);
                        end

                        Coherence_outsideCOI = core.Coherence;
                        Coherence_outsideCOI(COI_mask) = NaN;

                        Coherence_sig_outsideCOI = Coherence_sig;
                        Coherence_sig_outsideCOI(COI_mask) = NaN;

                        % ---------- Build result struct ----------
                        R = struct();

                        % ============================================================
                        % METADATA / IDENTIFIERS
                        % ============================================================
                        R.subject   = string(subjID);
                        R.condition = string(cond);
                        R.leg       = string(leg);
                        R.pair_name = string(pairName);
                        R.muscles   = {mus1, mus2};
                        R.fs        = fs;

                        % ============================================================
                        % CYCLE / PHASE INFORMATION
                        % ============================================================
                        R.n_cycles_used = core.Ncycle;

                        if ismember('cycle_number', Tseg.Properties.VariableNames)
                            R.valid_cycle_numbers = Tseg.cycle_number(analysis_cycle_mask);
                        else
                            R.valid_cycle_numbers = P.valid_cycle_numbers;
                        end

                        R.final_cycle_segments_table = Tseg;

                        R.ToeOffPercentPerCycle = toeoff_percentages;
                        R.ToeOffPercentMean     = toeoff_percent;
                        R.ToeOffPercent         = toeoff_percent;

                        R.StanceIndices = stance_phase_indices;
                        R.SwingIndices  = swing_phase_indices;

                        R.Freq         = Freq;
                        R.Time_percent = linspace(0, 100, W.n_interp_time);

                        % ============================================================
                        % STORED COHERENCE MATRICES
                        % ============================================================
                        R.SignificanceThreshold = seuil;

                        if W.store_raw_coherence
                            R.PowSpec_signal1 = core.PowSpec_s1;
                            R.PowSpec_signal2 = core.PowSpec_s2;
                            R.CrossSpectrumMagnitudeSquared = abs(core.CrossSpec_mean).^2;
                            R.Coherence = core.Coherence;
                        else
                            R.PowSpec_signal1 = [];
                            R.PowSpec_signal2 = [];
                            R.CrossSpectrumMagnitudeSquared = [];
                            R.Coherence = [];
                        end

                        if W.store_sig_coherence
                            R.Coherence_sig = Coherence_sig;
                        else
                            R.Coherence_sig = [];
                        end

                        if isfield(W, 'store_sig_equalized_coherence') && W.store_sig_equalized_coherence
                            R.Coherence_sig_equalized = Coherence_sig_equalized;
                        else
                            R.Coherence_sig_equalized = [];
                        end

                        if isfield(W, 'store_sig_common_threshold_coherence') && W.store_sig_common_threshold_coherence
                            R.Coherence_sig_common_threshold = Coherence_sig_common_threshold;
                        else
                            R.Coherence_sig_common_threshold = [];
                        end

                        if isfield(W, 'store_zcoh_bokil_map') && W.store_zcoh_bokil_map
                            R.Coherence_zcoh_bokil = Coherence_zcoh_bokil;
                        else
                            R.Coherence_zcoh_bokil = [];
                        end

                        if isfield(W, 'store_surrogate_delta_maps') && W.store_surrogate_delta_maps
                            R.Coherence_surrogate_threshold = Coherence_surrogate_threshold;
                            R.Coherence_surrogate_delta = Coherence_surrogate_delta;
                        else
                            R.Coherence_surrogate_threshold = [];
                            R.Coherence_surrogate_delta = [];
                        end

                        if isfield(W, 'store_equalized_coherence') && W.store_equalized_coherence
                            if ~isempty(core_equalized) && isfield(core_equalized, 'Coherence')
                                R.Coherence_equalized = core_equalized.Coherence;
                            else
                                R.Coherence_equalized = [];
                            end
                        else
                            R.Coherence_equalized = [];
                        end

                        if isfield(W, 'store_cycle_bias_corrected_coherence') && W.store_cycle_bias_corrected_coherence
                            R.Coherence_cycle_bias_corrected = Coherence_cycle_bias_corrected;
                        else
                            R.Coherence_cycle_bias_corrected = [];
                        end

                        % ============================================================
                        % CLEAN SCALAR METRICS
                        % ============================================================
                        % Saved separately for:
                        %   R.Metrics.sig.full / stance / swing / poi
                        %   R.Metrics.raw.full / stance / swing / poi
                        %   R.Metrics.sig_equalized.full / stance / swing / poi

                        metricSourcesToSave = lower(string(W.metric_sources_to_save));

                        R.Metrics = struct();
                        R.Metrics.info = struct();
                        R.Metrics.info.sources_saved = metricSourcesToSave;
                        R.Metrics.info.sig_source = "Coherence_sig";
                        R.Metrics.info.raw_source = "Coherence";
                        R.Metrics.info.sig_equalized_source = "Coherence_sig_equalized";

                        saveSig              = any(metricSourcesToSave == "sig");
                        saveRaw              = any(metricSourcesToSave == "raw");
                        saveEqualized        = any(metricSourcesToSave == "equalized");
                        saveSigEqualized     = any(metricSourcesToSave == "sig_equalized");
                        saveSigCommon        = any(metricSourcesToSave == "sig_common_threshold");
                        saveZcohBokil        = any(metricSourcesToSave == "zcoh_bokil");
                        saveSurrogateDelta   = any(metricSourcesToSave == "surrogate_delta");
                        saveCycleBiasCorrected = any(metricSourcesToSave == "cycle_bias_corrected");

                        if saveSig

                            metrics_sig = compute_coherence_scalar_metrics( Coherence_sig, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                            poiMetrics_sig = compute_pair_poi_coherence_metrics( Coherence_sig, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                            R.Metrics.sig = package_full_stance_swing_metrics(metrics_sig);
                            R.Metrics.sig.poi = package_poi_metrics(poiMetrics_sig);
                        end

                        if saveRaw

                            metrics_raw = compute_coherence_scalar_metrics( core.Coherence, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                            poiMetrics_raw = compute_pair_poi_coherence_metrics( core.Coherence, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                            R.Metrics.raw = package_full_stance_swing_metrics(metrics_raw);
                            R.Metrics.raw.poi = package_poi_metrics(poiMetrics_raw);
                        end

                        if saveSigEqualized

                            if ~isempty(Coherence_sig_equalized)

                                metrics_sig_equalized = compute_coherence_scalar_metrics( Coherence_sig_equalized, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_sig_equalized = compute_pair_poi_coherence_metrics( Coherence_sig_equalized, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.sig_equalized = package_full_stance_swing_metrics(metrics_sig_equalized);
                                R.Metrics.sig_equalized.poi = package_poi_metrics(poiMetrics_sig_equalized);

                            else
                                R.Metrics.sig_equalized = struct();
                            end
                        end

                        if saveSigCommon

                            if ~isempty(Coherence_sig_common_threshold)

                                metrics_sig_common = compute_coherence_scalar_metrics( Coherence_sig_common_threshold, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_sig_common = compute_pair_poi_coherence_metrics( Coherence_sig_common_threshold, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.sig_common_threshold = package_full_stance_swing_metrics(metrics_sig_common);
                                R.Metrics.sig_common_threshold.poi = package_poi_metrics(poiMetrics_sig_common);

                            else
                                R.Metrics.sig_common_threshold = struct();
                            end
                        end

                        if saveZcohBokil

                            if ~isempty(Coherence_zcoh_bokil)

                                metrics_zcoh_bokil = compute_coherence_scalar_metrics( Coherence_zcoh_bokil, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_zcoh_bokil = compute_pair_poi_coherence_metrics( Coherence_zcoh_bokil, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.zcoh_bokil = package_full_stance_swing_metrics(metrics_zcoh_bokil);
                                R.Metrics.zcoh_bokil.poi = package_poi_metrics(poiMetrics_zcoh_bokil);

                            else
                                R.Metrics.zcoh_bokil = struct();
                            end
                        end

                        if saveSurrogateDelta

                            if ~isempty(Coherence_surrogate_delta)

                                metrics_surrogate_delta = compute_coherence_scalar_metrics( Coherence_surrogate_delta, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_surrogate_delta = compute_pair_poi_coherence_metrics( Coherence_surrogate_delta, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.surrogate_delta = package_full_stance_swing_metrics(metrics_surrogate_delta);
                                R.Metrics.surrogate_delta.poi = package_poi_metrics(poiMetrics_surrogate_delta);

                            else
                                R.Metrics.surrogate_delta = struct();
                            end
                        end

                        if saveEqualized

                            if ~isempty(core_equalized) && isfield(core_equalized, 'Coherence') && ~isempty(core_equalized.Coherence)

                                metrics_equalized = compute_coherence_scalar_metrics( core_equalized.Coherence, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_equalized = compute_pair_poi_coherence_metrics( core_equalized.Coherence, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.equalized = package_full_stance_swing_metrics(metrics_equalized);
                                R.Metrics.equalized.poi = package_poi_metrics(poiMetrics_equalized);

                            else
                                R.Metrics.equalized = struct();
                            end
                        end

                        if saveCycleBiasCorrected

                            if ~isempty(Coherence_cycle_bias_corrected)

                                metrics_cycle_bias_corrected = compute_coherence_scalar_metrics( Coherence_cycle_bias_corrected, Freq, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics, stance_phase_indices, swing_phase_indices);

                                poiMetrics_cycle_bias_corrected = compute_pair_poi_coherence_metrics( Coherence_cycle_bias_corrected, Freq, pairName, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                                R.Metrics.cycle_bias_corrected = package_full_stance_swing_metrics(metrics_cycle_bias_corrected);
                                R.Metrics.cycle_bias_corrected.poi = package_poi_metrics(poiMetrics_cycle_bias_corrected);

                            else
                                R.Metrics.cycle_bias_corrected = struct();
                            end
                        end

                        R.Metrics.info.equalization_enabled = W.cycle_equalization.enable;
                        R.Metrics.info.equalization_mode = string(W.cycle_equalization.mode);
                        R.Metrics.info.equalization_selection = string(W.cycle_equalization.selection);
                        R.Metrics.info.N_common_equalized = N_common_equalized;
                        R.Metrics.info.N_equalized_used = sum(analysis_cycle_mask_equalized);
                        R.Metrics.info.SignificanceThreshold_equalized = seuil_equalized;
                        R.Metrics.info.common_threshold_enabled = ~isnan(seuil_common);
                        R.Metrics.info.SignificanceThreshold_common = seuil_common;
                        R.Metrics.info.common_threshold_source = "minimum retained cycle count for this pair within dataset";
                        R.Metrics.info.equalized_source = "raw coherence computed from equalized cycle subset";
                        R.Metrics.info.N_equalized_used = sum(analysis_cycle_mask_equalized);
                        R.Metrics.info.N_available_before_equalization = sum(analysis_cycle_mask);

                        if isfield(W, 'zcoh_bokil')
                            R.Metrics.info.zcoh_bokil_enabled = W.zcoh_bokil.enable;
                            R.Metrics.info.zcoh_bokil_input_transform = string(W.zcoh_bokil.input_transform);
                            R.Metrics.info.zcoh_bokil_df_mode = string(W.zcoh_bokil.df_mode);
                            R.Metrics.info.zcoh_bokil_n_cycles = core.Ncycle;
                        else
                            R.Metrics.info.zcoh_bokil_enabled = false;
                            R.Metrics.info.zcoh_bokil_input_transform = "";
                            R.Metrics.info.zcoh_bokil_df_mode = "";
                            R.Metrics.info.zcoh_bokil_n_cycles = NaN;
                        end

                        if isfield(W, 'surrogate_delta')
                            R.Metrics.info.surrogate_delta_enabled = W.surrogate_delta.enable;
                            R.Metrics.info.surrogate_delta_n_surrogates = W.surrogate_delta.n_surrogates;
                            R.Metrics.info.surrogate_delta_percentile = W.surrogate_delta.percentile;
                            R.Metrics.info.surrogate_delta_shuffle_mode = string(W.surrogate_delta.shuffle_mode);
                        else
                            R.Metrics.info.surrogate_delta_enabled = false;
                        end

                        R.Metrics.info.cycle_bias_correction_enabled = W.cycle_bias_correction.enable;
                        R.Metrics.info.cycle_bias_correction_formula = "Ccorr = Craw - a*(1/N - 1/Nref)";
                        R.Metrics.info.cycle_bias_correction_a = W.cycle_bias_correction.a;
                        R.Metrics.info.cycle_bias_correction_Nref = W.cycle_bias_correction.Nref;
                        R.Metrics.info.cycle_bias_correction_N_used = core.Ncycle;

                        % ============================================================
                        % POI METADATA
                        % ============================================================
                        % Same POI window for raw and significant metrics
                        R.POI = get_pair_poi_metadata(pairName, C, W.n_interp_time);

                        % Optional direct fields for quick inspection / backward readability
                        R.HasPOI           = R.POI.has_poi;
                        R.POI_StartPercent = R.POI.start_pct;
                        R.POI_EndPercent   = R.POI.end_pct;
                        R.POI_Indices      = R.POI.indices;

                        % ============================================================
                        % POWER / SNR-LIKE DIAGNOSTICS IN POI
                        % ============================================================
                        powerMetrics = compute_pair_poi_power_metrics( core.PowSpec_s1, core.PowSpec_s2, Freq, pairName, C, DS.FreqBands_this);

                        R.PowerPOI_signal1 = powerMetrics.power_poi_signal1;
                        R.PowerPOI_signal2 = powerMetrics.power_poi_signal2;
                        R.PowerPOI_mean_both = powerMetrics.power_poi_mean_both;
                        R.PowerPOI_log_mean_both = powerMetrics.power_poi_log_mean_both;
                        R.PowerPOI_ratio_1over2 = powerMetrics.power_poi_ratio_1over2;

                        % ============================================================
                        % OUTER VS MIDDLE DIAGNOSTICS
                        % ============================================================
                        qcdiag = compute_outer_cycle_diagnostics( core, Freq, mask_real_outer, mask_analysis_outer, mask_analysis_middle, W);

                        % ---------- Cycle-level QC from per-cycle coherence ----------
                        R.CycleBandCoherence = struct();
                        R.CycleBandCoherence.cycle_number = (1:height(Tseg))';
                        R.CycleBandCoherence.Alpha        = core.alpha_by_cycle;
                        R.CycleBandCoherence.Beta         = core.beta_by_cycle;
                        R.CycleBandCoherence.Gamma        = core.gamma_by_cycle;
                        R.CycleBandCoherence.FullRange    = core.fullrange_by_cycle;
                        R.CycleBandCoherence.analysis_cycle_mask = analysis_cycle_mask;
                        R.CycleBandCoherence.mask_real_outer = mask_real_outer;
                        R.CycleBandCoherence.mask_analysis_outer = mask_analysis_outer;
                        R.CycleBandCoherence.mask_analysis_middle = mask_analysis_middle;

                        % ---------- Padding / analysis mask ----------
                        R.padding_mode = string(W.padding.mode);
                        R.padding_info_signal1 = padInfo1;
                        R.padding_info_signal2 = padInfo2;

                        R.analysis_cycle_mask = analysis_cycle_mask;
                        R.n_cycles_total_before_edge_exclusion = height(Tseg);
                        R.exclude_edge_cycles_after_wavelet = W.exclude_edge_cycles_after_wavelet;
                        R.n_edge_cycles_excluded_each_side = W.n_edge_cycles_excluded_each_side;

                        % ---------- Equalized cycle mask ----------
                        if exist('analysis_cycle_mask_equalized', 'var') && ~isempty(analysis_cycle_mask_equalized)

                            R.analysis_cycle_mask_equalized = analysis_cycle_mask_equalized;
                            R.n_cycles_equalized_used = sum(analysis_cycle_mask_equalized);

                            if ismember('cycle_number', Tseg.Properties.VariableNames)
                                R.equalized_cycle_numbers = Tseg.cycle_number(analysis_cycle_mask_equalized);
                            else
                                R.equalized_cycle_numbers = find(analysis_cycle_mask_equalized);
                            end

                        else
                            R.analysis_cycle_mask_equalized = [];
                            R.n_cycles_equalized_used = NaN;
                            R.equalized_cycle_numbers = [];
                        end

                        % ---------- Original full concatenated paired signals ----------
                        if isfield(W, 'store_final_concatenated_signals') && W.store_final_concatenated_signals
                            R.final_concatenated_signal_1 = x1;
                            R.final_concatenated_signal_2 = x2;
                        else
                            R.final_concatenated_signal_1 = [];
                            R.final_concatenated_signal_2 = [];
                        end

                        % ---------- Signals corresponding to cycles actually used for normal coherence ----------
                        if isfield(W, 'store_analysis_concatenated_signals') && W.store_analysis_concatenated_signals

                            R.analysis_concatenated_signal_1 = build_signal_from_cycle_mask(x1, Tseg, analysis_cycle_mask, 1);
                            R.analysis_concatenated_signal_2 = build_signal_from_cycle_mask(x2, Tseg, analysis_cycle_mask, 2);

                            R.analysis_equalized_concatenated_signal_1 = build_signal_from_cycle_mask(x1, Tseg, analysis_cycle_mask_equalized, 1);
                            R.analysis_equalized_concatenated_signal_2 = build_signal_from_cycle_mask(x2, Tseg, analysis_cycle_mask_equalized, 2);

                        else
                            R.analysis_concatenated_signal_1 = [];
                            R.analysis_concatenated_signal_2 = [];
                            R.analysis_equalized_concatenated_signal_1 = [];
                            R.analysis_equalized_concatenated_signal_2 = [];
                        end

                        R.cycle_equalization = struct();
                        R.cycle_equalization.enabled = isfield(W, 'cycle_equalization') && W.cycle_equalization.enable;

                        if R.cycle_equalization.enabled
                            R.cycle_equalization.mode = string(W.cycle_equalization.mode);
                            R.cycle_equalization.selection = string(W.cycle_equalization.selection);
                            R.cycle_equalization.N_common = N_common_equalized;
                            R.cycle_equalization.N_available_before_equalization = sum(analysis_cycle_mask);
                            R.cycle_equalization.N_used_after_equalization = R.n_cycles_equalized_used;
                            R.cycle_equalization.SignificanceThreshold_equalized = seuil_equalized;
                        else
                            R.cycle_equalization.mode = "";
                            R.cycle_equalization.selection = "";
                            R.cycle_equalization.N_common = NaN;
                            R.cycle_equalization.N_available_before_equalization = sum(analysis_cycle_mask);
                            R.cycle_equalization.N_used_after_equalization = NaN;
                            R.cycle_equalization.SignificanceThreshold_equalized = NaN;
                        end

                        % ---------- COI QC ----------
                        R.COI_period_mean = COI_period_mean;
                        R.COI_freq_mean   = COI_freq_mean;
                        R.COI_mask        = COI_mask;
                        R.Coherence_outsideCOI     = Coherence_outsideCOI;
                        R.Coherence_sig_outsideCOI = Coherence_sig_outsideCOI;

                        % ---------- Outer / middle QC ----------
                        R.mask_real_outer          = mask_real_outer;
                        R.mask_analysis_outer      = mask_analysis_outer;
                        R.mask_analysis_middle     = mask_analysis_middle;

                        R.n_cycles_real_outer      = qcdiag.Ncycle_real_outer;
                        R.n_cycles_analysis_outer  = qcdiag.Ncycle_analysis_outer;
                        R.n_cycles_analysis_middle = qcdiag.Ncycle_analysis_middle;

                        R.Coherence_real_outer      = qcdiag.Coherence_real_outer;
                        R.Coherence_analysis_outer  = qcdiag.Coherence_analysis_outer;
                        R.Coherence_analysis_middle = qcdiag.Coherence_analysis_middle;

                        R.mean_real_outer_spectrum      = qcdiag.mean_real_outer_spectrum;
                        R.mean_analysis_outer_spectrum  = qcdiag.mean_analysis_outer_spectrum;
                        R.mean_analysis_middle_spectrum = qcdiag.mean_analysis_middle_spectrum;

                        R.diag_full_mean_real_outer      = qcdiag.diag_full_mean_real_outer;
                        R.diag_full_mean_analysis_outer  = qcdiag.diag_full_mean_analysis_outer;
                        R.diag_full_mean_analysis_middle = qcdiag.diag_full_mean_analysis_middle;

                        R.diag_diff_realouter_vs_middle     = qcdiag.diag_diff_realouter_vs_middle;
                        R.diag_diff_analysisouter_vs_middle = qcdiag.diag_diff_analysisouter_vs_middle;

                        % ---------- Dataset metadata ----------
                        R.input_dataset = datasetName;
                        R.dataset_name  = datasetName;
                        R.freq_bands_used = DS.FreqBands_this;
                        R.compute_fullband_metrics = DS.computeFullBandMetrics;

                        % ---------- Save nested result ----------
                        COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName) = R;

                        % ---------- Save lightweight diagnostic row ----------
                        diag_i = diag_i + 1;
                        DIAG_ROWS(diag_i,:) = { string(subjID), string(cond), string(leg), string(pairName), qcdiag.Ncycle_real_outer, qcdiag.Ncycle_analysis_outer, qcdiag.Ncycle_analysis_middle, qcdiag.diag_full_mean_real_outer, qcdiag.diag_full_mean_analysis_outer, qcdiag.diag_full_mean_analysis_middle, qcdiag.diag_diff_realouter_vs_middle, qcdiag.diag_diff_analysisouter_vs_middle };

                        % ---------- Optional per-entry plots ----------
                        if PL.enable

                            if isfield(PL, 'individual') && PL.individual.enable
                                [doPlot, plotTracker.individual] = should_make_limited_subject_plot( subjID, plotTracker.individual, PL.individual.max_plots);
                                if doPlot
                                    plot_wavelet_coherence_result(R, datasetDirs.individualDir, DS.plot_freq_range_this);
                                end
                            end

                            if isfield(PL, 'before_after') && PL.before_after.enable
                                [doPlot, plotTracker.before_after] = should_make_limited_subject_plot( subjID, plotTracker.before_after, PL.before_after.max_plots);
                                if doPlot
                                    plot_coherence_before_after(R, datasetDirs.beforeAfterDir, DS.plot_freq_range_this);
                                end
                            end

                            if isfield(PL, 'outer_cycle_diag') && PL.outer_cycle_diag.enable
                                [doPlot, plotTracker.outer_cycle_diag] = should_make_limited_subject_plot( subjID, plotTracker.outer_cycle_diag, PL.outer_cycle_diag.max_plots);
                                if doPlot
                                    plot_outer_cycle_diagnostics(R, datasetDirs.outerCycleDiagDir, DS.plot_freq_range_this);
                                end
                            end
                        end

                        fprintf('  %s | %s | %s -> %d cycles used\n', cond, leg, pairName, core.Ncycle);
                    end
                end
            end
        end

        % ============================================================
        % 2) SAVE CORE DATASET OUTPUTS
        % ============================================================
        fprintf('\nSaving coherence results for %s...\n', datasetName);
        save(datasetOutMat, 'COHERENCE_RESULTS', 'CONCAT_SIGNAL_QC', 'W', 'datasetName', '-v7.3');
        fprintf('Saved:\n%s\n', datasetOutMat);

        COHERENCE_SUMMARY_TABLE = build_coherence_summary_table( COHERENCE_RESULTS, C, DS.summaryScalarVars_this, W, W.metric_sources_to_save);

        writetable(COHERENCE_SUMMARY_TABLE, datasetSummaryCsv);

        if ~isempty(DIAG_ROWS)
            DIAG_TABLE = cell2table(DIAG_ROWS, 'VariableNames', { 'subject','condition','leg','pair_name', 'n_real_outer','n_analysis_outer','n_analysis_middle', 'real_outer_mean','analysis_outer_mean','analysis_middle_mean', 'diff_realouter_vs_middle','diff_analysisouter_vs_middle'});

            writetable(DIAG_TABLE, fullfile(datasetDirs.qcDir, sprintf('OUTER_CYCLE_DIAGNOSTICS_%s.csv', datasetName)));
        end

        % ============================================================
        % 3) OPTIONAL QC PLOTS
        % ============================================================
        if PL.enable

            % ---------- Cycle-band QC ----------
            if isfield(PL, 'cycle_band_qc') && PL.cycle_band_qc.enable
                outDir = fullfile(datasetDirs.qcDir, 'cycle_band_coherence_qc');
                if ~exist(outDir, 'dir'), mkdir(outDir); end

                fprintf('\nGenerating cycle-band coherence QC plots for %s', datasetName);
                plot_saved_cycle_band_coherence_examples(COHERENCE_RESULTS, outDir, PL.cycle_band_qc.max_examples);
                plot_pooled_cycle_band_coherence(COHERENCE_RESULTS, outDir, PL.cycle_band_qc.max_pooled);
                plot_pooled_fullrange_cycle_coherence(COHERENCE_RESULTS, outDir, PL.cycle_band_qc.max_pooled);
                plot_boxplot_fullrange_cycle_groups(COHERENCE_RESULTS, outDir);
            end

            % ---------- Whole-signal normalized map QC ----------
            if isfield(PL, 'whole_signal_qc') && PL.whole_signal_qc.enable
                outDir = fullfile(datasetDirs.qcDir, 'whole_signal_normalized_map_qc');
                if ~exist(outDir, 'dir'), mkdir(outDir); end

                fprintf('\nGenerating pooled whole-signal normalized coherence map QC for %s', datasetName);
                plot_pooled_whole_signal_normalized_coherence( inFile, outDir, datasetName, DS.FreqMin_this, DS.FreqMax_this, W);
            end

            % ---------- COI examples ----------
            if isfield(PL, 'coi_examples') && PL.coi_examples.enable && ~isempty(COI_EXAMPLES)
                fprintf('\nPlotting COI examples for %s', datasetName);

                coiPlotCfg = PL.coi_examples;
                if isfield(coiPlotCfg, 'dir') && ~isempty(coiPlotCfg.dir)
                    coiPlotCfg.out_dir = fullfile(coiPlotCfg.dir, char(datasetName));
                    fprintf('Using custom output directory for COI examples:\n%s\n', coiPlotCfg.out_dir);
                else
                    fprintf('No custom directory specified for COI examples. Using default:\n%s\n', datasetDirs.individualDir);
                    coiPlotCfg.out_dir = fullfile(datasetDirs.individualDir, 'coi_examples');
                end
                if ~exist(coiPlotCfg.out_dir, 'dir'), mkdir(coiPlotCfg.out_dir); end

                plot_random_coi_examples(COI_EXAMPLES, W, coiPlotCfg);
            end

            % ---------- Pooled before-vs-after edge-cycle removal QC ----------
            if isfield(PL, 'edge_cycle_compare') && PL.edge_cycle_compare.enable
                if EdgeCycleQC.n > 0
                    outDir = fullfile(datasetDirs.qcDir, 'edge_cycle_compare_qc');
                    if ~exist(outDir, 'dir'), mkdir(outDir); end

                    fprintf('\nGenerating pooled before-vs-after edge-cycle removal QC for %s', datasetName);

                    mean_before = EdgeCycleQC.sum_before / EdgeCycleQC.n;
                    mean_after  = EdgeCycleQC.sum_after  / EdgeCycleQC.n;

                    plot_pooled_before_after_edgecycle_qc( mean_before, mean_after, EdgeCycleQC.Freq, datasetName, EdgeCycleQC.n, PL.edge_cycle_compare.use_significant, outDir);
                else
                    warning('No signals were accumulated for before-vs-after edge-cycle QC in dataset %s.', datasetName);
                end
            end


            % ============================================================
            % 4) OPTIONAL GROUP / FINAL PLOTS
            % ============================================================
            G = [];

            if GP.enable || FP.enable
                G = build_group_plot_struct(COHERENCE_RESULTS, C, W, W.default_metric_source_for_tables);
            end

            if GP.enable && ~isempty(G)
                fprintf('\nGenerating group-level summary and plots for %s', datasetName);
                run_group_level_plots( G, datasetDirs.groupDir, DS.plot_freq_range_this, DS.scalar_plot_sets_this, GP, C);
            end

            if FP.enable && ~isempty(G)
                fprintf('\nGenerating final comparison plots for %s', datasetName);
                run_final_comparison_plots( G, datasetDirs.finalDir, DS.plot_freq_range_this, FP, C);
            end
        end
    end
end