function [T, S] = audit_wavelet_transform_scope(varargin)
% AUDIT_WAVELET_TRANSFORM_SCOPE  How much do glue points between kept cycles
% change the coherence?
%
%   audit_wavelet_transform_scope()                          FULL and ALPHA
%   [T,S] = audit_wavelet_transform_scope('Datasets',"ALPHA") one dataset
%
% Options
%   'Datasets'  dataset names from C.g_coherence.io.input_sets (default ["FULL","ALPHA"])
%   'Scopes'    "concatenated" plus any per_trial context policies
%               (default ["concatenated","kept_blocks","trial_run_safe"])
%   'OutDir'    default Results/g_emg_emg_wavelet_coherence/transform_scope_audit
%   'ArchiveDir' folder with the COHERENCE_SUMMARY_TABLE_<DATASET>.csv of the
%               run before the junction fix, used to check that the
%               "concatenated" scope reproduces it
%               (default Results/_archive_before_correctness_round/g_emg_emg_wavelet_coherence)
%   'FromRows'  path of a saved TRANSFORM_SCOPE_AUDIT_ROWS.csv: skip the
%               recomputation and only rebuild the summary and reproduction check
%
% Stage f glues kept cycles end to end and, before 2026-10, stage g ran one
% wavelet transform over the result, so the wavelet saw a jump at every
% glue point (a trial boundary or a rejected cycle in between). This
% recomputes the equalized coherence of every included pair exactly as g
% does (same masks, same N_common, same POI metrics) under each scope and
% compares them.
%
% Output (CSV):
%   TRANSFORM_SCOPE_AUDIT_ROWS.csv     pair x band x scope: POI AUC_norm,
%                                      edge (first+last 20% of the cycle) and
%                                      mid coherence, segment counts, and the
%                                      share of each equalized cycle's
%                                      neighbours that are trial junctions,
%                                      rejection gaps or contiguous
%   TRANSFORM_SCOPE_AUDIT_SUMMARY.csv  dataset x pair x band x scope: paired
%                                      change vs "concatenated" (median, IQR,
%                                      signrank p), and its Spearman
%                                      correlation with the junction share
%   TRANSFORM_SCOPE_REPRODUCTION.csv   "concatenated" vs the archived g table
%
% Lives in Tools/ like the other diagnostics; needs the stage-f outputs with
% cycle_run_id (2026-10 and later).

opt = parse_args(varargin);
C   = config_emg();
addpath(genpath(C.paths.helpers.coherence));
addpath(genpath(C.paths.toolboxes.wtc));

W0 = C.g_coherence.params;
GP = C.g_coherence.group_plot;

if isempty(opt.OutDir), opt.OutDir = fullfile(C.g_coherence.io.summary_csv_dir, 'transform_scope_audit'); end
if isempty(opt.ArchiveDir)
    opt.ArchiveDir = fullfile(C.paths.results_dir, '_archive_before_correctness_round', 'g_emg_emg_wavelet_coherence');
end
if ~isfolder(opt.OutDir), mkdir(opt.OutDir); end

if ~isempty(opt.FromRows)
    T = readtable(opt.FromRows, 'TextType', 'string');
else
rows = {};
for dsName = upper(string(opt.Datasets))
    set = find(cellfun(@(s) upper(string(s.name)) == dsName, C.g_coherence.io.input_sets), 1);
    if isempty(set), error('Unknown dataset %s', dsName); end
    inFile = C.g_coherence.io.input_sets{set}.mat_file;
    fprintf('\n=== Transform-scope audit: %s ===\n%s\n', dsName, inFile);

    DS = get_dataset_specific_coherence_settings(dsName, W0, GP);
    FPS = load_final_paired_signals_file(inFile);
    Ncommon = struct();

    for subj = string(fieldnames(FPS))'
        for cond = string(fieldnames(FPS.(subj)))'
            for leg = string(fieldnames(FPS.(subj).(cond)))'
                for pair = string(fieldnames(FPS.(subj).(cond).(leg)))'
                    P = FPS.(subj).(cond).(leg).(pair);
                    if ~isfield(P, 'included_after_crosstalk') || ~P.included_after_crosstalk, continue; end
                    Tseg = P.final_cycle_segments_table;
                    x1 = P.final_concatenated_signal_1(:);
                    x2 = P.final_concatenated_signal_2(:);
                    if isempty(x1) || isempty(Tseg), continue; end

                    [mask, mro, mao, mam] = build_analysis_cycle_masks(Tseg, W0, subj, cond, leg, pair);
                    if isempty(mask), continue; end
                    if ~isfield(Ncommon, pair)
                        Ncommon.(pair) = get_min_analysis_cycles_in_dataset(FPS, W0, char(pair));
                    end
                    eqMask = select_equalized_cycle_mask(mask, Ncommon.(pair), W0.cycle_equalization, subj, cond, leg, pair);

                    J = neighbour_types(Tseg, eqMask);
                    Args = WaveletParameters(DS.FreqMin_this, DS.FreqMax_this, W0.Resolution, W0.WaveNumber, P.fs);

                    for scope = string(opt.Scopes)
                        W = W0;
                        if scope == "concatenated"
                            W.transform_scope = "concatenated";
                        else
                            W.transform_scope = "per_trial";
                            W.per_trial.context_policy = scope;
                        end
                        [TFR1, TFR2, coi1, coi2, period, ~, ~, tinfo] = compute_pair_tfr(x1, x2, Tseg, P, W, Args);
                        Freq = 1 ./ period;
                        core = compute_cycle_interpolated_coherence_core(TFR1, TFR2, coi1, coi2, Tseg, Freq, eqMask, mro, mao, mam, W, DS);
                        poi  = compute_pair_poi_coherence_metrics(core.Coherence, Freq, pair, C, DS.FreqBands_this, DS.FullBandRange_this, DS.computeFullBandMetrics);

                        for band = string(fieldnames(DS.FreqBands_this))'
                            fr = DS.FreqBands_this.(band);
                            [edgeC, midC] = edge_mid(core.Coherence, Freq, fr);
                            rows(end+1, :) = {dsName, subj, cond, leg, pair, scope, band, ...
                                poi.auc_coherence_poi_norm.(band), edgeC, midC, edgeC - midC, core.Ncycle, ...
                                tinfo.n_segments, tinfo.n_context_cycles, tinfo.fallback, string(tinfo.note), ...
                                J.trial_junction, J.rejection_gap, J.contiguous, J.signal_edge}; %#ok<AGROW>
                        end
                    end
                end
            end
        end
        fprintf('  %s done\n', subj);
    end
    clear FPS
end

T = cell2table(rows, 'VariableNames', {'dataset','subject','condition','leg','pair_name','scope','band', ...
    'auc_norm_poi','edge_coh','mid_coh','edge_minus_mid','n_cycles', ...
    'n_segments','n_context_cycles','fallback','note', ...
    'share_trial_junction','share_rejection_gap','share_contiguous','share_signal_edge'});
writetable(T, fullfile(opt.OutDir, 'TRANSFORM_SCOPE_AUDIT_ROWS.csv'));
end

S = summarise(T);
writetable(S, fullfile(opt.OutDir, 'TRANSFORM_SCOPE_AUDIT_SUMMARY.csv'));

R = check_reproduction(T, opt.ArchiveDir);
writetable(R, fullfile(opt.OutDir, 'TRANSFORM_SCOPE_REPRODUCTION.csv'));

fprintf('\nWrote %s\n', opt.OutDir);
disp(S(:, {'dataset','pair_name','band','scope','n','median_delta','q25_delta','q75_delta','p_signrank','rho_junction_share'}));
disp(R);
end

% ---------------------------------------------------------------------------

function J = neighbour_types(Tseg, eqMask)
% Share of the boundaries of the equalized cycles (two per cycle) that sit
% next to a trial junction, a rejection gap, a contiguous kept cycle or the
% end of the concatenated signal
    k = find(eqMask(:));
    t = strings(0, 1);
    hasRun = ismember('run_id', Tseg.Properties.VariableNames);
    for r = k'
        for nb = [r-1, r+1]
            if nb < 1 || nb > height(Tseg)
                t(end+1) = "signal_edge"; %#ok<AGROW>
            elseif ~hasRun || isnan(Tseg.run_id(r)) || isnan(Tseg.run_id(nb))
                t(end+1) = "unknown"; %#ok<AGROW>
            elseif Tseg.run_id(nb) == Tseg.run_id(r) && abs(Tseg.cycle_number(nb) - Tseg.cycle_number(r)) == 1
                t(end+1) = "contiguous"; %#ok<AGROW>
            elseif Tseg.trial_id(nb) == Tseg.trial_id(r)
                t(end+1) = "rejection_gap"; %#ok<AGROW>
            else
                t(end+1) = "trial_junction"; %#ok<AGROW>
            end
        end
    end
    n = max(numel(t), 1);
    J = struct('trial_junction', sum(t == "trial_junction") / n, 'rejection_gap', sum(t == "rejection_gap") / n, ...
        'contiguous', sum(t == "contiguous") / n, 'signal_edge', sum(t == "signal_edge") / n);
end

function [edgeC, midC] = edge_mid(Coh, Freq, fr)
% Mean coherence in the band over the first+last 20% of the cycle vs the middle 60%
    rowsF = Freq >= fr(1) & Freq <= fr(2);
    nT = size(Coh, 2);
    nE = round(0.2 * nT);
    isEdge = false(1, nT);
    isEdge([1:nE, nT-nE+1:nT]) = true;
    A = Coh(rowsF, :);
    edgeC = mean(A(:, isEdge), 'all', 'omitnan');
    midC  = mean(A(:, ~isEdge), 'all', 'omitnan');
end

function S = summarise(T)
    keys = {'dataset','subject','condition','leg','pair_name','band'};
    base = T(T.scope == "concatenated", [keys, {'auc_norm_poi','edge_minus_mid'}]);
    base = renamevars(base, {'auc_norm_poi','edge_minus_mid'}, {'auc_norm_poi_base','edge_minus_mid_base'});
    out = {};
    for scope = setdiff(unique(T.scope), "concatenated")'
        X = innerjoin(T(T.scope == scope, :), base, 'Keys', keys);
        d = X.auc_norm_poi - X.auc_norm_poi_base;
        dEdge = X.edge_minus_mid - X.edge_minus_mid_base;
        junction = X.share_trial_junction + X.share_rejection_gap;
        G = findgroups(X.dataset, X.pair_name, X.band);
        for g = 1:max(G)
            i = G == g & isfinite(d);
            if ~any(i), continue; end
            q = quantile(d(i), [0.25 0.5 0.75]);
            p = NaN; rho = NaN;
            if sum(i) >= 5
                p = signrank(d(i));
                rho = corr(d(i), junction(i), 'Type', 'Spearman', 'Rows', 'complete');
            end
            j = find(i, 1);
            out(end+1, :) = {X.dataset(j), X.pair_name(j), X.band(j), scope, sum(i), ...
                median(X.auc_norm_poi_base(i)), q(2), q(1), q(3), mean(d(i) < 0), p, ...
                median(dEdge(i)), rho, median(junction(i))}; %#ok<AGROW>
        end
    end
    S = cell2table(out, 'VariableNames', {'dataset','pair_name','band','scope','n', ...
        'median_auc_norm_concatenated','median_delta','q25_delta','q75_delta','share_decreased','p_signrank', ...
        'median_delta_edge_minus_mid','rho_junction_share','median_junction_share'});
end

function R = check_reproduction(T, archiveDir)
% "concatenated" must reproduce the archived g summary (<Band>_AUC_norm_POI)
    out = {};
    base = T(T.scope == "concatenated", :);
    for ds = unique(base.dataset)'
        f = fullfile(archiveDir, sprintf('COHERENCE_SUMMARY_TABLE_%s.csv', ds));
        if ~isfile(f)
            out(end+1, :) = {ds, "", 0, NaN, "archive_missing"}; %#ok<AGROW>
            continue;
        end
        A = readtable(f, 'TextType', 'string');
        A = A(A.metric_source == "equalized", :);
        for band = unique(base.band(base.dataset == ds))'
            col = band + "_AUC_norm_POI";
            if ~ismember(col, A.Properties.VariableNames), continue; end
            B = base(base.dataset == ds & base.band == band, :);
            [tf, loc] = ismember(B.subject + B.condition + B.leg + B.pair_name, ...
                A.subject + A.condition + A.leg + A.pair_name);
            d = abs(B.auc_norm_poi(tf) - A.(col)(loc(tf)));
            out(end+1, :) = {ds, band, sum(tf), max(d, [], 'omitnan'), ...
                string(sprintf('%d of %d pairs matched', sum(tf), height(B)))}; %#ok<AGROW>
        end
    end
    R = cell2table(out, 'VariableNames', {'dataset','band','n_matched','max_abs_diff','note'});
end

function opt = parse_args(args)
    p = inputParser;
    p.addParameter('Datasets', ["FULL","ALPHA"]);
    p.addParameter('Scopes', ["concatenated","kept_blocks","trial_run_safe"]);
    p.addParameter('OutDir', '');
    p.addParameter('ArchiveDir', '');
    p.addParameter('FromRows', '');
    p.parse(args{:});
    opt = p.Results;
end
