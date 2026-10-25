function y = normalize_cycle(x)

    x = x(:);
    x = x - mean(x, 'omitnan');
    s = std(x, 'omitnan');

    if ~isfinite(s) || s == 0
    else
        y = x ./ s;
    end
end