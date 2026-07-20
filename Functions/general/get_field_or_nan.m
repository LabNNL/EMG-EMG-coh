function val = get_field_or_nan(S, fieldName)
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        val = S.(fieldName);
    else
        val = NaN;
    end
end