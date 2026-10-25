function [FINAL_PAIRED_SIGNALS, CYCLE_QC_ROWS, PAIR_QC_ROWS, SIGNAL_ROWS] = f_select_cycles_and_rebuild_pairs(C)
% F_SELECT_CYCLES_AND_REBUILD_PAIRS  The core of stage f. For every subject x
% condition x leg x muscle pair: align the two muscles' gait cycles, judge
% each cycle per muscle (bursts, flatline, bad bursts near the phase of
% interest, per band), keep the cycles valid in both muscles, and rebuild the
% pair signals from the kept cycles. Returns the pair struct and the rows of
% the cycle, pair-cycle and signal QC tables.

    IO = C.f_final_signals.io;
    P  = C.f_final_signals.params;

    %% ===================== PREPARE WAVELET BOUNDARIES =====================

    WCQ = P.wavelet_contamination_qc;

    BAND_BOUNDARIES = compute_wavelet_band_boundaries_from_config(WCQ);
    OVERALL_BOUNDARY_SEC = get_overall_contamination_boundary_sec(BAND_BOUNDARIES, WCQ);
    bandNames = fieldnames(WCQ.freq_bands);

    print_wavelet_band_boundaries_from_struct(BAND_BOUNDARIES, WCQ);

    print_phase_intervals_for_pair("TAprox_TAdist", 1.0, WCQ);
    print_phase_intervals_for_pair("SOL_GM", 1.0, WCQ);
    print_phase_intervals_for_pair("VL_RF", 1.0, WCQ);

    %% ===================== CHECKS =====================
    assert(isfile(IO.final_burst_mat), 'FINAL_BURST_QC.mat not found: %s', IO.final_burst_mat);
    burstFiles = dir(fullfile(IO.bursts_dir, '*_EMG_BURSTS.mat'));
    assert(~isempty(burstFiles), 'No burst files found in %s', IO.bursts_dir);

    fprintf('Processing pairs: ');
    for iPair = 1:numel(P.pairs)
        fprintf('%s, ', P.pairs{iPair}.name);
    end
    fprintf('\n');

    %% ===================== LOAD FINAL BURST QC =====================
    Lq = load(IO.final_burst_mat);
    assert(isfield(Lq, 'FINAL_BURST_QC'), 'FINAL_BURST_QC not found in mat file.');
    FINAL_BURST_QC = Lq.FINAL_BURST_QC;

    %% ===================== MAP BURST FILES =====================
    burstMap = containers.Map('KeyType','char','ValueType','char');
    for k = 1:numel(burstFiles)
        tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
        end
    end

    %% ===================== OUTPUT STRUCTURES =====================
    FINAL_PAIRED_SIGNALS = struct();
    CYCLE_QC_ROWS = {};
    PAIR_QC_ROWS  = {};
    SIGNAL_ROWS   = {};
    riC = 0; riP = 0; riS = 0;

    subjects = fieldnames(FINAL_BURST_QC);

    %% ===================== MAIN LOOP =====================

    fprintf('\n=== Active cycle policy ===\n');
    disp(P.cycle_policy)

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        fprintf('\n=== Build final paired signals: %s ===\n', subjID);

        if ~isKey(burstMap, subjID)
            warning('No burst file found for %s. Skipping subject.', subjID);
            continue;
        end

        Lb = load(burstMap(subjID));
        if ~isfield(Lb, 'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
            warning('BURSTS_DET missing for %s. Skipping subject.', subjID);
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

                for iPair = 1:numel(P.pairs)
                    pairName = P.pairs{iPair}.name;
                    mus1 = P.pairs{iPair}.muscles{1};
                    mus2 = P.pairs{iPair}.muscles{2};

                    % ---------- check presence ----------
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

                    % ---------- signals ----------
                    if ~isfield(E1,'signal') || isempty(E1.signal) || ~isfield(E2,'signal') || isempty(E2.signal)
                        continue;
                    end

                    x1 = E1.signal(:);
                    x2 = E2.signal(:);

                    % ---------- fs ----------
                    fs = get_fs_from_entry_or_default(E1, C);

                    % ---------- cycle starts / ends ----------
                    [cycle_starts_1, cycle_ends_1, cycle_source_1] = get_cycle_boundaries(E1, P.cycle_field_candidates, P.cycle_end_field_candidates);
                    [cycle_starts_2, cycle_ends_2, cycle_source_2] = get_cycle_boundaries(E2, P.cycle_field_candidates, P.cycle_end_field_candidates);

                    % ---------- find toe off events in cycle coordinates ----------
                    toe_off_1 = get_toe_off_in_concat_coordinates(E1);
                    toe_off_2 = get_toe_off_in_concat_coordinates(E2);


                    % Need both muscles to define a synchronized pair
                    if isempty(cycle_starts_1) || isempty(cycle_starts_2)
                        warning('No cycle starts for %s | %s | %s | %s', subjID, cond, leg, pairName);
                        continue;
                    end


                    % ---------- align cycle boundaries between muscles ----------
                    % Since pair analysis needs identical moments, we require identical cycles.
                    [cycle_starts_pair, cycle_ends_pair, cycle_alignment_note] = harmonize_cycle_boundaries(cycle_starts_1, cycle_ends_1, cycle_starts_2, cycle_ends_2, numel(x1), numel(x2));

                    cycle_starts_pair = cycle_starts_pair(:);
                    cycle_ends_pair   = cycle_ends_pair(:);

                    if numel(cycle_starts_pair) ~= numel(cycle_ends_pair)
                        warning('Mismatched cycle starts/ends after harmonization for %s | %s | %s | %s: starts=%d ends=%d', subjID, cond, leg, pairName, numel(cycle_starts_pair), numel(cycle_ends_pair));
                        nTmp = min(numel(cycle_starts_pair), numel(cycle_ends_pair));
                        cycle_starts_pair = cycle_starts_pair(1:nTmp);
                        cycle_ends_pair   = cycle_ends_pair(1:nTmp);
                    elseif numel(cycle_starts_pair) == 0
                        warning('No valid cycles after harmonization for %s | %s | %s | %s', subjID, cond, leg, pairName);
                        continue;
                    end

                    % Which trial each cycle came from, and which cycles are
                    % continuous recording; stage g transforms per run.
                    [cycle_trial_id, cycle_run_id, cycle_run_note] = get_pair_cycle_run_ids( ...
                        E1, E2, cycle_starts_pair, cycle_ends_pair, cycle_alignment_note);

                    toe_pair_1 = assign_toe_off_to_cycles(cycle_starts_pair, cycle_ends_pair, toe_off_1);
                    toe_pair_2 = assign_toe_off_to_cycles(cycle_starts_pair, cycle_ends_pair, toe_off_2);

                    if isempty(cycle_starts_pair)
                        warning('Could not harmonize cycles for %s | %s | %s | %s', subjID, cond, leg, pairName);
                        continue;
                    end

                    nCycles = numel(cycle_starts_pair);

                    % ---------- burst info ----------
                    bursts1 = get_bursts_idx_from_qc_or_entry(Q1, E1);
                    bursts2 = get_bursts_idx_from_qc_or_entry(Q2, E2);

                    keep1 = get_final_keep_mask(Q1, size(bursts1,1));
                    keep2 = get_final_keep_mask(Q2, size(bursts2,1));

                    reason1 = get_final_reason(Q1, size(bursts1,1));
                    reason2 = get_final_reason(Q2, size(bursts2,1));

                    cyc1 = evaluate_cycles_for_one_muscle(subjID, cond, leg, mus1, pairName, x1, cycle_starts_pair, cycle_ends_pair, bursts1, keep1, reason1, P, fs, WCQ, OVERALL_BOUNDARY_SEC, BAND_BOUNDARIES);

                    cyc2 = evaluate_cycles_for_one_muscle(subjID, cond, leg, mus2, pairName, x2, cycle_starts_pair, cycle_ends_pair, bursts2, keep2, reason2, P, fs, WCQ, OVERALL_BOUNDARY_SEC, BAND_BOUNDARIES);

                    cyc1.source_bursts_idx = bursts1;
                    cyc2.source_bursts_idx = bursts2;

                    cyc1.source_burst_keep_mask = keep1;
                    cyc2.source_burst_keep_mask = keep2;

                    cyc1.source_burst_reason = reason1;
                    cyc2.source_burst_reason = reason2;

                    % ---------- pair-level cycle QC ----------
                    pair_cycle_keep = cyc1.cycle_keep_mask & cyc2.cycle_keep_mask;
                    pair_cycle_reason = strings(nCycles,1);
                    pair_wavelet_keep_overall = cyc1.wavelet_keep_overall & cyc2.wavelet_keep_overall;
                    pair_wavelet_contaminated_overall = ~pair_wavelet_keep_overall;

                    pair_cycle_keep_by_band = struct();
                    pair_cycle_reason_by_band = struct();

                    for ib = 1:numel(bandNames)
                        band = bandNames{ib};

                        pair_cycle_keep_by_band.(band) = cyc1.band_keep_mask.(band) & cyc2.band_keep_mask.(band);

                        tmpReason = strings(nCycles,1);

                        for iCyc = 1:nCycles
                            rr = strings(0,1);

                            if ~cyc1.band_keep_mask.(band)(iCyc)
                                rr(end+1) = "bad_in_" + string(mus1);
                            end
                            if ~cyc2.band_keep_mask.(band)(iCyc)
                                rr(end+1) = "bad_in_" + string(mus2);
                            end

                            if isempty(rr)
                                tmpReason(iCyc) = "keep";
                            else
                                tmpReason(iCyc) = strjoin(rr, "+");
                            end
                        end

                        pair_cycle_reason_by_band.(band) = tmpReason;
                    end

                    for iCyc = 1:nCycles
                        reasons = strings(0,1);

                        if ~cyc1.cycle_keep_mask(iCyc)
                            reasons(end+1) = "bad_in_" + string(mus1);
                        end
                        if ~cyc2.cycle_keep_mask(iCyc)
                            reasons(end+1) = "bad_in_" + string(mus2);
                        end

                        if isempty(reasons)
                            pair_cycle_reason(iCyc) = "keep";
                        else
                            pair_cycle_reason(iCyc) = strjoin(reasons, "+");
                        end
                    end

                    valid_cycle_numbers   = find(pair_cycle_keep);
                    removed_cycle_numbers = find(~pair_cycle_keep);

                    n_valid_cycles = numel(valid_cycle_numbers);
                    included_for_analysis = n_valid_cycles >= P.min_cycles_required;

                    if included_for_analysis
                        exclusion_reason = "";
                    else
                        exclusion_reason = "too_few_valid_cycles";
                    end

                    % ---------- build final concatenated signals ----------
                    [final_sig_1, final_sig_2, cycle_segments_table] = build_final_concatenated_pair( x1, x2, cycle_starts_pair, cycle_ends_pair, pair_cycle_keep, cycle_run_id, cycle_trial_id);

                    band_specific = struct();

                    for ib = 1:numel(bandNames)
                        band = bandNames{ib};

                        [sig1_band, sig2_band, Tseg_band] = build_final_concatenated_pair( x1, x2, cycle_starts_pair, cycle_ends_pair, pair_cycle_keep_by_band.(band), cycle_run_id, cycle_trial_id);

                        Tseg_band = add_toe_off_to_rebuilt_segments(Tseg_band, toe_pair_1);

                        band_specific.(band) = struct();
                        band_specific.(band).pair_cycle_keep_mask = pair_cycle_keep_by_band.(band);
                        band_specific.(band).pair_cycle_reason = pair_cycle_reason_by_band.(band);
                        band_specific.(band).valid_cycle_numbers = find(pair_cycle_keep_by_band.(band));
                        band_specific.(band).removed_cycle_numbers = find(~pair_cycle_keep_by_band.(band));
                        band_specific.(band).n_valid_cycles = sum(pair_cycle_keep_by_band.(band));
                        band_specific.(band).included_for_analysis = sum(pair_cycle_keep_by_band.(band)) >= P.min_cycles_required;

                        band_specific.(band).final_concatenated_signal_1 = sig1_band;
                        band_specific.(band).final_concatenated_signal_2 = sig2_band;
                        band_specific.(band).final_cycle_segments_table = Tseg_band;
                    end

                    cycle_segments_table = add_toe_off_to_rebuilt_segments(cycle_segments_table, toe_pair_1);

                    % ---------- save cycle qc rows ----------
                    for iCyc = 1:nCycles
                        riC = riC + 1;
                        CYCLE_QC_ROWS(riC,:) = { string(subjID), string(cond), string(leg), string(mus1), iCyc, cycle_starts_pair(iCyc), cycle_ends_pair(iCyc), cyc1.n_overlapping_bursts(iCyc), cyc1.has_any_burst(iCyc), cyc1.has_good_burst(iCyc), cyc1.has_bad_burst(iCyc), cyc1.cycle_keep_mask(iCyc), string(cyc1.cycle_reason(iCyc)) };

                        riC = riC + 1;
                        CYCLE_QC_ROWS(riC,:) = { string(subjID), string(cond), string(leg), string(mus2), iCyc, cycle_starts_pair(iCyc), cycle_ends_pair(iCyc), cyc2.n_overlapping_bursts(iCyc), cyc2.has_any_burst(iCyc), cyc2.has_good_burst(iCyc), cyc2.has_bad_burst(iCyc), cyc2.cycle_keep_mask(iCyc), string(cyc2.cycle_reason(iCyc)) };
                    end

                    % ---------- save pair qc rows ----------
                    for iCyc = 1:nCycles
                        riP = riP + 1;

                        pairReason_i = string(pair_cycle_reason(iCyc));
                        if numel(pairReason_i) ~= 1
                            pairReason_i = strjoin(pairReason_i, "+");
                        end

                        bandKeep = cell(1, numel(bandNames));
                        bandReason = cell(1, numel(bandNames));
                        for ib = 1:numel(bandNames)
                            band = bandNames{ib};
                            r = string(pair_cycle_reason_by_band.(band)(iCyc));
                            if numel(r) ~= 1
                                r = strjoin(r, "+");
                            end
                            bandKeep{ib} = logical(pair_cycle_keep_by_band.(band)(iCyc));
                            bandReason{ib} = char(r);
                        end

                        PAIR_QC_ROWS(riP,:) = [{ char(string(subjID)), char(string(cond)), char(string(leg)), char(string(pairName)), char(string(mus1)), char(string(mus2)), double(iCyc), double(cycle_starts_pair(iCyc)), double(cycle_ends_pair(iCyc)), logical(cyc1.cycle_keep_mask(iCyc)), logical(cyc2.cycle_keep_mask(iCyc)), logical(pair_cycle_keep(iCyc)), char(pairReason_i)}, bandKeep, bandReason];
                    end

                    age_group = subject_to_group(subjID, C);

                    % ---------- save summary row ----------
                    riS = riS + 1;
                    SIGNAL_ROWS(riS,:) = [{ string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(mus1), string(mus2), nCycles, n_valid_cycles, numel(removed_cycle_numbers), included_for_analysis, string(exclusion_reason), numel(final_sig_1), numel(final_sig_2), fs, string(cycle_source_1), string(cycle_source_2), string(cycle_alignment_note)}, ...
                        cellfun(@(b) band_specific.(b).n_valid_cycles, bandNames(:)', 'UniformOutput', false), ...
                        cellfun(@(b) band_specific.(b).included_for_analysis, bandNames(:)', 'UniformOutput', false)];
                    % ---------- save hierarchical struct ----------
                    FINAL_PAIRED_SIGNALS = ensure_pair_fields(FINAL_PAIRED_SIGNALS, subjID, cond, leg);

                    PairStruct = struct();
                    PairStruct.pair_name = string(pairName);
                    PairStruct.muscles = {mus1, mus2};
                    PairStruct.fs = fs;

                    % original signals
                    PairStruct.original_signal_1 = x1;
                    PairStruct.original_signal_2 = x2;

                    % cycle metadata
                    PairStruct.cycle_starts = cycle_starts_pair;
                    PairStruct.cycle_ends   = cycle_ends_pair;
                    PairStruct.n_cycles_total = nCycles;
                    PairStruct.cycle_trial_id = cycle_trial_id;
                    PairStruct.cycle_run_id   = cycle_run_id;
                    PairStruct.cycle_run_note = cycle_run_note;
                    PairStruct.valid_cycle_numbers = valid_cycle_numbers(:);
                    PairStruct.removed_cycle_numbers = removed_cycle_numbers(:);

                    % toe off info
                    PairStruct.toe_off_original_idx_muscle1 = toe_off_1;
                    PairStruct.toe_off_original_idx_muscle2 = toe_off_2;

                    PairStruct.toe_off_info_muscle1 = toe_pair_1;
                    PairStruct.toe_off_info_muscle2 = toe_pair_2;

                    % muscle-specific cycle QC
                    PairStruct.muscle1_cycle_qc = cyc1;
                    PairStruct.muscle2_cycle_qc = cyc2;

                    PairStruct.muscle1_bursts_idx = bursts1;
                    PairStruct.muscle2_bursts_idx = bursts2;

                    PairStruct.muscle1_burst_keep_mask = keep1;
                    PairStruct.muscle2_burst_keep_mask = keep2;

                    % pair-level cycle QC
                    PairStruct.pair_cycle_keep_mask = pair_cycle_keep;
                    PairStruct.pair_cycle_reason    = pair_cycle_reason;

                    PairStruct.muscle1_burst_reason = reason1;
                    PairStruct.muscle2_burst_reason = reason2;

                    % final inclusion
                    PairStruct.n_valid_cycles = n_valid_cycles;
                    PairStruct.min_cycles_required = P.min_cycles_required;
                    PairStruct.included_for_analysis = included_for_analysis;
                    PairStruct.exclusion_reason = exclusion_reason;

                    % cycle sources / alignment
                    PairStruct.cycle_source_field_muscle1 = cycle_source_1;
                    PairStruct.cycle_source_field_muscle2 = cycle_source_2;
                    PairStruct.cycle_alignment_note = cycle_alignment_note;

                    % final analysis-ready concatenated signals
                    PairStruct.final_concatenated_signal_1 = final_sig_1;
                    PairStruct.final_concatenated_signal_2 = final_sig_2;

                    % more traceability
                    PairStruct.final_cycle_segments_table = cycle_segments_table;

                    % wavelet contamination qc info
                    PairStruct.pair_wavelet_keep_overall = pair_wavelet_keep_overall;
                    PairStruct.pair_wavelet_contaminated_overall = pair_wavelet_contaminated_overall;
                    PairStruct.overall_contamination_half_width_sec = OVERALL_BOUNDARY_SEC;
                    PairStruct.wavelet_contamination_qc = WCQ;

                    % Band-specific pair cycle keep / reason
                    PairStruct.general_keep_mask_muscle1 = cyc1.general_keep_mask;
                    PairStruct.general_keep_mask_muscle2 = cyc2.general_keep_mask;
                    PairStruct.general_reason_muscle1 = cyc1.general_reason;
                    PairStruct.general_reason_muscle2 = cyc2.general_reason;

                    PairStruct.band_specific = band_specific;

                    % save under pair name
                    FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(char(pairName)) = PairStruct;

                    fprintf('  %s | %s | %s -> valid cycles %d / %d | included=%d\n', cond, leg, pairName, n_valid_cycles, nCycles, included_for_analysis);
                end
            end
        end
    end
end
