function statsStruct = apply_pairwise_p_correction(statsStruct, method)

    if isempty(statsStruct)
        return;
    end

    p = [statsStruct.p];

    switch lower(method)
        case 'holm'
            p_adj = holm_adjust_pvalues(p);
        case 'fdr'
            p_adj = fdr_bh_adjust_pvalues(p);
        otherwise
            error('Unknown correction method: %s', method);
    end

    for i = 1:numel(statsStruct)
        statsStruct(i).p_raw = statsStruct(i).p;
        statsStruct(i).p = p_adj(i);
    end
end

function p_adj = holm_adjust_pvalues(p)

    p_adj = p;
    valid = ~isnan(p);
    pv = p(valid);

    if isempty(pv)
        return;
    end

    [pv_sorted, sortIdx] = sort(pv(:));
    m = numel(pv_sorted);

    adj_sorted = zeros(size(pv_sorted));
    for i = 1:m
        adj_sorted(i) = (m - i + 1) * pv_sorted(i);
    end

    for i = 2:m
        adj_sorted(i) = max(adj_sorted(i), adj_sorted(i-1));
    end

    adj_sorted(adj_sorted > 1) = 1;

    adj = zeros(size(pv_sorted));
    adj(sortIdx) = adj_sorted;

    p_adj(valid) = adj;
end

function p_adj = fdr_bh_adjust_pvalues(p)

    p_adj = p;
    valid = ~isnan(p);
    pv = p(valid);

    if isempty(pv)
        return;
    end

    [pv_sorted, sortIdx] = sort(pv(:));
    m = numel(pv_sorted);

    adj_sorted = zeros(size(pv_sorted));
    for i = 1:m
        adj_sorted(i) = pv_sorted(i) * m / i;
    end

    for i = m-1:-1:1
        adj_sorted(i) = min(adj_sorted(i), adj_sorted(i+1));
    end

    adj_sorted(adj_sorted > 1) = 1;

    adj = zeros(size(pv_sorted));
    adj(sortIdx) = adj_sorted;

    p_adj(valid) = adj;
end