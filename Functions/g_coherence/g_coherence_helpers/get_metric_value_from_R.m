function val = get_metric_value_from_R(R, source, scope, metricName, bandName)
% GET_METRIC_VALUE_FROM_R  One scalar metric out of R.Metrics, or NaN.
%
% Its own file so that build_group_plot_struct, now also its own file, can
% still reach it.


    val = NaN;

    try
        source = lower(string(source));
        scope = lower(string(scope));
        metricName = char(string(metricName));
        bandName = char(string(bandName));

        if ~isfield(R, 'Metrics') || ~isfield(R.Metrics, source)
            return;
        end

        Msource = R.Metrics.(source);

        if ~isfield(Msource, scope)
            return;
        end

        Mscope = Msource.(scope);

        if ~isfield(Mscope, metricName)
            return;
        end

        X = Mscope.(metricName);

        if isstruct(X)
            if ~isempty(bandName) && isfield(X, bandName)
                val = X.(bandName);
            end
        else
            val = X;
        end

    catch
        val = NaN;
    end
end
