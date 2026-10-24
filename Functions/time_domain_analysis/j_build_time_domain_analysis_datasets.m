%% j_build_time_domain_analysis_datasets.m
% Build cycle-based datasets ready for time-domain analysis
%
% INPUT:
%   - FINAL_BURST_QC.mat
%   - *_EMG_BURSTS.mat
%   - *_EMG_PREPROC.mat
%
% OUTPUT:
%   - TIME_DOMAIN_DATA.mat
%   - TD_SINGLE_CYCLE_TABLE.csv
%   - TD_PAIR_CYCLE_TABLE.csv
%   - TD_SINGLE_SIGNAL_SUMMARY.csv
%   - TD_PAIR_SIGNAL_SUMMARY.csv
%
% LOGIC:
% -------------------------------------------------------------------------
% Single-muscle mode:
%   - evaluate each muscle independently
%   - decide which gait cycles are valid / invalid
%   - extract valid cycle signals from continuous preprocessed EMG
%   - store cycle boundaries, toe-off info, QC decisions, and cycle-level
%     bandpassed / rectified / envelope signals
%
% Pairwise mode:
%   - evaluate paired muscles on harmonized cycles
%   - valid pair cycles = valid in both muscles on the same cycle
%   - extract valid paired cycle signals from continuous preprocessed EMG
%   - store cycle boundaries, toe-off info, QC decisions, and paired cycle-level
%     bandpassed / rectified / envelope signals
%
% IMPORTANT:
%   - preprocessing is NOT done cycle by cycle here
%   - signals are extracted from the continuous EMG_PREPROC time-domain branch
% -------------------------------------------------------------------------
function j_build_time_domain_analysis_datasets()
    


    C  = config_emg();
    IO = C.j_time_domain.io;
    P  = C.j_time_domain.params;
    PL = C.j_time_domain.plot;

    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.csv_dir, 'dir'), mkdir(IO.csv_dir); end

    %% ===================== CHECKS =====================
    assert(isfile(IO.final_burst_mat), 'FINAL_BURST_QC.mat not found: %s', IO.final_burst_mat);

    burstFiles = dir(fullfile(IO.bursts_dir, '*_EMG_BURSTS.mat'));
    assert(~isempty(burstFiles), 'No burst files found in %s', IO.bursts_dir);

    %% ===================== LOAD FINAL BURST QC =====================
    fprintf('Loading FINAL_BURST_QC from %s...\n', IO.final_burst_mat);
    Lq = load(IO.final_burst_mat);
    assert(isfield(Lq, 'FINAL_BURST_QC'), 'FINAL_BURST_QC not found in mat file.');
    FINAL_BURST_QC = Lq.FINAL_BURST_QC;

    %% ===================== MAP BURST FILES =====================
    fprintf('Mapping burst files from %s...\n', IO.bursts_dir);
    burstMap = containers.Map('KeyType','char','ValueType','char');
    for k = 1:numel(burstFiles)
        tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
        end
    end

    %% ===================== MAP PREPROC FILES =====================
    fprintf('Mapping preprocessed EMG files from %s...\n', IO.preproc_dir);
    preprocFiles = dir(fullfile(IO.preproc_dir, '*_EMG_PREPROC.mat'));
    assert(~isempty(preprocFiles), 'No preprocessed EMG files found in %s', IO.preproc_dir);

    preprocMap = containers.Map('KeyType','char','ValueType','char');
    for k = 1:numel(preprocFiles)
        tok = regexp(preprocFiles(k).name, '^(.*)_EMG_PREPROC\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            preprocMap(tok{1}) = fullfile(preprocFiles(k).folder, preprocFiles(k).name);
        end
    end

    %% ===================== OUTPUT STRUCTURES =====================
    fprintf('Initializing output structures...\n');
    TIME_DOMAIN_SINGLE_MUSCLE = struct();
    TIME_DOMAIN_PAIRWISE = struct();

    TD_SINGLE_ROWS = {};
    TD_PAIR_ROWS   = {};
    TD_SINGLE_SUM_ROWS = {};
    TD_PAIR_SUM_ROWS   = {};

    riSC = 0;  % single cycle row index
    riPC = 0;  % pair cycle row index
    riSS = 0;  % single summary row index
    riPS = 0;  % pair summary row index

    subjects = fieldnames(FINAL_BURST_QC);

    %% ===================== MAIN LOOP =====================
    fprintf('\nProcessing subjects...\n');
    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        fprintf('\n=== Build time-domain data: %s ===\n', subjID);

        if ~isKey(burstMap, subjID)
            warning('No burst file found for %s. Skipping subject.', subjID);
            continue;
        end

        Lb = load(burstMap(subjID));
        if ~isfield(Lb, 'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
            warning('BURSTS_DET missing for %s. Skipping subject.', subjID);
            continue;
        end

        if ~isKey(preprocMap, subjID)
            warning('No preprocessed EMG file found for %s. Skipping subject.', subjID);
            continue;
        end

        Lp = load(preprocMap(subjID));
        if ~isfield(Lp, 'EMG_PREPROC') || ~isfield(Lp.EMG_PREPROC, subjID)
            warning('EMG_PREPROC missing for %s. Skipping subject.', subjID);
            continue;
        end

        conds = fieldnames(FINAL_BURST_QC.(subjID));
        for ic = 1:numel(conds)
            cond = conds{ic};

            if ~isfield(Lb.BURSTS_DET.(subjID), cond), continue; end

            legs = fieldnames(FINAL_BURST_QC.(subjID).(cond));
            for il = 1:numel(legs)
                leg = legs{il};

                if ~isfield(Lb.BURSTS_DET.(subjID).(cond), leg), continue; end

                % =========================================================
                % A) SINGLE-MUSCLE TIME-DOMAIN DATA
                % =========================================================
                if P.single.enable
                    muscleFields = fieldnames(FINAL_BURST_QC.(subjID).(cond).(leg));

                    for iM = 1:numel(muscleFields)
                        mf = muscleFields{iM};

                        if ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mf)
                            continue;
                        end

                        E = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf);
                        Q = FINAL_BURST_QC.(subjID).(cond).(leg).(mf);

                        if ~isfield(E, 'signal') || isempty(E.signal)
                            continue;
                        end

                        x = E.signal(:);
                        fs = get_fs_from_entry_or_default(E, C);

                        [cycle_starts, cycle_ends, cycle_source] = get_cycle_boundaries( E, P.cycle_field_candidates, P.cycle_end_field_candidates);

                        [toe_off_idx, toe_source] = get_toe_off_in_concat_coordinates_multi( E, P.toeoff_field_candidates);

                        if isempty(cycle_starts)
                            continue;
                        end

                        cycle_ends = finalize_cycle_ends(cycle_starts, cycle_ends, numel(x));
                        toe_info   = assign_toe_off_to_cycles(cycle_starts, cycle_ends, toe_off_idx);

                        bursts = get_bursts_idx_from_qc_or_entry(Q, E);
                        keep   = get_final_keep_mask(Q, size(bursts,1));
                        reason = get_final_reason(Q, size(bursts,1));

                        cyc = evaluate_cycles_for_one_muscle_time_domain( subjID, cond, leg, mf, x, cycle_starts, cycle_ends, bursts, keep, reason, P.single_cycle_policy);

                        cyc.source_bursts_idx = bursts;
                        cyc.source_burst_keep_mask = keep;
                        cyc.source_burst_reason = reason;
                        cyc.toe_off_info = toe_info;
                        cyc.cycle_source_field = cycle_source;
                        cyc.toe_off_source_field = toe_source;

                        valid_cycle_numbers = find(cyc.cycle_keep_mask);
                        removed_cycle_numbers = find(~cyc.cycle_keep_mask);
                        n_valid_cycles = numel(valid_cycle_numbers);

                        included_for_analysis = n_valid_cycles >= P.single.min_cycles_required;
                        if included_for_analysis
                            exclusion_reason = "";
                        else
                            exclusion_reason = "too_few_valid_cycles";
                        end

                        preprocEntry = get_preproc_entry_single(Lp.EMG_PREPROC, subjID, cond, leg, mf);

                        validCycleStruct = build_valid_cycle_dataset_one_muscle( preprocEntry, cycle_starts, cycle_ends, toe_info, valid_cycle_numbers, P);

                        validCycleTable = validCycleStruct.table;

                        age_group = subject_to_group(subjID, C);

                        % ---------- single-cycle table rows ----------
                        Tcyc = cyc.cycle_table;
                        if ~isempty(Tcyc)
                            Tcyc.age_group = repmat(string(age_group), height(Tcyc), 1);
                            Tcyc.fs = repmat(fs, height(Tcyc), 1);

                            Tcyc.has_toe_off = toe_info.has_toe_off;
                            Tcyc.toe_off_original_idx = toe_info.toe_off_original_idx;
                            Tcyc.toe_off_relative_idx = toe_info.toe_off_relative_idx;
                            Tcyc.toe_off_relative_fraction = toe_info.toe_off_relative_fraction;

                            for ir = 1:height(Tcyc)
                                riSC = riSC + 1;
                                TD_SINGLE_ROWS(riSC,:) = table2cell(Tcyc(ir,:));
                            end
                        end

                        % ---------- single summary ----------
                        riSS = riSS + 1;
                        TD_SINGLE_SUM_ROWS(riSS,:) = { string(subjID), string(age_group), string(cond), string(leg), string(mf), fs, numel(cycle_starts), n_valid_cycles, numel(removed_cycle_numbers), included_for_analysis, string(exclusion_reason), string(cycle_source), string(toe_source) };

                        % ---------- save hierarchical struct ----------
                        TIME_DOMAIN_SINGLE_MUSCLE = ensure_td_single_fields(TIME_DOMAIN_SINGLE_MUSCLE, subjID, cond, leg);

                        S = struct();
                        S.subject = string(subjID);
                        S.age_group = string(age_group);
                        S.condition = string(cond);
                        S.leg = string(leg);
                        S.muscle = string(mf);
                        S.fs = fs;

                        S.original_signal = x;
                        S.cycle_starts = cycle_starts(:);
                        S.cycle_ends = cycle_ends(:);
                        S.n_cycles_total = numel(cycle_starts);

                        S.valid_cycle_numbers = valid_cycle_numbers(:);
                        S.removed_cycle_numbers = removed_cycle_numbers(:);
                        S.n_valid_cycles = n_valid_cycles;

                        S.cycle_qc = cyc;
                        S.toe_off_info = toe_info;

                        S.cycle_source_field = string(cycle_source);
                        S.toe_off_source_field = string(toe_source);

                        S.bursts_idx = bursts;
                        S.burst_keep_mask = keep;
                        S.burst_reason = reason;

                        S.valid_cycles = validCycleStruct;
                        S.valid_cycles_table = validCycleTable;

                        S.min_cycles_required = P.single.min_cycles_required;
                        S.included_for_analysis = included_for_analysis;
                        S.exclusion_reason = string(exclusion_reason);

                        TIME_DOMAIN_SINGLE_MUSCLE.(subjID).(cond).(leg).(mf) = S;

                        fprintf('  SINGLE | %s | %s | %s | %s -> valid cycles %d / %d | included=%d\n', subjID, cond, leg, mf, n_valid_cycles, numel(cycle_starts), included_for_analysis);
                    end
                end

                % =========================================================
                % B) PAIRWISE TIME-DOMAIN DATA
                % =========================================================
                if P.pairwise.enable
                    for iPair = 1:numel(P.pairs)
                        pairName = P.pairs{iPair}.name;
                        mus1 = P.pairs{iPair}.muscles{1};
                        mus2 = P.pairs{iPair}.muscles{2};

                        if ~isfield(FINAL_BURST_QC.(subjID).(cond).(leg), mus1) || ~isfield(FINAL_BURST_QC.(subjID).(cond).(leg), mus2)
                            continue;
                        end

                        if ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mus1) || ~isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mus2)
                            continue;
                        end

                        E1 = Lb.BURSTS_DET.(subjID).(cond).(leg).(mus1);
                        E2 = Lb.BURSTS_DET.(subjID).(cond).(leg).(mus2);

                        Q1 = FINAL_BURST_QC.(subjID).(cond).(leg).(mus1);
                        Q2 = FINAL_BURST_QC.(subjID).(cond).(leg).(mus2);

                        if ~isfield(E1,'signal') || isempty(E1.signal) || ~isfield(E2,'signal') || isempty(E2.signal)
                            continue;
                        end

                        x1 = E1.signal(:);
                        x2 = E2.signal(:);

                        fs = get_fs_from_entry_or_default(E1, C);

                        [cycle_starts_1, cycle_ends_1, cycle_source_1] = get_cycle_boundaries( E1, P.cycle_field_candidates, P.cycle_end_field_candidates);
                        [cycle_starts_2, cycle_ends_2, cycle_source_2] = get_cycle_boundaries( E2, P.cycle_field_candidates, P.cycle_end_field_candidates);

                        [toe_off_1, toe_source_1] = get_toe_off_in_concat_coordinates_multi(E1, P.toeoff_field_candidates);
                        [toe_off_2, toe_source_2] = get_toe_off_in_concat_coordinates_multi(E2, P.toeoff_field_candidates);

                        if isempty(cycle_starts_1) || isempty(cycle_starts_2)
                            continue;
                        end

                        cycle_ends_1 = finalize_cycle_ends(cycle_starts_1, cycle_ends_1, numel(x1));
                        cycle_ends_2 = finalize_cycle_ends(cycle_starts_2, cycle_ends_2, numel(x2));

                        [cycle_starts_pair, cycle_ends_pair, cycle_alignment_note] = harmonize_cycle_boundaries(cycle_starts_1, cycle_ends_1, cycle_starts_2, cycle_ends_2, numel(x1), numel(x2));

                        if isempty(cycle_starts_pair)
                            continue;
                        end

                        toe_pair_1 = assign_toe_off_to_cycles(cycle_starts_pair, cycle_ends_pair, toe_off_1);
                        toe_pair_2 = assign_toe_off_to_cycles(cycle_starts_pair, cycle_ends_pair, toe_off_2);

                        bursts1 = get_bursts_idx_from_qc_or_entry(Q1, E1);
                        bursts2 = get_bursts_idx_from_qc_or_entry(Q2, E2);

                        keep1 = get_final_keep_mask(Q1, size(bursts1,1));
                        keep2 = get_final_keep_mask(Q2, size(bursts2,1));

                        reason1 = get_final_reason(Q1, size(bursts1,1));
                        reason2 = get_final_reason(Q2, size(bursts2,1));

                        cyc1 = evaluate_cycles_for_one_muscle_time_domain( subjID, cond, leg, mus1, x1, cycle_starts_pair, cycle_ends_pair, bursts1, keep1, reason1, P.single_cycle_policy);

                        cyc2 = evaluate_cycles_for_one_muscle_time_domain( subjID, cond, leg, mus2, x2, cycle_starts_pair, cycle_ends_pair, bursts2, keep2, reason2, P.single_cycle_policy);

                        pair_cycle_keep = cyc1.cycle_keep_mask & cyc2.cycle_keep_mask;
                        nCycles = numel(pair_cycle_keep);

                        pair_cycle_reason = strings(nCycles,1);
                        for iC = 1:nCycles
                            reasons = strings(0,1);
                            if ~cyc1.cycle_keep_mask(iC), reasons(end+1) = "bad_in_" + string(mus1); end
                            if ~cyc2.cycle_keep_mask(iC), reasons(end+1) = "bad_in_" + string(mus2); end

                            if isempty(reasons)
                                pair_cycle_reason(iC) = "keep";
                            else
                                pair_cycle_reason(iC) = strjoin(reasons, "+");
                            end
                        end

                        valid_pair_cycle_numbers = find(pair_cycle_keep);
                        removed_pair_cycle_numbers = find(~pair_cycle_keep);
                        n_valid_pair_cycles = numel(valid_pair_cycle_numbers);

                        included_for_analysis = n_valid_pair_cycles >= P.pairwise.min_cycles_required;
                        if included_for_analysis
                            exclusion_reason = "";
                        else
                            exclusion_reason = "too_few_valid_pair_cycles";
                        end

                        preprocEntry1 = get_preproc_entry_single(Lp.EMG_PREPROC, subjID, cond, leg, mus1);
                        preprocEntry2 = get_preproc_entry_single(Lp.EMG_PREPROC, subjID, cond, leg, mus2);

                        pairValidStruct = build_valid_cycle_dataset_pairwise( preprocEntry1, preprocEntry2, cycle_starts_pair, cycle_ends_pair, toe_pair_1, toe_pair_2, valid_pair_cycle_numbers, P);

                        pairValidTable = pairValidStruct.table;

                        age_group = subject_to_group(subjID, C);

                        % ---------- pair cycle rows ----------
                        Tpair = build_pair_cycle_table( subjID, age_group, cond, leg, pairName, mus1, mus2, cycle_starts_pair, cycle_ends_pair, cyc1, cyc2, pair_cycle_keep, pair_cycle_reason, toe_pair_1, toe_pair_2, fs);

                        if ~isempty(Tpair)
                            for ir = 1:height(Tpair)
                                riPC = riPC + 1;
                                TD_PAIR_ROWS(riPC,:) = table2cell(Tpair(ir,:));
                            end
                        end

                        % ---------- pair summary ----------
                        riPS = riPS + 1;
                        TD_PAIR_SUM_ROWS(riPS,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(mus1), string(mus2), fs, numel(cycle_starts_pair), n_valid_pair_cycles, numel(removed_pair_cycle_numbers), included_for_analysis, string(exclusion_reason), string(cycle_source_1), string(cycle_source_2), string(toe_source_1), string(toe_source_2), string(cycle_alignment_note) };

                        % ---------- save hierarchical struct ----------
                        TIME_DOMAIN_PAIRWISE = ensure_td_pair_fields(TIME_DOMAIN_PAIRWISE, subjID, cond, leg);

                        S = struct();
                        S.subject = string(subjID);
                        S.age_group = string(age_group);
                        S.condition = string(cond);
                        S.leg = string(leg);
                        S.pair_name = string(pairName);
                        S.muscles = {mus1, mus2};
                        S.fs = fs;

                        S.original_signal_1 = x1;
                        S.original_signal_2 = x2;

                        S.cycle_starts = cycle_starts_pair(:);
                        S.cycle_ends = cycle_ends_pair(:);
                        S.n_cycles_total = numel(cycle_starts_pair);

                        S.valid_pair_cycle_numbers = valid_pair_cycle_numbers(:);
                        S.removed_pair_cycle_numbers = removed_pair_cycle_numbers(:);
                        S.n_valid_pair_cycles = n_valid_pair_cycles;

                        S.muscle1_cycle_qc = cyc1;
                        S.muscle2_cycle_qc = cyc2;

                        S.muscle1_bursts_idx = bursts1;
                        S.muscle2_bursts_idx = bursts2;
                        S.muscle1_burst_keep_mask = keep1;
                        S.muscle2_burst_keep_mask = keep2;
                        S.muscle1_burst_reason = reason1;
                        S.muscle2_burst_reason = reason2;

                        S.pair_cycle_keep_mask = pair_cycle_keep;
                        S.pair_cycle_reason = pair_cycle_reason;

                        S.toe_off_info_muscle1 = toe_pair_1;
                        S.toe_off_info_muscle2 = toe_pair_2;

                        S.cycle_source_field_muscle1 = string(cycle_source_1);
                        S.cycle_source_field_muscle2 = string(cycle_source_2);
                        S.toe_off_source_field_muscle1 = string(toe_source_1);
                        S.toe_off_source_field_muscle2 = string(toe_source_2);
                        S.cycle_alignment_note = string(cycle_alignment_note);

                        S.valid_pair_cycles = pairValidStruct;
                        S.valid_pair_cycles_table = pairValidTable;

                        S.min_cycles_required = P.pairwise.min_cycles_required;
                        S.included_for_analysis = included_for_analysis;
                        S.exclusion_reason = string(exclusion_reason);

                        TIME_DOMAIN_PAIRWISE.(subjID).(cond).(leg).(char(pairName)) = S;

                        fprintf('  PAIR   | %s | %s | %s | %s -> valid pair cycles %d / %d | included=%d\n', subjID, cond, leg, pairName, n_valid_pair_cycles, numel(cycle_starts_pair), included_for_analysis);
                    end
                end
            end
        end
    end

    %% ===================== BUILD TABLES =====================
    fprintf('\nBuilding output tables...\n');

    TD_SINGLE_CYCLE_TABLE = rows_to_table(TD_SINGLE_ROWS, { 'subject','condition','leg','muscle','cycle_number', 'cycle_start_idx','cycle_end_idx','cycle_length_samples', 'n_overlapping_bursts','n_good_bursts','n_bad_bursts', 'has_any_burst','has_good_burst','has_bad_burst', 'bad_burst_covered_samples','bad_burst_fraction', 'cycle_ptp','cycle_std','is_flatline', 'cycle_keep','cycle_reason','age_group','fs', 'has_toe_off','toe_off_original_idx','toe_off_relative_idx','toe_off_relative_fraction'});

    TD_PAIR_CYCLE_TABLE = rows_to_table(TD_PAIR_ROWS, { 'subject','age_group','condition','leg','pair_name','muscle1','muscle2', 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples','fs', 'muscle1_cycle_keep','muscle2_cycle_keep','pair_cycle_keep','pair_cycle_reason', 'muscle1_has_toe_off','muscle2_has_toe_off', 'muscle1_toe_off_relative_fraction','muscle2_toe_off_relative_fraction'});

    TD_SINGLE_SIGNAL_SUMMARY = rows_to_table(TD_SINGLE_SUM_ROWS, { 'subject','age_group','condition','leg','muscle','fs', 'n_cycles_total','n_valid_cycles','n_removed_cycles', 'included_for_analysis','exclusion_reason', 'cycle_source_field','toe_off_source_field'});

    TD_PAIR_SIGNAL_SUMMARY = rows_to_table(TD_PAIR_SUM_ROWS, { 'subject','age_group','condition','leg','pair_name','muscle1','muscle2','fs', 'n_cycles_total','n_valid_pair_cycles','n_removed_pair_cycles', 'included_for_analysis','exclusion_reason', 'cycle_source_field_muscle1','cycle_source_field_muscle2', 'toe_off_source_field_muscle1','toe_off_source_field_muscle2', 'cycle_alignment_note'});

    TD_SINGLE_ANALYZABLE_SIGNALS = TD_SINGLE_SIGNAL_SUMMARY(TD_SINGLE_SIGNAL_SUMMARY.included_for_analysis == true, :);
    TD_PAIR_ANALYZABLE_SIGNALS   = TD_PAIR_SIGNAL_SUMMARY(TD_PAIR_SIGNAL_SUMMARY.included_for_analysis == true, :);

    %% ===================== SAVE =====================
    fprintf('\nSaving time-domain data...\n');

    save(IO.out_mat, 'TIME_DOMAIN_SINGLE_MUSCLE', 'TIME_DOMAIN_PAIRWISE', 'TD_SINGLE_CYCLE_TABLE', 'TD_PAIR_CYCLE_TABLE', 'TD_SINGLE_SIGNAL_SUMMARY', 'TD_PAIR_SIGNAL_SUMMARY', 'TD_SINGLE_ANALYZABLE_SIGNALS', 'TD_PAIR_ANALYZABLE_SIGNALS', 'IO', 'P', 'PL', '-v7.3');

    writetable(TD_SINGLE_CYCLE_TABLE, IO.single_cycle_csv);
    writetable(TD_PAIR_CYCLE_TABLE, IO.pair_cycle_csv);
    writetable(TD_SINGLE_SIGNAL_SUMMARY, IO.single_sum_csv);
    writetable(TD_PAIR_SIGNAL_SUMMARY, IO.pair_sum_csv);
    writetable(TD_SINGLE_ANALYZABLE_SIGNALS, IO.single_analyzable_csv);
    writetable(TD_PAIR_ANALYZABLE_SIGNALS, IO.pair_analyzable_csv);

    fprintf('Saved:\n  %s\n', IO.out_mat);
end

%% ===================== LOCAL FUNCTIONS =====================
function [cycle_starts, cycle_ends, source_field] = get_cycle_boundaries(E, startCandidates, endCandidates)
    cycle_starts = [];
    cycle_ends   = [];
    source_field = "";

    for i = 1:numel(startCandidates)
        fn = startCandidates{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            cycle_starts = round(E.(fn)(:));
            cycle_starts = cycle_starts(~isnan(cycle_starts));
            cycle_starts = unique(cycle_starts, 'stable');
            source_field = string(fn);
            break;
        end
    end

    if isempty(cycle_starts), return; end

    for i = 1:numel(endCandidates)
        fn = endCandidates{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            cycle_ends = round(E.(fn)(:));
            cycle_ends = cycle_ends(~isnan(cycle_ends));
            break;
        end
    end

    if isempty(cycle_ends)
        if numel(cycle_starts) >= 2
            cycle_ends = [cycle_starts(2:end)-1; NaN];
        else
            cycle_ends = NaN(size(cycle_starts));
        end
    end
end

function cycle_ends = finalize_cycle_ends(cycle_starts, cycle_ends, nSamples)
    cycle_starts = cycle_starts(:);

    if isempty(cycle_ends)
        cycle_ends = [cycle_starts(2:end)-1; nSamples];
        return;
    end

    cycle_ends = cycle_ends(:);

    if numel(cycle_ends) ~= numel(cycle_starts)
        if numel(cycle_starts) >= 2
            cycle_ends = [cycle_starts(2:end)-1; nSamples];
        else
            cycle_ends = nSamples;
        end
    end

    if isnan(cycle_ends(end))
        cycle_ends(end) = nSamples;
    end

    cycle_ends = round(cycle_ends);
    cycle_ends(cycle_ends > nSamples) = nSamples;
end

function [toe_off, note] = get_toe_off_in_concat_coordinates_multi(E, candidate_fields)
    toe_off = [];
    note = "";

    for i = 1:numel(candidate_fields)
        fn = candidate_fields{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            toe_off = round(E.(fn)(:));
            toe_off = toe_off(~isnan(toe_off));
            toe_off = unique(toe_off, 'stable');
            note = string(fn);
            return;
        end
    end
end

function [starts_pair, ends_pair, note] = harmonize_cycle_boundaries(st1, en1, st2, en2, n1, n2)
    note = "identical";

    st1 = st1(:); en1 = en1(:);
    st2 = st2(:); en2 = en2(:);

    if ~isempty(en1) && isnan(en1(end)), en1(end) = n1; end
    if ~isempty(en2) && isnan(en2(end)), en2(end) = n2; end

    if isequal(st1, st2)
        starts_pair = st1;
        ends_pair = min(en1, en2);
        return;
    end

    commonStarts = intersect(st1, st2, 'stable');
    if isempty(commonStarts)
        starts_pair = [];
        ends_pair = [];
        note = "no_common_cycle_starts";
        return;
    end

    starts_pair = commonStarts(:);
    ends_pair = [starts_pair(2:end)-1; min(n1,n2)];
    note = "used_common_cycle_starts_intersection";
end
function cyc = evaluate_cycles_for_one_muscle_time_domain(subjID, cond, leg, mf, x, cycle_starts, cycle_ends, bursts, burst_keep, burst_reason, Pcyc)

    nCycles = numel(cycle_starts);
    nBursts = size(bursts,1);

    cyc = struct();
    cyc.subject   = string(subjID);
    cyc.condition = string(cond);
    cyc.leg       = string(leg);
    cyc.muscle    = string(mf);

    cyc.cycle_starts = cycle_starts(:);
    cyc.cycle_ends   = cycle_ends(:);
    cyc.cycle_length_samples = cycle_ends(:) - cycle_starts(:) + 1;

    cyc.n_overlapping_bursts = zeros(nCycles,1);
    cyc.overlapping_burst_idx = cell(nCycles,1);

    cyc.has_any_burst  = false(nCycles,1);
    cyc.has_good_burst = false(nCycles,1);
    cyc.has_bad_burst  = false(nCycles,1);

    cyc.n_good_bursts = zeros(nCycles,1);
    cyc.n_bad_bursts  = zeros(nCycles,1);

    cyc.bad_burst_overlap_segments = cell(nCycles,1);
    cyc.bad_burst_covered_samples  = zeros(nCycles,1);
    cyc.bad_burst_fraction         = zeros(nCycles,1);

    cyc.cycle_ptp = nan(nCycles,1);
    cyc.cycle_std = nan(nCycles,1);
    cyc.is_flatline = false(nCycles,1);

    cyc.flatline_segments = cell(nCycles,1);
    cyc.flatline_covered_samples = zeros(nCycles,1);
    cyc.flatline_fraction = zeros(nCycles,1);
    cyc.is_partly_flatline = false(nCycles,1);

    cyc.cycle_keep_mask = false(nCycles,1);
    cyc.cycle_reason = strings(nCycles,1);

    for iC = 1:nCycles
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);
        x_cycle = x(c1:c2);

        cyc.cycle_ptp(iC) = max(x_cycle, [], 'omitnan') - min(x_cycle, [], 'omitnan');
        cyc.cycle_std(iC) = std(x_cycle, 'omitnan');

        if Pcyc.reject_flatline_cycles
            switch string(Pcyc.flatline_method)
                case "ptp"
                    cyc.is_flatline(iC) = cyc.cycle_ptp(iC) < Pcyc.flatline_min_ptp;
                case "std"
                    cyc.is_flatline(iC) = cyc.cycle_std(iC) < Pcyc.flatline_min_std;
                otherwise
                    error('Unknown flatline_method: %s', string(Pcyc.flatline_method));
            end
        end

        flat_segments = zeros(0,2);
        if numel(x_cycle) >= 2 && ~cyc.is_flatline(iC)
            dx = abs(diff(x_cycle));
            flat_mask = dx < Pcyc.flatline_diff_thresh;

            flat_runs = logical_to_runs_local(flat_mask);
            if ~isempty(flat_runs)
                run_lengths = flat_runs(:,2) - flat_runs(:,1) + 1;
                flat_runs = flat_runs(run_lengths >= Pcyc.flatline_min_run_samples, :);

                if ~isempty(flat_runs)
                    flat_segments = [flat_runs(:,1), flat_runs(:,2)+1];
                    flat_segments = merge_segments_local(flat_segments);
                end
            end
        end

        if isempty(flat_segments)
            flat_covered = 0;
        else
            flat_covered = sum(flat_segments(:,2) - flat_segments(:,1) + 1);
        end

        flat_fraction = flat_covered / cyc.cycle_length_samples(iC);

        cyc.flatline_segments{iC} = flat_segments;
        cyc.flatline_covered_samples(iC) = flat_covered;
        cyc.flatline_fraction(iC) = flat_fraction;
        cyc.is_partly_flatline(iC) = flat_fraction > Pcyc.max_flatline_fraction;

        overlap_idx = [];
        bad_segments = [];

        for iB = 1:nBursts
            b1 = bursts(iB,1);
            b2 = bursts(iB,2);

            if (b1 <= c2) && (b2 >= c1)
                overlap_idx(end+1) = iB; %#ok<AGROW>

                if ~burst_keep(iB)
                    ov1 = max(b1, c1);
                    ov2 = min(b2, c2);
                    if ov2 >= ov1
                        bad_segments = [bad_segments; ov1-c1+1, ov2-c1+1]; %#ok<AGROW>
                    end
                end
            end
        end

        overlap_idx = unique(overlap_idx, 'stable');
        cyc.overlapping_burst_idx{iC} = overlap_idx;
        cyc.n_overlapping_bursts(iC) = numel(overlap_idx);
        cyc.has_any_burst(iC) = ~isempty(overlap_idx);

        if ~isempty(overlap_idx)
            cyc.has_good_burst(iC) = any(burst_keep(overlap_idx));
            cyc.has_bad_burst(iC)  = any(~burst_keep(overlap_idx));
            cyc.n_good_bursts(iC)  = sum(burst_keep(overlap_idx));
            cyc.n_bad_bursts(iC)   = sum(~burst_keep(overlap_idx));
        end

        if isempty(bad_segments)
            cyc.bad_burst_overlap_segments{iC} = zeros(0,2);
            cyc.bad_burst_covered_samples(iC) = 0;
            cyc.bad_burst_fraction(iC) = 0;
        else
            merged_bad_segments = merge_segments_local(bad_segments);
            cyc.bad_burst_overlap_segments{iC} = merged_bad_segments;
            covered = sum(merged_bad_segments(:,2) - merged_bad_segments(:,1) + 1);
            cyc.bad_burst_covered_samples(iC) = covered;
            cyc.bad_burst_fraction(iC) = covered / cyc.cycle_length_samples(iC);
        end

        reasons = strings(0,1);

        if Pcyc.require_at_least_one_burst && ~cyc.has_any_burst(iC)
            reasons(end+1) = "no_burst_detected";
        end

        if Pcyc.require_at_least_one_good_burst && ~cyc.has_good_burst(iC)
            reasons(end+1) = "no_good_burst";
        end

        if Pcyc.reject_if_any_bad_burst && cyc.has_bad_burst(iC)
            reasons(end+1) = "contains_bad_burst";
        end

        if Pcyc.reject_if_bad_burst_fraction_over && cyc.bad_burst_fraction(iC) > Pcyc.max_bad_burst_fraction
            reasons(end+1) = "bad_burst_fraction_too_high";
        end

        if Pcyc.reject_flatline_cycles && cyc.is_flatline(iC)
            reasons(end+1) = "flatline_cycle";
        end

        if Pcyc.reject_if_flatline_fraction_over && cyc.is_partly_flatline(iC)
            reasons(end+1) = "flatline_fraction_too_high";
        end

        if isempty(reasons)
            cyc.cycle_keep_mask(iC) = true;
            cyc.cycle_reason(iC) = "keep";
        else
            cyc.cycle_keep_mask(iC) = false;
            cyc.cycle_reason(iC) = strjoin(reasons, "+");
        end
    end

    cyc.cycle_table = table( repmat(string(subjID), nCycles,1), repmat(string(cond),   nCycles,1), repmat(string(leg),    nCycles,1), repmat(string(mf),     nCycles,1), (1:nCycles)', cycle_starts(:), cycle_ends(:), cyc.cycle_length_samples, cyc.n_overlapping_bursts, cyc.n_good_bursts, cyc.n_bad_bursts, cyc.has_any_burst, cyc.has_good_burst, cyc.has_bad_burst, cyc.bad_burst_covered_samples, cyc.bad_burst_fraction, cyc.cycle_ptp, cyc.cycle_std, cyc.is_flatline, cyc.cycle_keep_mask, cyc.cycle_reason, 'VariableNames', { 'subject','condition','leg','muscle','cycle_number', 'cycle_start_idx','cycle_end_idx','cycle_length_samples', 'n_overlapping_bursts','n_good_bursts','n_bad_bursts', 'has_any_burst','has_good_burst','has_bad_burst', 'bad_burst_covered_samples','bad_burst_fraction', 'cycle_ptp','cycle_std','is_flatline', 'cycle_keep','cycle_reason'});
end

function Svalid = build_valid_cycle_index_struct_one_muscle(cycle_starts, cycle_ends, toe_info, valid_cycle_numbers)

    nV = numel(valid_cycle_numbers);

    Svalid = struct();
    Svalid.cycle_number = valid_cycle_numbers(:);
    Svalid.cycle_start_idx = nan(nV,1);
    Svalid.cycle_end_idx = nan(nV,1);
    Svalid.cycle_length_samples = nan(nV,1);
    Svalid.has_toe_off = false(nV,1);
    Svalid.toe_off_original_idx = nan(nV,1);
    Svalid.toe_off_relative_idx = nan(nV,1);
    Svalid.toe_off_relative_fraction = nan(nV,1);

    rows = cell(nV, 8);

    for i = 1:nV
        cycNum = valid_cycle_numbers(i);
        c1 = cycle_starts(cycNum);
        c2 = cycle_ends(cycNum);
        len = c2 - c1 + 1;

        Svalid.cycle_start_idx(i) = c1;
        Svalid.cycle_end_idx(i) = c2;
        Svalid.cycle_length_samples(i) = len;
        Svalid.has_toe_off(i) = toe_info.has_toe_off(cycNum);
        Svalid.toe_off_original_idx(i) = toe_info.toe_off_original_idx(cycNum);
        Svalid.toe_off_relative_idx(i) = toe_info.toe_off_relative_idx(cycNum);
        Svalid.toe_off_relative_fraction(i) = toe_info.toe_off_relative_fraction(cycNum);

        rows(i,:) = { cycNum, c1, c2, len, toe_info.has_toe_off(cycNum), toe_info.toe_off_original_idx(cycNum), toe_info.toe_off_relative_idx(cycNum), toe_info.toe_off_relative_fraction(cycNum)};
    end

    if ~isempty(rows)
        Svalid.table = cell2table(rows, 'VariableNames', { 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples', 'has_toe_off','toe_off_original_idx','toe_off_relative_idx','toe_off_relative_fraction'});
    else
        Svalid.table = table();
    end
end

function Svalid = build_valid_cycle_index_struct_pairwise(cycle_starts, cycle_ends, toe1, toe2, valid_pair_cycle_numbers)

    nV = numel(valid_pair_cycle_numbers);

    Svalid = struct();
    Svalid.cycle_number = valid_pair_cycle_numbers(:);
    Svalid.cycle_start_idx = nan(nV,1);
    Svalid.cycle_end_idx = nan(nV,1);
    Svalid.cycle_length_samples = nan(nV,1);

    Svalid.muscle1_has_toe_off = false(nV,1);
    Svalid.muscle2_has_toe_off = false(nV,1);
    Svalid.muscle1_toe_off_relative_fraction = nan(nV,1);
    Svalid.muscle2_toe_off_relative_fraction = nan(nV,1);

    rows = cell(nV, 8);

    for i = 1:nV
        cycNum = valid_pair_cycle_numbers(i);
        c1 = cycle_starts(cycNum);
        c2 = cycle_ends(cycNum);
        len = c2 - c1 + 1;

        Svalid.cycle_start_idx(i) = c1;
        Svalid.cycle_end_idx(i) = c2;
        Svalid.cycle_length_samples(i) = len;

        Svalid.muscle1_has_toe_off(i) = toe1.has_toe_off(cycNum);
        Svalid.muscle2_has_toe_off(i) = toe2.has_toe_off(cycNum);
        Svalid.muscle1_toe_off_relative_fraction(i) = toe1.toe_off_relative_fraction(cycNum);
        Svalid.muscle2_toe_off_relative_fraction(i) = toe2.toe_off_relative_fraction(cycNum);

        rows(i,:) = { cycNum, c1, c2, len, toe1.has_toe_off(cycNum), toe2.has_toe_off(cycNum), toe1.toe_off_relative_fraction(cycNum), toe2.toe_off_relative_fraction(cycNum)};
    end

    if ~isempty(rows)
        Svalid.table = cell2table(rows, 'VariableNames', { 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples', 'muscle1_has_toe_off','muscle2_has_toe_off', 'muscle1_toe_off_relative_fraction','muscle2_toe_off_relative_fraction'});
    else
        Svalid.table = table();
    end
end

function T = build_pair_cycle_table(subjID, age_group, cond, leg, pairName, mus1, mus2, cycle_starts, cycle_ends, cyc1, cyc2, pair_keep, pair_reason, toe1, toe2, fs)
    nCycles = numel(cycle_starts);
    rows = cell(nCycles, 20);

    for iC = 1:nCycles
        rows(iC,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(mus1), string(mus2), iC, cycle_starts(iC), cycle_ends(iC), cycle_ends(iC)-cycle_starts(iC)+1, fs, logical(cyc1.cycle_keep_mask(iC)), logical(cyc2.cycle_keep_mask(iC)), logical(pair_keep(iC)), string(pair_reason(iC)), logical(toe1.has_toe_off(iC)), logical(toe2.has_toe_off(iC)), toe1.toe_off_relative_fraction(iC), toe2.toe_off_relative_fraction(iC) };
    end

    T = cell2table(rows, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','muscle1','muscle2', 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples','fs', 'muscle1_cycle_keep','muscle2_cycle_keep','pair_cycle_keep','pair_cycle_reason', 'muscle1_has_toe_off','muscle2_has_toe_off', 'muscle1_toe_off_relative_fraction','muscle2_toe_off_relative_fraction'});
end

function S = ensure_td_single_fields(S, subjID, cond, leg)
    if ~isfield(S, subjID), S.(subjID) = struct(); end
    if ~isfield(S.(subjID), cond), S.(subjID).(cond) = struct(); end
    if ~isfield(S.(subjID).(cond), leg), S.(subjID).(cond).(leg) = struct(); end
end

function S = ensure_td_pair_fields(S, subjID, cond, leg)
    if ~isfield(S, subjID), S.(subjID) = struct(); end
    if ~isfield(S.(subjID), cond), S.(subjID).(cond) = struct(); end
    if ~isfield(S.(subjID).(cond), leg), S.(subjID).(cond).(leg) = struct(); end
end
function T = rows_to_table(rows, varNames)
    if isempty(rows)
        T = table();
    else
        T = cell2table(rows, 'VariableNames', varNames);
    end
end

function E = get_preproc_entry_single(EMG_PREPROC, subjID, cond, leg, mf)
    assert(isfield(EMG_PREPROC, subjID), 'Missing subject in EMG_PREPROC: %s', subjID);
    assert(isfield(EMG_PREPROC.(subjID), cond), 'Missing condition in EMG_PREPROC: %s | %s', subjID, cond);
    assert(isfield(EMG_PREPROC.(subjID).(cond), leg), 'Missing leg in EMG_PREPROC: %s | %s | %s', subjID, cond, leg);
    assert(isfield(EMG_PREPROC.(subjID).(cond).(leg), mf), 'Missing muscle in EMG_PREPROC: %s | %s | %s | %s', subjID, cond, leg, mf);

    E = EMG_PREPROC.(subjID).(cond).(leg).(mf);
    assert(isfield(E, 'time_domain'), 'Missing time_domain branch in EMG_PREPROC entry.');
end

function Svalid = build_valid_cycle_dataset_one_muscle(preprocEntry, cycle_starts, cycle_ends, toe_info, valid_cycle_numbers, P)

    nV = numel(valid_cycle_numbers);

    Svalid = struct();
    Svalid.cycle_number = valid_cycle_numbers(:);
    Svalid.cycle_start_idx = nan(nV,1);
    Svalid.cycle_end_idx = nan(nV,1);
    Svalid.cycle_length_samples = nan(nV,1);

    Svalid.has_toe_off = false(nV,1);
    Svalid.toe_off_original_idx = nan(nV,1);
    Svalid.toe_off_relative_idx = nan(nV,1);
    Svalid.toe_off_relative_fraction = nan(nV,1);

    if P.extract_signals.bandpassed
        Svalid.bandpassed = cell(nV,1);
    end
    if P.extract_signals.rectified
        Svalid.rectified = cell(nV,1);
    end
    if P.extract_signals.envelope
        Svalid.envelope = cell(nV,1);
    end

    if P.store_time_normalized_cycles
        if P.extract_signals.bandpassed
            Svalid.time_normalized_bandpassed = cell(nV,1);
        end
        if P.extract_signals.rectified
            Svalid.time_normalized_rectified = cell(nV,1);
        end
        if P.extract_signals.envelope
            Svalid.time_normalized_envelope = cell(nV,1);
        end
    end

    rows = cell(nV, 8);

    for i = 1:nV
        cycNum = valid_cycle_numbers(i);
        c1 = cycle_starts(cycNum);
        c2 = cycle_ends(cycNum);
        len = c2 - c1 + 1;

        Svalid.cycle_start_idx(i) = c1;
        Svalid.cycle_end_idx(i) = c2;
        Svalid.cycle_length_samples(i) = len;

        Svalid.has_toe_off(i) = toe_info.has_toe_off(cycNum);
        Svalid.toe_off_original_idx(i) = toe_info.toe_off_original_idx(cycNum);
        Svalid.toe_off_relative_idx(i) = toe_info.toe_off_relative_idx(cycNum);
        Svalid.toe_off_relative_fraction(i) = toe_info.toe_off_relative_fraction(cycNum);

        if P.extract_signals.bandpassed
            x = preprocEntry.time_domain.bandpassed(c1:c2);
            Svalid.bandpassed{i} = x(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_bandpassed{i} = normalize_vector_to_n(x, P.n_normalized_points);
            end
        end

        if P.extract_signals.rectified
            x = preprocEntry.time_domain.rectified(c1:c2);
            Svalid.rectified{i} = x(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_rectified{i} = normalize_vector_to_n(x, P.n_normalized_points);
            end
        end

        if P.extract_signals.envelope
            x = preprocEntry.time_domain.envelope(c1:c2);
            Svalid.envelope{i} = x(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_envelope{i} = normalize_vector_to_n(x, P.n_normalized_points);
            end
        end

        rows(i,:) = { cycNum, c1, c2, len, toe_info.has_toe_off(cycNum), toe_info.toe_off_original_idx(cycNum), toe_info.toe_off_relative_idx(cycNum), toe_info.toe_off_relative_fraction(cycNum)};
    end

    if ~isempty(rows)
        Svalid.table = cell2table(rows, 'VariableNames', { 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples', 'has_toe_off','toe_off_original_idx','toe_off_relative_idx','toe_off_relative_fraction'});
    else
        Svalid.table = table();
    end
end

function Svalid = build_valid_cycle_dataset_pairwise(preprocEntry1, preprocEntry2, cycle_starts, cycle_ends, toe1, toe2, valid_pair_cycle_numbers, P)

    nV = numel(valid_pair_cycle_numbers);

    Svalid = struct();
    Svalid.cycle_number = valid_pair_cycle_numbers(:);
    Svalid.cycle_start_idx = nan(nV,1);
    Svalid.cycle_end_idx = nan(nV,1);
    Svalid.cycle_length_samples = nan(nV,1);

    Svalid.muscle1_has_toe_off = false(nV,1);
    Svalid.muscle2_has_toe_off = false(nV,1);
    Svalid.muscle1_toe_off_relative_fraction = nan(nV,1);
    Svalid.muscle2_toe_off_relative_fraction = nan(nV,1);

    if P.extract_signals.bandpassed
        Svalid.bandpassed_1 = cell(nV,1);
        Svalid.bandpassed_2 = cell(nV,1);
    end
    if P.extract_signals.rectified
        Svalid.rectified_1 = cell(nV,1);
        Svalid.rectified_2 = cell(nV,1);
    end
    if P.extract_signals.envelope
        Svalid.envelope_1 = cell(nV,1);
        Svalid.envelope_2 = cell(nV,1);
    end

    if P.store_time_normalized_cycles
        if P.extract_signals.bandpassed
            Svalid.time_normalized_bandpassed_1 = cell(nV,1);
            Svalid.time_normalized_bandpassed_2 = cell(nV,1);
        end
        if P.extract_signals.rectified
            Svalid.time_normalized_rectified_1 = cell(nV,1);
            Svalid.time_normalized_rectified_2 = cell(nV,1);
        end
        if P.extract_signals.envelope
            Svalid.time_normalized_envelope_1 = cell(nV,1);
            Svalid.time_normalized_envelope_2 = cell(nV,1);
        end
    end

    rows = cell(nV, 8);

    for i = 1:nV
        cycNum = valid_pair_cycle_numbers(i);
        c1 = cycle_starts(cycNum);
        c2 = cycle_ends(cycNum);
        len = c2 - c1 + 1;

        Svalid.cycle_start_idx(i) = c1;
        Svalid.cycle_end_idx(i) = c2;
        Svalid.cycle_length_samples(i) = len;

        Svalid.muscle1_has_toe_off(i) = toe1.has_toe_off(cycNum);
        Svalid.muscle2_has_toe_off(i) = toe2.has_toe_off(cycNum);
        Svalid.muscle1_toe_off_relative_fraction(i) = toe1.toe_off_relative_fraction(cycNum);
        Svalid.muscle2_toe_off_relative_fraction(i) = toe2.toe_off_relative_fraction(cycNum);

        if P.extract_signals.bandpassed
            x1 = preprocEntry1.time_domain.bandpassed(c1:c2);
            x2 = preprocEntry2.time_domain.bandpassed(c1:c2);
            Svalid.bandpassed_1{i} = x1(:);
            Svalid.bandpassed_2{i} = x2(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_bandpassed_1{i} = normalize_vector_to_n(x1, P.n_normalized_points);
                Svalid.time_normalized_bandpassed_2{i} = normalize_vector_to_n(x2, P.n_normalized_points);
            end
        end

        if P.extract_signals.rectified
            x1 = preprocEntry1.time_domain.rectified(c1:c2);
            x2 = preprocEntry2.time_domain.rectified(c1:c2);
            Svalid.rectified_1{i} = x1(:);
            Svalid.rectified_2{i} = x2(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_rectified_1{i} = normalize_vector_to_n(x1, P.n_normalized_points);
                Svalid.time_normalized_rectified_2{i} = normalize_vector_to_n(x2, P.n_normalized_points);
            end
        end

        if P.extract_signals.envelope
            x1 = preprocEntry1.time_domain.envelope(c1:c2);
            x2 = preprocEntry2.time_domain.envelope(c1:c2);
            Svalid.envelope_1{i} = x1(:);
            Svalid.envelope_2{i} = x2(:);
            if P.store_time_normalized_cycles
                Svalid.time_normalized_envelope_1{i} = normalize_vector_to_n(x1, P.n_normalized_points);
                Svalid.time_normalized_envelope_2{i} = normalize_vector_to_n(x2, P.n_normalized_points);
            end
        end

        rows(i,:) = { cycNum, c1, c2, len, toe1.has_toe_off(cycNum), toe2.has_toe_off(cycNum), toe1.toe_off_relative_fraction(cycNum), toe2.toe_off_relative_fraction(cycNum)};
    end

    if ~isempty(rows)
        Svalid.table = cell2table(rows, 'VariableNames', { 'cycle_number','cycle_start_idx','cycle_end_idx','cycle_length_samples', 'muscle1_has_toe_off','muscle2_has_toe_off', 'muscle1_toe_off_relative_fraction','muscle2_toe_off_relative_fraction'});
    else
        Svalid.table = table();
    end
end

function y = normalize_vector_to_n(x, n)
    x = x(:);
    if isempty(x)
        y = nan(n,1);
        return;
    end
    if numel(x) == 1
        y = repmat(x, n, 1);
        return;
    end

    xq = linspace(1, numel(x), n);
    y = interp1(1:numel(x), x, xq, 'linear');
    y = y(:);
end
