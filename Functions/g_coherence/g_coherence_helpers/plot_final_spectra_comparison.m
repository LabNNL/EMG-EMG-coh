function plot_final_spectra_comparison(Gpair, groupVals, groupField, pairName, outDir, freq_range, mode, C)

    fig = figure('Visible','off','Color','w','Position',[100 100 1600 450]);
    tl = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

    ax1 = nexttile; hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
    ax2 = nexttile; hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    ax3 = nexttile; hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');

    % Store global y-range across all panels
    globalYmin = inf;
    globalYmax = -inf;

    for ig = 1:numel(groupVals)
        gv = groupVals(ig);

        idx = false(numel(Gpair),1);
        for k = 1:numel(Gpair)
            idx(k) = (string(Gpair(k).(groupField)) == gv);
        end
        Gsel = Gpair(idx);

        if isempty(Gsel)
            continue;
        end

        F = Gsel(1).Freq(:);

        % ----- full cycle -----
        curves_full = nan(numel(F), numel(Gsel));
        for k = 1:numel(Gsel)
            if strcmp(mode, 'sig')
                curves_full(:,k) = mean(Gsel(k).Coherence_sig, 2, 'omitnan');
            else
                curves_full(:,k) = mean(Gsel(k).Coherence, 2, 'omitnan');
            end
        end
        mean_full = mean(curves_full, 2, 'omitnan');
        sem_full  = std(curves_full, 0, 2, 'omitnan') ./ sqrt(sum(~isnan(curves_full), 2));

        % ----- stance -----
        curves_stance = nan(numel(F), numel(Gsel));
        for k = 1:numel(Gsel)
            if isfield(Gsel(k), 'StanceIndices') && ~isempty(Gsel(k).StanceIndices)
                if strcmp(mode, 'sig')
                    curves_stance(:,k) = mean(Gsel(k).Coherence_sig(:, Gsel(k).StanceIndices), 2, 'omitnan');
                else
                    curves_stance(:,k) = mean(Gsel(k).Coherence(:, Gsel(k).StanceIndices), 2, 'omitnan');
                end
            end
        end
        mean_stance = mean(curves_stance, 2, 'omitnan');
        sem_stance  = std(curves_stance, 0, 2, 'omitnan') ./ sqrt(sum(~isnan(curves_stance), 2));

        % ----- swing -----
        curves_swing = nan(numel(F), numel(Gsel));
        for k = 1:numel(Gsel)
            if isfield(Gsel(k), 'SwingIndices') && ~isempty(Gsel(k).SwingIndices)
                if strcmp(mode, 'sig')
                    curves_swing(:,k) = mean(Gsel(k).Coherence_sig(:, Gsel(k).SwingIndices), 2, 'omitnan');
                else
                    curves_swing(:,k) = mean(Gsel(k).Coherence(:, Gsel(k).SwingIndices), 2, 'omitnan');
                end
            end
        end
        mean_swing = mean(curves_swing, 2, 'omitnan');
        sem_swing  = std(curves_swing, 0, 2, 'omitnan') ./ sqrt(sum(~isnan(curves_swing), 2));

        prettyLabel = get_pretty_group_label(gv, groupField);
        lab = sprintf('%s (n=%d)', prettyLabel, numel(Gsel));

        if strcmp(groupField, 'age_group')
            thisColor = get_age_color(gv, C);
        elseif strcmp(groupField, 'condition')
            thisColor = get_condition_color(gv, C);
        else
            thisColor = [0.3 0.3 0.3];
        end

        % ----- shaded SEM + mean line -----
        plot_shaded_curve(ax1, F, mean_full,   sem_full,   thisColor, lab);
        plot_shaded_curve(ax2, F, mean_stance, sem_stance, thisColor, lab);
        plot_shaded_curve(ax3, F, mean_swing,  sem_swing,  thisColor, lab);

        % ----- update global y-limits -----
        [globalYmin, globalYmax] = update_global_ylim(globalYmin, globalYmax, mean_full, sem_full);
        [globalYmin, globalYmax] = update_global_ylim(globalYmin, globalYmax, mean_stance, sem_stance);
        [globalYmin, globalYmax] = update_global_ylim(globalYmin, globalYmax, mean_swing, sem_swing);
    end

    % Safety fallback
    if ~isfinite(globalYmin) || ~isfinite(globalYmax) || globalYmin == globalYmax
        globalYmin = 0;
        globalYmax = 1;
    end

    % Optional small margin
    yrange = globalYmax - globalYmin;
    if yrange <= 0
        yrange = 0.05;
    end
    globalYmin = max(0, globalYmin - 0.05*yrange);
    globalYmax = globalYmax + 0.05*yrange;

    % Formatting
    allAx = [ax1 ax2 ax3];
    ttl = {'Whole cycle','Stance','Swing'};
    for ia = 1:3
        xlim(allAx(ia), freq_range);
        xticks(allAx(ia), unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
        ylim(allAx(ia), [globalYmin globalYmax]);
        xlabel(allAx(ia), 'Frequency (Hz)');
        ylabel(allAx(ia), 'Mean coherence');
        title(allAx(ia), ttl{ia});
        set(allAx(ia), 'Layer', 'top', 'LineWidth', 1.1);
    end

    legend(ax3, 'Location','best');

    if strcmp(mode, 'sig')
        plotLabel = 'Significant coherence spectra comparison';
        fileTag = 'SIG';
    else
        plotLabel = 'Coherence spectra comparison';
        fileTag = 'RAW';
    end

    title(tl, sprintf('%s | %s | grouped by %s', ...
        plotLabel, pairName, strrep(groupField,'_',' ')), ...
        'Interpreter','none', 'FontSize', 16, 'FontWeight','bold');

    fname = sprintf('FINAL_SPECTRA__%s__BY_%s__%s.png', pairName, upper(groupField), fileTag);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end

function plot_shaded_curve(ax, x, y, sem, c, displayName)

    valid = isfinite(x) & isfinite(y) & isfinite(sem);
    if ~any(valid)
        return;
    end

    xv = x(valid);
    yv = y(valid);
    sv = sem(valid);

    lower = yv - sv;
    upper = yv + sv;

    fill(ax, [xv; flipud(xv)], [lower; flipud(upper)], c, ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    plot(ax, xv, yv, 'LineWidth', 1.8, 'Color', c, 'DisplayName', displayName);
end

function [ymin_out, ymax_out] = update_global_ylim(ymin_in, ymax_in, y, sem)

    valid = isfinite(y) & isfinite(sem);
    if ~any(valid)
        ymin_out = ymin_in;
        ymax_out = ymax_in;
        return;
    end

    lower = y(valid) - sem(valid);
    upper = y(valid) + sem(valid);

    ymin_out = min(ymin_in, min(lower, [], 'omitnan'));
    ymax_out = max(ymax_in, max(upper, [], 'omitnan'));
end


