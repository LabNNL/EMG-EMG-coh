function apply_correlation_ylim(ax, HC, dv)

    if ~isfield(HC, 'plot')
        return;
    end

    if ~isfield(HC.plot, 'correlation_use_fixed_ylim') || ~HC.plot.correlation_use_fixed_ylim
        return;
    end

    yLimToUse = [];

    % Global y-limit
    if isempty(yLimToUse) && isfield(HC.plot, 'correlation_ylim')
        yLimToUse = HC.plot.correlation_ylim;
    end

    if isempty(yLimToUse) || numel(yLimToUse) ~= 2 || any(~isfinite(yLimToUse))
        warning('Invalid HC.plot.correlation_ylim for %s. Skipping fixed ylim.', string(dv));
        return;
    end

    ylim(ax, yLimToUse);
end