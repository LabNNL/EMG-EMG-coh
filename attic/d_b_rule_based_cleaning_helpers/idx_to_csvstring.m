function s = idx_to_csvstring(idx)
% Convert numeric indices into "3,7,8,12" (or "" if empty)
if isempty(idx)
    s = "";
    return;
end
idx = idx(:)';
s = strjoin(string(idx), ",");
end