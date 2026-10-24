%% f_build_final_paired_signals_from_burst_qc.m
% Build final analysis-ready paired signals for coherence / wavelet transform
%
% INPUT:
%   - FINAL_BURST_QC.mat
%   - *_EMG_BURSTS.mat
%
% OUTPUT:
%   - FINAL_PAIRED_SIGNALS.mat
%   - CYCLE_QC_TABLE.xlsx
%   - PAIR_CYCLE_QC_TABLE.xlsx
%   - FINAL_SIGNAL_SUMMARY.xlsx
%
% LOGIC:
% -------------------------------------------------------------------------
% For each subject / condition / leg / muscle:
%   1) recover cycle boundaries
%   2) assign bursts to cycles by overlap
%   3) cycle is valid only if:
%        - at least one burst overlaps the cycle
%        - at least one overlapping burst is GOOD
%        - no overlapping burst is BAD
%        - no burst overlaps multiple cycles
%
% For each muscle pair:
%   4) pair cycle is valid only if valid in BOTH muscles
%   5) final paired signals are built by concatenating only valid cycles
%   6) if number of valid cycles < min_cycles_required, mark pair as invalid
%
% NOTE:
%   final paired signals remain synchronized because the same kept cycles are
%   used for both muscles.
% -------------------------------------------------------------------------
function f_build_final_paired_signals_from_burst_qc()

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.final_data_qc));

    IO = C.f_final_signals.io;
    P  = C.f_final_signals.params;
    PL = C.f_final_signals.plot;

    W = C.g_coherence.params;

    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.xlsx_dir, 'dir'), mkdir(IO.xlsx_dir); end
    if ~exist(IO.recap_xlsx_dir, 'dir'), mkdir(IO.recap_xlsx_dir); end
    if ~exist(PL.hist_cycles_dir, 'dir'), mkdir(PL.hist_cycles_dir); end
    if ~exist(PL.excluded.out_dir, 'dir'), mkdir(PL.excluded.out_dir); end
    if ~exist(PL.rebuilt.out_dir, 'dir'), mkdir(PL.rebuilt.out_dir); end
    if ~exist(PL.manual.out_dir, 'dir'), mkdir(PL.manual.out_dir); end
    if ~exist(IO.excluded_burst_position_xlsx, 'dir'), mkdir(fileparts(IO.excluded_burst_position_xlsx)); end
    if ~exist(IO.excluded_burst_position_plot_dir, 'dir'), mkdir(IO.excluded_burst_position_plot_dir); end

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
                    [final_sig_1, final_sig_2, cycle_segments_table] = build_final_concatenated_pair( x1, x2, cycle_starts_pair, cycle_ends_pair, pair_cycle_keep);

                    band_specific = struct();

                    for ib = 1:numel(bandNames)
                        band = bandNames{ib};

                        [sig1_band, sig2_band, Tseg_band] = build_final_concatenated_pair( x1, x2, cycle_starts_pair, cycle_ends_pair, pair_cycle_keep_by_band.(band));

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

                        pairReasonAlpha = string(pair_cycle_reason_by_band.Alpha(iCyc));
                        if numel(pairReasonAlpha) ~= 1
                            pairReasonAlpha = strjoin(pairReasonAlpha, "+");
                        end

                        pairReasonBeta = string(pair_cycle_reason_by_band.Beta(iCyc));
                        if numel(pairReasonBeta) ~= 1
                            pairReasonBeta = strjoin(pairReasonBeta, "+");
                        end

                        pairReasonGamma = string(pair_cycle_reason_by_band.Gamma(iCyc));
                        if numel(pairReasonGamma) ~= 1
                            pairReasonGamma = strjoin(pairReasonGamma, "+");
                        end

                        PAIR_QC_ROWS(riP,1:19) = { char(string(subjID)), char(string(cond)), char(string(leg)), char(string(pairName)), char(string(mus1)), char(string(mus2)), double(iCyc), double(cycle_starts_pair(iCyc)), double(cycle_ends_pair(iCyc)), logical(cyc1.cycle_keep_mask(iCyc)), logical(cyc2.cycle_keep_mask(iCyc)), logical(pair_cycle_keep(iCyc)), char(pairReason_i), logical(pair_cycle_keep_by_band.Alpha(iCyc)), logical(pair_cycle_keep_by_band.Beta(iCyc)), logical(pair_cycle_keep_by_band.Gamma(iCyc)), char(pairReasonAlpha), char(pairReasonBeta), char(pairReasonGamma) };
                    end

                    age_group = subject_to_group(subjID, C);

                    % ---------- save summary row ----------
                    riS = riS + 1;
                    SIGNAL_ROWS(riS,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(mus1), string(mus2), nCycles, n_valid_cycles, numel(removed_cycle_numbers), included_for_analysis, string(exclusion_reason), numel(final_sig_1), numel(final_sig_2), fs, string(cycle_source_1), string(cycle_source_2), string(cycle_alignment_note), band_specific.Alpha.n_valid_cycles, band_specific.Beta.n_valid_cycles, band_specific.Gamma.n_valid_cycles, band_specific.Alpha.included_for_analysis, band_specific.Beta.included_for_analysis, band_specific.Gamma.included_for_analysis, };
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

    %% ===================== BUILD TABLES =====================
    fprintf('\nBuilding output tables...\n');
    if ~isempty(CYCLE_QC_ROWS)
        CYCLE_QC_TABLE = cell2table(CYCLE_QC_ROWS, 'VariableNames', { 'subject','condition','leg','muscle', 'cycle_number','cycle_start_idx','cycle_end_idx', 'n_overlapping_bursts', 'has_any_burst','has_good_burst','has_bad_burst', 'cycle_keep','cycle_reason'});
    else
        CYCLE_QC_TABLE = table();
    end
    fprintf('Cycle QC rows: %d\n', size(CYCLE_QC_ROWS,1));

    if ~isempty(PAIR_QC_ROWS)
        pairVarNames = { 'subject','condition','leg','pair_name','muscle1','muscle2', 'cycle_number','cycle_start_idx','cycle_end_idx', 'muscle1_cycle_keep','muscle2_cycle_keep', 'pair_cycle_keep','pair_cycle_reason', 'pair_cycle_keep_alpha','pair_cycle_keep_beta','pair_cycle_keep_gamma', 'pair_cycle_reason_alpha','pair_cycle_reason_beta','pair_cycle_reason_gamma'};

        assert(size(PAIR_QC_ROWS,2) == numel(pairVarNames), 'PAIR_QC_ROWS has %d columns but pairVarNames has %d names.', size(PAIR_QC_ROWS,2), numel(pairVarNames));

        PAIR_CYCLE_QC_TABLE = cell2table(PAIR_QC_ROWS, 'VariableNames', pairVarNames);
    else
        PAIR_CYCLE_QC_TABLE = table();
    end
    fprintf('Pair cycle QC rows: %d\n', size(PAIR_QC_ROWS,1));

    if ~isempty(SIGNAL_ROWS)
        FINAL_SIGNAL_SUMMARY = cell2table(SIGNAL_ROWS, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','muscle1','muscle2', 'n_cycles_total','n_valid_cycles','n_removed_cycles', 'included_for_analysis','exclusion_reason', 'final_signal_length_1','final_signal_length_2','fs', 'cycle_source_field_muscle1','cycle_source_field_muscle2','cycle_alignment_note', 'n_valid_cycles_alpha','n_valid_cycles_beta','n_valid_cycles_gamma', 'included_for_analysis_alpha','included_for_analysis_beta','included_for_analysis_gamma' });
    else
        FINAL_SIGNAL_SUMMARY = table();
    end

    fprintf('Final signal summary rows: %d\n', size(FINAL_SIGNAL_SUMMARY,1));


    %% ===================== APPLY CROSS-TALK EXCLUSION =====================


    if isfield(C.f_final_signals, 'crosstalk') && C.f_final_signals.crosstalk.enable
        XTK = C.f_final_signals.crosstalk;
        fprintf('\nApplying cross-talk QC exclusion...\n');

        [FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS] = apply_crosstalk_qc_to_final_signals( FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C);

    else
        CROSSTALK_QC_TABLE = table();
        CROSSTALK_QC_SUSPICIOUS = table();

        FINAL_SIGNAL_SUMMARY.excluded_by_crosstalk = false(height(FINAL_SIGNAL_SUMMARY),1);
        FINAL_SIGNAL_SUMMARY.crosstalk_reason = repmat("", height(FINAL_SIGNAL_SUMMARY),1);

        FINAL_SIGNAL_SUMMARY.included_after_crosstalk = FINAL_SIGNAL_SUMMARY.included_for_analysis;
        FINAL_SIGNAL_SUMMARY.included_after_crosstalk_alpha = FINAL_SIGNAL_SUMMARY.included_for_analysis_alpha;
        FINAL_SIGNAL_SUMMARY.included_after_crosstalk_beta  = FINAL_SIGNAL_SUMMARY.included_for_analysis_beta;
        FINAL_SIGNAL_SUMMARY.included_after_crosstalk_gamma = FINAL_SIGNAL_SUMMARY.included_for_analysis_gamma;
    end

    %% ===================== CYCLE RETENTION METRICS =====================

    if ~isempty(FINAL_SIGNAL_SUMMARY)
        FINAL_SIGNAL_SUMMARY.n_initial_cycles = FINAL_SIGNAL_SUMMARY.n_cycles_total;
        FINAL_SIGNAL_SUMMARY.n_final_valid_cycles = FINAL_SIGNAL_SUMMARY.n_valid_cycles;
        FINAL_SIGNAL_SUMMARY.n_cycles_removed_by_qc = FINAL_SIGNAL_SUMMARY.n_initial_cycles - FINAL_SIGNAL_SUMMARY.n_final_valid_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_kept = 100 * FINAL_SIGNAL_SUMMARY.n_final_valid_cycles ./ FINAL_SIGNAL_SUMMARY.n_initial_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_removed = 100 * FINAL_SIGNAL_SUMMARY.n_cycles_removed_by_qc ./ FINAL_SIGNAL_SUMMARY.n_initial_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_kept(~isfinite(FINAL_SIGNAL_SUMMARY.percent_cycles_kept)) = NaN;
        FINAL_SIGNAL_SUMMARY.percent_cycles_removed(~isfinite(FINAL_SIGNAL_SUMMARY.percent_cycles_removed)) = NaN;
    end

    %% ===================== FINAL CHECKS =====================

    fprintf('\n===================== BAND DIFFERENCE CHECK =====================\n');
    fprintf('Different valid-cycle counts vs overall:\n');
    fprintf('  Alpha: %d\n', sum(FINAL_SIGNAL_SUMMARY.n_valid_cycles_alpha ~= FINAL_SIGNAL_SUMMARY.n_valid_cycles));
    fprintf('  Beta:  %d\n', sum(FINAL_SIGNAL_SUMMARY.n_valid_cycles_beta  ~= FINAL_SIGNAL_SUMMARY.n_valid_cycles));
    fprintf('  Gamma: %d\n', sum(FINAL_SIGNAL_SUMMARY.n_valid_cycles_gamma ~= FINAL_SIGNAL_SUMMARY.n_valid_cycles));

    fprintf('Different inclusion status vs overall:\n');
    fprintf('  Alpha: %d\n', sum(FINAL_SIGNAL_SUMMARY.included_for_analysis_alpha ~= FINAL_SIGNAL_SUMMARY.included_for_analysis));
    fprintf('  Beta:  %d\n', sum(FINAL_SIGNAL_SUMMARY.included_for_analysis_beta  ~= FINAL_SIGNAL_SUMMARY.included_for_analysis));
    fprintf('  Gamma: %d\n', sum(FINAL_SIGNAL_SUMMARY.included_for_analysis_gamma ~= FINAL_SIGNAL_SUMMARY.included_for_analysis));

    %% ===================== RECAP: BURST POSITIONS IN EXCLUDED CYCLES =====================
    fprintf('\nBuilding excluded-cycle burst position recap...\n');

    EXCLUDED_BURST_ROWS = {};
    riEB = 0;

    subjFields = fieldnames(FINAL_PAIRED_SIGNALS);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        condFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};

            legFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};

                pairFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};
                    PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    if ~isfield(PairStruct, 'pair_cycle_keep_mask') || isempty(PairStruct.pair_cycle_keep_mask)
                        continue;
                    end

                    age_group = subject_to_group(subjID, C);

                    cycle_starts = PairStruct.cycle_starts(:);
                    cycle_ends   = PairStruct.cycle_ends(:);
                    pair_keep    = PairStruct.pair_cycle_keep_mask(:);

                    % muscle-specific qc
                    cycStructs = {PairStruct.muscle1_cycle_qc, PairStruct.muscle2_cycle_qc};

                    for iM = 1:2
                        cycM = cycStructs{iM};
                        musName = char(cycM.muscle);

                        % we need overlapping burst indices + burst keep information
                        if ~isfield(cycM, 'overlapping_burst_idx') || isempty(cycM.overlapping_burst_idx)
                            continue;
                        end

                        % recover burst keep mask from cycle qc / linked info
                        if isfield(cycM, 'burst_keep')
                            burst_keep_mask = cycM.burst_keep(:);
                        elseif isfield(cycM, 'burst_keep_mask')
                            burst_keep_mask = cycM.burst_keep_mask(:);
                        elseif isfield(cycM, 'source_burst_keep_mask')
                            burst_keep_mask = cycM.source_burst_keep_mask(:);
                        else
                            % if not saved there, try from pair struct if you later decide to store it there
                            burst_keep_mask = [];
                        end

                        if isfield(cycM, 'burst_idx_all')
                            all_bursts = cycM.burst_idx_all;
                        elseif isfield(cycM, 'bursts_idx')
                            all_bursts = cycM.bursts_idx;
                        elseif isfield(cycM, 'source_bursts_idx')
                            all_bursts = cycM.source_bursts_idx;
                        else
                            all_bursts = [];
                        end

                        % fallback: if not stored inside cycM, try reading from the pair struct fields if available
                        if isempty(all_bursts)
                            if iM == 1 && isfield(PairStruct, 'muscle1_bursts_idx')
                                all_bursts = PairStruct.muscle1_bursts_idx;
                            elseif iM == 2 && isfield(PairStruct, 'muscle2_bursts_idx')
                                all_bursts = PairStruct.muscle2_bursts_idx;
                            end
                        end

                        if isempty(burst_keep_mask)
                            if iM == 1 && isfield(PairStruct, 'muscle1_burst_keep_mask')
                                burst_keep_mask = PairStruct.muscle1_burst_keep_mask(:);
                            elseif iM == 2 && isfield(PairStruct, 'muscle2_burst_keep_mask')
                                burst_keep_mask = PairStruct.muscle2_burst_keep_mask(:);
                            end
                        end

                        if isempty(all_bursts) || isempty(burst_keep_mask)
                            warning('Missing burst metadata for excluded-cycle burst recap: %s | %s | %s | %s | %s', subjID, cond, leg, pairName, musName);
                            continue;
                        end

                        for iC = 1:numel(pair_keep)
                            if pair_keep(iC)
                                continue; % only excluded cycles
                            end

                            c1 = cycle_starts(iC);
                            c2 = cycle_ends(iC);
                            cLen = c2 - c1 + 1;

                            overlap_idx = cycM.overlapping_burst_idx{iC};
                            if isempty(overlap_idx)
                                continue;
                            end

                            cycleReason = "";
                            if isfield(cycM, 'cycle_reason') && numel(cycM.cycle_reason) >= iC
                                cycleReason = string(cycM.cycle_reason(iC));
                            end

                            for ib = 1:numel(overlap_idx)
                                bNum = overlap_idx(ib);

                                if bNum < 1 || bNum > size(all_bursts,1)
                                    continue;
                                end

                                b1 = all_bursts(bNum,1);
                                b2 = all_bursts(bNum,2);

                                ov1 = max(b1, c1);
                                ov2 = min(b2, c2);

                                if ov2 < ov1
                                    continue;
                                end

                                rel_start  = (ov1 - c1) / cLen * 100;
                                rel_end    = (ov2 - c1) / cLen * 100;
                                rel_center = (((ov1 + ov2)/2) - c1) / cLen * 100;

                                % riEB = riEB + 1;
                                % EXCLUDED_BURST_ROWS(riEB,:) = { ...
                                %     string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(musName), ...
                                %     iC, bNum, logical(burst_keep_mask(bNum)), ...
                                %     rel_start, rel_end, rel_center, ...
                                %     string(cycleReason) ...
                                %     };
                                % burst reason / method
                                if iM == 1 && isfield(PairStruct, 'muscle1_burst_reason') && numel(PairStruct.muscle1_burst_reason) >= bNum
                                    burstReason = string(PairStruct.muscle1_burst_reason(bNum));
                                elseif iM == 2 && isfield(PairStruct, 'muscle2_burst_reason') && numel(PairStruct.muscle2_burst_reason) >= bNum
                                    burstReason = string(PairStruct.muscle2_burst_reason(bNum));
                                elseif isfield(cycM, 'source_burst_reason') && numel(cycM.source_burst_reason) >= bNum
                                    burstReason = string(cycM.source_burst_reason(bNum));
                                else
                                    burstReason = "";
                                end

                                burstMethod = classify_burst_exclusion_method(burstReason, burst_keep_mask(bNum));

                                riEB = riEB + 1;
                                EXCLUDED_BURST_ROWS(riEB,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(musName), iC, bNum, logical(burst_keep_mask(bNum)), string(burstReason), string(burstMethod), rel_start, rel_end, rel_center, string(cycleReason) };
                            end
                        end
                    end
                end
            end
        end
    end

    if ~isempty(EXCLUDED_BURST_ROWS)
        EXCLUDED_CYCLE_BURST_POSITION_TABLE = cell2table(EXCLUDED_BURST_ROWS, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','muscle', 'cycle_number','burst_number','burst_keep', 'burst_reason','burst_method', 'overlap_start_pct','overlap_end_pct','overlap_center_pct', 'cycle_reason'});
    else
        EXCLUDED_CYCLE_BURST_POSITION_TABLE = table();
    end

    fprintf('Excluded-cycle burst-position rows: %d\n', height(EXCLUDED_CYCLE_BURST_POSITION_TABLE));

    % save xlsx
    writetable(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_xlsx);

    % make plots
    if ~isempty(EXCLUDED_CYCLE_BURST_POSITION_TABLE)
        delete(fullfile(IO.excluded_burst_position_plot_dir, '*.png'));
        fprintf('Class of T.burst_keep: %s\n', class(EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep));
        if iscell(EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep)
            lens = cellfun(@numel, EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep);
            fprintf('burst_keep cell sizes: min=%d, max=%d\n', min(lens), max(lens));
        end
        plot_excluded_burst_position_histograms(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
        plot_excluded_burst_position_histograms_by_muscle(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
        plot_excluded_burst_positions_by_method_and_muscle(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
    end

    %% ===================== HISTOGRAMS: INITIAL VS VALID CYCLES PER SIGNAL =====================

    if ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating histograms of initial and valid cycles per signal...\n');

        if ~exist(PL.hist_cycles_dir, 'dir'), mkdir(PL.hist_cycles_dir); end
        delete(fullfile(PL.hist_cycles_dir, '*.png'));

        % ---------- Overall histograms ----------
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'n_initial_cycles', 'Initial number of cycles per signal', 'hist_initial_cycles_overall.png', 'Initial cycles');
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'n_final_valid_cycles', 'Final valid cycles per signal after QC', 'hist_valid_cycles_overall.png', 'Valid cycles');
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'percent_cycles_kept', 'Percentage of cycles kept after QC', 'hist_percent_cycles_kept_overall.png', 'Cycles kept (%)');

        % ---------- By age group ----------
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'n_initial_cycles', 'Initial cycles by age group', 'hist_initial_cycles_by_age_group.png', 'Initial cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'n_final_valid_cycles', 'Valid cycles after QC by age group', 'hist_valid_cycles_by_age_group.png', 'Valid cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'percent_cycles_kept', 'Percentage of cycles kept by age group', 'hist_percent_cycles_kept_by_age_group.png', 'Cycles kept (%)');

        % ---------- By condition ----------
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'n_initial_cycles', 'Initial cycles by condition', 'hist_initial_cycles_by_condition.png', 'Initial cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'n_final_valid_cycles', 'Valid cycles after QC by condition', 'hist_valid_cycles_by_condition.png', 'Valid cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'percent_cycles_kept', 'Percentage of cycles kept by condition', 'hist_percent_cycles_kept_by_condition.png', 'Cycles kept (%)');

        % ---------- Per pair ----------
        pairNames = unique(string(FINAL_SIGNAL_SUMMARY.pair_name));
        pairNames(ismissing(pairNames)) = [];
        pairNames = sort(pairNames);

        for iP = 1:numel(pairNames)
            pairName = pairNames(iP);

            Tpair = FINAL_SIGNAL_SUMMARY(string(FINAL_SIGNAL_SUMMARY.pair_name) == pairName, :);
            if isempty(Tpair), continue; end

            pairTag = make_valid_filename(pairName);
            pairOutDir = fullfile(PL.hist_cycles_dir, ['pair_' char(pairTag)]);
            if ~exist(pairOutDir, 'dir'), mkdir(pairOutDir); end

            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'n_initial_cycles', sprintf('Initial cycles per signal (%s)', pairName), sprintf('hist_initial_cycles_overall__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'n_final_valid_cycles', sprintf('Valid cycles after QC per signal (%s)', pairName), sprintf('hist_valid_cycles_overall__%s.png', pairTag), 'Valid cycles');
            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'percent_cycles_kept', sprintf('Percentage of cycles kept after QC (%s)', pairName), sprintf('hist_percent_cycles_kept_overall__%s.png', pairTag), 'Cycles kept (%)');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'age_group', C.plotting.age_order, C.plotting.colors, pairOutDir, sprintf('Age group | %s', pairName), 'n_initial_cycles', sprintf('Initial cycles by age group | %s', pairName), sprintf('hist_initial_cycles_by_age_group__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'age_group', C.plotting.age_order, C.plotting.colors, pairOutDir, sprintf('Age group | %s', pairName), 'n_final_valid_cycles', sprintf('Valid cycles after QC by age group | %s', pairName), sprintf('hist_valid_cycles_by_age_group__%s.png', pairTag), 'Valid cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'condition', C.plotting.condition_order, C.plotting.colors, pairOutDir, sprintf('Condition | %s', pairName), 'n_initial_cycles', sprintf('Initial cycles by condition | %s', pairName), sprintf('hist_initial_cycles_by_condition__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'condition', C.plotting.condition_order, C.plotting.colors, pairOutDir, sprintf('Condition | %s', pairName), 'n_final_valid_cycles', sprintf('Valid cycles after QC by condition | %s', pairName), sprintf('hist_valid_cycles_by_condition__%s.png', pairTag), 'Valid cycles');
        end
    end

    %% ===================== PARTICIPANT-LEVEL HISTOGRAMS: MEAN CYCLES ACROSS LEGS =====================

    fprintf('\nGenerating participant-level 3x4 histograms of mean cycles across legs...\n');

    participantHistDir = fullfile(PL.hist_cycles_dir, 'participant_level_mean_across_legs');
    if ~exist(participantHistDir, 'dir'), mkdir(participantHistDir); end
    delete(fullfile(participantHistDir, '*.png'));

    % One row per participant x condition x pair:
    % mean initial and valid cycles across available legs
    TmeanLegs = groupsummary( FINAL_SIGNAL_SUMMARY, {'subject','age_group','condition','pair_name'}, {'mean','min','max'}, {'n_initial_cycles','n_final_valid_cycles','percent_cycles_kept'});

    % Rename useful variables
    TmeanLegs.Properties.VariableNames{'GroupCount'} = 'n_legs_available';

    TmeanLegs.Properties.VariableNames{'mean_n_initial_cycles'} = 'mean_initial_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'min_n_initial_cycles'}  = 'min_initial_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'max_n_initial_cycles'}  = 'max_initial_cycles_across_legs';

    TmeanLegs.Properties.VariableNames{'mean_n_final_valid_cycles'} = 'mean_valid_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'min_n_final_valid_cycles'}  = 'min_valid_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'max_n_final_valid_cycles'}  = 'max_valid_cycles_across_legs';

    TmeanLegs.Properties.VariableNames{'mean_percent_cycles_kept'} = 'mean_percent_cycles_kept_across_legs';
    TmeanLegs.Properties.VariableNames{'min_percent_cycles_kept'}  = 'min_percent_cycles_kept_across_legs';
    TmeanLegs.Properties.VariableNames{'max_percent_cycles_kept'}  = 'max_percent_cycles_kept_across_legs';

    pairNames = unique(string(TmeanLegs.pair_name));
    pairNames(ismissing(pairNames)) = [];
    pairNames = sort(pairNames);

    for iP = 1:numel(pairNames)
        pairName = pairNames(iP);

        Tpair = TmeanLegs(string(TmeanLegs.pair_name) == pairName, :);

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_initial_cycles_across_legs', sprintf('Participant-level initial cycles | %s | mean across legs', pairName), sprintf('hist_participant_initial_cycles_3x4__%s.png', make_valid_filename(pairName)), 'Mean initial cycles across legs');

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_valid_cycles_across_legs', sprintf('Participant-level valid cycles after QC | %s | mean across legs', pairName), sprintf('hist_participant_valid_cycles_3x4__%s.png', make_valid_filename(pairName)), 'Mean valid cycles across legs');

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_percent_cycles_kept_across_legs', sprintf('Participant-level percent cycles kept | %s | mean across legs', pairName), sprintf('hist_participant_percent_kept_3x4__%s.png', make_valid_filename(pairName)), 'Mean cycles kept across legs (%)');
    end

    writetable(TmeanLegs, fullfile(IO.xlsx_dir, 'CYCLES_PARTICIPANT_MEAN_ACROSS_LEGS.xlsx'));

    %% ===================== CYCLE RECAPS: DETAIL + MASTER DISTRIBUTIONS =====================

    fprintf('\nBuilding consolidated cycle recap tables...\n');

    if ~isempty(FINAL_SIGNAL_SUMMARY)

        % ---------- 1) Signal-level detail table ----------
        CYCLE_SIGNAL_DETAIL = FINAL_SIGNAL_SUMMARY(:, { 'subject','age_group','condition','leg','pair_name', 'n_initial_cycles','n_final_valid_cycles', 'n_cycles_removed_by_qc','percent_cycles_kept', 'included_after_crosstalk'});

        CYCLE_SIGNAL_DETAIL.n_valid_cycles = CYCLE_SIGNAL_DETAIL.n_final_valid_cycles;
    else
        CYCLE_SIGNAL_DETAIL = table();
    end

    fprintf('Rows in CYCLE_SIGNAL_DETAIL: %d\n', height(CYCLE_SIGNAL_DETAIL));

    % ---------- 2) Master distribution table, all levels but always pair-specific ----------
    CYCLE_RECAP_MASTER = table();

    if ~isempty(CYCLE_SIGNAL_DETAIL)

        cycleVars = { 'n_initial_cycles', 'n_final_valid_cycles', 'n_cycles_removed_by_qc', 'percent_cycles_kept'};

        inclusionModes = { 'all_signals', 'included_for_coherence'};

        rows = {};

        for iInc = 1:numel(inclusionModes)

            inclusionMode = string(inclusionModes{iInc});

            switch inclusionMode
                case "all_signals"
                    Tbase = CYCLE_SIGNAL_DETAIL;

                case "included_for_coherence"
                    Tbase = CYCLE_SIGNAL_DETAIL(CYCLE_SIGNAL_DETAIL.included_after_crosstalk == true, :);
            end

            for iV = 1:numel(cycleVars)
                valueVar = cycleVars{iV};

                rows{end+1,1} = build_cycle_recap_master_one_variable( Tbase, valueVar, inclusionMode); %#ok<AGROW>
            end
        end

        CYCLE_RECAP_MASTER = vertcat_fill_missing(rows{:});
    end

    % ---------- 3) Full-leg pair detail table ----------
    minCyclesFullLeg = 15;

    fprintf('\nBuilding full-leg pair detail recap using threshold >= %d valid cycles...\n', minCyclesFullLeg);

    FULL_LEG_PAIR_DETAIL_RECAP = table();
    FULL_LEG_NOT_VALID_RECAP = table();

    if ~isempty(CYCLE_SIGNAL_DETAIL)

        Tleg = CYCLE_SIGNAL_DETAIL;
        Tleg.has_enough_cycles_for_full_leg = Tleg.n_final_valid_cycles >= minCyclesFullLeg;
        Tleg.pair_var = matlab.lang.makeValidName(string(Tleg.pair_name));

        Tflags = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','has_enough_cycles_for_full_leg'}), 'has_enough_cycles_for_full_leg', 'pair_var');

        Tcounts = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','n_final_valid_cycles'}), 'n_final_valid_cycles', 'pair_var');

        Tinitial = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','n_initial_cycles'}), 'n_initial_cycles', 'pair_var');

        pairVars = matlab.lang.makeValidName(["TAprox_TAdist","SOL_GM","VL_RF"]);

        for i = 1:numel(pairVars)
            pv = char(pairVars(i));

            if ismember(pv, Tflags.Properties.VariableNames)
                Tflags.Properties.VariableNames{pv} = [pv '_enough_cycles'];
            end

            if ismember(pv, Tcounts.Properties.VariableNames)
                Tcounts.Properties.VariableNames{pv} = [pv '_n_valid_cycles'];
            end

            if ismember(pv, Tinitial.Properties.VariableNames)
                Tinitial.Properties.VariableNames{pv} = [pv '_n_initial_cycles'];
            end
        end

        FULL_LEG_PAIR_DETAIL_RECAP = outerjoin( Tflags, Tcounts, 'Keys', {'subject','age_group','condition','leg'}, 'MergeKeys', true);

        FULL_LEG_PAIR_DETAIL_RECAP = outerjoin( FULL_LEG_PAIR_DETAIL_RECAP, Tinitial, 'Keys', {'subject','age_group','condition','leg'}, 'MergeKeys', true);

        vars = FULL_LEG_PAIR_DETAIL_RECAP.Properties.VariableNames;

        flagVars = vars(endsWith(vars, '_enough_cycles'));
        countVars = vars(endsWith(vars, '_n_valid_cycles') | endsWith(vars, '_n_initial_cycles'));

        for i = 1:numel(flagVars)
            v = flagVars{i};
            FULL_LEG_PAIR_DETAIL_RECAP.(v) = logical(FULL_LEG_PAIR_DETAIL_RECAP.(v));
            FULL_LEG_PAIR_DETAIL_RECAP.(v)(ismissing(FULL_LEG_PAIR_DETAIL_RECAP.(v))) = false;
        end

        for i = 1:numel(countVars)
            v = countVars{i};
            FULL_LEG_PAIR_DETAIL_RECAP.(v)(isnan(FULL_LEG_PAIR_DETAIL_RECAP.(v))) = 0;
        end

        enoughMat = false(height(FULL_LEG_PAIR_DETAIL_RECAP), numel(flagVars));
        for i = 1:numel(flagVars)
            enoughMat(:,i) = FULL_LEG_PAIR_DETAIL_RECAP.(flagVars{i});
        end

        FULL_LEG_PAIR_DETAIL_RECAP.n_pairs_present = numel(flagVars) - sum(ismissing(FULL_LEG_PAIR_DETAIL_RECAP(:, flagVars)), 2);
        FULL_LEG_PAIR_DETAIL_RECAP.n_pairs_with_enough_cycles = sum(enoughMat, 2);
        FULL_LEG_PAIR_DETAIL_RECAP.full_leg_all_pairs_enough_cycles = all(enoughMat, 2);

        FULL_LEG_NOT_VALID_RECAP = FULL_LEG_PAIR_DETAIL_RECAP( FULL_LEG_PAIR_DETAIL_RECAP.full_leg_all_pairs_enough_cycles == false, :);
    end

    fprintf('Rows in CYCLE_RECAP_MASTER: %d\n', height(CYCLE_RECAP_MASTER));
    fprintf('Rows in FULL_LEG_PAIR_DETAIL_RECAP: %d\n', height(FULL_LEG_PAIR_DETAIL_RECAP));
    fprintf('Rows in FULL_LEG_NOT_VALID_RECAP: %d\n', height(FULL_LEG_NOT_VALID_RECAP));

    writetable(CYCLE_SIGNAL_DETAIL, fullfile(IO.xlsx_dir, 'CYCLE_SIGNAL_DETAIL.xlsx'));

    writetable(CYCLE_RECAP_MASTER, fullfile(IO.xlsx_dir, 'CYCLE_RECAP_MASTER_BY_PAIR.xlsx'));

    writetable(FULL_LEG_PAIR_DETAIL_RECAP, fullfile(IO.xlsx_dir, 'FULL_LEG_PAIR_DETAIL_RECAP.xlsx'));

    writetable(FULL_LEG_NOT_VALID_RECAP, fullfile(IO.xlsx_dir, 'FULL_LEG_NOT_VALID_RECAP.xlsx'));

    %% ===================== TEST GROUP/CONDITION DIFFERENCES IN CYCLE COUNTS =====================

    % ---------- Save ----------
    outStatsDir = fullfile(IO.xlsx_dir, 'cycle_count_stat_tests');
    if ~exist(outStatsDir, 'dir'), mkdir(outStatsDir); end

    fprintf('\nTesting age / condition differences in cycle counts...\n');

    T = FINAL_SIGNAL_SUMMARY;
    cycleVarsToTest = {'n_initial_cycles','n_final_valid_cycles','percent_cycles_kept'};

    ALL_CYCLE_LME_TESTS = table();
    ALL_CYCLE_KW_TESTS = table();

    for iV = 1:numel(cycleVarsToTest)

        cycleVar = cycleVarsToTest{iV};

        fprintf('\n\n===================== %s =====================\n', cycleVar);

        Tclean = T(~ismissing(T.age_group) & ~ismissing(T.condition) & ~isnan(T.(cycleVar)), :);

        Tclean.age_group = categorical(string(Tclean.age_group));
        Tclean.condition = categorical(string(Tclean.condition));
        Tclean.pair_name = categorical(string(Tclean.pair_name));
        Tclean.subject   = categorical(string(Tclean.subject));

        pairNames = categories(Tclean.pair_name);

        % ---------- A) Kruskal-Wallis: age group, condition, and age x condition ----------
        rowsKW = {};

        for iP = 1:numel(pairNames)
            pairName = pairNames{iP};
            Tp = Tclean(Tclean.pair_name == pairName, :);

            if height(Tp) < 10
                continue;
            end

            % Age
            pAge = NaN;
            if numel(categories(removecats(Tp.age_group))) >= 2
                pAge = kruskalwallis(Tp.(cycleVar), Tp.age_group, 'off');
            end

            % Condition
            pCond = NaN;
            if numel(categories(removecats(Tp.condition))) >= 2
                pCond = kruskalwallis(Tp.(cycleVar), Tp.condition, 'off');
            end

            % Age x Condition as combined groups
            ageCond = categorical(strcat(string(Tp.age_group), "_", string(Tp.condition)));
            pAgeCond = NaN;
            if numel(categories(removecats(ageCond))) >= 2
                pAgeCond = kruskalwallis(Tp.(cycleVar), ageCond, 'off');
            end

            rowsKW(end+1,:) = { string(cycleVar), string(pairName), height(Tp), pAge, pCond, pAgeCond }; %#ok<AGROW>
        end

        if ~isempty(rowsKW)
            KW_THIS = cell2table(rowsKW, 'VariableNames', { 'cycle_variable','pair_name','n_rows', 'p_kruskal_age_group','p_kruskal_condition','p_kruskal_age_condition_combined'});
            ALL_CYCLE_KW_TESTS = [ALL_CYCLE_KW_TESTS; KW_THIS]; %#ok<AGROW>
            disp(KW_THIS);
        end

        % ---------- B) Overall mixed model ----------
        try
            formulaOverall = sprintf('%s ~ age_group + condition + pair_name + (1|subject)', cycleVar);
            LME_overall = fitlme(Tclean, formulaOverall);
            A = dataset2table(anova(LME_overall));

            A.cycle_variable = repmat(string(cycleVar), height(A), 1);
            A.model_scope = repmat("overall_all_pairs", height(A), 1);
            A.pair_name = repmat("ALL", height(A), 1);

            A = movevars(A, {'cycle_variable','model_scope','pair_name'}, 'Before', 1);

            ALL_CYCLE_LME_TESTS = [ALL_CYCLE_LME_TESTS; A]; %#ok<AGROW>

            fprintf('\n===== LME OVERALL | %s =====\n', cycleVar);
            fprintf('%s\n', formulaOverall);
            disp(A);

        catch ME
            warning('Overall LME failed for %s: %s', cycleVar, ME.message);
        end

        % ---------- C) Mixed model per pair ----------
        for iP = 1:numel(pairNames)

            pairName = pairNames{iP};
            Tp = Tclean(Tclean.pair_name == pairName, :);

            if height(Tp) < 10 || numel(categories(removecats(Tp.age_group))) < 2 || numel(categories(removecats(Tp.condition))) < 2
                continue;
            end

            try
                formulaPair = sprintf('%s ~ age_group + condition + (1|subject)', cycleVar);
                LME_pair = fitlme(Tp, formulaPair);
                A = dataset2table(anova(LME_pair));

                A.cycle_variable = repmat(string(cycleVar), height(A), 1);
                A.model_scope = repmat("per_pair", height(A), 1);
                A.pair_name = repmat(string(pairName), height(A), 1);

                A = movevars(A, {'cycle_variable','model_scope','pair_name'}, 'Before', 1);

                ALL_CYCLE_LME_TESTS = [ALL_CYCLE_LME_TESTS; A]; %#ok<AGROW>

                fprintf('\n===== LME | %s | %s =====\n', pairName, cycleVar);
                fprintf('%s\n', formulaPair);
                disp(A);

            catch ME
                warning('Pair LME failed for %s | %s: %s', pairName, cycleVar, ME.message);
            end
        end
        DESC = groupsummary( Tclean, {'age_group','condition','pair_name'}, {'mean','median','std'}, cycleVar);

        disp(DESC);

        writetable(DESC, fullfile(outStatsDir, sprintf('DESC_%s_BY_AGE_CONDITION_PAIR.xlsx', cycleVar)));
    end

    writetable(ALL_CYCLE_KW_TESTS, fullfile(outStatsDir, 'CYCLE_COUNT_KRUSKAL_TESTS_BY_PAIR.xlsx'));

    writetable(ALL_CYCLE_LME_TESTS, fullfile(outStatsDir, 'CYCLE_COUNT_LME_TESTS.xlsx'));

    fprintf('\nSaved cycle-count statistical tests to:\n  %s\n', outStatsDir);

    %% ===================== LOAD PARTICIPANT METADATA =====================

    % Read the CSV, not the .xlsx beside it: the .xlsx is a stale export with
    % 77 of the 80 participants (CTL_78, CTL_79 and CTL_81 are missing), and
    % the join below is a left join, so those three silently ended up with
    % empty metadata. h_coherence_stats reads this same CSV.
    metadata_csv = fullfile(C.paths.metadata_dir, 'participants_metadata_EMG.csv');

    META = readtable(metadata_csv, 'Delimiter', ';', 'TreatAsEmpty', {'NA','NaN',''});
    META.subject = string(META.Participant);

    %% ===================== TARGET AGE GROUPS WITH 8-15 VALID CYCLES =====================

    minCyclesCheck = 8;
    maxCyclesCheck = 15;

    targetPairsRecoverability = ["TAprox_TAdist","SOL_GM"];
    targetAgeGroupsRecoverability = ["Adultes","Adolescents"];

    TallTarget = FINAL_SIGNAL_SUMMARY( ismember(string(FINAL_SIGNAL_SUMMARY.age_group), targetAgeGroupsRecoverability) & ismember(string(FINAL_SIGNAL_SUMMARY.pair_name), targetPairsRecoverability), :);

    assert(all(ismember(string(TallTarget.pair_name), targetPairsRecoverability)), 'TallTarget contains non-target pairs. Check targetPairsRecoverability filter.');

    assert(all(ismember(string(TallTarget.age_group), targetAgeGroupsRecoverability)), 'TallTarget contains non-target age groups. Check targetAgeGroupsRecoverability filter.');

    TtargetRange = TallTarget( TallTarget.n_final_valid_cycles >= minCyclesCheck & TallTarget.n_final_valid_cycles <= maxCyclesCheck, :);

    TARGET_8_TO_15_CYCLES_BY_SIGNAL = TtargetRange(:, { 'subject','age_group','condition','leg','pair_name', 'n_initial_cycles','n_final_valid_cycles', 'n_cycles_removed_by_qc','percent_cycles_kept'});

    fprintf('\nTarget age groups with %d-%d valid cycles per subject / condition / leg / pair: %d rows\n', minCyclesCheck, maxCyclesCheck, height(TARGET_8_TO_15_CYCLES_BY_SIGNAL));

    disp(TARGET_8_TO_15_CYCLES_BY_SIGNAL);

    %% ===================== ONE-LINE RECAP PER SUBJECT WITH 8-15 VALID CYCLES =====================

    TARGET_8_TO_15_ONE_ROW = table();

    if ~isempty(TtargetRange)

        targetIDs = unique(string(TtargetRange.subject));
        rows = {};

        for iA = 1:numel(targetIDs)
            subj = targetIDs(iA);

            TsRange = TtargetRange(string(TtargetRange.subject) == subj, :);
            TsAll   = TallTarget(string(TallTarget.subject) == subj, :);

            age_group_i = string(TsAll.age_group(1));

            nBelow = sum(TsAll.n_final_valid_cycles < minCyclesCheck);
            nIn    = sum(TsAll.n_final_valid_cycles >= minCyclesCheck & TsAll.n_final_valid_cycles <= maxCyclesCheck);
            nAbove = sum(TsAll.n_final_valid_cycles > maxCyclesCheck);

            minInitialAll = min(TsAll.n_initial_cycles);
            maxInitialAll = max(TsAll.n_initial_cycles);
            medianInitialAll = median(TsAll.n_initial_cycles, 'omitnan');

            minValidAll = min(TsAll.n_final_valid_cycles);
            maxValidAll = max(TsAll.n_final_valid_cycles);
            medianValidAll = median(TsAll.n_final_valid_cycles, 'omitnan');

            medianPercentKeptAll = median(TsAll.percent_cycles_kept, 'omitnan');
            minPercentKeptAll = min(TsAll.percent_cycles_kept);
            maxPercentKeptAll = max(TsAll.percent_cycles_kept);

            detailStrings = strings(height(TsRange),1);

            for i = 1:height(TsRange)
                detailStrings(i) = sprintf('%s_%s_%s: valid=%d/original=%d kept=%.1f%%', string(TsRange.condition(i)), string(TsRange.leg(i)), string(TsRange.pair_name(i)), TsRange.n_final_valid_cycles(i), TsRange.n_initial_cycles(i), TsRange.percent_cycles_kept(i));
            end

            rows(end+1,:) = { subj, age_group_i, height(TsAll), nBelow, nIn, nAbove, minInitialAll, medianInitialAll, maxInitialAll, minValidAll, medianValidAll, maxValidAll, minPercentKeptAll, medianPercentKeptAll, maxPercentKeptAll, strjoin(unique(string(TsRange.condition)), ","), strjoin(unique(string(TsRange.leg)), ","), strjoin(unique(string(TsRange.pair_name)), ","), strjoin(detailStrings, " | ") }; %#ok<SAGROW>
        end

        TARGET_8_TO_15_ONE_ROW = cell2table(rows, 'VariableNames', { 'subject', 'age_group', 'n_total_target_signals_TATA_SOLGM', 'n_signals_below_8_valid_cycles', 'n_signals_between_8_and_15_valid_cycles', 'n_signals_above_15_valid_cycles', 'min_initial_cycles_overall', 'median_initial_cycles_overall', 'max_initial_cycles_overall', 'min_valid_cycles_overall', 'median_valid_cycles_overall', 'max_valid_cycles_overall', 'min_percent_cycles_kept_overall', 'median_percent_cycles_kept_overall', 'max_percent_cycles_kept_overall', 'conditions_concerned_in_range', 'legs_concerned_in_range', 'pairs_concerned_in_range', 'detail_condition_leg_pair_valid_original_kept_in_range' });

        TARGET_8_TO_15_ONE_ROW.subject = string(TARGET_8_TO_15_ONE_ROW.subject);

        TARGET_8_TO_15_ONE_ROW = outerjoin( TARGET_8_TO_15_ONE_ROW, META, 'Keys', 'subject', 'MergeKeys', true, 'Type', 'left');

        metaCols = { 'Participant','AgeGroup','AgeMonths','Sex', 'Height_cm','Weight_kg','L0_m','IMC','TA_TA_cm'};

        metaCols = metaCols(ismember(metaCols, TARGET_8_TO_15_ONE_ROW.Properties.VariableNames));

        TARGET_8_TO_15_ONE_ROW = movevars( TARGET_8_TO_15_ONE_ROW, metaCols, 'Before', 'subject');
    end

    TARGET_8_TO_15_ONE_ROW = sortrows( TARGET_8_TO_15_ONE_ROW, 'n_signals_between_8_and_15_valid_cycles', 'descend');

    disp(TARGET_8_TO_15_ONE_ROW);

    writetable(TARGET_8_TO_15_CYCLES_BY_SIGNAL, fullfile(IO.xlsx_dir, 'TARGET_AGEGROUPS_8_TO_15_CYCLES_BY_SIGNAL.xlsx'));

    writetable(TARGET_8_TO_15_ONE_ROW, fullfile(IO.xlsx_dir, 'TARGET_AGEGROUPS_8_TO_15_ONE_ROW_RECAP.xlsx'));

    % Backward-compatible aliases for downstream code / XLSX function
    ADULTS_8_TO_15_CYCLES_BY_SIGNAL = TARGET_8_TO_15_CYCLES_BY_SIGNAL;
    ADULTS_8_TO_15_ONE_ROW = TARGET_8_TO_15_ONE_ROW;

    %% ===================== TARGET AGE GROUP RECOVERABILITY PRIORITY SCORE =====================

    fprintf('\nBuilding target age-group recoverability priority score...\n');

    expectedConditions = string(C.plotting.condition_order);
    expectedLegs = ["left","right"];

    RECOVERABILITY_PRIORITY_RECAP = table();

    if ~isempty(TallTarget)

        targetIDs = unique(string(TallTarget.subject));
        rows = {};

        for iA = 1:numel(targetIDs)

            subj = targetIDs(iA);

            TsAll = TallTarget(string(TallTarget.subject) == subj, :);
            TsTarget = TsAll;

            if isempty(TsTarget)
                continue;
            end

            nExpectedRows = numel(targetPairsRecoverability) * numel(expectedConditions) * numel(expectedLegs);
            nRowsPresent = height(TsTarget);
            nMissingRows = max(0, nExpectedRows - nRowsPresent);

            nBelow8 = sum(TsTarget.n_final_valid_cycles < 8);
            nIn8to15 = sum(TsTarget.n_final_valid_cycles >= 8 & TsTarget.n_final_valid_cycles <= 15);
            nAbove15 = sum(TsTarget.n_final_valid_cycles > 15);
            nZeroValid = sum(TsTarget.n_final_valid_cycles == 0);

            Tin = TsTarget(TsTarget.n_final_valid_cycles >= 8 & TsTarget.n_final_valid_cycles <= 15, :);

            if isempty(Tin)
                continue;
            end

            nConditionsPresent = numel(unique(string(TsTarget.condition)));
            nLegsPresent = numel(unique(string(TsTarget.leg)));
            nConditionLegPresent = height(unique(TsTarget(:, {'condition','leg'})));

            conditionCoverage = nConditionsPresent / numel(expectedConditions);
            legCoverage = nLegsPresent / numel(expectedLegs);
            rowCoverage = nRowsPresent / nExpectedRows;

            medianInitialTarget = median(TsTarget.n_initial_cycles, 'omitnan');
            medianValidTarget = median(TsTarget.n_final_valid_cycles, 'omitnan');
            medianPercentKeptTarget = median(TsTarget.percent_cycles_kept, 'omitnan');

            medianInitialInRange = median(Tin.n_initial_cycles, 'omitnan');
            medianValidInRange = median(Tin.n_final_valid_cycles, 'omitnan');
            medianPercentKeptInRange = median(Tin.percent_cycles_kept, 'omitnan');

            distanceTo15 = 15 - Tin.n_final_valid_cycles;
            medianDistanceTo15 = median(distanceTo15, 'omitnan');

            Tta = TsTarget(string(TsTarget.pair_name) == "TAprox_TAdist", :);
            Tsol = TsTarget(string(TsTarget.pair_name) == "SOL_GM", :);

            medianKeptTATA = median(Tta.percent_cycles_kept, 'omitnan');
            medianKeptSOLGM = median(Tsol.percent_cycles_kept, 'omitnan');

            nInRangeTATA = sum(Tta.n_final_valid_cycles >= 8 & Tta.n_final_valid_cycles <= 15);
            nInRangeSOLGM = sum(Tsol.n_final_valid_cycles >= 8 & Tsol.n_final_valid_cycles <= 15);

            metaRow = META(string(META.subject) == subj, :);

            height_cm = NaN;
            weight_kg = NaN;
            L0_m = NaN;
            TA_TA_cm = NaN;
            AgeMonths = NaN;
            Sex = "";

            if ~isempty(metaRow)
                if ismember('Height_cm', metaRow.Properties.VariableNames), height_cm = metaRow.Height_cm(1); end
                if ismember('Weight_kg', metaRow.Properties.VariableNames), weight_kg = metaRow.Weight_kg(1); end
                if ismember('L0_m', metaRow.Properties.VariableNames), L0_m = metaRow.L0_m(1); end
                if ismember('TA_TA_cm', metaRow.Properties.VariableNames), TA_TA_cm = metaRow.TA_TA_cm(1); end
                if ismember('AgeMonths', metaRow.Properties.VariableNames), AgeMonths = metaRow.AgeMonths(1); end
                if ismember('Sex', metaRow.Properties.VariableNames), Sex = string(metaRow.Sex(1)); end
            end

            height_m = NaN;
            expectedLowCycles_forHeight = NaN;
            expectedHighCycles_forHeight = NaN;
            initialCycleDeficitRelativeToHeight = NaN;
            sizeAdjustedInitialCycleScore = 0;

            if isfinite(height_cm) && height_cm > 0
                height_m = height_cm / 100;

                referenceHeight_m = 1.70;
                referenceLowCycles = 12;
                referenceHighCycles = 18;

                expectedLowCycles_forHeight  = referenceLowCycles  * referenceHeight_m / height_m;
                expectedHighCycles_forHeight = referenceHighCycles * referenceHeight_m / height_m;

                sizeAdjustedInitialCycleScore = clip01( (expectedHighCycles_forHeight - medianInitialTarget) / (expectedHighCycles_forHeight - expectedLowCycles_forHeight));

                initialCycleDeficitRelativeToHeight = expectedHighCycles_forHeight - medianInitialTarget;
            end

            keptScore = clip01(medianPercentKeptTarget / 80);
            distanceScore = clip01((7 - medianDistanceTo15) / 7);
            rangeAmountScore = clip01(nIn8to15 / 6);
            coverageScore = mean([rowCoverage, conditionCoverage, legCoverage], 'omitnan');

            zeroPenalty = clip01(nZeroValid / 4);
            missingPenalty = clip01(nMissingRows / nExpectedRows);

            recoverabilityScore = 100 * ( 0.25 * keptScore + 0.00 * distanceScore + 0.25 * rangeAmountScore + 0.15 * coverageScore + 0.15 * sizeAdjustedInitialCycleScore - 0.35 * zeroPenalty - 0.30 * missingPenalty);

            recoverabilityScore = max(0, min(100, recoverabilityScore));

            if recoverabilityScore >= 65
                category = "HIGH";
            elseif recoverabilityScore >= 40
                category = "MODERATE";
            else
                category = "LOW";
            end

            detailStrings = strings(height(Tin),1);
            for i = 1:height(Tin)
                detailStrings(i) = sprintf('%s_%s_%s: valid=%d/original=%d kept=%.1f%%', string(Tin.condition(i)), string(Tin.leg(i)), string(Tin.pair_name(i)), Tin.n_final_valid_cycles(i), Tin.n_initial_cycles(i), Tin.percent_cycles_kept(i));
            end

            missingNote = sprintf(['expected TA-TA/SOL-GM rows=%d; present=%d; missing=%d; ' 'zero_valid=%d; condition_coverage=%.2f; leg_coverage=%.2f; row_coverage=%.2f; size_adjusted_initial_cycle_score=%.2f'], nExpectedRows, nRowsPresent, nMissingRows, nZeroValid, conditionCoverage, legCoverage, rowCoverage, sizeAdjustedInitialCycleScore);

            rows(end+1,:) = { subj, string(TsTarget.age_group(1)), recoverabilityScore, category, keptScore, distanceScore, rangeAmountScore, coverageScore, zeroPenalty, missingPenalty, sizeAdjustedInitialCycleScore, height_m, expectedLowCycles_forHeight, expectedHighCycles_forHeight, initialCycleDeficitRelativeToHeight, nRowsPresent, nExpectedRows, nMissingRows, nZeroValid, nBelow8, nIn8to15, nAbove15, nInRangeTATA, nInRangeSOLGM, medianInitialTarget, medianValidTarget, medianPercentKeptTarget, medianInitialInRange, medianValidInRange, medianPercentKeptInRange, medianDistanceTo15, medianKeptTATA, medianKeptSOLGM, nConditionsPresent, nLegsPresent, nConditionLegPresent, conditionCoverage, legCoverage, rowCoverage, height_cm, weight_kg, L0_m, TA_TA_cm, AgeMonths, Sex, missingNote, strjoin(unique(string(Tin.condition)), ","), strjoin(unique(string(Tin.leg)), ","), strjoin(unique(string(Tin.pair_name)), ","), strjoin(detailStrings, " | ") }; %#ok<AGROW>
        end

        RECOVERABILITY_PRIORITY_RECAP = cell2table(rows, 'VariableNames', { 'subject', 'age_group', 'recoverability_score', 'recoverability_category', 'score_component_percent_kept', 'score_component_distance_to_15', 'score_component_n_borderline_signals', 'score_component_coverage', 'score_penalty_zero_valid_rows', 'score_penalty_missing_rows', 'score_component_low_initial_cycles_relative_to_height', 'height_m', 'expected_low_initial_cycles_for_height', 'expected_high_initial_cycles_for_height', 'initial_cycle_deficit_relative_to_height', 'n_target_rows_present_TATA_SOLGM', 'n_target_rows_expected_TATA_SOLGM', 'n_missing_target_rows_TATA_SOLGM', 'n_zero_valid_target_rows_TATA_SOLGM', 'n_target_signals_below_8', 'n_target_signals_between_8_and_15', 'n_target_signals_above_15', 'n_TATA_signals_between_8_and_15', 'n_SOLGM_signals_between_8_and_15', 'median_initial_cycles_target_pairs', 'median_valid_cycles_target_pairs', 'median_percent_kept_target_pairs', 'median_initial_cycles_in_range', 'median_valid_cycles_in_range', 'median_percent_kept_in_range', 'median_distance_to_15_cycles_in_range', 'median_percent_kept_TATA', 'median_percent_kept_SOLGM', 'n_conditions_present_target_pairs', 'n_legs_present_target_pairs', 'n_condition_leg_combinations_present_target_pairs', 'condition_coverage_target_pairs', 'leg_coverage_target_pairs', 'row_coverage_target_pairs', 'Height_cm', 'Weight_kg', 'L0_m', 'TA_TA_cm', 'AgeMonths', 'Sex', 'coverage_and_missing_note', 'conditions_concerned_in_range', 'legs_concerned_in_range', 'pairs_concerned_in_range', 'detail_borderline_signals_valid_original_kept' });

        RECOVERABILITY_PRIORITY_RECAP = sortrows( RECOVERABILITY_PRIORITY_RECAP, {'recoverability_score','n_target_signals_between_8_and_15'}, {'descend','descend'});
    end

    disp(RECOVERABILITY_PRIORITY_RECAP);

    writetable(RECOVERABILITY_PRIORITY_RECAP, fullfile(IO.xlsx_dir, 'RECOVERABILITY_PRIORITY_RECAP.xlsx'));

    %% ===================== EXPORT READABLE FINAL SIGNAL SUMMARY XLSX =====================

    fprintf('\nExporting readable final signal summary XLSX...\n');

    summaryXlsx = fullfile(IO.xlsx_dir, 'FINAL_SIGNAL_SUMMARY_READABLE.xlsx');

    include_metadata = false;

    export_final_signal_summary_readable_xlsx( FINAL_SIGNAL_SUMMARY, RECOVERABILITY_PRIORITY_RECAP, ADULTS_8_TO_15_CYCLES_BY_SIGNAL, FULL_LEG_PAIR_DETAIL_RECAP, META, summaryXlsx, include_metadata);

    fprintf('Saved readable XLSX:\n  %s\n', summaryXlsx);

    %% ===================== RECAP OF ANALYZABLE SIGNALS =====================
    if ~isempty(FINAL_SIGNAL_SUMMARY)

        ANALYZABLE_SIGNALS = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == true, :);
        ANALYZABLE_SIGNALS_ALPHA = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk_alpha == true, :);
        ANALYZABLE_SIGNALS_BETA  = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk_beta == true, :);
        ANALYZABLE_SIGNALS_GAMMA = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk_gamma == true, :);

        RECAP_OVERALL = build_signal_recap_tables(ANALYZABLE_SIGNALS);
        RECAP_ALPHA   = build_signal_recap_tables(ANALYZABLE_SIGNALS_ALPHA);
        RECAP_BETA    = build_signal_recap_tables(ANALYZABLE_SIGNALS_BETA);
        RECAP_GAMMA   = build_signal_recap_tables(ANALYZABLE_SIGNALS_GAMMA);

        % Backward-compatible overall variables
        RECAP_BY_AGE                = RECAP_OVERALL.by_age;
        RECAP_BY_CONDITION          = RECAP_OVERALL.by_condition;
        RECAP_BY_PAIR               = RECAP_OVERALL.by_pair;
        RECAP_BY_AGE_CONDITION      = RECAP_OVERALL.by_age_condition;
        RECAP_BY_PAIR_AGE           = RECAP_OVERALL.by_pair_age;
        RECAP_BY_PAIR_CONDITION     = RECAP_OVERALL.by_pair_condition;
        RECAP_BY_PAIR_AGE_CONDITION = RECAP_OVERALL.by_pair_age_condition;

        fprintf('\n===================== FINAL RECAP =====================\n');

        activeRules = get_active_cycle_policy_rules(P.cycle_policy);
        fprintf('Exclusion method(s) applied: %s\n', strjoin(activeRules, ", "));

        print_signal_recap_block('OVERALL', ANALYZABLE_SIGNALS, RECAP_OVERALL);
        print_signal_recap_block('ALPHA',   ANALYZABLE_SIGNALS_ALPHA, RECAP_ALPHA);
        print_signal_recap_block('BETA',    ANALYZABLE_SIGNALS_BETA,  RECAP_BETA);
        print_signal_recap_block('GAMMA',   ANALYZABLE_SIGNALS_GAMMA, RECAP_GAMMA);

    else
        ANALYZABLE_SIGNALS       = table();
        ANALYZABLE_SIGNALS_ALPHA = table();
        ANALYZABLE_SIGNALS_BETA  = table();
        ANALYZABLE_SIGNALS_GAMMA = table();

        RECAP_OVERALL = init_empty_signal_recap();
        RECAP_ALPHA   = init_empty_signal_recap();
        RECAP_BETA    = init_empty_signal_recap();
        RECAP_GAMMA   = init_empty_signal_recap();

        RECAP_BY_AGE                = table();
        RECAP_BY_CONDITION          = table();
        RECAP_BY_PAIR               = table();
        RECAP_BY_AGE_CONDITION      = table();
        RECAP_BY_PAIR_AGE           = table();
        RECAP_BY_PAIR_CONDITION     = table();
        RECAP_BY_PAIR_AGE_CONDITION = table();
    end

    %% ===================== PARTICIPANT-LEVEL RECAP =====================
    if ~isempty(ANALYZABLE_SIGNALS)

        PARTICIPANT_RECAP_OVERALL = build_participant_recap_tables(ANALYZABLE_SIGNALS);
        PARTICIPANT_RECAP_ALPHA   = build_participant_recap_tables(ANALYZABLE_SIGNALS_ALPHA);
        PARTICIPANT_RECAP_BETA    = build_participant_recap_tables(ANALYZABLE_SIGNALS_BETA);
        PARTICIPANT_RECAP_GAMMA   = build_participant_recap_tables(ANALYZABLE_SIGNALS_GAMMA);

        % Backward-compatible overall variables
        PARTICIPANT_SUMMARY = PARTICIPANT_RECAP_OVERALL.summary;
        RECAP_PARTICIPANTS_BY_AGE = PARTICIPANT_RECAP_OVERALL.by_age;
        RECAP_PARTICIPANTS_BY_CONDITION = PARTICIPANT_RECAP_OVERALL.by_condition;
        RECAP_PARTICIPANTS_BY_AGE_CONDITION = PARTICIPANT_RECAP_OVERALL.by_age_condition;
        RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = PARTICIPANT_RECAP_OVERALL.signals_per_participant_by_age;
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = PARTICIPANT_RECAP_OVERALL.conditions_per_participant_by_age;

        fprintf('\n===================== PARTICIPANT-LEVEL RECAP =====================\n');

        print_participant_recap_block('OVERALL', PARTICIPANT_RECAP_OVERALL);
        print_participant_recap_block('ALPHA',   PARTICIPANT_RECAP_ALPHA);
        print_participant_recap_block('BETA',    PARTICIPANT_RECAP_BETA);
        print_participant_recap_block('GAMMA',   PARTICIPANT_RECAP_GAMMA);

    else
        PARTICIPANT_RECAP_OVERALL = init_empty_participant_recap();
        PARTICIPANT_RECAP_ALPHA   = init_empty_participant_recap();
        PARTICIPANT_RECAP_BETA    = init_empty_participant_recap();
        PARTICIPANT_RECAP_GAMMA   = init_empty_participant_recap();

        PARTICIPANT_SUMMARY = table();
        RECAP_PARTICIPANTS_BY_AGE = table();
        RECAP_PARTICIPANTS_BY_CONDITION = table();
        RECAP_PARTICIPANTS_BY_AGE_CONDITION = table();
        RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = table();
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = table();
    end


    %% ===================== PARTICIPANT-LEVEL RECAP PER PAIR =====================
    if ~isempty(ANALYZABLE_SIGNALS)

        PARTICIPANT_PAIR_RECAP_OVERALL = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS);
        PARTICIPANT_PAIR_RECAP_ALPHA   = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS_ALPHA);
        PARTICIPANT_PAIR_RECAP_BETA    = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS_BETA);
        PARTICIPANT_PAIR_RECAP_GAMMA   = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS_GAMMA);

        % Backward-compatible overall variables
        PARTICIPANT_SUMMARY_BY_PAIR = PARTICIPANT_PAIR_RECAP_OVERALL.summary_by_pair;
        RECAP_PARTICIPANTS_BY_PAIR = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair;
        RECAP_PARTICIPANTS_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_age;
        RECAP_PARTICIPANTS_BY_PAIR_CONDITION = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_condition;
        RECAP_PARTICIPANTS_BY_PAIR_AGE_CONDITION = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_age_condition;
        RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.signals_per_participant_by_pair_age;
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.conditions_per_participant_by_pair_age;

        fprintf('\n===================== PARTICIPANT-LEVEL RECAP PER PAIR =====================\n');

        print_participant_pair_recap_block('OVERALL', PARTICIPANT_PAIR_RECAP_OVERALL);
        print_participant_pair_recap_block('ALPHA',   PARTICIPANT_PAIR_RECAP_ALPHA);
        print_participant_pair_recap_block('BETA',    PARTICIPANT_PAIR_RECAP_BETA);
        print_participant_pair_recap_block('GAMMA',   PARTICIPANT_PAIR_RECAP_GAMMA);

    else
        PARTICIPANT_PAIR_RECAP_OVERALL = init_empty_participant_pair_recap();
        PARTICIPANT_PAIR_RECAP_ALPHA   = init_empty_participant_pair_recap();
        PARTICIPANT_PAIR_RECAP_BETA    = init_empty_participant_pair_recap();
        PARTICIPANT_PAIR_RECAP_GAMMA   = init_empty_participant_pair_recap();

        PARTICIPANT_SUMMARY_BY_PAIR = table();
        RECAP_PARTICIPANTS_BY_PAIR = table();
        RECAP_PARTICIPANTS_BY_PAIR_AGE = table();
        RECAP_PARTICIPANTS_BY_PAIR_CONDITION = table();
        RECAP_PARTICIPANTS_BY_PAIR_AGE_CONDITION = table();
        RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE = table();
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE = table();
    end

    %% ===================== PLOTS FOR NON-INCLUDED PAIR SIGNALS =====================

    if PL.excluded.enable && ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating plots for excluded pair signals...\n');
        excludedT = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == false, :);

        if ~isempty(excludedT)

            if isempty(PL.excluded.random_seed)
                rng('shuffle');
            else
                rng(PL.excluded.random_seed);
            end

            nAvail = height(excludedT);
            nPlot  = min(PL.excluded.n_random_pairs, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                fprintf('  Plotting excluded pair signal %d / %d (index %d in excluded table)\n', ip, nPlot, idxPick(ip));
                row = excludedT(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                plot_excluded_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.excluded.out_dir, C);
                plot_excluded_multisignal( PairStruct, subjID, cond, leg, pairName, PL.excluded.out_dir, C, 'FileTag', 'excluded_pair', 'Visible', 'off');
            end
        end
    end
    fprintf('\nExcluded pair signal plots saved to:\n  %s\n', PL.excluded.out_dir);

    %% ===================== RANDOM PLOTS: BAND-SPECIFIC EXCLUDED SIGNALS =====================
    if isfield(PL, 'excluded_band') && PL.excluded_band.enable && ~isempty(FINAL_SIGNAL_SUMMARY)

        fprintf('\nGenerating random plots of band-specific excluded signals...\n');

        if ~exist(PL.excluded_band.out_dir, 'dir'), mkdir(PL.excluded_band.out_dir); end
        delete(fullfile(PL.excluded_band.out_dir, '*.png'));

        for ib = 1:numel(bandNames)
            band = bandNames{ib};

            includeVar = ['included_for_analysis_' lower(band)];
            TexclBand = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.(includeVar) == false, :);

            if isempty(TexclBand)
                fprintf('  No excluded signals for %s band.\n', band);
                continue;
            end

            if isempty(PL.excluded_band.random_seed)
                rng('shuffle');
            else
                rng(PL.excluded_band.random_seed + ib);
            end

            nAvail = height(TexclBand);
            nPlot  = min(PL.excluded_band.n_random_per_band, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                row = TexclBand(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);
                Pplot = make_band_plot_struct(PairStruct, band);

                plot_excluded_multisignal( Pplot, subjID, cond, leg, [pairName '_' band], PL.excluded_band.out_dir, C, 'FileTag', ['excluded_' lower(band)], 'Visible', 'off', 'FigureTitle', sprintf('%s | %s | %s | %s | %s-specific excluded', subjID, cond, leg, pairName, band));
            end
        end
    end

    fprintf('\nBand-specific excluded plots saved to:\n  %s\n', PL.excluded_band.out_dir);

    %% ===================== MANUAL PLOTS FOR SELECTED PAIRS =====================
    if isfield(PL, 'manual') && isfield(PL.manual, 'enable') && PL.manual.enable
        fprintf('\nGenerating manual plots for selected pairs set in config_emg.m...\n');

        if ~exist(PL.manual.out_dir, 'dir'), mkdir(PL.manual.out_dir); end

        % optional: remove old plots
        delete(fullfile(PL.manual.out_dir, '*.png'));

        requests = PL.manual.requests;

        for iR = 1:numel(requests)
            req = requests{iR};

            subjID   = char(string(req.subject));
            cond     = char(string(req.condition));
            leg      = char(string(req.leg));
            pairName = char(string(req.pair_name));

            fprintf('  Manual plot %d / %d: %s | %s | %s | %s\n', iR, numel(requests), subjID, cond, leg, pairName);

            if ~isfield(FINAL_PAIRED_SIGNALS, subjID)
                warning('Manual plot skipped: subject not found: %s', subjID);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond)
                warning('Manual plot skipped: condition not found: %s | %s', subjID, cond);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg)
                warning('Manual plot skipped: leg not found: %s | %s | %s', subjID, cond, leg);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                warning('Manual plot skipped: pair not found: %s | %s | %s | %s', subjID, cond, leg, pairName);
                continue;
            end

            PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

            % choose which plotting function you want
            plot_excluded_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C);
            plot_excluded_multisignal( PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C, 'FileTag', 'manual_pair', 'Visible', 'off');

            % If instead you want the rebuilt signal plot for that exact case, use:
            %plot_original_vs_rebuilt_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C);

            plot_original_vs_rebuilt_multisignal( PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C, 'FileTag', 'rebuilt_pair', 'Visible', 'off', 'CenterRebuilt', true);
        end
        fprintf('\nManual pair plots saved to:\n  %s\n', PL.manual.out_dir);
    else
        fprintf('\nNo manual plotting requested in config_emg.m, skipping manual plots.\n');
    end

    %% ===================== RANDOM PLOTS: ORIGINAL VS REBUILT =====================
    if PL.rebuilt.enable && ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating random plots of original vs rebuilt signals...\n');
        % Keep only signals that were included for analysis
        Tplot = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == true, :);

        if ~isempty(Tplot)
            if isempty(PL.rebuilt.random_seed)
                rng('shuffle');
            else
                rng(PL.rebuilt.random_seed);
            end

            % delete old plots
            if ~exist(PL.rebuilt.out_dir, 'dir'), mkdir(PL.rebuilt.out_dir); end
            delete(fullfile(PL.rebuilt.out_dir, '*.png'));

            nAvail = height(Tplot);
            nPlot  = min(PL.rebuilt.n_random, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot

                row = Tplot(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                %plot_original_vs_rebuilt_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.rebuilt.out_dir, C);
                plot_original_vs_rebuilt_multisignal( PairStruct, subjID, cond, leg, pairName, PL.rebuilt.out_dir, C, 'FileTag', 'rebuilt_pair', 'Visible', 'off', 'CenterRebuilt', true);
            end
        end
    end

    fprintf('\nOriginal vs rebuilt signal plots saved to:\n  %s\n', PL.rebuilt.out_dir);

    %% ===================== RANDOM PLOTS: BAND-SPECIFIC REBUILT SIGNALS =====================
    if isfield(PL, 'rebuilt_band') && PL.rebuilt_band.enable && ~isempty(FINAL_SIGNAL_SUMMARY)

        fprintf('\nGenerating random plots of band-specific rebuilt signals...\n');

        if ~exist(PL.rebuilt_band.out_dir, 'dir'), mkdir(PL.rebuilt_band.out_dir); end
        delete(fullfile(PL.rebuilt_band.out_dir, '*.png'));

        for ib = 1:numel(bandNames)
            band = bandNames{ib};

            includeVar = ['included_after_crosstalk_' lower(band)];
            Tband = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.(includeVar) == true, :);

            if isempty(Tband)
                fprintf('  No included signals for %s band.\n', band);
                continue;
            end

            if isempty(PL.rebuilt_band.random_seed)
                rng('shuffle');
            else
                rng(PL.rebuilt_band.random_seed + ib);
            end

            nAvail = height(Tband);
            nPlot  = min(PL.rebuilt_band.n_random_per_band, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                row = Tband(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);
                Pplot = make_band_plot_struct(PairStruct, band);

                plot_original_vs_rebuilt_multisignal( Pplot, subjID, cond, leg, [pairName '_' band], PL.rebuilt_band.out_dir, C, 'FileTag', ['rebuilt_' lower(band)], 'Visible', 'off', 'CenterRebuilt', true, 'FigureTitle', sprintf('%s | %s | %s | %s | %s-specific rebuilt', subjID, cond, leg, pairName, band));
            end
        end
    end

    %% ===================== WAVELET ROI EXCLUSION EXAMPLE PLOTS =====================
    if isfield(C.f_final_signals.plot, 'wavelet_roi') && C.f_final_signals.plot.wavelet_roi.enable
        fprintf('\nGenerating wavelet ROI exclusion example plots...\n');
        plot_wavelet_roi_exclusion_examples(FINAL_PAIRED_SIGNALS, C, P);
    end

    %% ===================== SAVE =====================
    fprintf('\nSaving final paired signals and tables...\n');
    save(IO.out_mat, 'FINAL_PAIRED_SIGNALS', 'CYCLE_QC_TABLE', 'PAIR_CYCLE_QC_TABLE', 'FINAL_SIGNAL_SUMMARY', 'CROSSTALK_QC_TABLE', 'CROSSTALK_QC_SUSPICIOUS', 'IO', 'P', 'PL', '-v7.3');

    fprintf('\nSaved all results to:\n  %s\n', IO.out_mat);

    fprintf('\nSaving tables as xlsx...\n');
    writetable(CYCLE_QC_TABLE, IO.cycle_qc_xlsx);
    fprintf('Saved:\n  %s\n', IO.cycle_qc_xlsx);
    writetable(PAIR_CYCLE_QC_TABLE, IO.pair_cycle_xlsx);
    fprintf('Saved:\n  %s\n', IO.pair_cycle_xlsx);
    writetable(FINAL_SIGNAL_SUMMARY, IO.signal_sum_xlsx);
    fprintf('Saved:\n  %s\n', IO.signal_sum_xlsx);

    %% ===================== SAVE MERGED RECAP TABLES =====================

    fprintf('\nBuilding merged recap master tables...\n');

    RECAP_MASTER_SIGNAL_BY_PAIR_BAND = [
        build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS,       "OVERALL")
        build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS_ALPHA, "ALPHA")
        build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS_BETA,  "BETA")
        build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS_GAMMA, "GAMMA")
    ];

    RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND = [
        build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS,       "OVERALL")
        build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS_ALPHA, "ALPHA")
        build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS_BETA,  "BETA")
        build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS_GAMMA, "GAMMA")
    ];

    RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND = [
        build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, "OVERALL", "included_after_crosstalk",       "n_valid_cycles")
        build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, "ALPHA",   "included_after_crosstalk_alpha", "n_valid_cycles_alpha")
        build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, "BETA",    "included_after_crosstalk_beta",  "n_valid_cycles_beta")
        build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, "GAMMA",   "included_after_crosstalk_gamma", "n_valid_cycles_gamma")
    ];

    writetable(RECAP_MASTER_SIGNAL_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_SIGNAL_BY_PAIR_BAND.xlsx'));

    writetable(RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND.xlsx'));

    writetable(RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND.xlsx'));

    fprintf('Saved merged recap master tables to:\n  %s\n', IO.recap_xlsx_dir);

    %% ===================== EXPORT BAND-SPECIFIC FINAL SIGNAL FILES =====================

    fprintf('\nBuilding exported band-specific FINAL_PAIRED_SIGNALS files...\n');

    FINAL_PAIRED_SIGNALS_OVERALL = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, "overall");
    FINAL_PAIRED_SIGNALS_ALPHA   = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, "Alpha");
    FINAL_PAIRED_SIGNALS_BETA    = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, "Beta");
    FINAL_PAIRED_SIGNALS_GAMMA   = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, "Gamma");

    fprintf('Saving:\n  %s\n', IO.out_mat_overall);
    save(IO.out_mat_overall, 'FINAL_PAIRED_SIGNALS_OVERALL', '-v7.3');

    fprintf('Saving:\n  %s\n', IO.out_mat_alpha);
    save(IO.out_mat_alpha, 'FINAL_PAIRED_SIGNALS_ALPHA', '-v7.3');

    fprintf('Saving:\n  %s\n', IO.out_mat_beta);
    save(IO.out_mat_beta, 'FINAL_PAIRED_SIGNALS_BETA', '-v7.3');

    fprintf('Saving:\n  %s\n', IO.out_mat_gamma);
    save(IO.out_mat_gamma, 'FINAL_PAIRED_SIGNALS_GAMMA', '-v7.3');

    save(IO.out_mat, 'FINAL_PAIRED_SIGNALS', 'CYCLE_QC_TABLE', 'PAIR_CYCLE_QC_TABLE', 'FINAL_SIGNAL_SUMMARY', 'ANALYZABLE_SIGNALS', 'RECAP_BY_AGE', 'RECAP_BY_CONDITION', 'RECAP_BY_PAIR', 'RECAP_BY_AGE_CONDITION', 'RECAP_BY_PAIR_AGE', 'RECAP_BY_PAIR_CONDITION', 'RECAP_BY_PAIR_AGE_CONDITION', 'PARTICIPANT_SUMMARY', 'RECAP_PARTICIPANTS_BY_AGE', 'RECAP_PARTICIPANTS_BY_CONDITION', 'RECAP_PARTICIPANTS_BY_AGE_CONDITION', 'RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE', 'RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE', 'PARTICIPANT_SUMMARY_BY_PAIR', 'RECAP_PARTICIPANTS_BY_PAIR', 'RECAP_PARTICIPANTS_BY_PAIR_AGE', 'RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE', 'RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE', 'ANALYZABLE_SIGNALS_ALPHA', 'ANALYZABLE_SIGNALS_BETA', 'ANALYZABLE_SIGNALS_GAMMA', 'RECAP_ALPHA', 'RECAP_BETA', 'RECAP_GAMMA', 'PARTICIPANT_RECAP_ALPHA', 'PARTICIPANT_RECAP_BETA', 'PARTICIPANT_RECAP_GAMMA', 'PARTICIPANT_PAIR_RECAP_ALPHA', 'PARTICIPANT_PAIR_RECAP_BETA', 'PARTICIPANT_PAIR_RECAP_GAMMA', 'CROSSTALK_QC_TABLE', 'CROSSTALK_QC_SUSPICIOUS', 'IO', 'P', 'PL', '-v7.3');
    fprintf('Updated mat file with recap tables.\n');
end