function bursts = get_bursts_idx_from_qc_or_entry(Q, E)
    if isfield(Q, 'bursts_idx') && ~isempty(Q.bursts_idx)
        bursts = round(Q.bursts_idx);
    elseif isfield(E, 'bursts_idx') && ~isempty(E.bursts_idx)
        bursts = round(E.bursts_idx);
    else
        bursts = zeros(0,2);
    end
end