function tag = make_h_stats_analysis_tag(HC)

    src = "unknownsource";
    scope = "unknownscope";
    metricTxt = "unknownmetric";

    if isfield(HC.analysis, 'coherence_source')
        src = lower(string(HC.analysis.coherence_source));
    end

    if isfield(HC.analysis, 'metric_scope')
        scope = lower(string(HC.analysis.metric_scope));
    end

    if isfield(HC.analysis, 'scalar_metric_families')
        metricFamilies = lower(string(HC.analysis.scalar_metric_families));
        metricTxt = strjoin(metricFamilies, "-");
    elseif isfield(HC.analysis, 'scalar_metric_family')
        metricTxt = lower(string(HC.analysis.scalar_metric_family));
    end

    includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    if includeCycleCov
        cycleTxt = "cyclecov";
    else
        cycleTxt = "nocyclecov";
    end

    tag = sprintf('%s_%s_%s_%s', src, scope, metricTxt, cycleTxt);
    tag = regexprep(tag, '[^a-zA-Z0-9_]', '_');
end
