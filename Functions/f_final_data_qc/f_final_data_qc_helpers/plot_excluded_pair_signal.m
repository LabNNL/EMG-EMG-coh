function plot_excluded_pair_signal(P, subjID, cond, leg, pairName, outDir, C)

    x1 = P.original_signal_1(:);
    x2 = P.original_signal_2(:);
    fs = P.fs;

    cyc1 = P.muscle1_cycle_qc;
    cyc2 = P.muscle2_cycle_qc;

    cycle_starts = P.cycle_starts(:);
    cycle_ends   = P.cycle_ends(:);

    t1 = (0:numel(x1)-1)/fs;
    t2 = (0:numel(x2)-1)/fs;

    fig = figure('Visible','off','Color','w','Position',[100 100 1700 950], ...
             'Toolbar','none','MenuBar','none');

    tl = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    mus1 = P.muscles{1};
    mus2 = P.muscles{2};

    % ---------- Colors from config ----------
    colKeep = C.plotting.colors.include;
    colBad  = C.plotting.colors.exclude;

    cycleLineColor = [0.3 0.3 0.3];

    %% ===================== TOP: muscle 1 =====================
    ax1 = nexttile; hold(ax1,'on');
    plot(ax1, t1, x1, 'k', 'LineWidth', 0.8);

    yL1 = ylim(ax1);
    for iC = 1:numel(cycle_starts)
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);
        xStart = (c1-1)/fs;
        xEnd   = (c2-1)/fs;

        if cyc1.cycle_keep_mask(iC)
            col = colKeep;
        else
            col = colBad;
        end

        patch(ax1, [xStart xEnd xEnd xStart], [yL1(1) yL1(1) yL1(2) yL1(2)], ...
            col, 'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
    end

    plot(ax1, t1, x1, 'k', 'LineWidth', 0.8);

    invalidIdx1 = find(~cyc1.cycle_keep_mask);
    % invalidIdx1 = invalidIdx1(1:end);

    for iC = 1:numel(cycle_starts)
        xc = (cycle_starts(iC)-1)/fs;
        xline(ax1, xc, '--', 'Color', cycleLineColor, 'LineWidth', 0.8);
    end

    for k = 1:numel(invalidIdx1)
        iC = invalidIdx1(k);
        xc = (cycle_starts(iC)-1)/fs;

        reasonStr = short_cycle_reason(cyc1.cycle_reason(iC));
        txt = sprintf('C%d: %s', iC, reasonStr);

        yText = yL1(1) + 0.9 * (yL1(2)-yL1(1));   % same height for all, fairly low

        text(ax1, xc, yText, txt, ...
            'Rotation', 90, ...
            'VerticalAlignment','top', ...
            'HorizontalAlignment','center', ...
            'FontSize', 8, ...
            'FontWeight', 'bold');
    end

    title(ax1, sprintf('%s | %s | %s | %s | %s', subjID, cond, leg, pairName, mus1), ...
        'Interpreter','none');
    ylabel(ax1, 'Amplitude');
    grid(ax1,'on');

    %% ===================== BOTTOM: muscle 2 =====================
    ax2 = nexttile; hold(ax2,'on');
    plot(ax2, t2, x2, 'k', 'LineWidth', 0.8);

    yL2 = ylim(ax2);
    for iC = 1:numel(cycle_starts)
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);
        xStart = (c1-1)/fs;
        xEnd   = (c2-1)/fs;

        if cyc2.cycle_keep_mask(iC)
            col = colKeep;
        else
            col = colBad;
        end

        patch(ax2, [xStart xEnd xEnd xStart], [yL2(1) yL2(1) yL2(2) yL2(2)], ...
            col, 'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
    end

    plot(ax2, t2, x2, 'k', 'LineWidth', 0.8);

    invalidIdx2 = find(~cyc2.cycle_keep_mask);
    % invalidIdx2 = invalidIdx2(1:end);

    for iC = 1:numel(cycle_starts)
        xc = (cycle_starts(iC)-1)/fs;
        xline(ax2, xc, '--', 'Color', cycleLineColor, 'LineWidth', 0.8);
    end

    for k = 1:numel(invalidIdx2)
        iC = invalidIdx2(k);
        xc = (cycle_starts(iC)-1)/fs;

        reasonStr = short_cycle_reason(cyc2.cycle_reason(iC));
        txt = sprintf('C%d: %s', iC, reasonStr);

        yText = yL2(1) + 0.9 * (yL2(2)-yL2(1));   % same height for all, fairly low

        text(ax2, xc, yText, txt, ...
            'Rotation', 90, ...
            'VerticalAlignment','top', ...
            'HorizontalAlignment','center', ...
            'FontSize', 8, ...
            'FontWeight', 'bold');
    end

    title(ax2, sprintf('%s | %s | %s | %s | %s', subjID, cond, leg, pairName, mus2), ...
        'Interpreter','none');

    xlabel(ax2, 'Time (s)');
    ylabel(ax2, 'Amplitude');
    grid(ax2,'on');

    %% ===================== GLOBAL ANNOTATION =====================
    nValid = P.n_valid_cycles;
    nTot   = P.n_cycles_total;
    excl   = char(P.exclusion_reason);

    sgtitle(sprintf(['Excluded pair signal | %s | %s | %s | %s\n' ...
        'Valid pair cycles: %d / %d | Min required: %d | Reason: %s'], ...
        subjID, cond, leg, pairName, ...
        nValid, nTot, P.min_cycles_required, excl), ...
        'Interpreter','none');

    runTag = char(string(datetime('now','Format','yyyyMMdd_HHmmss')));
    fname = sprintf('excluded_pair__%s__%s__%s__%s__%s.png', ...
        subjID, cond, leg, pairName, runTag);
    fpath = fullfile(outDir, fname);

    if isgraphics(fig)
        exportgraphics(fig, fpath, 'Resolution', 150);
    end

    if isgraphics(fig)
        close(fig);
    end
end