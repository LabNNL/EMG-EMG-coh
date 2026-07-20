function c = get_condition_color(condName, C)
    if isfield(C.plotting.colors, char(string(condName)))
        c = C.plotting.colors.(char(string(condName)));
    else
        c = [0.4 0.4 0.4];
    end
end