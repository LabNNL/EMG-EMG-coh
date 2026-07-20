
%% d_a_clustering_cleaning.m
% Build a burst-level feature table from BURSTS_DET files, inspect feature
% distributions, cluster bursts, and apply a manual keep/reject mapping.
%
% -------------------------------------------------------------------------
% OVERVIEW
% -------------------------------------------------------------------------
% This script performs four main steps:
%
% 1) FEATURE EXTRACTION
%    - reads previously detected bursts from *_EMG_BURSTS.mat
%    - extracts one row per burst
%    - computes metadata + numerical features for each burst
%    - stores everything in a flat table: BURST_FEATURES
%
% 2) FEATURE INSPECTION
%    - plots distributions of the extracted features:
%         * overall
%         * by age group
%         * by muscle
%         * by condition
%    - helps decide which features seem informative for clustering
%
% 3) CLUSTERING
%    - clusters bursts using a selected subset of features
%    - clustering can be performed:
%         * globally ("ALL")
%         * per muscle
%         * per age group
%         * per condition
%    - different clustering quality scores can be inspected to choose k
%
% 4) MANUAL CLUSTER INTERPRETATION
%    - after inspecting cluster plots, the user specifies which cluster(s)
%      should be considered "good" / physiologically plausible
%    - this produces a final burst-level clustering decision:
%         * cluster_good = true / false
%
% -------------------------------------------------------------------------
% EXPECTED INPUT
% -------------------------------------------------------------------------
% Input files are burst files produced earlier in the pipeline:
%   *_EMG_BURSTS.mat
%
% Each signal entry is expected to contain at least:
%   - signal           : concatenated preprocessed EMG signal
%   - bursts_idx       : [start end] indices for detected bursts
%   - bursts_table     : burst-level metadata
%   - n_cycles         : total number of cycles contributing to the signal
%
% -------------------------------------------------------------------------
% MAIN OUTPUTS
% -------------------------------------------------------------------------
% 1) BURST_FEATURES.mat / .csv
%    Flat burst-level table with:
%      - metadata
%      - feature values
%
% 2) Feature inspection plots
%    Histograms overall and by group
%
% 3) CLUSTER_RESULTS.mat
%    Contains clustering results, quality scores, best k, summaries, etc.
%
% 4) BURST_FEATURES_CLUSTERED
%    Same burst-level table, enriched with:
%      - cluster_id
%      - cluster_k_best
%      - cluster_valid
%      - cluster_good
%      - cluster_decision_reason
%
% -------------------------------------------------------------------------
% IMPORTANT CONFIG STRUCTS
% -------------------------------------------------------------------------
% C                  : full project configuration from config_emg()
%
% DF_IO              : feature extraction I/O paths and filenames
% DF_P               : feature extraction parameters
% DF_PLT             : feature plotting settings
% DF_H               : helper function paths
%
% DC_IO              : clustering I/O paths and filenames
% DC_P               : clustering parameters
% DC_I               : clustering inspection settings
%
% DM_IO              : manual cluster interpretation output paths
% DM_QC              : manual cluster QC plotting settings
% DM_KEEP            : user-defined mapping of group -> good clusters
%
% -------------------------------------------------------------------------
% IMPORTANT BURST-LEVEL METADATA VARIABLES
% -------------------------------------------------------------------------
% subjID             : participant identifier
% cond               : walking condition
% leg                : leg side ("left" / "right")
% mf                 : muscle field name (e.g. EMG_GM_Concat)
% fs                 : sampling frequency of the signal
% bursts_idx         : Nx2 matrix of burst start/end sample indices
% nBursts            : number of bursts in the current signal
% burst_sig          : signal segment corresponding to one burst
% metaRow            : row from bursts_table containing saved metadata
%
% -------------------------------------------------------------------------
% EXTRACTED FEATURES (one row per burst)
% -------------------------------------------------------------------------
% MedFreq
%   - median frequency of the burst
%   - computed from wavelet-based time-frequency power within the burst
%   - reflects where the power of the burst is centered in frequency
%
% Maxim
%   - maximum absolute amplitude of the burst
%   - sensitive to very large peaks / spikes
%
% Skew
%   - skewness of the burst amplitude distribution
%   - reflects asymmetry of the signal distribution
%
% Kurt
%   - kurtosis of the burst amplitude distribution
%   - higher values can indicate more peaky / heavy-tailed bursts
%
% Variance
%   - here implemented as std(burst_sig), matching the original teacher code
%   - reflects burst amplitude spread
%
% SampEntr
%   - sample entropy
%   - measures signal irregularity / unpredictability
%
% FuzzyEntr
%   - fuzzy entropy
%   - another irregularity / complexity measure, often smoother than
%     sample entropy
%
% HFD
%   - Higuchi fractal dimension
%   - measures signal roughness / complexity across scales
%
% MeanAbs
%   - mean absolute amplitude of the burst
%   - more robust than the maximum alone
%
% RMS
%   - root mean square amplitude
%   - global measure of burst energy / magnitude
%
% MaxDeriv
%   - maximum absolute first derivative of the burst
%   - highlights very abrupt transitions / spikes
%
% MeanAbsDeriv
%   - mean absolute first derivative
%   - summarizes average sharpness of the burst
%
% -------------------------------------------------------------------------
% NOTES
% -------------------------------------------------------------------------
% - Feature extraction is done on the preprocessed burst signal, not on the
%   envelope, except for metadata already stored in bursts_table
%   (mean_envelope, peak_envelope).
%
% - Clustering is exploratory: the selected number of clusters and the
%   cluster(s) considered "good" must be checked visually.
%
% - When run_feature_extraction is false, the script can reload the saved
%   BURST_FEATURES table and continue with plotting / clustering only.
% -------------------------------------------------------------------------

function d_a_clustering_cleaning()
    clc; clear; close all;

    %% ===================== CONFIG =====================
    C = config_emg();

    DF_IO   = C.d_features.io;
    DF_P    = C.d_features.params;
    DF_PLT  = C.d_features.plot;

    DC_IO   = C.d_clustering.io;
    DC_P    = C.d_clustering.params;
    DC_I    = C.d_clustering.inspect;

    DM_IO   = C.d_cluster_manual.io;
    DM_QC   = C.d_cluster_manual.qc;
    DM_KEEP = C.d_cluster_manual.keep;

    % addpath(genpath(DF_H.functions_root));
    % addpath(genpath(DF_H.preprocessing));

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.clustering_cleaning));
    % addpath(genpath(C.paths.helpers.preprocessing));

    if ~exist(DF_IO.out_dir, 'dir'), mkdir(DF_IO.out_dir); end
    if ~exist(DF_IO.plot_dir, 'dir'), mkdir(DF_IO.plot_dir); end
    if ~exist(DF_IO.csv_dir, 'dir'), mkdir(DF_IO.csv_dir); end

    if ~exist(DC_IO.cluster_dir, 'dir'), mkdir(DC_IO.cluster_dir); end
    if ~exist(DC_IO.csv_dir, 'dir'), mkdir(DC_IO.csv_dir); end
    if ~exist(DC_IO.plot_dir, 'dir'), mkdir(DC_IO.plot_dir); end

    if ~exist(DM_IO.final_plot_dir, 'dir'), mkdir(DM_IO.final_plot_dir); end

    files = dir(fullfile(DF_IO.in_dir, DF_IO.input_pattern));
    fprintf('Found %d burst files.\n', numel(files));

    %% ===================== MAIN TABLE =====================

    if DF_P.run_feature_extraction
        all_signal_tables = cell(0,1);

        for f = 1:numel(files)
            inFile = fullfile(files(f).folder, files(f).name);
            S = load(inFile);

            if ~isfield(S, 'BURSTS_DET')
                warning('Skipping %s: BURSTS_DET not found.', files(f).name);
                continue;
            end

            BURSTS_DET = S.BURSTS_DET;

            subjFields = fieldnames(BURSTS_DET);
            subjFields(strcmp(subjFields, 'meta')) = [];
            if isempty(subjFields)
                warning('No subject field found in %s.', files(f).name);
                continue;
            end

            subjID = subjFields{1};
            fprintf('\n=== Feature extraction: %s ===\n', subjID);

            subjStruct = BURSTS_DET.(subjID);
            age_group = string(get_subject_group(C, subjID));

            if isfield(subjStruct, 'meta') && isfield(subjStruct.meta, 'source_file')
                source_file = string(subjStruct.meta.source_file);
            else
                source_file = "";
            end

            conds = fieldnames(subjStruct);
            conds(strcmp(conds, 'meta')) = [];

            for ic = 1:numel(conds)
                cond = conds{ic};
                condStruct = subjStruct.(cond);
                if ~isstruct(condStruct), continue; end

                legs = fieldnames(condStruct);
                for il = 1:numel(legs)
                    leg = legs{il};
                    legStruct = condStruct.(leg);
                    if ~isstruct(legStruct), continue; end

                    musFields = fieldnames(legStruct);
                    for im = 1:numel(musFields)
                        mf = musFields{im};
                        entry = legStruct.(mf);

                        if ~isstruct(entry), continue; end
                        if ~isfield(entry, 'signal') || isempty(entry.signal), continue; end
                        if ~isfield(entry, 'bursts_idx') || isempty(entry.bursts_idx), continue; end
                        if ~isfield(entry, 'bursts_table') || isempty(entry.bursts_table), continue; end

                        x = entry.signal(:);
                        fs = get_fs_from_entry_or_config(entry, C);

                        bursts_idx = entry.bursts_idx;
                        nBursts = size(bursts_idx,1);
                        bursts_table = entry.bursts_table;
                        n_cycles_total = entry.n_cycles;

                        Args = WaveletParameters(DF_P.FreqMin, DF_P.FreqMax, DF_P.Resolution, DF_P.WaveNumber, fs);

                        try
                            [norm_tf, ~, Wave_FreqS] = TimeFreqTransform(x, fs, Args, 1);
                        catch ME
                            warning('TimeFreqTransform failed for %s | %s | %s | %s: %s', subjID, cond, leg, mf, ME.message);
                            continue;
                        end

                        signal_rows = cell(nBursts,1);
                        nValidRows = 0;

                        for iB = 1:nBursts
                            idx1 = max(1, round(bursts_idx(iB,1)));
                            idx2 = min(numel(x), round(bursts_idx(iB,2)));

                            if idx2 <= idx1
                                continue;
                            end

                            burst_sig = x(idx1:idx2);

                            % ----- Median frequency from wavelet power -----
                            try
                                PowSpec = mean(norm_tf(:, idx1:idx2), 2, 'omitnan');
                                cumInt  = cumtrapz(PowSpec);

                                if isempty(cumInt) || all(isnan(cumInt)) || max(cumInt) == 0
                                    MedFreq = NaN;
                                else
                                    [~, idxMF] = min(abs(cumInt - max(cumInt)/2));
                                    MedFreq = Wave_FreqS(idxMF);
                                end
                            catch
                                MedFreq = NaN;
                            end

                            % ----- Amplitude/statistical features -----
                            Maxim = max(abs(burst_sig), [], 'omitnan');
                            Skew  = safe_skewness(burst_sig);
                            Kurt  = safe_kurtosis(burst_sig);
                            Variance = std(burst_sig, 'omitnan');

                            % ----- Entropy / complexity features -----
                            zsig = safe_zscore(burst_sig);
                            SampEntr  = safe_sample_entropy(zsig, DF_P.SampleEntropy_m, DF_P.SampleEntropy_r);
                            FuzzyEntr = safe_fuzzy_en(zsig, DF_P.FuzzyEn_m, DF_P.FuzzyEn_r, DF_P.FuzzyEn_n);
                            HFD       = safe_hfd(zsig, DF_P.HFD_kmax);

                            % ----- Additional amplitude features -----
                            MeanAbs = mean(abs(burst_sig), 'omitnan');
                            RMS     = sqrt(mean(burst_sig.^2, 'omitnan'));

                            % ----- Derivative-based features -----
                            dSig = diff(burst_sig);
                            dSig = dSig(~isnan(dSig));

                            if isempty(dSig)
                                MaxDeriv = NaN;
                                MeanAbsDeriv = NaN;
                            else
                                MaxDeriv = max(abs(dSig));
                                MeanAbsDeriv = mean(abs(dSig));
                            end

                            metaRow = bursts_table(iB,:);

                            row = init_burst_feature_row();

                            row.burst_id               = metaRow.burst_id;
                            row.subject                = metaRow.subject;
                            row.condition              = metaRow.condition;
                            row.leg                    = metaRow.leg;
                            row.muscle                 = metaRow.muscle;
                            row.age_group              = age_group;

                            row.burst_number           = metaRow.burst_number;
                            row.start_idx              = metaRow.start_idx;
                            row.end_idx                = metaRow.end_idx;
                            row.center_idx             = metaRow.center_idx;
                            row.duration_samples       = metaRow.duration_samples;
                            row.duration_s             = metaRow.duration_s;
                            row.start_time_s           = metaRow.start_time_s;
                            row.end_time_s             = metaRow.end_time_s;
                            row.mean_envelope          = metaRow.mean_envelope;
                            row.peak_envelope          = metaRow.peak_envelope;
                            row.cycle_idx_start        = metaRow.cycle_idx_start;
                            row.cycle_idx_end          = metaRow.cycle_idx_end;
                            row.burst_in_single_cycle  = metaRow.burst_in_single_cycle;

                            row.source_file            = source_file;
                            row.fs                     = fs;
                            row.n_cycles_total         = n_cycles_total;

                            row.MedFreq                = MedFreq;
                            row.Maxim                  = Maxim;
                            row.Skew                   = Skew;
                            row.Kurt                   = Kurt;
                            row.Variance               = Variance;
                            row.SampEntr               = SampEntr;
                            row.FuzzyEntr              = FuzzyEntr;
                            row.HFD                    = HFD;
                            row.MeanAbs                = MeanAbs;
                            row.RMS                    = RMS;
                            row.MaxDeriv               = MaxDeriv;
                            row.MeanAbsDeriv           = MeanAbsDeriv;

                            nValidRows = nValidRows + 1;
                            signal_rows{nValidRows} = row;
                        end

                        if nValidRows > 0
                            signal_rows = signal_rows(1:nValidRows);
                            all_signal_tables{end+1,1} = vertcat(signal_rows{:}); %#ok<AGROW>
                        end

                        fprintf('  %s | %s | %s -> %d bursts\n', cond, leg, mf, nValidRows);
                    end
                end
            end
        end

        if isempty(all_signal_tables)
            BURST_FEATURES = init_burst_features_table();
        else
            BURST_FEATURES = vertcat(all_signal_tables{:});
        end

        fprintf('\nTotal bursts in table: %d\n', height(BURST_FEATURES));

        save(fullfile(DF_IO.out_dir, DF_IO.output_mat), 'BURST_FEATURES', '-v7.3');
        writetable(BURST_FEATURES, fullfile(DF_IO.csv_dir, DF_IO.output_csv));

        featureVars = DF_PLT.featureVars;
    else
        fprintf('Feature extraction skipped. Set DF_P.run_feature_extraction = true to run it.\n');
    end

    %% ===================== PLOT FEATURE DISTRIBUTIONS =====================

    % if BURST_FEATURES is not defined, use the saved .mat file to load it (if it exists), otherwise skip plotting
    if exist('BURST_FEATURES', 'var') && height(BURST_FEATURES) > 0
        fprintf('\nPlotting feature distributions...\n');
        plot_histograms_overall(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir);
        plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'age_group', 'Age group', C);
        plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'muscle', 'Muscle', C);
        plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'condition', 'Condition', C);

        fprintf('\nSaved table and plots in:\n%s\n', DF_IO.out_dir);
    elseif exist(fullfile(DF_IO.out_dir, DF_IO.output_mat), 'file')
        fprintf('\nBURST_FEATURES table not found in workspace, but .mat file exists. Loading from file for plotting...\n');
        S = load(fullfile(DF_IO.out_dir, DF_IO.output_mat), 'BURST_FEATURES');
        if isfield(S, 'BURST_FEATURES')
            BURST_FEATURES = S.BURST_FEATURES;
            fprintf('Loaded BURST_FEATURES from:\n%s\n', fullfile(DF_IO.out_dir, DF_IO.output_mat));
            featureVars = DF_PLT.featureVars;
            plot_histograms_overall(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir);
            plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'age_group', 'Age group', C);
            plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'muscle', 'Muscle', C);
            plot_histograms_by_group(BURST_FEATURES, featureVars, DF_PLT.nbins, DF_IO.plot_dir, 'condition', 'Condition', C);
            fprintf('\nSaved table and plots in:\n%s\n', DF_IO.out_dir);
        else
            warning('The file %s does not contain a variable named BURST_FEATURES. Skipping plotting.', fullfile(DF_IO.out_dir, DF_IO.output_mat));
        end
    else
        fprintf('Feature extraction skipped. Set DF_P.run_feature_extraction = true to run it.\n');
    end

    %% ===================== FEATURE CORRELATION MATRIX =====================

    corrVars = DF_PLT.featureVars;   % or define your own list manually
    corrOutDir = DF_IO.plot_dir;

    % Keep only variables that actually exist in the table
    corrVars = corrVars(ismember(corrVars, BURST_FEATURES.Properties.VariableNames));

    if isempty(corrVars)
        warning('No valid feature variables found for correlation matrix.');
    else
        X = BURST_FEATURES(:, corrVars);

        % Convert to numeric matrix
        Xmat = nan(height(X), numel(corrVars));
        for i = 1:numel(corrVars)
            Xmat(:, i) = X.(corrVars{i});
        end

        % Remove rows that are all NaN
        Xmat = Xmat(~all(isnan(Xmat),2), :);

        % Spearman is often safer than Pearson for skewed burst features
        [R, P] = corr(Xmat, 'Type', 'Spearman', 'Rows', 'pairwise');

        % Save numeric results
        corrTable = array2table(R, 'VariableNames', corrVars, 'RowNames', corrVars);
        writetable(corrTable, fullfile(corrOutDir, 'feature_correlation_matrix.csv'), 'WriteRowNames', true);

        pTable = array2table(P, 'VariableNames', corrVars, 'RowNames', corrVars);
        writetable(pTable, fullfile(corrOutDir, 'feature_correlation_pvalues.csv'), 'WriteRowNames', true);

        % Plot correlation heatmap
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 900 800]);
        imagesc(R);
        axis equal tight;
        colorbar;
        clim([-1 1]);

        set(gca, 'XTick', 1:numel(corrVars), 'XTickLabel', corrVars, 'YTick', 1:numel(corrVars), 'YTickLabel', corrVars, 'XTickLabelRotation', 45);

        title('Feature correlation matrix (Spearman)');
        exportgraphics(fig, fullfile(corrOutDir, 'feature_correlation_matrix.png'), 'Resolution', 200);
        close(fig);

        fprintf('\nSaved feature correlation matrix in:\n%s\n', corrOutDir);
    end

    %% ===================== CLUSTERING FEATURES FEATURE CORRELATION MATRIX =====================

    corrVars = DC_P.featureVars;   % or define your own list manually
    corrOutDir = DF_IO.plot_dir;

    % Keep only variables that actually exist in the table
    corrVars = corrVars(ismember(corrVars, BURST_FEATURES.Properties.VariableNames));

    if isempty(corrVars)
        warning('No valid feature variables found for correlation matrix.');
    else
        X = BURST_FEATURES(:, corrVars);

        % Convert to numeric matrix
        Xmat = nan(height(X), numel(corrVars));
        for i = 1:numel(corrVars)
            Xmat(:, i) = X.(corrVars{i});
        end

        % Remove rows that are all NaN
        Xmat = Xmat(~all(isnan(Xmat),2), :);

        % Spearman is often safer than Pearson for skewed burst features
        [R, P] = corr(Xmat, 'Type', 'Spearman', 'Rows', 'pairwise');

        % Save numeric results
        corrTable = array2table(R, 'VariableNames', corrVars, 'RowNames', corrVars);
        writetable(corrTable, fullfile(corrOutDir, 'clustering_feature_correlation_matrix.csv'), 'WriteRowNames', true);

        pTable = array2table(P, 'VariableNames', corrVars, 'RowNames', corrVars);
        writetable(pTable, fullfile(corrOutDir, 'clustering_feature_correlation_pvalues.csv'), 'WriteRowNames', true);

        % Plot correlation heatmap
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 900 800]);
        imagesc(R);
        axis equal tight;
        colorbar;
        clim([-1 1]);

        set(gca, 'XTick', 1:numel(corrVars), 'XTickLabel', corrVars, 'YTick', 1:numel(corrVars), 'YTickLabel', corrVars, 'XTickLabelRotation', 45);

        title('Feature correlation matrix (Spearman)');
        exportgraphics(fig, fullfile(corrOutDir, 'clustering_feature_correlation_matrix.png'), 'Resolution', 200);
        close(fig);

        fprintf('\nSaved feature correlation matrix in:\n%s\n', corrOutDir);
    end

    %% ===================== CLUSTERING =====================
    rng(DC_P.randomSeed);

    % ===================== LOAD OR REUSE TABLE =====================
    matFile = fullfile(DF_IO.out_dir, DF_IO.output_mat);
    fprintf('\nChecking for existing BURST_FEATURES on path\n%s\n', matFile);

    if exist('BURST_FEATURES', 'var') && height(BURST_FEATURES) > 0
        fprintf('Using BURST_FEATURES already present in workspace.\n');
    else
        if ~exist(matFile, 'file')
            error('BURST_FEATURES.mat not found. Please run the feature extraction part first.');
        end

        S = load(matFile, 'BURST_FEATURES');

        if ~isfield(S, 'BURST_FEATURES')
            error('The file BURST_FEATURES.mat does not contain a variable named BURST_FEATURES.');
        end

        BURST_FEATURES = S.BURST_FEATURES;
        fprintf('Loaded BURST_FEATURES from:\n%s\n', matFile);
    end

    [CLUSTER_RESULTS, BURST_FEATURES_CLUSTERED] = run_flexible_clustering(BURST_FEATURES, DC_P);

    writetable(BURST_FEATURES_CLUSTERED, fullfile(DC_IO.csv_dir, DC_IO.output_clustered_csv));

    plot_clustering_scores(CLUSTER_RESULTS, DC_IO.plot_dir);
    plot_cluster_feature_histograms(BURST_FEATURES_CLUSTERED, CLUSTER_RESULTS, DC_P.featureVars, DC_IO.plot_dir);

    fprintf('\nClustering results (.mat) saved in:\n%s\n ', DC_IO.cluster_dir);
    fprintf('\nClustering results (.csv) saved in:\n%s\n', DC_IO.csv_dir);

    disp_tree(CLUSTER_RESULTS, DC_I.disp_tree_depth);
    disp_tree(BURST_FEATURES_CLUSTERED, DC_I.disp_tree_depth);

    %% ===================== MANUAL CLUSTER INTERPRETATION =====================
    % Define which clusters are considered CLEAN for each grouping level.
    % For DC_P.groupVar == "muscle", keys should match muscle names.
    % For DC_P.groupVar == "ALL", use key "ALL".
    % For DC_P.groupVar == "condition", use condition names, etc.

    % ===================== MANUAL CLUSTER INTERPRETATION CHECKPOINT =====================
    fprintf('\nClustering finished.\n');
    fprintf('You should now inspect the plots and update DM_KEEP.\n');
    fprintf('Suggested files to inspect:\n');
    fprintf(' - silhouette plots\n');
    fprintf(' - cluster feature histograms\n');
    fprintf(' - random signal plots\n\n');
    fprintf('Current clusters to keep:\n');
    KEEP_prev = get_keep_map_from_config(DC_P.groupVar, DM_KEEP);
    disp(KEEP_prev);

    fprintf('After inspecting the results, update the DM_KEEP variable in config_emg.m to specify which clusters to keep for each group.\n');
    fprintf('\nPress any key after saving config_emg.m...\n');
    pause;

    clear config_emg
    rehash

    C = config_emg();
    DM_KEEP = C.d_cluster_manual.keep;

    KEEP = get_keep_map_from_config(DC_P.groupVar, DM_KEEP);
    fprintf('\nApplying manual cluster keep map for groupVar "%s":\n', DC_P.groupVar);
    disp(KEEP);

    [BURST_FEATURES_CLUSTERED, CLUSTER_RESULTS] = apply_manual_cluster_keep_map( BURST_FEATURES_CLUSTERED, CLUSTER_RESULTS, DC_P, KEEP);

    save(fullfile(DC_IO.cluster_dir, DC_IO.output_results_mat), 'CLUSTER_RESULTS', 'BURST_FEATURES_CLUSTERED', 'DC_P', '-v7.3');

    %% ===================== RECAP: ACCEPTED / REJECTED BY MUSCLE =====================

    assert(ismember('muscle', BURST_FEATURES_CLUSTERED.Properties.VariableNames), 'muscle column not found in BURST_FEATURES_CLUSTERED.');
    assert(ismember('cluster_valid', BURST_FEATURES_CLUSTERED.Properties.VariableNames), 'cluster_valid column not found in BURST_FEATURES_CLUSTERED.');
    assert(ismember('cluster_good', BURST_FEATURES_CLUSTERED.Properties.VariableNames), 'cluster_good column not found in BURST_FEATURES_CLUSTERED.');

    Trecap = BURST_FEATURES_CLUSTERED(BURST_FEATURES_CLUSTERED.cluster_valid == true, :);

    muscles = unique(string(Trecap.muscle));
    muscles(ismissing(muscles) | muscles == "") = [];
    muscles = sort(muscles);

    RECAP_CLUSTER_BY_MUSCLE = table();

    for iM = 1:numel(muscles)
        thisMuscle = muscles(iM);
        idx = string(Trecap.muscle) == thisMuscle;

        n_total    = sum(idx);
        n_keep     = sum(Trecap.cluster_good(idx));
        n_reject   = sum(~Trecap.cluster_good(idx));
        pct_keep   = 100 * n_keep   / max(n_total,1);
        pct_reject = 100 * n_reject / max(n_total,1);

        row = table( thisMuscle, n_total, n_keep, n_reject, pct_keep, pct_reject, 'VariableNames', {'muscle','n_total','n_keep','n_reject','pct_keep','pct_reject'});

        RECAP_CLUSTER_BY_MUSCLE = [RECAP_CLUSTER_BY_MUSCLE; row];
    end

    disp('=== Accepted / Rejected bursts by muscle ===');
    disp(RECAP_CLUSTER_BY_MUSCLE);

    writetable(RECAP_CLUSTER_BY_MUSCLE, fullfile(DC_IO.cluster_dir, 'RECAP_CLUSTER_BY_MUSCLE.csv'));

    %% ===================== PLOT RANDOM SIGNALS WITH FINAL DECISIONS =====================
    plot_random_cluster_decisions_final( BURST_FEATURES_CLUSTERED, DF_IO.in_dir, DM_QC, DM_IO.final_plot_dir);

    %% ===================== PLOT SELECTED CLUSTER DECISION EXAMPLE =====================

    % Reload config in case you just want to run this section without running whats above

    C = config_emg();
    DF_IO = C.d_features.io;
    DC_IO   = C.d_clustering.io;
    DM_IO   = C.d_cluster_manual.io;

    subject   = 'CTL_79';
    condition = 'Flat';
    leg       = 'right';
    muscle    = 'EMG_TAdist_Concat';

    plot_selected_cluster_decision_final( subject, condition, leg, muscle, DF_IO.in_dir, DC_IO.cluster_dir, DC_IO.output_results_mat, DM_IO.final_plot_dir);

    %% ===================== LOCAL FUNCTIONS =====================
end