function [trial_id, run_id, note] = get_pair_cycle_run_ids(E1, E2, cycle_starts, cycle_ends, alignment_note)
% GET_PAIR_CYCLE_RUN_IDS  Which trial each pair cycle came from, and which
% cycles form one uninterrupted stretch of recording.
%
%   [trial_id, run_id, note] = get_pair_cycle_run_ids(E1, E2, cycle_starts, cycle_ends)
%   [...] = get_pair_cycle_run_ids(..., alignment_note)
%
% Stage a cuts every trial into heel-strike-to-heel-strike cycles and glues
% all of them, from all trials, into one signal. A "run" is a set of
% consecutive cycles that were also consecutive in the original recording,
% so there is no discontinuity between them. A new run starts whenever:
%   - the trial changes,
%   - stage a's original sample indices show a gap inside the trial, or
%   - the pair's cycles are not adjacent in the concatenation (cycles lost
%     while harmonising the two muscles).
%
% Stage g uses this to compute the wavelet transform over real, continuous
% recording instead of across the glue points.
%
% When the two muscles disagree about which trial a cycle came from, or the
% cycles were aligned by intersecting their start points, the run structure
% cannot be trusted. Then run_id is all NaN and note says why; stage g falls
% back to its old single-transform behaviour for that pair.

if nargin < 5
    alignment_note = "";
end

n = numel(cycle_starts);
trial_id = strings(n, 1);
run_id   = nan(n, 1);
note     = "";

need = {'cycle_starts', 'trial_id', 'orig_start', 'orig_end'};
if ~all(isfield(E1, need)) || ~all(isfield(E2, need))
    note = "missing_stage_a_cycle_fields";
    return
end

if contains(string(alignment_note), "intersection")
    note = "cycles_aligned_by_intersection";
    return
end

[ok1, k1] = ismember(cycle_starts(:), E1.cycle_starts(:));
[ok2, k2] = ismember(cycle_starts(:), E2.cycle_starts(:));
if ~all(ok1) || ~all(ok2)
    note = "pair_cycle_not_found_in_stage_a";
    return
end

t1 = string(E1.trial_id(k1));
t2 = string(E2.trial_id(k2));
if any(t1(:) ~= t2(:))
    note = "muscles_disagree_on_trial";
    return
end

o_start = double(E1.orig_start(k1));
o_end   = double(E1.orig_end(k1));

trial_id = t1(:);
run_id(1) = 1;
for k = 2:n
    same_trial = trial_id(k) == trial_id(k-1);
    % Within a trial, consecutive cycles share the heel-strike sample, so
    % the next start is at or one sample past the previous end.
    contiguous_in_trial = o_start(k) <= o_end(k-1) + 1;
    adjacent_in_concat  = cycle_starts(k) == cycle_ends(k-1) + 1;

    if same_trial && contiguous_in_trial && adjacent_in_concat
        run_id(k) = run_id(k-1);
    else
        run_id(k) = run_id(k-1) + 1;
    end
end
note = "ok";
end
