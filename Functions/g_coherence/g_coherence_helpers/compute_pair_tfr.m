function [TFR1, TFR2, coi1, coi2, period, padInfo1, padInfo2, info] = compute_pair_tfr(x1, x2, Tseg, P, W, Args)
% Wavelet transforms of the two signals of a pair, returned in the layout of
% the final concatenated signals (nFreq x numel(x1)), so that cycle k of Tseg
% sits at Tseg.final_concat_start/end_idx_signal*.
%
% W.transform_scope:
%   "concatenated" - one transform over the glued kept cycles (original behaviour)
%   "per_trial"    - one transform per stretch of continuous recording
%                    (build_transform_segments, W.per_trial.context_policy),
%                    each padded by symmetric extension to at least
%                    W.per_trial.min_pad_sec and at least one cycle length.
%                    Kept cycles are then copied into the concatenated layout.
% Falls back to "concatenated" for a pair without run ids (info.fallback).

    scope = "concatenated";
    if isfield(W, 'transform_scope') && ~isempty(W.transform_scope)
        scope = string(W.transform_scope);
    end

    info = struct('scope', scope, 'policy', "", 'fallback', false, 'note', "ok", ...
        'n_segments', 1, 'n_context_cycles', 0, 'n_context_dropped_for_bad_bursts', 0);

    if scope == "per_trial"
        [segs, sinfo] = build_transform_segments(P, W.per_trial.context_policy);
        info.policy = sinfo.policy;
        info.note = sinfo.note;
        if sinfo.fallback
            info.fallback = true;
            scope = "concatenated";
        end
    elseif scope ~= "concatenated"
        error('Unknown transform_scope: %s', scope);
    end

    if scope == "concatenated"
        [x1_for_wav, idx_orig_1, padInfo1] = build_padded_signal_for_wavelet(x1, Tseg, W.padding, 1);
        [x2_for_wav, idx_orig_2, padInfo2] = build_padded_signal_for_wavelet(x2, Tseg, W.padding, 2);

        [TFR1_pad, period, ~, coi1_pad] = wavelet( x1_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
        [TFR2_pad, ~, ~, coi2_pad] = wavelet( x2_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

        TFR1 = TFR1_pad(:, idx_orig_1);
        TFR2 = TFR2_pad(:, idx_orig_2);
        coi1 = coi1_pad(idx_orig_1);
        coi2 = coi2_pad(idx_orig_2);
        return;
    end

    % ---------- per_trial ----------
    minPad = round(W.per_trial.min_pad_sec * P.fs);
    n1 = numel(x1);
    n2 = numel(x2);
    TFR1 = []; TFR2 = [];
    coi1 = nan(1, n1); coi2 = nan(1, n2);
    filled1 = false(1, n1); filled2 = false(1, n2);
    period = [];
    nPadPre = zeros(numel(segs), 1); nPadPost = zeros(numel(segs), 1);

    for k = 1:numel(segs)
        S = segs(k);
        nPre  = max(minPad, P.cycle_ends(S.cycles(1))   - P.cycle_starts(S.cycles(1))   + 1);
        nPost = max(minPad, P.cycle_ends(S.cycles(end)) - P.cycle_starts(S.cycles(end)) + 1);
        nPadPre(k) = nPre; nPadPost(k) = nPost;

        y1 = symmetric_extend(P.original_signal_1(S.s:S.e), nPre, nPost);
        y2 = symmetric_extend(P.original_signal_2(S.s:S.e), nPre, nPost);

        [W1, per_k, ~, c1] = wavelet( y1, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
        [W2, ~, ~, c2]     = wavelet( y2, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

        if isempty(period)
            period = per_k;
            TFR1 = complex(nan(numel(period), n1));
            TFR2 = complex(nan(numel(period), n2));
        elseif ~isequal(per_k, period)
            error('compute_pair_tfr: wavelet periods differ between segments.');
        end

        for c = S.kept_cycles(:)'
            row = find(Tseg.cycle_number == c, 1);
            if isempty(row)
                error('compute_pair_tfr: kept cycle %d not in Tseg.', c);
            end
            src = (P.cycle_starts(c):P.cycle_ends(c)) - S.s + 1 + nPre;
            d1 = Tseg.final_concat_start_idx_signal1(row):Tseg.final_concat_end_idx_signal1(row);
            d2 = Tseg.final_concat_start_idx_signal2(row):Tseg.final_concat_end_idx_signal2(row);

            TFR1(:, d1) = W1(:, src);  coi1(d1) = c1(src);  filled1(d1) = true; %#ok<AGROW>
            TFR2(:, d2) = W2(:, src);  coi2(d2) = c2(src);  filled2(d2) = true; %#ok<AGROW>
        end
    end

    if ~all(filled1) || ~all(filled2)
        error('compute_pair_tfr: %d / %d samples not covered by any segment.', sum(~filled1) + sum(~filled2), n1 + n2);
    end

    padInfo1 = struct('mode', "per_trial_symmetric", 'n_segments', numel(segs), ...
        'n_pre_samples', nPadPre, 'n_post_samples', nPadPost, ...
        'segment_start_idx', [segs.s]', 'segment_end_idx', [segs.e]');
    padInfo2 = padInfo1;

    info.n_segments = numel(segs);
    info.n_context_cycles = sinfo.n_context_cycles;
    info.n_context_dropped_for_bad_bursts = sinfo.n_context_dropped_for_bad_bursts;
end

function y = symmetric_extend(x, nPre, nPost)
% Half-sample symmetric extension (same as flipud padding in
% build_padded_signal_for_wavelet), repeated when the pad exceeds numel(x).
    x = x(:);
    n = numel(x);
    p = (1:nPre)';
    m = mod(p - 1, 2*n);
    iPre = m + 1;  iPre(m >= n) = 2*n - m(m >= n);
    p = (1:nPost)';
    m = mod(p - 1, 2*n);
    iPost = m + 1;  iPost(m >= n) = 2*n - m(m >= n);
    y = [x(flipud(iPre)); x; x(n + 1 - iPost)];
end
