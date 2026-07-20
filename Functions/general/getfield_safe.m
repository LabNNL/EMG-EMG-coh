function v = getfield_safe(S, fieldName, defaultValue)
    if  isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        v = S.(fieldName);
    else
        v = defaultValue;
    end
end