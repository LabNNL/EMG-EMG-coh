function [T, useCycleCov, cycleCovSource] = add_log_cycle_covariate_for_dv(T, dv, requested)

    useCycleCov = false;
    cycleCovSource = "";

    if ~requested
        return;
    end

    bandName = infer_band_from_metric_name(dv);

    meanField = sprintf('%s_mean_cycles_used_for_metric_across_legs', bandName);
    rowField  = sprintf('%s_n_cycles_used_for_metric', bandName);
    logField  = sprintf('%s_log_n_cycles', bandName);

    if ismember(logField, T.Properties.VariableNames)
        T.log_n_cycles = T.(logField);
        cycleCovSource = string(logField);

    elseif ismember(meanField, T.Properties.VariableNames)
        T.log_n_cycles = log_safe(T.(meanField));
        cycleCovSource = string(meanField);

    elseif ismember(rowField, T.Properties.VariableNames)
        T.log_n_cycles = log_safe(T.(rowField));
        cycleCovSource = string(rowField);

    else
        warning('Cycle-count covariate requested for %s, but no cycle-count field found.', string(dv));
        return;
    end

    valid = isfinite(T.log_n_cycles);

    if sum(valid) < 5
        fprintf('Skipping cycle covariate for %s: fewer than 5 valid log_n_cycles values.\n', string(dv));
        return;
    end

    if std(T.log_n_cycles(valid), 'omitnan') < 1e-10
        fprintf('Skipping cycle covariate for %s: log_n_cycles is constant for this model.\n', string(dv));
        return;
    end

    useCycleCov = true;
end