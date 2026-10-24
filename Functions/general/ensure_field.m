function S = ensure_field(S, f, defaultVal)
    if ~isfield(S, f) || isempty(S.(f))
        S.(f) = defaultVal;
    end
end
