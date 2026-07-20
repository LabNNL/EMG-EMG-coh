function add_sig_bars(ax, statsStruct, groupOrder, yBase, yStep, HC)

    if isempty(statsStruct)
        return;
    end

    yl = ylim(ax);

    useFixedY = nargin >= 6 && isfield(HC, 'plot') && isfield(HC.plot, 'use_fixed_coherence_ylim') && HC.plot.use_fixed_coherence_ylim && isfield(HC.plot, 'coherence_ylim') && numel(HC.plot.coherence_ylim) == 2;
    % fprintf('Using fixed Y for sig bars: %d\n', useFixedY);

    if useFixedY
        yl = HC.plot.coherence_ylim;
        ylim(ax, yl);
    end

    yr = yl(2) - yl(1);

    if nargin < 4 || isempty(yBase)
        if useFixedY
            yBase = yl(2) - 0.15 * yr;
        else
            yBase = yl(1) + 0.88 * yr;
        end
    end

    if nargin < 5 || isempty(yStep)
        yStep = 0.055 * yr;
    end

    drawnCount = 0;
    maxUsedY = yl(2);

    for i = 1:numel(statsStruct)
        p = statsStruct(i).p;

        if isnan(p) || p >= 0.05
            continue;
        end

        x1 = find(strcmp(groupOrder, char(statsStruct(i).g1)), 1, 'first');
        x2 = find(strcmp(groupOrder, char(statsStruct(i).g2)), 1, 'first');

        if isempty(x1) || isempty(x2)
            continue;
        end

        drawnCount = drawnCount + 1;

        if useFixedY
            y = yBase - (drawnCount-1)*yStep;
        else
            y = yBase + (drawnCount-1)*yStep;
        end

        tickH = 0.15 * yStep;

        h = plot(ax, [x1 x1 x2 x2], [y y+tickH y+tickH y], 'k-', 'LineWidth', 1.2);
        set(get(get(h, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');

        text(ax, mean([x1 x2]), y+tickH+0.001*yr, p_to_stars(p), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 11, 'FontWeight', 'bold', 'Clipping', 'on');

        maxUsedY = max(maxUsedY, y + tickH + yStep);
    end

    if useFixedY
        ylim(ax, yl);
    elseif drawnCount > 0
        ylim(ax, [yl(1), max(yl(2), maxUsedY)]);
    end
end