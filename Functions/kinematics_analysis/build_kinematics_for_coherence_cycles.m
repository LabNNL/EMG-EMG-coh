%% build_kinematics_for_coherence_cycles.m
% Map the exact post-QC coherence cycles onto marker-based gait metrics.
%
% INPUTS
%   - FINAL_PAIRED_SIGNALS.mat produced by f_build_final_paired_signals_from_burst_qc.m
%   - *_RAW_CYCLES_CONCAT.mat produced by a_extract_raw_cycles_concat_fast.m
%     These files must contain CYCLES_SIGNAL_RAW and RAW_MARKERS.
%
% OUTPUTS
%   - KINEMATICS_COHERENCE_CYCLES_TABLE.xlsx
%   - KINEMATICS_COHERENCE_SIGNAL_SUMMARY.xlsx
%   - KINEMATICS_COHERENCE_CYCLES.mat
%
% Main idea:
%   The EMG QC output decides which cycles exist in the coherence analysis.
%   This script only attaches kinematic metrics to those same cycles.
function build_kinematics_for_coherence_cycles()
    clc; clear; close all;

    addpath(genpath(fullfile(pwd, 'Functions')));

    C = config_emg();
    K = get_kinematics_coherence_config(C);

    if ~exist(K.io.out_dir, 'dir'), mkdir(K.io.out_dir); end

    assert(isfile(K.io.final_paired_mat), 'FINAL_PAIRED_SIGNALS mat file not found: %s', K.io.final_paired_mat);
    assert(isfolder(K.io.raw_cycles_dir), 'Raw cycles directory not found: %s', K.io.raw_cycles_dir);

    L = load(K.io.final_paired_mat, 'FINAL_PAIRED_SIGNALS', 'FINAL_SIGNAL_SUMMARY');
    assert(isfield(L, 'FINAL_PAIRED_SIGNALS'), 'FINAL_PAIRED_SIGNALS missing.');

    FINAL_PAIRED_SIGNALS = L.FINAL_PAIRED_SIGNALS;

    if isfield(L, 'FINAL_SIGNAL_SUMMARY')
        FINAL_SIGNAL_SUMMARY = L.FINAL_SIGNAL_SUMMARY;
    else
        FINAL_SIGNAL_SUMMARY = table();
    end

    ageLookup = build_age_lookup(FINAL_SIGNAL_SUMMARY);

    rawFiles = dir(fullfile(K.io.raw_cycles_dir, '*_RAW_CYCLES_CONCAT.mat'));
    assert(~isempty(rawFiles), 'No *_RAW_CYCLES_CONCAT.mat files found in %s', K.io.raw_cycles_dir);

    rawMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for iF = 1:numel(rawFiles)
        tok = regexp(rawFiles(iF).name, '^(.*)_RAW_CYCLES_CONCAT\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            rawMap(tok{1}) = fullfile(rawFiles(iF).folder, rawFiles(iF).name);
        end
    end

    rows = {};
    ri = 0;
    missingMarkerCache = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    missingHeelCache = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    subjects = fieldnames(FINAL_PAIRED_SIGNALS);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};

        if ~isKey(rawMap, subjID)
            warning('No raw-cycle file found for %s. Skipping.', subjID);
            continue;
        end

        fprintf('\n=== Kinematics mapping: %s ===\n', subjID);
        R = load(rawMap(subjID), 'CYCLES_SIGNAL_RAW', 'RAW_MARKERS');

        if ~isfield(R, 'CYCLES_SIGNAL_RAW') || ~isfield(R, 'RAW_MARKERS')
            warning('Missing CYCLES_SIGNAL_RAW or RAW_MARKERS in %s. Skipping.', rawMap(subjID));
            continue;
        end

        conds = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));

        for iC = 1:numel(conds)
            cond = conds{iC};
            legs = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));

            for iL = 1:numel(legs)
                leg = legs{iL};
                pairs = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));

                for iP = 1:numel(pairs)
                    pairName = pairs{iP};
                    P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    modes = get_cycle_selection_modes(P, K);

                    for iM = 1:numel(modes)
                        mode = modes(iM);

                        if K.params.only_included_signals && ~mode.included_for_analysis
                            continue;
                        end

                        keepMask = mode.keep_mask(:);
                        cycleNums = find(keepMask);

                        if isempty(cycleNums)
                            continue;
                        end

                        rawIpsi = get_raw_cycle_entry(R.CYCLES_SIGNAL_RAW, subjID, cond, leg, P.muscles);
                        if isempty(rawIpsi)
                            warning('No raw EMG cycle metadata for %s | %s | %s | %s', subjID, cond, leg, pairName);
                            continue;
                        end

                        contraLeg = opposite_leg(leg);
                        rawContra = get_any_raw_cycle_entry(R.CYCLES_SIGNAL_RAW, subjID, cond, contraLeg);

                        for kk = 1:numel(cycleNums)
                            cyc = cycleNums(kk);

                            if cyc > numel(rawIpsi.orig_start) || cyc > numel(rawIpsi.orig_end)
                                warning('Cycle %d exceeds raw metadata length for %s | %s | %s | %s', cyc, subjID, cond, leg, pairName);
                                continue;
                            end

                            trialID = string(rawIpsi.trial_id{cyc});
                            i0 = double(rawIpsi.orig_start(cyc));
                            i1 = double(rawIpsi.orig_end(cyc));

                            M = get_marker_trial_struct(R.RAW_MARKERS, subjID, cond, trialID, leg);
                            Mcontra = get_marker_trial_struct(R.RAW_MARKERS, subjID, cond, trialID, contraLeg);

                            if isempty(M)
                                missingKey = char(strjoin([string(subjID), string(cond), string(trialID)], "|"));
                                if ~isKey(missingMarkerCache, missingKey)
                                    missingMarkerCache(missingKey) = true;
                                    availableMarkerFields = describe_available_marker_fields(R.RAW_MARKERS, subjID, cond);
                                    warning('No marker trial found for %s | %s | trial %s. Available marker fields: %s', subjID, cond, trialID, availableMarkerFields);
                                end
                                continue;
                            end

                            fsEmg = get_pair_fs(P, K);
                            fsMarker = get_marker_fs(M, K);

                            f0 = analog_sample_to_marker_frame(i0, fsEmg, fsMarker);
                            f1 = analog_sample_to_marker_frame(i1, fsEmg, fsMarker);

                            ipsiHeel = get_heel_marker(M, leg, K);
                            contraHeel = get_heel_marker(Mcontra, contraLeg, K);
                            refMarker = get_reference_marker(M, K);

                            if isempty(ipsiHeel) || isempty(contraHeel)
                                heelKey = char(strjoin([string(subjID), string(cond), string(trialID)], "|"));
                                if ~isKey(missingHeelCache, heelKey)
                                    missingHeelCache(heelKey) = true;
                                    warning(['Heel marker incomplete for %s | %s | trial %s | ipsi %s missing=%d | contra %s missing=%d. ' 'Ipsi marker-like fields: %s | Contra marker-like fields: %s'], subjID, cond, trialID, leg, isempty(ipsiHeel), contraLeg, isempty(contraHeel), describe_marker_like_fields(M), describe_marker_like_fields(Mcontra));
                                end
                            end

                            [strideLen, strideSpeed, cycleDur] = compute_stride_metrics( ipsiHeel, refMarker, f0, f1, fsMarker, K);

                            [stepDur1, stepDur2, stepLen1, stepLen2, contraHS, stepNote] = compute_step_metrics( rawContra, trialID, i0, i1, fsEmg, fsMarker, ipsiHeel, contraHeel, leg, K);

                            ageGroup = lookup_age_group(ageLookup, subjID, cond, leg, pairName);

                            ri = ri + 1;
                            rows(ri,:) = { string(subjID), string(ageGroup), string(cond), string(leg), string(pairName), string(mode.band), string(mode.selection_name), logical(mode.included_for_analysis), double(cyc), string(trialID), double(i0), double(i1), double(contraHS), double(cycleDur), double(strideLen), double(strideSpeed), double(stepDur1), double(stepDur2), double(stepLen1), double(stepLen2), mean([stepLen1 stepLen2], 'omitnan'), string(stepNote) }; %#ok<SAGROW>
                        end
                    end
                end
            end
        end
    end

    cycleVarNames = kinematics_cycle_var_names();

    if isempty(rows)
        KINEMATICS_COHERENCE_CYCLES_TABLE = cell2table(cell(0, numel(cycleVarNames)), 'VariableNames', cycleVarNames);
    else
        KINEMATICS_COHERENCE_CYCLES_TABLE = cell2table(rows, 'VariableNames', cycleVarNames);
    end

    % Keep the variable list near the table construction for readability.
    % The helper is below so empty-output handling stays robust.
    %{
        'subject','age_group','condition','leg','pair_name','band','selection_name', 'signal_included_for_analysis','cycle_number','trial_id', 'orig_start_sample','orig_end_sample','contralateral_hs_sample', 'cycle_duration_s','stride_length_m','stride_speed_mps', 'step_duration_1_s','step_duration_2_s', 'step_length_1_m','step_length_2_m','mean_step_length_m', 'step_metric_note' });
    %}

    KINEMATICS_COHERENCE_SIGNAL_SUMMARY = summarize_kinematics_by_signal(KINEMATICS_COHERENCE_CYCLES_TABLE);

    save(K.io.out_mat, 'KINEMATICS_COHERENCE_CYCLES_TABLE', 'KINEMATICS_COHERENCE_SIGNAL_SUMMARY', 'K', '-v7.3');

    writetable(KINEMATICS_COHERENCE_CYCLES_TABLE, K.io.out_cycle_xlsx);
    writetable(KINEMATICS_COHERENCE_SIGNAL_SUMMARY, K.io.out_summary_xlsx);

    fprintf('\nSaved:\n  %s\n  %s\n  %s\n', K.io.out_mat, K.io.out_cycle_xlsx, K.io.out_summary_xlsx);

    print_kinematics_output_recap(KINEMATICS_COHERENCE_CYCLES_TABLE, KINEMATICS_COHERENCE_SIGNAL_SUMMARY);
end

%% ===================== LOCAL FUNCTIONS =====================

function K = get_kinematics_coherence_config(C)
    K = struct();

    if isfield(C, 'kinematics_coherence')
        K = C.kinematics_coherence;
    end

    K.io = ensure_field(K, 'io', struct());
    K.params = ensure_field(K, 'params', struct());
    K.markers = ensure_field(K, 'markers', struct());

    K.io.final_paired_mat = get_nested_or_default(K, {'io','final_paired_mat'}, get_nested_or_default(C, {'f_final_signals','io','out_mat'}, fullfile(pwd, 'FINAL_PAIRED_SIGNALS.mat')));
    K.io.raw_cycles_dir = get_nested_or_default(K, {'io','raw_cycles_dir'}, get_nested_or_default(C, {'paths','raw_dir'}, fullfile(pwd, 'raw')));
    K.io.out_dir = get_nested_or_default(K, {'io','out_dir'}, fullfile(get_nested_or_default(C, {'paths','results_dir'}, pwd), 'kinematics_coherence_cycles'));

    K.io.out_mat = fullfile(K.io.out_dir, 'KINEMATICS_COHERENCE_CYCLES.mat');
    K.io.out_cycle_xlsx = fullfile(K.io.out_dir, 'KINEMATICS_COHERENCE_CYCLES_TABLE.xlsx');
    K.io.out_summary_xlsx = fullfile(K.io.out_dir, 'KINEMATICS_COHERENCE_SIGNAL_SUMMARY.xlsx');

    K.params.only_included_signals = get_nested_or_default(K, {'params','only_included_signals'}, true);
    K.params.include_bands = get_nested_or_default(K, {'params','include_bands'}, true);
    K.params.forward_dim = get_nested_or_default(K, {'params','forward_dim'}, 1);
    K.params.marker_units = string(get_nested_or_default(K, {'params','marker_units'}, 'mm'));
    K.params.use_abs_lengths = get_nested_or_default(K, {'params','use_abs_lengths'}, true);
    K.params.fs_marker_default = get_nested_or_default(C, {'general','fs_vicon'}, 100);
    K.params.fs_emg_default = get_nested_or_default(C, {'general','fs_emg'}, 2000);

    K.markers.left_heel_candidates = get_nested_or_default(K, {'markers','left_heel_candidates'}, get_nested_or_default(C, {'a_extract_raw','markers','left','heel_candidates'}, {'LHEE','L_HEE','LeftHeel','LHeel','L_HEEL','LANK'}));
    K.markers.right_heel_candidates = get_nested_or_default(K, {'markers','right_heel_candidates'}, get_nested_or_default(C, {'a_extract_raw','markers','right','heel_candidates'}, {'RHEE','R_HEE','RightHeel','RHeel','R_HEEL','RANK'}));
    K.markers.reference_candidates = get_nested_or_default(K, {'markers','reference_candidates'}, {'SACR','Sacrum','PELO','Pelvis','LASI','RASI'});
end

function names = kinematics_cycle_var_names()
    names = { 'subject','age_group','condition','leg','pair_name','band','selection_name', 'signal_included_for_analysis','cycle_number','trial_id', 'orig_start_sample','orig_end_sample','contralateral_hs_sample', 'cycle_duration_s','stride_length_m','stride_speed_mps', 'step_duration_1_s','step_duration_2_s', 'step_length_1_m','step_length_2_m','mean_step_length_m', 'step_metric_note' };
end

function print_kinematics_output_recap(Tcycle, Tsummary)
    fprintf('\n=== Kinematics output recap ===\n');
    fprintf('Cycle rows: %d\n', height(Tcycle));
    fprintf('Signal-summary rows: %d\n', height(Tsummary));

    if height(Tcycle) == 0
        fprintf('No cycle rows were created. Check marker/cycle mapping before plotting.\n');
        return;
    end

    fprintf('Rows with stride length: %d / %d\n', sum(~isnan(Tcycle.stride_length_m)), height(Tcycle));
    fprintf('Rows with stride speed:  %d / %d\n', sum(~isnan(Tcycle.stride_speed_mps)), height(Tcycle));
    fprintf('Rows with mean step length: %d / %d\n', sum(~isnan(Tcycle.mean_step_length_m)), height(Tcycle));

    if ismember('step_metric_note', Tcycle.Properties.VariableNames)
        disp(groupsummary(Tcycle, 'step_metric_note'));
    end
end

function modes = get_cycle_selection_modes(P, K)
    modes = struct('band', {}, 'selection_name', {}, 'keep_mask', {}, 'included_for_analysis', {});

    modes(end+1).band = "OVERALL";
    modes(end).selection_name = "pair_cycle_keep";
    modes(end).keep_mask = P.pair_cycle_keep_mask(:);
    modes(end).included_for_analysis = logical(P.included_for_analysis);

    if K.params.include_bands && isfield(P, 'band_specific')
        bands = fieldnames(P.band_specific);
        for ib = 1:numel(bands)
            band = bands{ib};
            B = P.band_specific.(band);
            modes(end+1).band = string(band); %#ok<AGROW>
            modes(end).selection_name = "pair_cycle_keep_" + string(band);
            modes(end).keep_mask = B.pair_cycle_keep_mask(:);
            modes(end).included_for_analysis = logical(B.included_for_analysis);
        end
    end
end

function rawEntry = get_raw_cycle_entry(S, subjID, cond, leg, muscles)
    rawEntry = [];
    if ~isfield(S, subjID) || ~isfield(S.(subjID), cond) || ~isfield(S.(subjID).(cond), leg)
        return;
    end

    for im = 1:numel(muscles)
        field = char(string(muscles{im}));
        if ~endsWith(field, '_Concat')
            field = char(string(field) + "_Concat");
        end
        if isfield(S.(subjID).(cond).(leg), field)
            rawEntry = S.(subjID).(cond).(leg).(field);
            return;
        end
    end
end

function rawEntry = get_any_raw_cycle_entry(S, subjID, cond, leg)
    rawEntry = [];
    if ~isfield(S, subjID) || ~isfield(S.(subjID), cond) || ~isfield(S.(subjID).(cond), leg)
        return;
    end

    F = fieldnames(S.(subjID).(cond).(leg));
    for i = 1:numel(F)
        if endsWith(F{i}, '_Concat') && isfield(S.(subjID).(cond).(leg).(F{i}), 'orig_start')
            rawEntry = S.(subjID).(cond).(leg).(F{i});
            return;
        end
    end
end

function M = get_marker_trial_struct(RAW_MARKERS, subjID, cond, trialID, leg)
    M = [];
    if nargin < 5
        leg = "";
    end

    if ~isfield(RAW_MARKERS, subjID) || ~isfield(RAW_MARKERS.(subjID), cond)
        return;
    end

    root = RAW_MARKERS.(subjID).(cond);

    if strlength(string(leg)) > 0 && isfield(root, char(leg))
        legRoot = root.(char(leg));
        M = get_marker_trial_from_root(legRoot, trialID);
        if ~isempty(M)
            return;
        end
    end

    M = get_marker_trial_from_root(root, trialID);
end

function M = get_marker_trial_from_root(root, trialID)
    M = [];

    if istable(root)
        M = get_marker_trial_from_table(root, trialID);
        return;
    end

    candidates = unique([ string(trialID), matlab.lang.makeValidName(string(trialID)), "Trial_" + string(trialID), "trial_" + string(trialID), "Trial" + string(trialID), "trial" + string(trialID), "Essai_" + string(trialID), "essai_" + string(trialID), "Essai" + string(trialID), "essai" + string(trialID), "T" + string(trialID), "t" + string(trialID), "E" + string(trialID), "e" + string(trialID) ]);

    for i = 1:numel(candidates)
        f = char(candidates(i));
        if isfield(root, f)
            M = root.(f);
            return;
        end
    end

    F = fieldnames(root);
    for i = 1:numel(F)
        if contains(string(F{i}), string(trialID))
            M = root.(F{i});
            return;
        end
    end

    M = find_marker_trial_recursive(root, trialID, 0);
end

function M = get_marker_trial_from_table(T, trialID)
    M = [];
    vars = string(T.Properties.VariableNames);
    trialVars = vars(contains(lower(vars), "trial") | contains(lower(vars), "essai"));
    if isempty(trialVars), return; end

    v = trialVars(1);
    trialValues = string(T.(v));
    idx = find(trialValues == string(trialID) | trialValues == erase(string(trialID), "0"), 1, 'first');
    if isempty(idx), return; end

    M = table2struct(T(idx,:));
end

function M = find_marker_trial_recursive(S, trialID, depth)
    M = [];
    if depth > 5 || isempty(S)
        return;
    end

    if istable(S)
        M = get_marker_trial_from_table(S, trialID);
        return;
    end

    if ~isstruct(S)
        return;
    end

    if struct_has_trial_id(S, trialID)
        M = S;
        return;
    end

    F = fieldnames(S);
    for i = 1:numel(F)
        f = string(F{i});
        val = S.(F{i});

        if contains(f, string(trialID)) && isstruct(val)
            M = val;
            return;
        end

        M = find_marker_trial_recursive(val, trialID, depth + 1);
        if ~isempty(M)
            return;
        end
    end
end

function tf = struct_has_trial_id(S, trialID)
    tf = false;
    candidateFields = {'trial_id','trial','Trial','essai','Essai','trialID','TrialID'};

    for i = 1:numel(candidateFields)
        f = candidateFields{i};
        if isfield(S, f)
            val = string(S.(f));
            tf = any(val == string(trialID) | val == erase(string(trialID), "0"));
            if tf, return; end
        end
    end
end

function txt = describe_available_marker_fields(RAW_MARKERS, subjID, cond)
    txt = "<none>";
    if ~isfield(RAW_MARKERS, subjID)
        txt = "subject field missing";
        return;
    end
    if ~isfield(RAW_MARKERS.(subjID), cond)
        txt = "condition field missing";
        return;
    end

    root = RAW_MARKERS.(subjID).(cond);
    if istable(root)
        txt = "table vars: " + strjoin(string(root.Properties.VariableNames(1:min(width(root), 12))), ", ");
        return;
    end
    if ~isstruct(root)
        txt = class(root);
        return;
    end

    F = string(fieldnames(root));
    if isempty(F)
        txt = "<empty struct>";
    else
        txt = strjoin(F(1:min(numel(F), 20)), ", ");
    end
end

function fs = get_pair_fs(P, K)
    if isfield(P, 'fs') && ~isempty(P.fs) && ~isnan(P.fs)
        fs = double(P.fs);
    else
        fs = double(get_nested_or_default(K, {'params','fs_emg_default'}, 1000));
    end
end

function fs = get_marker_fs(M, K)
    possible = {'fs_marker','marker_fs','FreqVicon','freq_vicon','sampling_frequency'};
    fs = NaN;
    for i = 1:numel(possible)
        if isfield(M, possible{i}) && isnumeric(M.(possible{i})) && ~isempty(M.(possible{i}))
            fs = double(M.(possible{i})(1));
            break;
        end
    end
    if isnan(fs)
        fs = double(K.params.fs_marker_default);
    end
end

function frame = analog_sample_to_marker_frame(sampleIdx, fsAnalog, fsMarker)
    frame = round((double(sampleIdx) - 1) / double(fsAnalog) * double(fsMarker)) + 1;
    frame = max(1, frame);
end

function xyz = get_heel_marker(M, leg, K)
    xyz = [];
    if isempty(M), return; end

    if isstruct(M) && isfield(M, 'heel_xyz') && ~isempty(M.heel_xyz)
        xyz = double(M.heel_xyz);
        return;
    end

    if strcmpi(leg, 'left')
        candidates = K.markers.left_heel_candidates;
    else
        candidates = K.markers.right_heel_candidates;
    end

    sideRoot = get_side_marker_substruct(M, leg);
    if ~isempty(sideRoot)
        sideCandidates = [cellstr(string(candidates(:)))', {'heel','hee'}];
        xyz = find_marker_xyz(sideRoot, sideCandidates);
        if ~isempty(xyz), return; end
    end

    xyz = find_marker_xyz(M, candidates);
end

function xyz = get_reference_marker(M, K)
    xyz = find_marker_xyz(M, K.markers.reference_candidates);
end

function sideRoot = get_side_marker_substruct(M, leg)
    sideRoot = [];
    if isempty(M) || ~isstruct(M), return; end

    if strcmpi(leg, 'left')
        candidates = ["left","Left","LEFT","L","markers_left","left_markers"];
    else
        candidates = ["right","Right","RIGHT","R","markers_right","right_markers"];
    end

    for i = 1:numel(candidates)
        f = char(candidates(i));
        if isfield(M, f) && (isstruct(M.(f)) || istable(M.(f)))
            sideRoot = M.(f);
            return;
        end
    end
end

function xyz = find_marker_xyz(S, candidates)
    xyz = [];
    if isempty(S), return; end

    for i = 1:numel(candidates)
        names = unique([string(candidates{i}), matlab.lang.makeValidName(string(candidates{i}))]);
        for j = 1:numel(names)
            xyz = find_marker_xyz_recursive(S, char(names(j)), 0);
            if ~isempty(xyz), return; end
        end
    end

    % Fallback: tolerate small naming differences such as L_HEE vs LHEE,
    % Left_Heel vs leftHeel, or marker structs nested under generic fields.
    for i = 1:numel(candidates)
        xyz = find_marker_xyz_fuzzy(S, string(candidates{i}), 0);
        if ~isempty(xyz), return; end
    end
end

function xyz = find_marker_xyz_recursive(S, name, depth)
    xyz = [];
    if depth > 5 || isempty(S), return; end

    if istable(S)
        xyz = find_marker_xyz_in_table(S, string(name));
        return;
    end

    if ~isstruct(S), return; end

    if isfield(S, name)
        xyz = coerce_xyz(S.(name));
        if ~isempty(xyz), return; end
    end

    F = fieldnames(S);
    for i = 1:numel(F)
        val = S.(F{i});
        if isstruct(val)
            xyz = find_marker_xyz_recursive(val, name, depth + 1);
            if ~isempty(xyz), return; end
        end
    end
end

function xyz = find_marker_xyz_fuzzy(S, candidate, depth)
    xyz = [];
    if depth > 5 || isempty(S), return; end

    if istable(S)
        xyz = find_marker_xyz_in_table(S, candidate);
        return;
    end

    if ~isstruct(S), return; end

    target = normalize_marker_name(candidate);
    F = fieldnames(S);

    for i = 1:numel(F)
        f = string(F{i});
        normalizedField = normalize_marker_name(f);

        if normalizedField == target || contains(normalizedField, target) || contains(target, normalizedField)
            xyz = coerce_xyz(S.(F{i}));
            if ~isempty(xyz), return; end
        end
    end

    for i = 1:numel(F)
        val = S.(F{i});
        if isstruct(val) || istable(val)
            xyz = find_marker_xyz_fuzzy(val, candidate, depth + 1);
            if ~isempty(xyz), return; end
        end
    end
end

function xyz = find_marker_xyz_in_table(T, candidate)
    xyz = [];
    vars = string(T.Properties.VariableNames);
    target = normalize_marker_name(candidate);
    normVars = strings(size(vars));
    for i = 1:numel(vars)
        normVars(i) = normalize_marker_name(vars(i));
    end

    % Common format: one variable contains an Nx3 numeric marker trajectory.
    for i = 1:numel(vars)
        if normVars(i) == target || contains(normVars(i), target)
            val = T.(char(vars(i)));
            xyz = coerce_xyz(val);
            if ~isempty(xyz), return; end
        end
    end

    % Wide format: LHEE_X, LHEE_Y, LHEE_Z or Left_Heel_x/y/z.
    xIdx = find_component_var(normVars, target, "x");
    yIdx = find_component_var(normVars, target, "y");
    zIdx = find_component_var(normVars, target, "z");

    if ~isempty(xIdx) && ~isempty(yIdx) && ~isempty(zIdx)
        xyz = [double(T.(char(vars(xIdx)))), double(T.(char(vars(yIdx)))), double(T.(char(vars(zIdx))))];
    end
end

function idx = find_component_var(normVars, target, component)
    idx = [];
    suffixes = [component, "pos" + component, component + "coord"];

    for i = 1:numel(normVars)
        v = normVars(i);
        if contains(v, target)
            for s = suffixes
                if endsWith(v, s)
                    idx = i;
                    return;
                end
            end
        end
    end
end

function xyz = coerce_xyz(val)
    xyz = [];
    if istable(val)
        numericVars = varfun(@isnumeric, val, 'OutputFormat', 'uniform');
        if sum(numericVars) >= 3
            X = table2array(val(:, numericVars));
            xyz = double(X(:,1:3));
        end
        return;
    end

    if isnumeric(val) && size(val, 2) >= 3
        xyz = double(val(:,1:3));
        return;
    end

    if isnumeric(val) && size(val, 1) == 3 && size(val, 2) > 3
        xyz = double(val(1:3,:)');
        return;
    end

    if iscell(val) && numel(val) == 1
        xyz = coerce_xyz(val{1});
        return;
    end

    if isstruct(val)
        if all(isfield(val, {'x','y','z'}))
            xyz = [double(val.x(:)), double(val.y(:)), double(val.z(:))];
            return;
        end
        if all(isfield(val, {'X','Y','Z'}))
            xyz = [double(val.X(:)), double(val.Y(:)), double(val.Z(:))];
            return;
        end

        fields = {'data','xyz','XYZ','trajectory','position'};
        for i = 1:numel(fields)
            if isfield(val, fields{i}) && isnumeric(val.(fields{i})) && size(val.(fields{i}), 2) >= 3
                xyz = double(val.(fields{i})(:,1:3));
                return;
            end
            if isfield(val, fields{i}) && isnumeric(val.(fields{i})) && size(val.(fields{i}), 1) == 3
                xyz = double(val.(fields{i})(1:3,:)');
                return;
            end
        end
    end
end

function out = normalize_marker_name(x)
    out = lower(regexprep(string(x), '[^a-zA-Z0-9]', ''));
end

function txt = describe_marker_like_fields(S)
    names = collect_marker_like_fields(S, "", 0, strings(0,1));
    if isempty(names)
        txt = "<none found>";
    else
        txt = strjoin(names(1:min(numel(names), 30)), ", ");
    end
end

function names = collect_marker_like_fields(S, prefix, depth, names)
    if depth > 4 || isempty(S), return; end

    if istable(S)
        vars = string(S.Properties.VariableNames);
        names = [names; prefix + "table:" + vars(:)]; %#ok<AGROW>
        return;
    end

    if ~isstruct(S), return; end

    F = string(fieldnames(S));
    for i = 1:numel(F)
        f = F(i);
        val = S.(char(f));
        path = f;
        if strlength(prefix) > 0
            path = prefix + "." + f;
        end

        if isnumeric(val) && (size(val,2) >= 3 || size(val,1) == 3)
            names(end+1,1) = path; %#ok<AGROW>
        elseif isstruct(val) || istable(val)
            names = collect_marker_like_fields(val, path, depth + 1, names);
        end
    end

    names = unique(names, 'stable');
end

function [strideLen, strideSpeed, cycleDur] = compute_stride_metrics(ipsiHeel, refMarker, f0, f1, fsMarker, K)
    strideLen = NaN;
    strideSpeed = NaN;
    cycleDur = (double(f1) - double(f0)) / double(fsMarker);

    if isempty(ipsiHeel) || f0 > size(ipsiHeel,1) || f1 > size(ipsiHeel,1) || f1 <= f0
        return;
    end

    dim = K.params.forward_dim;
    strideLen = ipsiHeel(f1, dim) - ipsiHeel(f0, dim);

    if ~isempty(refMarker) && f0 <= size(refMarker,1) && f1 <= size(refMarker,1)
        % The reference marker is not used by default, but this keeps the
        % hook available if you later prefer pelvis/SACR displacement.
    end

    strideLen = convert_marker_units(strideLen, K);
    if K.params.use_abs_lengths
        strideLen = abs(strideLen);
    end

    if cycleDur > 0
        strideSpeed = strideLen / cycleDur;
    end
end

function [stepDur1, stepDur2, stepLen1, stepLen2, contraHS, note] = compute_step_metrics( rawContra, trialID, i0, i1, fsEmg, fsMarker, ipsiHeel, contraHeel, leg, K)

    stepDur1 = NaN;
    stepDur2 = NaN;
    stepLen1 = NaN;
    stepLen2 = NaN;
    contraHS = NaN;
    note = "missing_contralateral_cycle_metadata";

    if isempty(rawContra) || ~isfield(rawContra, 'orig_start') || ~isfield(rawContra, 'trial_id')
        return;
    end

    contraStarts = double(rawContra.orig_start(:));
    contraTrials = string(rawContra.trial_id(:));

    inSameTrial = contraTrials == string(trialID);
    inCycle = contraStarts > double(i0) & contraStarts < double(i1);
    candidates = contraStarts(inSameTrial & inCycle);

    if isempty(candidates)
        note = "no_contralateral_hs_inside_cycle";
        return;
    end

    contraHS = candidates(1);
    stepDur1 = (contraHS - double(i0)) / double(fsEmg);
    stepDur2 = (double(i1) - contraHS) / double(fsEmg);

    if isempty(ipsiHeel) && isempty(contraHeel)
        note = "missing_both_heel_markers";
        return;
    elseif isempty(ipsiHeel)
        note = "missing_ipsilateral_heel_marker";
        return;
    elseif isempty(contraHeel)
        note = "missing_contralateral_heel_marker";
        return;
    end

    fIpsiHS = analog_sample_to_marker_frame(i0, fsEmg, fsMarker);
    fContraHS = analog_sample_to_marker_frame(contraHS, fsEmg, fsMarker);

    dim = K.params.forward_dim;

    if fIpsiHS <= size(ipsiHeel,1) && fIpsiHS <= size(contraHeel,1)
        stepLen1 = ipsiHeel(fIpsiHS, dim) - contraHeel(fIpsiHS, dim);
    end

    if fContraHS <= size(ipsiHeel,1) && fContraHS <= size(contraHeel,1)
        stepLen2 = contraHeel(fContraHS, dim) - ipsiHeel(fContraHS, dim);
    end

    stepLen1 = convert_marker_units(stepLen1, K);
    stepLen2 = convert_marker_units(stepLen2, K);

    if K.params.use_abs_lengths
        stepLen1 = abs(stepLen1);
        stepLen2 = abs(stepLen2);
    end

    note = "ok";

    if strcmpi(leg, 'right')
        % The absolute-value default makes side sign irrelevant. This branch
        % exists only to make the side convention explicit for future edits.
    end
end

function x = convert_marker_units(x, K)
    switch lower(string(K.params.marker_units))
        case "mm"
            x = x / 1000;
        case "cm"
            x = x / 100;
        otherwise
            % assume meters
    end
end

function out = summarize_kinematics_by_signal(T)
    if isempty(T) || height(T) == 0
        out = table();
        return;
    end

    Gvars = {'subject','age_group','condition','leg','pair_name','band','selection_name'};
    [G, keys] = findgroups(T(:, Gvars));

    out = keys;
    out.n_cycles = splitapply(@numel, T.cycle_number, G);
    out.mean_cycle_duration_s = splitapply(@(x) mean(x, 'omitnan'), T.cycle_duration_s, G);
    out.mean_stride_length_m = splitapply(@(x) mean(x, 'omitnan'), T.stride_length_m, G);
    out.mean_stride_speed_mps = splitapply(@(x) mean(x, 'omitnan'), T.stride_speed_mps, G);
    out.mean_step_duration_1_s = splitapply(@(x) mean(x, 'omitnan'), T.step_duration_1_s, G);
    out.mean_step_duration_2_s = splitapply(@(x) mean(x, 'omitnan'), T.step_duration_2_s, G);
    out.mean_step_length_m = splitapply(@(x) mean(x, 'omitnan'), T.mean_step_length_m, G);
end

function ageLookup = build_age_lookup(T)
    ageLookup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    if isempty(T) || height(T) == 0 || ~all(ismember({'subject','condition','leg','pair_name','age_group'}, T.Properties.VariableNames))
        return;
    end

    for i = 1:height(T)
        key = make_lookup_key(T.subject(i), T.condition(i), T.leg(i), T.pair_name(i));
        ageLookup(key) = char(string(T.age_group(i)));
    end
end

function ageGroup = lookup_age_group(ageLookup, subjID, cond, leg, pairName)
    key = make_lookup_key(subjID, cond, leg, pairName);
    if isKey(ageLookup, key)
        ageGroup = string(ageLookup(key));
    else
        ageGroup = "";
    end
end

function key = make_lookup_key(subjID, cond, leg, pairName)
    key = char(strjoin([string(subjID), string(cond), string(leg), string(pairName)], "|"));
end

function other = opposite_leg(leg)
    if strcmpi(leg, 'left')
        other = 'right';
    else
        other = 'left';
    end
end

function S = ensure_field(S, f, defaultVal)
    if ~isfield(S, f) || isempty(S.(f))
        S.(f) = defaultVal;
    end
end

function val = get_nested_or_default(S, path, defaultVal)
    val = defaultVal;
    cur = S;
    for i = 1:numel(path)
        f = path{i};
        if ~isstruct(cur) || ~isfield(cur, f)
            return;
        end
        cur = cur.(f);
    end
    if ~isempty(cur)
        val = cur;
    end
end
