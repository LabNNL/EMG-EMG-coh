function [segs, info] = build_transform_segments(P, policy)
% Groups the pair's cycles into stretches of continuous recording that are
% wavelet-transformed separately (transform_scope = "per_trial").
%
% A segment never crosses a trial boundary or a gap in the recording
% (P.cycle_run_id from stage f). Which rejected cycles may stay in as real
% context around the kept ones depends on policy:
%   "kept_blocks"    - none; every run of consecutive kept cycles is its own segment
%   "trial_run"      - all of them (audit only: may leak artifacts of rejected cycles)
%   "trial_run_safe" - only rejected cycles that pass the general QC in both
%                      muscles and whose bad bursts are farther than
%                      P.overall_contamination_half_width_sec from any kept sample
% Leading/trailing context is limited to one cycle on each side.
%
% segs(k): .s, .e (indices into P.original_signal_*), .cycles (all cycle
% numbers in the segment), .kept_cycles, .n_context
% info.fallback is true when run ids are missing (caller uses "concatenated").

    policy = string(policy);
    nC   = numel(P.cycle_starts);
    keep = logical(P.pair_cycle_keep_mask(:));
    segs = struct('s', {}, 'e', {}, 'cycles', {}, 'kept_cycles', {}, 'n_context', {});

    info = struct('policy', policy, 'fallback', false, 'note', "ok", ...
        'n_segments', 0, 'n_context_cycles', 0, 'n_context_dropped_for_bad_bursts', 0);

    if ~isfield(P, 'cycle_run_id') || numel(P.cycle_run_id) ~= nC || any(isnan(P.cycle_run_id(keep)))
        info.fallback = true;
        info.note = "missing_run_ids";
        if isfield(P, 'cycle_run_note'), info.note = "missing_run_ids:" + string(P.cycle_run_note); end
        return;
    end
    run = P.cycle_run_id(:);

    switch policy
        case "kept_blocks"
            use = keep;
        case "trial_run"
            use = ~isnan(run);
        case "trial_run_safe"
            gk1 = P.general_keep_mask_muscle1(:);
            gk2 = P.general_keep_mask_muscle2(:);
            if numel(gk1) ~= nC || numel(gk2) ~= nC
                use = keep;
                info.note = "general_keep_mask_size_mismatch_used_kept_blocks";
            else
                use = keep | (gk1 & gk2 & ~isnan(run));
            end
        otherwise
            error('Unknown per_trial context_policy: %s', policy);
    end

    % Drop context cycles whose bad bursts are within reach of a kept sample
    if policy == "trial_run_safe"
        halfN = round(P.overall_contamination_half_width_sec * P.fs);
        changed = true;
        while changed
            changed = false;
            G = group_cycles(use, run);
            for g = 1:numel(G)
                cyc = G{g};
                ctx = cyc(~keep(cyc));
                if isempty(ctx) || ~any(keep(cyc)), continue; end
                s0 = P.cycle_starts(cyc(1));
                keptIdx = [];
                for c = cyc(keep(cyc))'
                    keptIdx = [keptIdx, (P.cycle_starts(c):P.cycle_ends(c)) - s0 + 1]; %#ok<AGROW>
                end
                for c = ctx'
                    bad = cycle_bad_samples(P, c) - s0 + 1;
                    if ~isempty(bad) && min(abs(bad(:) - keptIdx(:)'), [], 'all') <= halfN
                        use(c) = false;
                        changed = true;
                        info.n_context_dropped_for_bad_bursts = info.n_context_dropped_for_bad_bursts + 1;
                    end
                end
            end
        end
    end

    G = group_cycles(use, run);
    for g = 1:numel(G)
        cyc = G{g};
        k = find(keep(cyc));
        if isempty(k), continue; end
        cyc = cyc(max(1, k(1)-1):min(numel(cyc), k(end)+1));   % at most one context cycle outside the kept ones

        seg.s = P.cycle_starts(cyc(1));
        seg.e = P.cycle_ends(cyc(end));
        seg.cycles = cyc(:);
        seg.kept_cycles = cyc(keep(cyc));
        seg.n_context = sum(~keep(cyc));
        segs(end+1) = seg; %#ok<AGROW>
    end

    info.n_segments = numel(segs);
    info.n_context_cycles = sum([segs.n_context]);
end

function G = group_cycles(use, run)
% Consecutive used cycles belonging to the same run
    G = {};
    cur = [];
    for c = 1:numel(use)
        if use(c) && ~isempty(cur) && run(c) == run(cur(end)) && c == cur(end) + 1
            cur(end+1) = c; %#ok<AGROW>
        else
            if ~isempty(cur), G{end+1} = cur(:); end %#ok<AGROW>
            cur = [];
            if use(c), cur = c; end
        end
    end
    if ~isempty(cur), G{end+1} = cur(:); end
end

function idx = cycle_bad_samples(P, c)
% Bad-burst samples of cycle c (both muscles), in original-signal coordinates
    idx = [];
    for q = {P.muscle1_cycle_qc, P.muscle2_cycle_qc}
        Q = q{1};
        if ~isfield(Q, 'bad_burst_overlap_segments') || numel(Q.bad_burst_overlap_segments) < c
            continue;
        end
        S = Q.bad_burst_overlap_segments{c};
        for r = 1:size(S, 1)
            idx = [idx, (S(r,1):S(r,2)) + P.cycle_starts(c) - 1]; %#ok<AGROW>
        end
    end
end
