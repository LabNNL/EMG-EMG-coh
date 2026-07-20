function v = getfield_or_nan(M, field)
if isfield(M, field), v = M.(field); else, v = NaN; end
end
