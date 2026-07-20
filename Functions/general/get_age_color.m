function c = get_age_color(ageName, C)
    if isfield(C.plotting.colors, char(string(ageName)))
        c = C.plotting.colors.(char(string(ageName)));
    else
        c = [0.4 0.4 0.4];
    end
end

