function add_sig_bars_grouped_boxes(ax, statsStruct, groupLevels, subLevels, offsets, yBase, yStep, HC)

    if isempty(statsStruct)
        return;
    end

    yl = ylim(ax);

    useFixedY = nargin >= 8 && isfield(HC, 'plot') && isfield(HC.plot, 'use_fixed_coherence_ylim') && HC.plot.use_fixed_coherence_ylim && isfield(HC.plot, 'coherence_ylim') && numel(HC.plot.coherence_ylim) == 2;

    if useFixedY
        yl = HC.plot.coherence_ylim;
        ylim(ax, yl);
    end

    yr = yl(2) - yl(1);

    if nargin < 6 || isempty(yBase)
        if useFixedY
            yBase = yl(2) - 0.30 * yr;
        else
            yBase = yl(1) + 0.82 * yr;
        end
    end

    if nargin < 7 || isempty(yStep)
        yStep = 0.055 * yr;
    end

    maxUsedY = yl(2);

    for ig = 1:numel(groupLevels)
        groupName = groupLevels{ig};

        if ~isfield(statsStruct, 'group')
            continue;
        end

        statsThis = statsStruct(strcmp({statsStruct.group}, groupName));
        if isempty(statsThis)
            continue;
        end

        localCount = 0;

        for i = 1:numel(statsThis)
            p = statsThis(i).p;

            if isnan(p) || p >= 0.05
                continue;
            end

            s1 = find(strcmp(subLevels, char(statsThis(i).g1)), 1, 'first');
            s2 = find(strcmp(subLevels, char(statsThis(i).g2)), 1, 'first');

            if isempty(s1) || isempty(s2)
                continue;
            end

            xCenter = ig;
            x1 = xCenter + offsets(s1);
            x2 = xCenter + offsets(s2);

            localCount = localCount + 1;

            if useFixedY
                y = yBase - (localCount-1)*yStep;
            else
                y = yBase + (localCount-1)*yStep;
            end

            tickH = 0.15 * yStep;

            h = plot(ax, [x1 x1 x2 x2], [y y+tickH y+tickH y], 'k-', 'LineWidth', 1.1);
            set(get(get(h, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');

            text(ax, mean([x1 x2]), y+tickH+0.001*yr, p_to_stars(p), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10, 'FontWeight', 'bold', 'Clipping', 'on');

            maxUsedY = max(maxUsedY, y + tickH + yStep);
        end
    end

    if useFixedY
        ylim(ax, yl);
    else
        ylim(ax, [yl(1), max(yl(2), maxUsedY + yStep)]);
    end
end