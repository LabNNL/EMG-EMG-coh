%% e_final_burst_qc_combination.m
% Final burst-level QC decision after rule-based cleaning, clustering,
% and optional visual mapping.
%
% GOAL
% -------------------------------------------------------------------------
% Build the final keep / reject decision for every detected burst by
% combining:
%   1) signal-level visual mapping (optional; only score 3 excludes)
%   2) signal-level rule-based QC (FAIL excludes the whole signal)
%   3) burst-level rule-based QC
%   4) burst-level clustering decision
%
% DECISION LOGIC
% -------------------------------------------------------------------------
% 1) If visual mapping is enabled and a signal has visual_score == 3:
%       -> reject all bursts in that signal
%
% 2) Else, if the signal-level rule-based QC status is FAIL:
%       -> reject all bursts in that signal
%
% 3) Else, combine burst-level rule-based and clustering decisions:
%       - if both say good  -> keep
%       - if both say bad   -> reject
%       - if they disagree  -> resolve using P.decision_rule:
%             "conservative" -> reject
%             "inclusive"    -> keep
%
% IMPORTANT
% -------------------------------------------------------------------------
% - Visual mapping is signal-level only in this script.
% - Visual scores 0 / 1 / 2 do not directly affect burst-level decisions.
% - Visual mapping can be disabled with:
%       P.use_visual_mapping = false
% - Muscle names from visual mapping are matched after removing "_Concat"
%   from burst-file muscle field names.
%
% INPUTS
% -------------------------------------------------------------------------
% From config_emg():
%   IO.rule_based_mat   -> QC_bursts.mat
%   IO.cluster_mat      -> CLUSTER_RESULTS.mat
%   IO.visual_xlsm      -> Mapping-EMG.xlsm (if enabled)
%
% MAIN OUTPUTS
% -------------------------------------------------------------------------
%   FINAL_BURST_QC.mat
%       hierarchical struct with signal-level and burst-level final decisions
%
%   FINAL_BURST_QC_summary.csv
%       flat table with one row per burst, including:
%       - visual info
%       - signal-level rule-based info
%       - burst-level rule-based info
%       - clustering info
%       - final keep / reject decision
%       - final_reason
%
% OPTIONAL OUTPUTS
% -------------------------------------------------------------------------
% - Random signal-level QC plots
% - Histograms of bad burst location within the gait cycle
% - Random single-burst example plots by exclusion category / reason
%
% NOTES
% -------------------------------------------------------------------------
% This file is intended to be the final decision stage before rebuilding
% cleaned signals and paired signals for downstream coherence analysis.

function e_final_burst_qc_combination()

    C = config_emg();

    IO = C.e_final_burst_qc.io;
    P  = C.e_final_burst_qc.params;
    PL = C.e_final_burst_qc.plot;
    I  = C.e_final_burst_qc.inspect;

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.burst_qc));

    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.csv_dir, 'dir'), mkdir(IO.csv_dir); end
    if ~exist(PL.out_dir, 'dir'), mkdir(PL.out_dir); end

    %% ===================== BASIC CHECKS =====================
    assert(isfile(IO.rule_based_mat), 'Rule-based QC mat not found: %s', IO.rule_based_mat);
    assert(isfile(IO.cluster_mat),      'Cluster mat not found: %s', IO.cluster_mat);

    if P.use_visual_mapping
        assert(isfile(IO.visual_xlsm), 'Visual mapping file not found: %s', IO.visual_xlsm);
    end
    %% ===================== LOAD RULE-BASED QC =====================
    Lq = load(IO.rule_based_mat);
    assert(isfield(Lq, 'BURST_QC'), 'BURST_QC not found in QC_bursts.mat');
    BURST_QC = Lq.BURST_QC;

    %% ===================== LOAD CLUSTERING =====================
    Lc = load(IO.cluster_mat);
    assert(isfield(Lc, 'BURST_FEATURES_CLUSTERED'), 'BURST_FEATURES_CLUSTERED not found in CLUSTER_RESULTS.mat');

    Tclust = Lc.BURST_FEATURES_CLUSTERED;

    assert(ismember('cluster_good', Tclust.Properties.VariableNames), 'cluster_good not found in BURST_FEATURES_CLUSTERED. Please run d_a_clustering with manual keep mapping.');

    assert(ismember('cluster_valid', Tclust.Properties.VariableNames), 'cluster_valid not found in BURST_FEATURES_CLUSTERED.');

    Tclust.cluster_good  = logical(Tclust.cluster_good);
    Tclust.cluster_valid = logical(Tclust.cluster_valid);

    Tclust.subject      = string(Tclust.subject);
    Tclust.condition    = string(Tclust.condition);
    Tclust.leg          = lower(string(Tclust.leg));
    Tclust.muscle       = string(Tclust.muscle);
    Tclust.burst_number = double(Tclust.burst_number);

    % Tclust.cluster_good = ismember(Tclust.cluster_id, D.cluster_labels_to_keep);

    if ~ismember('burst_id', Tclust.Properties.VariableNames)
        Tclust.burst_id = strings(height(Tclust),1);
        for i = 1:height(Tclust)
            Tclust.burst_id(i) = sprintf('%s__%s__%s__%s__%04d', Tclust.subject(i), Tclust.condition(i), Tclust.leg(i), Tclust.muscle(i), Tclust.burst_number(i));
        end
    end

    clusterMap = containers.Map('KeyType','char','ValueType','any');
    for i = 1:height(Tclust)
        tmpStruct = struct( 'cluster_id', Tclust.cluster_id(i), 'cluster_good', logical(Tclust.cluster_good(i)), 'cluster_valid', logical(Tclust.cluster_valid(i)));

        if ismember('cluster_decision_reason', Tclust.Properties.VariableNames)
            tmpStruct.cluster_decision_reason = string(Tclust.cluster_decision_reason(i));
        else
            tmpStruct.cluster_decision_reason = "";
        end

        clusterMap(char(Tclust.burst_id(i))) = tmpStruct;
    end

    %% ===================== LOAD VISUAL MAPPING =====================
    if P.use_visual_mapping
        fprintf('Visual mapping enabled. Loading visual mapping from:\n%s (sheet: %s)\n', IO.visual_xlsm, IO.visual_sheet);
        visualT = parse_visual_mapping_xlsm(IO.visual_xlsm, IO.visual_sheet);


        visualT.subjID     = string(visualT.subjID);
        visualT.condition  = string(visualT.condition);
        visualT.leg        = lower(string(visualT.leg));
        visualT.muscleName = string(visualT.muscleName);
    else
        fprintf('Visual mapping disabled. Change P.use_visual_mapping to true and set IO.visual_xlsm and IO.visual_sheet to enable.\n');
        visualT = table();
    end
    %% ===================== MAIN LOOP =====================
    FINAL_BURST_QC = struct();
    rows = {};
    ri = 0;

    subjects = fieldnames(BURST_QC);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        fprintf('\n=== FINAL BURST QC: %s ===\n', subjID);

        conds = fieldnames(BURST_QC.(subjID));
        for ic = 1:numel(conds)
            cond = conds{ic};

            legs = fieldnames(BURST_QC.(subjID).(cond));
            for il = 1:numel(legs)
                leg = legs{il};

                muscles = fieldnames(BURST_QC.(subjID).(cond).(leg));
                for im = 1:numel(muscles)
                    mf = muscles{im};
                    E = BURST_QC.(subjID).(cond).(leg).(mf);

                    if ~isstruct(E), continue; end
                    if ~isfield(E,'bursts_idx') || isempty(E.bursts_idx), continue; end

                    nB = size(E.bursts_idx,1);
                    bursts_idx = E.bursts_idx;

                    % ---------- Signal-level rule based info ----------
                    if isfield(E,'signal_status') && ~isempty(E.signal_status)
                        signal_rule_based_status = string(E.signal_status);
                    else
                        signal_rule_based_status = "UNKNOWN";
                    end

                    if isfield(E,'signal_reason') && ~isempty(E.signal_reason)
                        signal_rule_based_reason = string(E.signal_reason);
                    else
                        signal_rule_based_reason = "";
                    end

                    % ---------- Burst-level rule based info ----------
                    if isfield(E,'burst_keep_mask') && ~isempty(E.burst_keep_mask)
                        rule_based_keep = logical(E.burst_keep_mask(:));
                    else
                        rule_based_keep = true(nB,1);
                    end

                    if isfield(E,'burst_reason') && ~isempty(E.burst_reason)
                        rule_based_reason = string(E.burst_reason(:));
                    else
                        rule_based_reason = repmat("", nB, 1);
                    end

                    % ---------- Signal-level visual lookup ----------
                    if P.use_visual_mapping
                        mf_vis = erase(string(mf), "_Concat");

                        visRow = visualT( visualT.subjID == string(subjID) & visualT.condition == string(cond) & visualT.leg == string(lower(leg)) & visualT.muscleName == mf_vis, :);

                        visual_present = ~isempty(visRow);
                        if not (visual_present)
                            warning('No visual mapping found for %s | %s | %s | %s. This signal will be treated as having no visual mapping.', subjID, cond, leg, mf);
                        end
                        visual_score   = NaN;

                        if visual_present
                            visual_score = visRow.visual_score(1);
                        end

                        signal_visual_fail = visual_present && visual_score == 3;
                    else
                        %fprintf('Visual mapping disabled. Change P.use_visual_mapping to true to enable.\n');
                        visual_present = false;
                        visual_score   = NaN;
                        signal_visual_fail = false;
                    end

                    if signal_visual_fail
                        signal_visual_reason = "visual_score_3";
                    else
                        signal_visual_reason = "";
                    end

                    % ---------- Cluster info per burst ----------
                    cluster_id    = nan(nB,1);
                    cluster_good  = false(nB,1);
                    cluster_valid = false(nB,1);
                    cluster_reason = strings(nB,1);

                    for iB = 1:nB
                        burst_id = sprintf('%s__%s__%s__%s__%04d', subjID, cond, leg, mf, iB);

                        if isKey(clusterMap, burst_id)
                            tmp = clusterMap(burst_id);
                            cluster_id(iB)    = tmp.cluster_id;
                            cluster_good(iB)  = logical(tmp.cluster_good);
                            cluster_valid(iB) = logical(tmp.cluster_valid);
                            cluster_reason(iB)= string(tmp.cluster_decision_reason);
                        else
                            cluster_id(iB)    = NaN;
                            cluster_valid(iB) = false;
                            cluster_good(iB)  = false;
                            cluster_reason(iB)= "missing_from_cluster_table";
                        end
                    end

                    % ---------- Final decision ----------
                    final_keep   = false(nB,1);
                    final_reason = strings(nB,1);

                    if signal_visual_fail
                        final_keep(:)   = false;
                        final_reason(:) = "visual_signal_3";

                    elseif signal_rule_based_status == "FAIL"
                        final_keep(:)   = false;
                        final_reason(:) = "rule_based_signal_fail";

                    else
                        for iB = 1:nB
                            ruleGood = rule_based_keep(iB);
                            cluGood = cluster_good(iB);

                            if ruleGood && cluGood
                                final_keep(iB) = true;
                                final_reason(iB) = "rule_based_good+cluster_good";

                            elseif ~ruleGood && ~cluGood
                                final_keep(iB) = false;
                                if cluster_valid(iB)
                                    final_reason(iB) = "rule_based_bad+cluster_bad";
                                else
                                    final_reason(iB) = "rule_based_bad+cluster_missing";
                                end

                            else
                                if P.decision_rule == "conservative"
                                    final_keep(iB) = false;

                                    if ruleGood && ~cluGood
                                        if cluster_valid(iB)
                                            final_reason(iB) = "disagreement_conservative_rule_based_good_cluster_bad";
                                        else
                                            final_reason(iB) = "disagreement_conservative_rule_based_good_cluster_missing";
                                        end
                                    else
                                        final_reason(iB) = "disagreement_conservative_rule_based_bad_cluster_good";
                                    end

                                elseif P.decision_rule == "inclusive"
                                    final_keep(iB) = true;

                                    if ruleGood && ~cluGood
                                        if cluster_valid(iB)
                                            final_reason(iB) = "disagreement_inclusive_rule_based_good_cluster_bad";
                                        else
                                            final_reason(iB) = "disagreement_inclusive_rule_based_good_cluster_missing";
                                        end
                                    else
                                        final_reason(iB) = "disagreement_inclusive_rule_based_bad_cluster_good";
                                    end
                                else
                                    error('Unknown decision_rule: %s', P.decision_rule);
                                end
                            end
                        end
                    end

                    % ---------- Save struct ----------
                    FINAL_BURST_QC = ensure_final_fields(FINAL_BURST_QC, subjID, cond, leg);

                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).visual_present           = visual_present;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).visual_score             = visual_score;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).signal_visual_fail       = signal_visual_fail;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).signal_visual_reason = signal_visual_reason;

                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).signal_rule_based_status  = signal_rule_based_status;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).signal_rule_based_reason  = signal_rule_based_reason;

                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).bursts_idx       = bursts_idx;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).rule_based_keep   = rule_based_keep;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).rule_based_reason = rule_based_reason;

                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).cluster_id       = cluster_id;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).cluster_good     = cluster_good;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).cluster_valid    = cluster_valid;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).cluster_reason = cluster_reason;

                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).final_keep_mask  = final_keep;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).final_reason     = final_reason;
                    FINAL_BURST_QC.(subjID).(cond).(leg).(mf).bad_bursts_idx   = find(~final_keep);

                    % ---------- Summary rows ----------
                    for iB = 1:nB
                        ri = ri + 1;
                        rows(ri,:) = { string(subjID), string(cond), string(leg), string(mf), iB, bursts_idx(iB,1), bursts_idx(iB,2), visual_present, visual_score, signal_visual_fail, string(signal_visual_reason), string(signal_rule_based_status), string(signal_rule_based_reason), rule_based_keep(iB), string(rule_based_reason(iB)), cluster_id(iB), cluster_valid(iB), cluster_good(iB), string(cluster_reason(iB)), final_keep(iB), string(final_reason(iB)) };
                    end

                    fprintf('  %s | %s | %s -> kept %d / %d\n', cond, leg, mf, sum(final_keep), nB);
                end
            end
        end
    end

    %% ===================== SAVE =====================
    fprintf('\nSaving final QC results to:\n%s\n', IO.out_mat);
    if ~isempty(rows)
        FINAL_QC_TABLE = cell2table(rows, 'VariableNames', { 'subject','condition','leg','muscle','burst_number','start_idx','end_idx', 'visual_present','visual_score','signal_visual_fail','signal_visual_reason', 'signal_rule_based_status','signal_rule_based_reason', 'rule_based_keep','rule_based_reason', 'cluster_id','cluster_valid','cluster_good', 'cluster_reason', 'final_keep','final_reason'});
    else
        FINAL_QC_TABLE = table();
    end

    save(IO.out_mat, 'FINAL_BURST_QC', 'FINAL_QC_TABLE', 'IO', 'P', 'PL', 'I', '-v7.3');
    fprintf('Saved MAT:\n%s\n', IO.out_mat);
    writetable(FINAL_QC_TABLE, IO.out_csv);
    fprintf('Saved CSV:\n%s\n', IO.out_csv);

    %% ====================== DISPLAY SUMMARY =====================
    fprintf('\nFinal burst QC summary:\n');
    if ~isempty(FINAL_QC_TABLE)
        disp_tree(FINAL_BURST_QC, C.e_final_burst_qc.inspect.disp_tree_depth);
    else
        fprintf('No bursts found in FINAL_QC_TABLE.\n');
    end

    %% ===================== RANDOM FINAL QC PLOTS =====================
    if PL.enable && ~isempty(FINAL_QC_TABLE)
        rng('shuffle');  % different random sample each launch

        burstFiles = dir(fullfile(IO.bursts_dir, '*_EMG_BURSTS.mat'));
        burstMap = containers.Map('KeyType','char','ValueType','char');
        for k = 1:numel(burstFiles)
            tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
            if ~isempty(tok)
                burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
            end
        end

        % unique signals
        signalKeys = unique(FINAL_QC_TABLE(:, {'subject','condition','leg','muscle'}), 'rows');
        nAvail = height(signalKeys);
        nPlot = min(PL.n_random_signals, nAvail);

        if nPlot > 0
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                row = signalKeys(idxPick(ip), :);

                subjID = char(row.subject);
                cond   = char(row.condition);
                leg    = char(row.leg);
                mf     = char(row.muscle);

                if ~isKey(burstMap, subjID)
                    warning('No burst file found for %s. Skipping plot.', subjID);
                    continue;
                end

                Lb = load(burstMap(subjID));
                % fieldnames(Lb)
                % fieldnames(Lb.BURSTS_DET.(subjID))
                % fieldnames(Lb.BURSTS_DET.(subjID).(cond))
                % fieldnames(Lb.BURSTS_DET.(subjID).(cond).(leg))

                if ~isfield(Lb, 'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
                    warning('BURSTS_DET missing for %s. Skipping plot.', subjID);
                    continue;
                end

                if ~isfield(Lb.BURSTS_DET.(subjID), cond) || ~isfield(Lb.BURSTS_DET.(subjID).(cond), leg) || ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mf)
                    warning('Signal not found in BURSTS_DET for %s | %s | %s | %s', subjID, cond, leg, mf);
                    continue;
                end

                Eplot = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf);
                % fieldnames(Eplot)

                if ~isfield(Eplot, 'signal') || isempty(Eplot.signal)
                    warning('No signal found for %s | %s | %s | %s', subjID, cond, leg, mf);
                    continue;
                end

                x = Eplot.signal(:);

                if isfield(Eplot, 'envelope') && ~isempty(Eplot.envelope)
                    x_env = Eplot.envelope(:);
                else
                    x_env = [];
                end

                if isfield(Eplot, 'fs') && ~isempty(Eplot.fs)
                    fs = Eplot.fs;
                elseif isfield(C, 'analysis') && isfield(C.analysis, 'fs_emg')
                    fs = C.analysis.fs_emg;
                else
                    fs = 2000;
                end

                % Try to recover cycle starts from common field names
                cycle_starts = [];

                candidateCycleFields = {'cycle_starts','gc_start_idx','gait_cycle_starts', 'heel_strikes','hs_idx','cycleStartIdx','starts_idx'};

                for icf = 1:numel(candidateCycleFields)
                    fn = candidateCycleFields{icf};
                    if isfield(Eplot, fn) && ~isempty(Eplot.(fn))
                        cycle_starts = Eplot.(fn)(:);
                        break;
                    end
                end
                % Try to recover toe off from common field names
                toe_off_concat = [];
                candidateToeOffFields = {'toe_off_concat'};

                for itf = 1:numel(candidateToeOffFields)
                    fn = candidateToeOffFields{itf};
                    if isfield(Eplot, fn) && ~isempty(Eplot.(fn))
                        toe_off_concat = Eplot.(fn)(:);
                        break;
                    end
                end

                Tsig = FINAL_QC_TABLE( FINAL_QC_TABLE.subject == string(subjID) & FINAL_QC_TABLE.condition == string(cond) & FINAL_QC_TABLE.leg == string(leg) & FINAL_QC_TABLE.muscle == string(mf), :);

                if isempty(Tsig)
                    continue;
                end

                plot_one_final_qc_signal(subjID, cond, leg, mf, fs, x, x_env, cycle_starts, toe_off_concat, Tsig, PL.out_dir, C);
            end
        end
    end

    fprintf('\nSaved MAT:\n%s\n', IO.out_mat);
    fprintf('Saved CSV:\n%s\n', IO.out_csv);

    if ~isempty(FINAL_QC_TABLE)
        disp(groupcounts(FINAL_QC_TABLE, "final_keep"));
    end
    %% ===================== BAD BURST LOCATION HISTOGRAMS =====================
    if PL.bad_burst_hist.enable && ~isempty(FINAL_QC_TABLE)
        fprintf('\nGenerating bad burst location histograms...\n');

        H = PL.bad_burst_hist;
        if ~exist(H.out_dir, 'dir'), mkdir(H.out_dir); end

        burstFiles = dir(fullfile(IO.bursts_dir, '*_EMG_BURSTS.mat'));
        burstMap = containers.Map('KeyType','char','ValueType','char');
        for k = 1:numel(burstFiles)
            tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
            if ~isempty(tok)
                burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
            end
        end

        rowsHist = {};
        rh = 0;

        signalKeys = unique(FINAL_QC_TABLE(:, {'subject','condition','leg','muscle'}), 'rows');
        oldsubjID = "";

        for isg = 1:height(signalKeys)
            subjID = char(signalKeys.subject(isg));
            cond   = char(signalKeys.condition(isg));
            leg    = char(signalKeys.leg(isg));
            mf     = char(signalKeys.muscle(isg));

            if ~strcmp(subjID, oldsubjID)
                fprintf('Processing subject %s...\n', subjID);
                oldsubjID = subjID;
            end

            if ~isKey(burstMap, subjID)
                continue;
            end

            Lb = load(burstMap(subjID));
            if ~isfield(Lb, 'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
                continue;
            end
            if ~isfield(Lb.BURSTS_DET.(subjID), cond) || ~isfield(Lb.BURSTS_DET.(subjID).(cond), leg) || ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mf)
                continue;
            end

            Eplot = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf);

            % recover cycle starts
            cycle_starts = [];
            candidateCycleFields = {'cycle_starts','gc_start_idx','gait_cycle_starts', 'heel_strikes','hs_idx','cycleStartIdx','starts_idx'};
            for icf = 1:numel(candidateCycleFields)
                fn = candidateCycleFields{icf};
                if isfield(Eplot, fn) && ~isempty(Eplot.(fn))
                    cycle_starts = Eplot.(fn)(:);
                    break;
                end
            end

            if isempty(cycle_starts)
                continue;
            end

            cycle_starts = cycle_starts(~isnan(cycle_starts));
            cycle_starts = unique(round(cycle_starts));
            cycle_starts = cycle_starts(cycle_starts >= 1);

            if numel(cycle_starts) < 2
                continue;
            end

            Tsig = FINAL_QC_TABLE( FINAL_QC_TABLE.subject == string(subjID) & FINAL_QC_TABLE.condition == string(cond) & FINAL_QC_TABLE.leg == string(leg) & FINAL_QC_TABLE.muscle == string(mf), :);

            if isempty(Tsig)
                continue;
            end

            % only bad bursts
            Tsig = Tsig(~Tsig.final_keep, :);
            if isempty(Tsig)
                continue;
            end

            for iB = 1:height(Tsig)
                mid_idx = round((Tsig.start_idx(iB) + Tsig.end_idx(iB)) / 2);

                % find cycle containing the midpoint
                iCycle = find(cycle_starts <= mid_idx, 1, 'last');

                if isempty(iCycle) || iCycle >= numel(cycle_starts)
                    continue;
                end

                cStart = cycle_starts(iCycle);
                cEnd   = cycle_starts(iCycle + 1) - 1;

                if cEnd <= cStart
                    continue;
                end
                if mid_idx < cStart || mid_idx > cEnd
                    continue;
                end

                pct_cycle = 100 * (mid_idx - cStart) / (cEnd - cStart);

                ruleBad = ~Tsig.rule_based_keep(iB);
                cluBad  = ~Tsig.cluster_good(iB);

                if ruleBad && cluBad
                    bad_type = "both_bad";
                elseif ruleBad && ~cluBad
                    bad_type = "rule_only";
                elseif ~ruleBad && cluBad
                    bad_type = "cluster_only";
                else
                    continue;
                end

                rh = rh + 1;
                rowsHist(rh,:) = { string(subjID), string(cond), string(leg), string(mf), Tsig.burst_number(iB), mid_idx, iCycle, pct_cycle, logical(ruleBad), logical(cluBad), bad_type };
            end
        end

        if ~isempty(rowsHist)
            badBurstHistT = cell2table(rowsHist, 'VariableNames', { 'subject','condition','leg','muscle','burst_number', 'mid_idx','cycle_number','pct_cycle', 'rule_bad','cluster_bad','bad_type'});

            writetable(badBurstHistT, H.out_csv);
        end
    elseif PL.bad_burst_hist.enable
        fprintf('\nNo bad bursts with valid cycle assignment were found for histogram plotting.\n');
    else
        fprintf('\nBad burst histogram generation is disabled. Skipping...\n');
    end

    %%

    if PL.bad_burst_hist.enable && exist('badBurstHistT', 'var') && ~isempty(badBurstHistT)
        if ~isempty(badBurstHistT)
            muscleList = unique(badBurstHistT.muscle);
            typeOrder = ["rule_only","cluster_only","both_bad"];
            typeTitles = ["Rule-based only bad","Cluster only bad","Both bad"];

            for im = 1:numel(muscleList)
                muscleName = muscleList(im);
                Tm = badBurstHistT(badBurstHistT.muscle == muscleName, :);

                if isempty(Tm)
                    continue;
                end

                fig = figure('Visible','off','Color','w','Position',[100 100 1500 450]);

                for it = 1:3
                    ax = subplot(1,3,it);
                    hold(ax,'on');

                    Tt = Tm(Tm.bad_type == typeOrder(it), :);

                    if typeOrder(it) == "rule_only"
                        barColor = C.plotting.colors.exclude_rule_based;
                    elseif typeOrder(it) == "cluster_only"
                        barColor = C.plotting.colors.exclude_cluster_based;
                    else
                        barColor = C.plotting.colors.exclude;
                    end

                    if ~isempty(Tt)
                        histogram(ax, Tt.pct_cycle, H.nbins, 'BinLimits', [0 100], 'Normalization', H.normalize, 'FaceColor', barColor, 'EdgeColor', 'none');
                    end

                    xlim(ax, [0 100]);
                    xlabel(ax, 'Burst midpoint (% of cycle)');
                    if strcmpi(H.normalize, 'probability')
                        ylabel(ax, 'Probability');
                    else
                        ylabel(ax, 'Count');
                    end
                    title(ax, sprintf('%s (n=%d)', typeTitles(it), height(Tt)));
                    grid(ax, 'on');
                end

                sgtitle(fig, sprintf('Location of bad bursts within gait cycle | %s', muscleName), 'Interpreter', 'none');

                outPngMuscle = fullfile(H.out_dir, sprintf('bad_burst_location_histograms__%s.png', muscleName));
                saveas(fig, outPngMuscle);
                close(fig);

                fprintf('Saved muscle-specific histogram PNG:\n%s\n', outPngMuscle);
            end

            fprintf('\nSaved bad burst histogram PNG:\n%s\n', H.out_png);
            fprintf('Saved bad burst histogram CSV:\n%s\n', H.out_csv);
        else
            fprintf('\nNo bad bursts with valid cycle assignment were found for histogram plotting.\n');
        end
    else
        fprintf('\nBad burst histogram generation is disabled. Skipping...\n');
    end

    %% ===================== RANDOM BURST EXAMPLES BY REASON =====================
    C  = config_emg();
    IO = C.e_final_burst_qc.io;
    P  = C.e_final_burst_qc.params;
    PL = C.e_final_burst_qc.plot;

    if isfield(PL, 'burst_examples') && PL.burst_examples.enable && ~isempty(FINAL_QC_TABLE)

        BX = PL.burst_examples;
        if ~exist(PL.out_dir_examples, 'dir'), mkdir(PL.out_dir_examples); end

        if BX.delete_old_png
            delete(fullfile(PL.out_dir_examples, '*.png'));
        end

        if isempty(BX.random_seed)
            rng('shuffle');
        else
            rng(BX.random_seed);
        end

        % ---------- Build burst file map ----------
        burstFiles = dir(fullfile(IO.bursts_dir, '*_EMG_BURSTS.mat'));
        burstMap = containers.Map('KeyType','char','ValueType','char');
        for k = 1:numel(burstFiles)
            tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
            if ~isempty(tok)
                burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
            end
        end

        % ---------- Candidate groups ----------
        Tgood = FINAL_QC_TABLE(FINAL_QC_TABLE.final_keep, :);

        Trule_only = FINAL_QC_TABLE( ~FINAL_QC_TABLE.rule_based_keep & FINAL_QC_TABLE.cluster_good, :);

        Tcluster_only = FINAL_QC_TABLE( FINAL_QC_TABLE.rule_based_keep & ~FINAL_QC_TABLE.cluster_good, :);

        Tboth_bad = FINAL_QC_TABLE( ~FINAL_QC_TABLE.rule_based_keep & ~FINAL_QC_TABLE.cluster_good, :);

        Tvisual_fail = FINAL_QC_TABLE(FINAL_QC_TABLE.final_reason == "visual_signal_3", :);
        Tsignal_rule_fail = FINAL_QC_TABLE(FINAL_QC_TABLE.final_reason == "rule_based_signal_fail", :);

        % Keep only rows with an actual rule-based reason
        Trule_only = Trule_only(strlength(string(Trule_only.rule_based_reason)) > 0, :);

        % ---------- Unique rule-based reasons from RULE-ONLY bursts ----------
        reasonList = unique(string(Trule_only.rule_based_reason));
        reasonList = reasonList(reasonList ~= "");

        emptyLike = FINAL_QC_TABLE([], :);

        % ---------- Sample one burst per rule-based reason ----------
        Tsamp_rule = emptyLike;
        for ir = 1:numel(reasonList)
            thisReason = reasonList(ir);
            Tr = Trule_only(string(Trule_only.rule_based_reason) == thisReason, :);

            if isempty(Tr)
                continue;
            end

            nPick = min(BX.n_per_reason, height(Tr));
            idx = randperm(height(Tr), nPick);
            Tsamp_rule = [Tsamp_rule; Tr(idx,:)]; %#ok<AGROW>
        end

        nRule = height(Tsamp_rule);

        % ---------- Sample same number of visual-signal-fail bursts ----------
        Tsamp_visual = emptyLike;
        if nRule > 0 && ~isempty(Tvisual_fail)
            nPick = min(nRule, height(Tvisual_fail));
            idx = randperm(height(Tvisual_fail), nPick);
            Tsamp_visual = Tvisual_fail(idx,:);
        end

        % ---------- Sample same number of signal-level rule-based fail bursts ----------
        Tsamp_signal_rule = emptyLike;
        if nRule > 0 && ~isempty(Tsignal_rule_fail)
            nPick = min(nRule, height(Tsignal_rule_fail));
            idx = randperm(height(Tsignal_rule_fail), nPick);
            Tsamp_signal_rule = Tsignal_rule_fail(idx,:);
        end

        % ---------- Sample same number of good bursts ----------
        Tsamp_good = emptyLike;
        if nRule > 0 && ~isempty(Tgood)
            nPick = min(nRule, height(Tgood));
            idx = randperm(height(Tgood), nPick);
            Tsamp_good = Tgood(idx,:);
        end

        % ---------- Sample same number of cluster-only bad bursts ----------
        Tsamp_clu = emptyLike;
        if nRule > 0 && ~isempty(Tcluster_only)
            nPick = min(nRule, height(Tcluster_only));
            idx = randperm(height(Tcluster_only), nPick);
            Tsamp_clu = Tcluster_only(idx,:);
        end

        % ---------- Sample same number of both-bad bursts ----------
        Tsamp_both = emptyLike;
        if nRule > 0 && ~isempty(Tboth_bad)
            nPick = min(nRule, height(Tboth_bad));
            idx = randperm(height(Tboth_bad), nPick);
            Tsamp_both = Tboth_bad(idx,:);
        end

        % ---------- Merge selected rows ----------
        Tsamp_rule.example_group = repmat("rule_only_reason", height(Tsamp_rule), 1);
        Tsamp_good.example_group = repmat("good",             height(Tsamp_good), 1);
        Tsamp_clu.example_group  = repmat("cluster_only",     height(Tsamp_clu), 1);
        Tsamp_both.example_group = repmat("both_bad",         height(Tsamp_both), 1);
        Tsamp_visual.example_group = repmat("visual_signal_fail", height(Tsamp_visual), 1);
        Tsamp_signal_rule.example_group = repmat("signal_rule_fail", height(Tsamp_signal_rule), 1);

        Tsamp = [Tsamp_rule; Tsamp_good; Tsamp_clu; Tsamp_both; Tsamp_visual; Tsamp_signal_rule];

        if ~isempty(Tsamp)
            % ---------- Extract snippets ----------
            halfWin = round((BX.window_ms/1000) * C.general.fs_emg / 2);

            snippets = cell(height(Tsamp),1);
            time_axes = cell(height(Tsamp),1);
            labels = strings(height(Tsamp),1);

            allVals = [];

            mid_indices = nan(height(Tsamp),1);
            for i = 1:height(Tsamp)
                subjID = char(Tsamp.subject(i));
                cond   = char(Tsamp.condition(i));
                leg    = char(Tsamp.leg(i));
                mf     = char(Tsamp.muscle(i));

                if ~isKey(burstMap, subjID)
                    continue;
                end

                Lb = load(burstMap(subjID));
                if ~isfield(Lb, 'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
                    continue;
                end
                if ~isfield(Lb.BURSTS_DET.(subjID), cond) || ~isfield(Lb.BURSTS_DET.(subjID).(cond), leg) || ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mf)
                    continue;
                end

                Eplot = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf);
                if ~isfield(Eplot, 'signal') || isempty(Eplot.signal)
                    continue;
                end

                x = Eplot.signal(:);

                if isfield(Eplot, 'fs') && ~isempty(Eplot.fs)
                    fs = Eplot.fs;
                else
                    fs = C.general.fs_emg;
                end

                mid_idx = round((Tsamp.start_idx(i) + Tsamp.end_idx(i)) / 2);

                i1 = max(1, mid_idx - halfWin);
                i2 = min(numel(x), mid_idx + halfWin);

                xseg = x(i1:i2);
                tseg = ((i1:i2) - mid_idx) / fs * 1000; % ms relative to burst midpoint

                snippets{i} = xseg;
                time_axes{i} = tseg;
                allVals = [allVals; xseg(:)]; %#ok<AGROW>

                if Tsamp.example_group(i) == "good"
                    labels(i) = "Good";
                elseif Tsamp.example_group(i) == "visual_signal_fail"
                    labels(i) = "Visual signal fail (score=3)";
                elseif Tsamp.example_group(i) == "signal_rule_fail"
                    labels(i) = "Signal-level rule-based fail";
                else
                    labels(i) = get_exclusion_reason_for_plot(Tsamp, i);
                end
                mid_indices(i) = mid_idx;
            end

            % robust global y-limits
            if ~isempty(allVals)
                yMin = prctile(allVals, 1);
                yMax = prctile(allVals, 99);
            else
                yMin = [];
                yMax = [];
            end

            % ---------- Save one plot per burst ----------
            for i = 1:height(Tsamp)
                if isempty(snippets{i}), continue; end

                fig = figure('Visible','off','Color','w','Position',[100 100 700 300]);
                ax = axes(fig); hold(ax,'on');

                if Tsamp.example_group(i) == "visual_signal_fail"
                    thisColor = BX.visual_color;
                elseif Tsamp.example_group(i) == "signal_rule_fail"
                    thisColor = BX.signal_rule_color;
                elseif Tsamp.example_group(i) == "rule_only_reason"
                    thisColor = BX.rule_color;
                elseif Tsamp.example_group(i) == "cluster_only"
                    thisColor = BX.cluster_color;
                elseif Tsamp.example_group(i) == "both_bad"
                    thisColor = BX.both_color;
                elseif Tsamp.example_group(i) == "good"
                    thisColor = BX.good_color;
                else
                    thisColor = [0.2 0.2 0.2];
                end

                % plot(ax, time_axes{i}, snippets{i}, 'Color', thisColor, 'LineWidth', 1.5);
                % xline(ax, 0, '--k', 'LineWidth', 1.0);

                plot(ax, time_axes{i}, snippets{i}, 'Color', thisColor, 'LineWidth', 1.5);

                burst_start_ms = (Tsamp.start_idx(i) - mid_indices(i)) / fs * 1000;
                burst_end_ms   = (Tsamp.end_idx(i)   - mid_indices(i)) / fs * 1000;

                xline(ax, burst_start_ms, '--', 'LineWidth', 1.0, 'Color', [0.2 0.2 0.2]);
                xline(ax, burst_end_ms,   '--', 'LineWidth', 1.0, 'Color', [0.2 0.2 0.2]);

                if BX.use_fixed_ylim && ~isempty(yMin) && ~isempty(yMax)
                    ylim(ax, [yMin yMax]);
                end
                xlim(ax, [-BX.window_ms/2 BX.window_ms/2]);

                xlabel(ax, 'Time relative to burst midpoint (ms)');
                ylabel(ax, 'Amplitude');
                grid(ax,'on');

                title(ax, sprintf('%s | %s | %s | %s | burst %d', Tsamp.subject(i), Tsamp.condition(i), Tsamp.leg(i), Tsamp.muscle(i), Tsamp.burst_number(i)), 'Interpreter','none');

                subtitle(ax, labels(i), 'Interpreter','none');

                fname = sprintf('burst_example__%s__%s__%s__%s__b%03d__%s.png', Tsamp.subject(i), Tsamp.condition(i), Tsamp.leg(i), Tsamp.muscle(i), Tsamp.burst_number(i), regexprep(char(labels(i)), '[^a-zA-Z0-9_]', '_'));

                saveas(fig, fullfile(PL.out_dir_examples, fname));
                close(fig);
            end

            fprintf('\nSaved burst example plots in:\n%s\n', PL.out_dir_examples);
        end
    end

    %% ===================== OPTIONAL INSPECTION =====================
    subject   = 'CTL_79'; % CTL_XX
    condition = 'Flat'; % Choose from High, Medium, Flat
    leg       = 'right'; % Choose from 'left' or 'right'
    muscle    = 'EMG_TAdist_Concat'; % Choose from the following: EMG_GMED_Concat, EMG_GM_Concat, EMG_RF_Concat, EMG_SOL_Concat, EMG_ST_Concat, EMG_TAdist_Concat, EMG_TAprox_Concat, EMG_VL_Concat

    Tsig = FINAL_QC_TABLE( FINAL_QC_TABLE.subject == string(subject) & FINAL_QC_TABLE.condition == string(condition) & FINAL_QC_TABLE.leg == string(leg) & FINAL_QC_TABLE.muscle == string(muscle), :);

    if subject == "" || condition == "" || leg == "" || muscle == ""
        warning('Please specify subject, condition, leg, and muscle for inspection. Skipping plot.');
    elseif isempty(Tsig)
        warning('No matching signal found in FINAL_QC_TABLE for subject=%s, condition=%s, leg=%s, muscle=%s. Skipping plot.', subject, condition, leg, muscle);
    else
        burstFile = fullfile(IO.bursts_dir, sprintf('%s_EMG_BURSTS.mat', subject));
        Lb = load(burstFile);

        Eplot = Lb.BURSTS_DET.(subject).(condition).(leg).(muscle);

        x = Eplot.signal(:);

        if isfield(Eplot, 'envelope') && ~isempty(Eplot.envelope)
            x_env = Eplot.envelope(:);
        else
            x_env = [];
        end

        if isfield(Eplot, 'fs') && ~isempty(Eplot.fs)
            fs = Eplot.fs;
        else
            fs = C.analysis.fs_emg;
        end

        cycle_starts = [];
        candidateCycleFields = {'cycle_starts','gc_start_idx','gait_cycle_starts', 'heel_strikes','hs_idx','cycleStartIdx','starts_idx'};
        for icf = 1:numel(candidateCycleFields)
            fn = candidateCycleFields{icf};
            if isfield(Eplot, fn) && ~isempty(Eplot.(fn))
                cycle_starts = Eplot.(fn)(:);
                break;
            end
        end

        toe_off_concat = [];
        if isfield(Eplot, 'toe_off_concat') && ~isempty(Eplot.toe_off_concat)
            toe_off_concat = Eplot.toe_off_concat(:);
        end

        plot_one_final_qc_signal(subject, condition, leg, muscle, fs, x, x_env, cycle_starts, toe_off_concat, Tsig, PL.out_dir, C);
    end
end