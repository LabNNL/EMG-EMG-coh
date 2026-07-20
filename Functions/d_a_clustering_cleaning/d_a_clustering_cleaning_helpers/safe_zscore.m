function z = safe_zscore(x)
    x = x(:);
    mu = mean(x, 'omitnan');
    sd = std(x, 'omitnan');
    if isempty(sd) || isnan(sd) || sd == 0
        z = zeros(size(x));
    else
        z = (x - mu) ./ sd;
    end
end