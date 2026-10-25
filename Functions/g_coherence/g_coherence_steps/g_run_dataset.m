function g_run_dataset(inputSet, C)
% G_RUN_DATASET  Coherence for every included pair of one input dataset
% (FULL, or one band; C.g_coherence.io.input_sets): loads the stage-f pair
% signals, computes each pair (g_compute_pair_coherence) with the
% dataset-wide N_common, saves COHERENCE_RESULTS_<DATASET>.mat and the summary
% table, and makes the optional QC and group plots.

    IO  = C.g_coherence.io;
    W   = C.g_coherence.params;
    PL  = C.g_coherence.plot;
    GP  = C.g_coherence.group_plot;
    FP  = C.g_coherence.final_plot;

    % ---------------- Skip disabled datasets ----------------
    if ~inputSet.enabled
        return;
    end

    datasetName = upper(string(inputSet.name));
    inFile      = inputSet.mat_file;

    fprintf('\n====================================================\n');
    fprintf('Running coherence for dataset: %s\n', datasetName);
    fprintf('Input file: %s\n', inFile);
    fprintf('====================================================\n');

    if ~isfile(inFile)
        warning('Input file not found for dataset %s:\n%s', datasetName, inFile);
        return;
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

    % Collected across pairs for the dataset-level QC (see g_compute_pair_coherence)
    ACC = struct();
    ACC.plotTracker = plotTracker;
    ACC.CONCAT_SIGNAL_QC = CONCAT_SIGNAL_QC;
    ACC.n_concat_saved = n_concat_saved;
    ACC.COI_EXAMPLES = COI_EXAMPLES;
    ACC.EdgeCycleQC = EdgeCycleQC;
    ACC.DIAG_ROWS = DIAG_ROWS;
    ACC.diag_i = diag_i;

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

                    [R, ACC] = g_compute_pair_coherence(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName), subjID, cond, leg, pairName, N_common_equalized, C, DS, datasetName, datasetDirs, ACC);
                    if isempty(R)
                        continue;
                    end
                    COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName) = R;
                end
            end
        end
    end

    CONCAT_SIGNAL_QC = ACC.CONCAT_SIGNAL_QC;
    COI_EXAMPLES = ACC.COI_EXAMPLES;
    EdgeCycleQC = ACC.EdgeCycleQC;
    DIAG_ROWS = ACC.DIAG_ROWS;

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
