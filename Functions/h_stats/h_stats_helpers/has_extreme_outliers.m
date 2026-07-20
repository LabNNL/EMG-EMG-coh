function tf = has_extreme_outliers(x, zThresh)

    tf = false;
    x = x(~isnan(x));

    if numel(x) < 3
        return;
    end

    medx = median(x, 'omitnan');
    madx = mad(x, 1);

    if madx == 0 || isnan(madx)
        return;
    end

    robustZ = 0.6745 * (x - medx) / madx;
    tf = any(abs(robustZ) > zThresh);
end