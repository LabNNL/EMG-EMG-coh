function txt = get_metric_scope_label(metricScope)
    switch lower(string(metricScope))
        case "poi"
            txt = 'in POI';
        case "full"
            txt = '(full cycle)';
        case "stance"
            txt = '(stance)';
        case "swing"
            txt = '(swing)';
        otherwise
            txt = '';
    end
end
