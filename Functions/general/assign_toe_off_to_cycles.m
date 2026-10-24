function toeInfo = assign_toe_off_to_cycles(cycle_starts, cycle_ends, toe_off_idx)
    nCycles = numel(cycle_starts);

    toeInfo = struct();
    toeInfo.has_toe_off = false(nCycles,1);
    toeInfo.toe_off_original_idx = nan(nCycles,1);
    toeInfo.toe_off_relative_idx = nan(nCycles,1);
    toeInfo.toe_off_relative_fraction = nan(nCycles,1);
    toeInfo.n_toe_off_in_cycle = zeros(nCycles,1);
    toeInfo.toe_off_all_in_cycle = cell(nCycles,1);

    for iC = 1:nCycles
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);

        idx = toe_off_idx(toe_off_idx >= c1 & toe_off_idx <= c2);

        toeInfo.n_toe_off_in_cycle(iC) = numel(idx);
        toeInfo.toe_off_all_in_cycle{iC} = idx;

        if ~isempty(idx)
            % keep the first one by default
            toeInfo.has_toe_off(iC) = true;
            toeInfo.toe_off_original_idx(iC) = idx(1);
            toeInfo.toe_off_relative_idx(iC) = idx(1) - c1 + 1;
            toeInfo.toe_off_relative_fraction(iC) = (idx(1) - c1 + 1) / (c2 - c1 + 1);
        end
    end
end