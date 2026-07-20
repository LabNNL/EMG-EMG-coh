function yTopCommon = get_common_spectrum_ymax(axList, HS, HC)
%GET_COMMON_SPECTRUM_YMAX Return one shared y-axis upper limit for spectrum subplot figures.

    if isfield(HS, 'use_fixed_ylim') && HS.use_fixed_ylim && isfield(HS, 'fixed_ylim') && numel(HS.fixed_ylim) == 2

        yTopCommon = HS.fixed_ylim(2);
        return;
    end

    if isfield(HC, 'plot') && isfield(HC.plot, 'use_fixed_coherence_ylim') && HC.plot.use_fixed_coherence_ylim && isfield(HC.plot, 'coherence_ylim') && numel(HC.plot.coherence_ylim) == 2

        yTopCommon = HC.plot.coherence_ylim(2);
        return;
    end

    yTopCommon = 0;

    for i = 1:numel(axList)

        ax = axList(i);

        if ~isgraphics(ax, 'axes')
            continue;
        end

        yl = ylim(ax);

        if isfinite(yl(2))
            yTopCommon = max(yTopCommon, yl(2));
        end
    end

    if ~isfinite(yTopCommon) || yTopCommon <= 0
        yTopCommon = 0.1;
    end

    % modest headroom for bars/stars
    yTopCommon = yTopCommon * 1.05;
end