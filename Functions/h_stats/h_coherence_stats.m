function h_coherence_stats()
% H_COHERENCE_STATS  Stage h: statistics on the stage-g coherence results.
%
% Reads   mat_coherence_data/COHERENCE_RESULTS_FULL.mat and _<BAND>.mat (stage g)
% Writes  Results/h_coherence_stats_pair_phase_main/{tables,models}/,
%         figures in Results/png_visualisation/h_coherence_stats_pair_phase_main/,
%         workspaces in mat_stats_data/
% Settings  C.h_stats (config/config_emg.m)
%
% Primary analysis, per muscle pair and band (C.shared_wavelet.FreqBands):
%   <Band>_AUC_norm ~ AgeYears_z * condition + (1|subject)
% on the equalized coherence in the pair's phase of interest, legs averaged,
% fitted with effects coding / REML / Satterthwaite (C.h_stats.lme) and
% Holm-adjusted across the models (h_continuous_age_models).
%
% The steps are in Functions/h_stats/h_stats_steps/, one function each, in
% the order below. Optional analyses check their own switch in C.h_stats.

    %% ===================== SETUP =====================

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.stats));

    HC = C.h_stats;
    runStart = datetime('now') - seconds(1);

    ANALYSIS_TAG = make_h_stats_analysis_tag(HC);

    fprintf('\n=== H-STATS ANALYSIS TAG ===\n');
    fprintf('%s\n', ANALYSIS_TAG);

    if isfield(HC.analysis, 'scalar_metric_families')
        fprintf('Scalar metric families: %s\n', strjoin(string(HC.analysis.scalar_metric_families), ', '));
    end

    fprintf('Dependent variables analyzed:\n');
    disp(HC.analysis.dv_list(:));

    includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    if includeCycleCov && ~strcmpi(string(HC.analysis.coherence_source), "raw")
        warning(['Cycle-count covariate is enabled, but coherence_source is not raw. ' 'For the Bokil-inspired main comparison, use coherence_source = "raw".']);
    end

    if ~exist(HC.io.out_dir, 'dir'), mkdir(HC.io.out_dir); end
    if ~exist(HC.io.tables_dir, 'dir'), mkdir(HC.io.tables_dir); end
    if ~exist(HC.io.models_dir, 'dir'), mkdir(HC.io.models_dir); end
    if ~exist(HC.io.plots_dir, 'dir'), mkdir(HC.io.plots_dir); end
    if ~exist(HC.io.mat_dir, 'dir'), mkdir(HC.io.mat_dir); end
    if ~exist(HC.io.band_triplet_dir, 'dir'), mkdir(HC.io.band_triplet_dir); end

    fprintf('\n=== Running coherence stats: pair-specific main phase analysis ===\n');

    %% ===================== STEPS =====================

    [T_row, T_subj, COH_DEFAULT, allCoh, subjects, bandSource] = h_build_tables(C, HC, ANALYSIS_TAG);
    h_age_correlations(T_subj, C, HC, ANALYSIS_TAG);
    CONTINUOUS_AGE_LME_TABLE = h_continuous_age_models(T_subj, C, HC, ANALYSIS_TAG);
    h_power_correlations(T_subj, HC);
    h_sample_recap(T_row, T_subj, HC, ANALYSIS_TAG, bandSource);
    [DESCRIPTIVE_ALL, OMNIBUS_TABLE, POSTHOC_TABLE] = h_descriptives_and_categorical_models(T_row, T_subj, C, HC, ANALYSIS_TAG);
    h_power_control_models(T_subj, HC, ANALYSIS_TAG);
    h_band_triplet_figures(T_subj, C, HC, CONTINUOUS_AGE_LME_TABLE);
    h_spectrum_curves_and_spm(COH_DEFAULT, allCoh, subjects, C, HC);
    h_cycle_triplets(COH_DEFAULT, C, HC);

    %% ===================== SAVE WORKSPACE =====================

    save(fullfile(HC.io.mat_dir, sprintf('workspace__%s.mat', ANALYSIS_TAG)), 'T_row', 'T_subj', 'DESCRIPTIVE_ALL', 'OMNIBUS_TABLE', 'POSTHOC_TABLE', 'HC', 'ANALYSIS_TAG', '-v7.3');

    % Optional latest-copy workspace
    save(HC.io.workspace_mat, 'T_row', 'T_subj', 'DESCRIPTIVE_ALL', 'OMNIBUS_TABLE', 'POSTHOC_TABLE', 'HC', 'ANALYSIS_TAG', '-v7.3');

    % ---------- Move outputs this run did not rewrite out of the way ----------
    if ~isfield(HC.io, 'archive_stale_outputs') || HC.io.archive_stale_outputs
        archive_stale_h_outputs({HC.io.tables_dir, HC.io.models_dir, HC.io.plots_dir}, runStart, C.paths.results_dir, C.paths.results_archive_dir);
    end

    fprintf('\nDone.\n');
    fprintf('Results saved in:\n%s\n', HC.io.out_dir);
end
