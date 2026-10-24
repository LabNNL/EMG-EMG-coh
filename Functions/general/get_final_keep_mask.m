function keep = get_final_keep_mask(Q, nB)
    if isfield(Q,'final_keep_mask') && ~isempty(Q.final_keep_mask)
        keep = logical(Q.final_keep_mask(:));
    else
        keep = true(nB,1);
    end
    if numel(keep) ~= nB
        error('final_keep_mask length mismatch with bursts_idx.');
    end
end