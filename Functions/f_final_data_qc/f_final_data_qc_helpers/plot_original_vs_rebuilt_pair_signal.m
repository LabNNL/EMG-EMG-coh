function plot_original_vs_rebuilt_pair_signal(P, subjID, cond, leg, pairName, outDir, C)

    fs = P.fs;
    mus1 = P.muscles{1};
    mus2 = P.muscles{2};

    colExcluded = C.plotting.colors.exclude;

    x1_orig = P.original_signal_1(:);
    x2_orig = P.original_signal_2(:);

    x1_new = P.final_concatenated_signal_1(:);
    x2_new = P.final_concatenated_signal_2(:);

    cycStarts = P.cycle_starts(:);
    cycEnds   = P.cycle_ends(:);
    pairKeep  = P.pair_cycle_keep_mask(:);

    % cycle segments in rebuilt signal
    if isfield(P, 'final_cycle_segments_table') && ~isempty(P.final_cycle_segments_table)
        Tseg = P.final_cycle_segments_table;
    else
        Tseg = table();
    end

    % center rebuilt signals
    if ~isempty(x1_new), x1_new = x1_new - mean(x1_new, 'omitnan'); end
    if ~isempty(x2_new), x2_new = x2_new - mean(x2_new, 'omitnan'); end

    t1_orig = (0:numel(x1_orig)-1) / fs;
    t2_orig = (0:numel(x2_orig)-1) / fs;
    t1_new  = (0:numel(x1_new)-1) / fs;
    t2_new  = (0:numel(x2_new)-1) / fs;

    % Make it not visible during creation to avoid flickering, but we'll export it at the end
    fig = figure('Color','w','Position',[100 100 1800 1000], 'Visible','off', 'Toolbar','none','MenuBar','none');

    % same y scale within each muscle original/rebuilt
    y1_all = [x1_orig; x1_new];
    y2_all = [x2_orig; x2_new];

    if isempty(y1_all), y1_all = [0;1]; end
    if isempty(y2_all), y2_all = [0;1]; end

    yL1 = [min(y1_all,[],'omitnan'), max(y1_all,[],'omitnan')];
    yL2 = [min(y2_all,[],'omitnan'), max(y2_all,[],'omitnan')];

    if yL1(1) == yL1(2), yL1 = yL1 + [-1 1]; end
    if yL2(1) == yL2(2), yL2 = yL2 + [-1 1]; end

    %% ===================== MUSCLE 1 ORIGINAL =====================
    ax1 = subplot(2,2,1); hold(ax1,'on');

    % shade removed cycles
    for iC = 1:numel(pairKeep)
        if ~pairKeep(iC)
            xStart = (cycStarts(iC)-1)/fs;
            xEnd   = (cycEnds(iC)-1)/fs;
            patch(ax1, [xStart xEnd xEnd xStart], [yL1(1) yL1(1) yL1(2) yL1(2)], ...
                colExcluded, 'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
        end
    end

    plot(ax1, t1_orig, x1_orig, 'k', 'LineWidth', 0.8);

    % vertical bars around removed cycles
    for iC = 1:numel(pairKeep)
        if ~pairKeep(iC)
            xStart = (cycStarts(iC)-1)/fs;
            xEnd   = (cycEnds(iC)-1)/fs;
            xline(ax1, xStart, '-', 'LineWidth', 1.5);
            xline(ax1, xEnd,   '-', 'LineWidth', 1.5);
        end
    end

    ylim(ax1, yL1);
    title(ax1, sprintf('%s | original | %s', mus1, subjID), 'Interpreter','none');
    ylabel(ax1, 'Amplitude');
    grid(ax1,'on');

    %% ===================== MUSCLE 1 REBUILT =====================
    ax2 = subplot(2,2,3); hold(ax2,'on');
    plot(ax2, t1_new, x1_new, 'k', 'LineWidth', 0.8);

    % vertical bars only where a cut really happened in the original signal
    if ~isempty(Tseg) && height(Tseg) >= 2
        for i = 2:height(Tseg)
            prevCycle = Tseg.cycle_number(i-1);
            currCycle = Tseg.cycle_number(i);

            % if cycle numbers are not consecutive, something was removed between them
            if currCycle > prevCycle + 1
                xCutNew1 = (Tseg.final_concat_start_idx_signal1(i)-1)/fs;
                xline(ax2, xCutNew1, '--', 'LineWidth', 1.8);
            end
        end
    end

    ylim(ax2, yL1);
    title(ax2, sprintf('%s | rebuilt / centered', mus1), 'Interpreter','none');
    xlabel(ax2, 'Time (s)');
    ylabel(ax2, 'Amplitude');
    grid(ax2,'on');

    %% ===================== MUSCLE 2 ORIGINAL =====================
    ax3 = subplot(2,2,2); hold(ax3,'on');

    for iC = 1:numel(pairKeep)
        if ~pairKeep(iC)
            xStart = (cycStarts(iC)-1)/fs;
            xEnd   = (cycEnds(iC)-1)/fs;
            patch(ax3, [xStart xEnd xEnd xStart], [yL2(1) yL2(1) yL2(2) yL2(2)], ...
                colExcluded, 'FaceAlpha', C.plotting.AlphaTransparency, 'EdgeColor', 'none');
        end
    end

    plot(ax3, t2_orig, x2_orig, 'k', 'LineWidth', 0.8);

    % vertical bars around removed cycles
    for iC = 1:numel(pairKeep)
        if ~pairKeep(iC)
            xStart = (cycStarts(iC)-1)/fs;
            xEnd   = (cycEnds(iC)-1)/fs;
            xline(ax3, xStart, '-', 'LineWidth', 1.5);
            xline(ax3, xEnd,   '-', 'LineWidth', 1.5);
        end
    end

    ylim(ax3, yL2);
    title(ax3, sprintf('%s | original', mus2), 'Interpreter','none');
    ylabel(ax3, 'Amplitude');
    grid(ax3,'on');

    %% ===================== MUSCLE 2 REBUILT =====================
    ax4 = subplot(2,2,4); hold(ax4,'on');
    plot(ax4, t2_new, x2_new, 'k', 'LineWidth', 0.8);

    % vertical bars only where a cut really happened in the original signal
    if ~isempty(Tseg) && height(Tseg) >= 2
        for i = 2:height(Tseg)
            prevCycle = Tseg.cycle_number(i-1);
            currCycle = Tseg.cycle_number(i);

            if currCycle > prevCycle + 1
                xCutNew2 = (Tseg.final_concat_start_idx_signal2(i)-1)/fs;
                xline(ax4, xCutNew2, '--', 'LineWidth', 1.8);
            end
        end
    end

    ylim(ax4, yL2);
    title(ax4, sprintf('%s | rebuilt / centered', mus2), 'Interpreter','none');
    xlabel(ax4, 'Time (s)');
    ylabel(ax4, 'Amplitude');
    grid(ax4,'on');

    nValid = P.n_valid_cycles;
    nTot   = P.n_cycles_total;
    sgtitle(sprintf('%s | %s | %s | %s | valid cycles %d / %d', ...
        subjID, cond, leg, pairName, nValid, nTot), 'Interpreter','none');

    fname = sprintf('rebuilt__%s__%s__%s__%s.png', subjID, cond, leg, pairName);
    fpath = fullfile(outDir, fname);

    axs = findall(fig, 'Type', 'axes');
    for ia = 1:numel(axs)
        try
            axs(ia).Toolbar.Visible = 'off';
        catch
        end
    end

    exportgraphics(fig, fpath, 'Resolution', 200);
    %close(fig);
end