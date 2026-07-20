function [analysis_cycle_mask, mask_real_outer, mask_analysis_outer, mask_analysis_middle] = ...
    build_analysis_cycle_masks(Tseg, W, subjID, cond, leg, pairName)

    nCyclesTotal = height(Tseg);
    analysis_cycle_mask = true(nCyclesTotal,1);

    if W.exclude_edge_cycles_after_wavelet
        nExcl = W.n_edge_cycles_excluded_each_side;

        if nCyclesTotal <= 2*nExcl
            warning('Not enough cycles to exclude %d edge cycles on each side for %s | %s | %s | %s', ...
                nExcl, subjID, cond, leg, pairName);
            analysis_cycle_mask = [];
            mask_real_outer = [];
            mask_analysis_outer = [];
            mask_analysis_middle = [];
            return;
        end

        analysis_cycle_mask(1:nExcl) = false;
        analysis_cycle_mask(end-nExcl+1:end) = false;
    end

    mask_real_outer = false(nCyclesTotal,1);
    if nCyclesTotal >= 1
        mask_real_outer(1) = true;
        mask_real_outer(end) = true;
    end

    analysis_idx = find(analysis_cycle_mask);

    mask_analysis_outer = false(nCyclesTotal,1);
    if ~isempty(analysis_idx)
        mask_analysis_outer(analysis_idx(1)) = true;
        mask_analysis_outer(analysis_idx(end)) = true;
    end

    mask_analysis_middle = analysis_cycle_mask & ~mask_analysis_outer;
end