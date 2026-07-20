function txt = p_to_stars_with_p(p)

    if ~isfinite(p)
        txt = 'n/a';
        return;
    end

    if p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = 'ns';
    end

    txt = sprintf('%s (p=%.3g)', stars, p);
end