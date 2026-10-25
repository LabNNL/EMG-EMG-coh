function [cycle_starts, cycle_ends, source_field] = get_cycle_boundaries(E, startCandidates, endCandidates)
    cycle_starts = [];
    cycle_ends   = [];
    source_field = "";

    % starts
    for i = 1:numel(startCandidates)
        fn = startCandidates{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            cycle_starts = E.(fn)(:);
            source_field = string(fn);
            break;
        end
    end

    if isempty(cycle_starts)
        return;
    end

    cycle_starts = round(cycle_starts(:));
    cycle_starts = cycle_starts(~isnan(cycle_starts));
    cycle_starts = unique(cycle_starts, 'stable');

    % explicit ends if available
    for i = 1:numel(endCandidates)
        fn = endCandidates{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            cycle_ends = round(E.(fn)(:));
            cycle_ends = cycle_ends(~isnan(cycle_ends));
            break;
        end
    end

    % if not available, infer ends from successive starts
    if isempty(cycle_ends)
        if numel(cycle_starts) >= 2
            cycle_ends = [cycle_starts(2:end)-1; NaN];
        else
            cycle_ends = NaN(size(cycle_starts));
        end
    end
end
