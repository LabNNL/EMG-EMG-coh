function reason = get_final_reason(Q, nB)
    if isfield(Q,'final_reason') && ~isempty(Q.final_reason)
        reason = string(Q.final_reason(:));
    else
        reason = repmat("", nB, 1);
    end
    if numel(reason) ~= nB
        error('final_reason length mismatch with bursts_idx.');
    end
end