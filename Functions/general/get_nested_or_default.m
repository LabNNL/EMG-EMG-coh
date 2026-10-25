function val = get_nested_or_default(S, path, defaultVal)
    val = defaultVal;
    cur = S;
    for i = 1:numel(path)
        f = path{i};
        if ~isstruct(cur) || ~isfield(cur, f)
            return;
        end
        cur = cur.(f);
    end
    if ~isempty(cur)
        val = cur;
    end
end
