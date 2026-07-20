function mask_eq = select_equalized_cycle_mask(analysis_cycle_mask, N_common, EQ, subjID, cond, leg, pairName)

    mask_eq = false(size(analysis_cycle_mask));

    idx = find(analysis_cycle_mask);
    nAvail = numel(idx);

    if isempty(idx)
        return;
    end

    if isnan(N_common) || N_common <= 0
        error('Invalid N_common for cycle equalization.');
    end

    if nAvail < N_common
        warning('Available cycles (%d) < N_common (%d) for %s | %s | %s | %s. Skipping equalized metrics.', ...
            nAvail, N_common, subjID, cond, leg, pairName);
        return;
    end

    N_common = min(N_common, nAvail);

    selection = "evenly_spaced";
    if isfield(EQ, 'selection') && ~isempty(EQ.selection)
        selection = lower(string(EQ.selection));
    end

    switch selection

        case "evenly_spaced"
            % Deterministic and spread across the retained cycles.
            pos = round(linspace(1, nAvail, N_common));
            pos = unique(pos, 'stable');

            % Safety if rounding caused duplicates.
            if numel(pos) < N_common
                missing = setdiff(1:nAvail, pos, 'stable');
                pos = [pos(:); missing(1:(N_common-numel(pos)))'];
                pos = sort(pos);
            end

            selected_idx = idx(pos);

        case "first"
            selected_idx = idx(1:N_common);

        case "last"
            selected_idx = idx(end-N_common+1:end);

        case "random_once"
            if isfield(EQ, 'random_seed') && ~isempty(EQ.random_seed)
                seedVal = double(EQ.random_seed) + double(sum(char(string(subjID)))) + ...
                    double(sum(char(string(cond)))) + double(sum(char(string(leg)))) + ...
                    double(sum(char(string(pairName))));
                rng(seedVal);
            end

            pos = randperm(nAvail, N_common);
            pos = sort(pos);
            selected_idx = idx(pos);

        otherwise
            error('Unknown cycle_equalization.selection: %s', selection);
    end

    mask_eq(selected_idx) = true;
end
