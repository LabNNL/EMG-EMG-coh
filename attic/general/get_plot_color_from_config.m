function col = get_plot_color_from_config(C, name, fallback)
    col = fallback;
    if isfield(C, 'plotting') && isfield(C.plotting, 'colors')
        if isfield(C.plotting.colors, char(string(name)))
            col = C.plotting.colors.(char(string(name)));
        end
    end
end