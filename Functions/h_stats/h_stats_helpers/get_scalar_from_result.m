function val = get_scalar_from_result(R, vname, metricScope, coherenceSource)
% Scalar coherence metric vname of result R, NaN when absent

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

        % vname = <Band>[_AUC_norm | _AUC_raw | _Peak], e.g. HighBeta_AUC_norm
        vname = string(vname);
        band = extractBefore(vname + "_", "_");
        switch extractAfter(vname, strlength(band))
            case ""
                type = 'mean';
            case "_AUC_norm"
                type = 'auc_norm';
            case "_AUC_raw"
                type = 'auc_raw';
            case "_Peak"
                type = 'peak';
            otherwise
                return;
        end

        if isfield(M, type) && isfield(M.(type), band)
            val = M.(type).(band);
        end

    catch
        val = NaN;
    end
end