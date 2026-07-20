function txt = format_p_text(label, p)
    if isnan(p)
        txt = sprintf('%s = NA', label);
    else
        txt = sprintf('%s = %.3g', label, p);
    end
end