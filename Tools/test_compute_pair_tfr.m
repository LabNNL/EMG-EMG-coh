function test_compute_pair_tfr()
% TEST_COMPUTE_PAIR_TFR  Checks of the stage-g transform scopes on synthetic data.
%
%   1. Identity: one trial, every cycle kept -> "per_trial" gives exactly the
%      same TFR as "concatenated" (same signal, same padding).
%   2. Glue artifact: two independent noise channels, each trial with its own
%      DC offset shared by both channels, one rejected cycle per trial.
%      "concatenated" sees a common step at every glue point, so 8-15 Hz
%      coherence is raised near the cycle edges; "per_trial" removes it.
%   3. Layout: every kept sample is filled and the periods are identical.
%
% Errors on failure, prints a short report otherwise.

    C  = config_emg();
    addpath(genpath(C.paths.helpers.coherence));
    addpath(genpath(C.paths.toolboxes.wtc));
    W  = C.g_coherence.params;
    fs = 2000;
    Args = WaveletParameters(8, 60, W.Resolution, W.WaveNumber, fs);
    rng(1);

    % ---------- 1. identity ----------
    P = make_pair(fs, 1, 6, [], 0);
    [x1, x2, Tseg] = glue(P);
    Wc = W; Wc.transform_scope = "concatenated";
    Wp = W; Wp.transform_scope = "per_trial"; Wp.per_trial.context_policy = "trial_run_safe";
    [A1, A2] = compute_pair_tfr(x1, x2, Tseg, P, Wc, Args);
    [B1, B2, ~, ~, ~, ~, ~, info] = compute_pair_tfr(x1, x2, Tseg, P, Wp, Args);
    d = max([abs(A1(:) - B1(:)); abs(A2(:) - B2(:))]);
    assert(d < 1e-12 && info.n_segments == 1 && ~info.fallback, 'identity test failed (max diff %g)', d);
    fprintf('identity: max |TFR diff| = %.1e over 1 segment\n', d);

    % ---------- 2. glue artifact ----------
    nTrials = 12;
    P = make_pair(fs, nTrials, 4, 2, 4);
    [x1, x2, Tseg] = glue(P);
    [T1, T2, ~, ~, perC] = compute_pair_tfr(x1, x2, Tseg, P, Wc, Args);
    for policy = ["kept_blocks", "trial_run_safe"]
        Wp.per_trial.context_policy = policy;
        [U1, U2, ~, ~, perP, ~, ~, info] = compute_pair_tfr(x1, x2, Tseg, P, Wp, Args);
        assert(isequal(perC, perP), 'periods differ');
        assert(all(isfinite(U1(:))) && all(isfinite(U2(:))), 'unfilled samples');
        [eC, mC] = edge_mid_coherence(T1, T2, Tseg, 1 ./ perC);
        [eP, mP] = edge_mid_coherence(U1, U2, Tseg, 1 ./ perP);
        fprintf('%-15s segments=%2d context=%d | edge-mid 8-15 Hz: concatenated %.3f, per_trial %.3f\n', ...
            policy, info.n_segments, info.n_context_cycles, eC - mC, eP - mP);
        assert(eC - mC > 0.05, 'glue artifact not visible under concatenated');
        assert(eP - mP < (eC - mC) / 3, 'per_trial did not remove the glue artifact');
    end
    fprintf('test_compute_pair_tfr: all checks passed\n');
end

function P = make_pair(fs, nTrials, nCyclesPerTrial, rejectCycle, offsetSd)
% Trials of nCyclesPerTrial cycles (~1 s each), back to back in the
% all-cycle signal like stage a builds it
    s = []; e = []; run = []; trial = strings(0, 1); x1 = []; x2 = [];
    for t = 1:nTrials
        off = offsetSd * randn;
        for c = 1:nCyclesPerTrial
            L = fs + randi(200) - 100;
            n0 = numel(x1);
            x1 = [x1; randn(L, 1) + off]; %#ok<AGROW>
            x2 = [x2; randn(L, 1) + off]; %#ok<AGROW>
            s(end+1, 1) = n0 + 1; e(end+1, 1) = n0 + L; %#ok<AGROW>
            run(end+1, 1) = t; trial(end+1, 1) = "T" + t; %#ok<AGROW>
        end
    end
    nC = numel(s);
    keep = true(nC, 1);
    if ~isempty(rejectCycle)
        keep(rejectCycle:nCyclesPerTrial:nC) = false;
    end
    P = struct('fs', fs, 'original_signal_1', x1, 'original_signal_2', x2, ...
        'cycle_starts', s, 'cycle_ends', e, 'pair_cycle_keep_mask', keep, ...
        'cycle_run_id', run, 'cycle_trial_id', trial, ...
        'general_keep_mask_muscle1', true(nC, 1), 'general_keep_mask_muscle2', true(nC, 1), ...
        'overall_contamination_half_width_sec', 0.3);
    P.muscle1_cycle_qc.bad_burst_overlap_segments = repmat({zeros(0, 2)}, nC, 1);
    P.muscle2_cycle_qc = P.muscle1_cycle_qc;
end

function [x1, x2, Tseg] = glue(P)
    [x1, x2, Tseg] = build_final_concatenated_pair(P.original_signal_1, P.original_signal_2, ...
        P.cycle_starts, P.cycle_ends, P.pair_cycle_keep_mask, P.cycle_run_id, P.cycle_trial_id);
end

function [edgeC, midC] = edge_mid_coherence(T1, T2, Tseg, Freq)
% Cycle-averaged coherence on a 100-point cycle grid, 8-15 Hz, first+last 20% vs middle
    nT = 100;
    rows = Freq >= 8 & Freq <= 15;
    S12 = 0; S11 = 0; S22 = 0;
    for r = 1:height(Tseg)
        i = Tseg.final_concat_start_idx_signal1(r):Tseg.final_concat_end_idx_signal1(r);
        g = round(linspace(i(1), i(end), nT));
        a = T1(rows, g); b = T2(rows, g);
        S12 = S12 + a .* conj(b); S11 = S11 + abs(a).^2; S22 = S22 + abs(b).^2;
    end
    Coh = abs(S12).^2 ./ (S11 .* S22);
    edge = [1:20, 81:100];
    edgeC = mean(Coh(:, edge), 'all');
    midC  = mean(Coh(:, 21:80), 'all');
end
