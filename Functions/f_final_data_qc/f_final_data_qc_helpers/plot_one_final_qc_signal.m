function plot_one_final_qc_signal(subjID, cond, leg, mf, fs, x, x_env, cycle_starts, toe_off_concat, Tsig, outDir, C)

    fprintf('Plotting final QC signal for %s | %s | %s | %s...\n', subjID, cond, leg, mf);

    t = (0:numel(x)-1) / fs;
    fig = figure('Visible','off','Color','w','Position',[100 100 1600 900]);

    % ---------- Colors from config ----------
    signalColor = [0 0 0];

    if isfield(C.plotting.colors, 'envColor')
        envColor = C.plotting.colors.envColor;
    else
        envColor = [0 0 1];
    end

    colKeep        = C.plotting.colors.include;                % both agree keep
    colBothBad     = C.plotting.colors.exclude;               % both agree reject
    colRuleBad     = C.plotting.colors.exclude_rule_based;    % only rule-based bad
    colClusterBad  = C.plotting.colors.exclude_cluster_based; % only clustering bad

    %% ===================== TOP PANEL: final burst QC =====================
    ax1 = subplot(2,1,1);
    hold(ax1, 'on');

    plot(ax1, t, x, 'Color', signalColor, 'LineWidth', 0.8);
    if ~isempty(x_env) && numel(x_env) == numel(x)
        plot(ax1, t, x_env, 'Color', envColor, 'LineWidth', 1.2);
    end

    yL1 = ylim(ax1);
    yRange1 = yL1(2) - yL1(1);
    yTop1 = yL1(2);

    for i = 1:height(Tsig)
        idx1 = max(1, Tsig.start_idx(i));
        idx2 = min(numel(x), Tsig.end_idx(i));
        x1 = (idx1-1)/fs;
        x2 = (idx2-1)/fs;

        [patchColor, patchAlpha] = get_patch_style( ...
            Tsig.rule_based_keep(i), Tsig.cluster_good(i), ...
            colKeep, colBothBad, colRuleBad, colClusterBad, C);

        patch(ax1, [x1 x2 x2 x1], [yL1(1) yL1(1) yL1(2) yL1(2)], ...
            patchColor, 'FaceAlpha', patchAlpha, 'EdgeColor', 'none');
    end

    plot(ax1, t, x, 'Color', signalColor, 'LineWidth', 0.8);
    if ~isempty(x_env) && numel(x_env) == numel(x)
        plot(ax1, t, x_env, 'Color', envColor, 'LineWidth', 1.2);
    end

    for i = 1:height(Tsig)
        idx1 = max(1, Tsig.start_idx(i));
        idx2 = min(numel(x), Tsig.end_idx(i));
        xc = ((idx1 + idx2)/2 - 1) / fs;

        xline(ax1, (idx1-1)/fs, ':', 'LineWidth', 0.7);
        xline(ax1, (idx2-1)/fs, ':', 'LineWidth', 0.7);

        txt = get_short_plot_label(Tsig.rule_based_keep(i), Tsig.cluster_good(i));
        if txt ~= ""
            text(ax1, xc, yTop1 - 0.05*yRange1, txt, ...
                'Rotation', 90, ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','top', ...
                'FontSize', 8, ...
                'FontWeight', 'bold');
        end
    end

    nKeep = sum(Tsig.final_keep);
    nTot  = height(Tsig);

    title(ax1, sprintf('%s | %s | %s | %s  --> kept %d / %d', ...
        subjID, cond, leg, mf, nKeep, nTot), 'Interpreter','none');
    ylabel(ax1, 'Amplitude');
    grid(ax1, 'on');

    p1 = patch(ax1, nan, nan, colKeep,       'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
    p2 = patch(ax1, nan, nan, colBothBad,    'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
    p3 = patch(ax1, nan, nan, colClusterBad, 'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
    p4 = patch(ax1, nan, nan, colRuleBad,    'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');

    legend(ax1, [p1 p2 p3 p4], ...
        {'keep: both agree', 'reject: both agree', 'cluster only bad', 'rule only bad'}, ...
        'Location', 'best');

    %% ===================== BOTTOM PANEL: cycle starts =====================
    ax2 = subplot(2,1,2);
    hold(ax2, 'on');

    plot(ax2, t, x, 'Color', signalColor, 'LineWidth', 0.8);
    if ~isempty(x_env) && numel(x_env) == numel(x)
        plot(ax2, t, x_env, 'Color', envColor, 'LineWidth', 1.0);
    end

    yL2 = ylim(ax2);

    for i = 1:height(Tsig)
        idx1 = max(1, Tsig.start_idx(i));
        idx2 = min(numel(x), Tsig.end_idx(i));
        x1 = (idx1-1)/fs;
        x2 = (idx2-1)/fs;

        [patchColor, patchAlpha] = get_patch_style( ...
            Tsig.rule_based_keep(i), Tsig.cluster_good(i), ...
            colKeep, colBothBad, colRuleBad, colClusterBad, C);

        patch(ax2, [x1 x2 x2 x1], [yL2(1) yL2(1) yL2(2) yL2(2)], ...
            patchColor, 'FaceAlpha', patchAlpha, 'EdgeColor', 'none');
    end

    plot(ax2, t, x, 'Color', signalColor, 'LineWidth', 0.8);
    if ~isempty(x_env) && numel(x_env) == numel(x)
        plot(ax2, t, x_env, 'Color', envColor, 'LineWidth', 1.0);
    end

    if ~isempty(cycle_starts)
        cycle_starts = cycle_starts(~isnan(cycle_starts));
        cycle_starts = cycle_starts(cycle_starts >= 1 & cycle_starts <= numel(x));
        cycle_starts = unique(round(cycle_starts));

        for iC = 1:numel(cycle_starts)
            xc = (cycle_starts(iC)-1)/fs;
            xline(ax2, xc, '--', 'LineWidth', 1.2);
            text(ax2, xc, yL2(2), sprintf('C%d', iC), ...
                'Rotation', 90, ...
                'VerticalAlignment','top', ...
                'HorizontalAlignment','center', ...
                'FontSize', 8);
        end
        title(ax2, 'Signal with cycle starts', 'Interpreter','none');
    else
        title(ax2, 'Signal with cycle starts (not available in loaded file)', 'Interpreter','none');
    end

    if ~isempty(toe_off_concat)
        toe_off_concat = toe_off_concat(:);
        toe_off_concat = toe_off_concat(~isnan(toe_off_concat));
        toe_off_concat = toe_off_concat(toe_off_concat >= 1 & toe_off_concat <= numel(x));
        toe_off_concat = unique(round(toe_off_concat));

        for iT = 1:numel(toe_off_concat)
            xc = (toe_off_concat(iT)-1)/fs;
            xline(ax2, xc, ':', 'LineWidth', 1.0, 'Color', [0.85 0.33 0.1]);
            text(ax2, xc, yL2(2)*0.95, sprintf('TO%d', iT), ...
                'Rotation', 90, ...
                'VerticalAlignment','top', ...
                'HorizontalAlignment','center', ...
                'FontSize', 8, ...
                'Color', [0.85 0.33 0.1]);
        end
    end

    xlabel(ax2, 'Time (s)');
    ylabel(ax2, 'Amplitude');
    grid(ax2, 'on');

    runTag = char(string(datetime('now','Format','yyyyMMdd_HHmmss')));
    fname = sprintf('final_qc__%s__%s__%s__%s__%s.png', subjID, cond, leg, mf, runTag);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end

function [patchColor, patchAlpha] = get_patch_style(thrGood, cluGood, colKeep, colBothBad, colRuleBad, colClusterBad, C)
    if thrGood && cluGood
        patchColor = colKeep;
        patchAlpha = C.plotting.AlphaTransparency;
    elseif ~thrGood && ~cluGood
        patchColor = colBothBad;
        patchAlpha = C.plotting.AlphaTransparency;
    elseif thrGood && ~cluGood
        patchColor = colClusterBad;
        patchAlpha = C.plotting.AlphaTransparency;
    else
        patchColor = colRuleBad;
        patchAlpha = C.plotting.AlphaTransparency;
    end
end

function txt = get_short_plot_label(thrGood, cluGood)
    if thrGood && ~cluGood
        txt = "C";
    elseif ~thrGood && cluGood
        txt = "R";
    else
        txt = "";
    end
end