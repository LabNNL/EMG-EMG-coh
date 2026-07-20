function val = get_scalar_from_result(R, vname, metricScope, coherenceSource)

    val = NaN;

    try
        metricScope = lower(char(string(metricScope)));
        coherenceSource = lower(char(string(coherenceSource)));

        if ~isfield(R, 'Metrics')
            return;
        end
        if ~isfield(R.Metrics, coherenceSource)
            return;
        end
        if ~isfield(R.Metrics.(coherenceSource), metricScope)
            return;
        end

        M = R.Metrics.(coherenceSource).(metricScope);

        switch char(string(vname))

            case 'Alpha'
                val = M.mean.Alpha;
            case 'Beta'
                val = M.mean.Beta;
            case 'Gamma'
                val = M.mean.Gamma;

            case 'Alpha_AUC_norm'
                val = M.auc_norm.Alpha;
            case 'Beta_AUC_norm'
                val = M.auc_norm.Beta;
            case 'Gamma_AUC_norm'
                val = M.auc_norm.Gamma;

            case 'Alpha_AUC_raw'
                val = M.auc_raw.Alpha;
            case 'Beta_AUC_raw'
                val = M.auc_raw.Beta;
            case 'Gamma_AUC_raw'
                val = M.auc_raw.Gamma;

            case 'Alpha_Peak'
                val = M.peak.Alpha;
            case 'Beta_Peak'
                val = M.peak.Beta;
            case 'Gamma_Peak'
                val = M.peak.Gamma;
        end

    catch
        val = NaN;
    end
end