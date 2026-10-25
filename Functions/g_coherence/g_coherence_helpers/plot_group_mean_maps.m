function plot_group_mean_maps(Gpair, groupVals, groupField, pairName, outDir, freq_range, mapField)
    nG = numel(groupVals);
    if nG == 0, return; end

    fig = figure('Visible','off','Color','w','Position',[100 100 430*nG 420]);

    % Better layout than subplot
    tl = tiledlayout(1, nG, 'TileSpacing','compact', 'Padding','compact');

    Cmeans = cell(nG,1);
    Fplots = cell(nG,1);
    Tplot  = [];
    nPerGroup = zeros(nG,1);

    cmin = inf;
    cmax = -inf;

    % ---------- First pass: compute mean maps and global color range ----------
    for ig = 1:nG
        gv = groupVals(ig);

        idx = false(numel(Gpair),1);
        for k = 1:numel(Gpair)
            idx(k) = (string(Gpair(k).(groupField)) == gv);
        end
        Gsel = Gpair(idx);
        nPerGroup(ig) = numel(Gsel);

        if isempty(Gsel)
            continue;
        end

        Cstack = [];
        for k = 1:numel(Gsel)
            if isfield(Gsel(k), mapField) && ~isempty(Gsel(k).(mapField))
                Cstack = cat(3, Cstack, Gsel(k).(mapField));
            end
        end

        if isempty(Cstack)
            continue;
        end
        Cmean = mean(Cstack, 3, 'omitnan');

        idxFreq = Gsel(1).Freq >= freq_range(1) & Gsel(1).Freq <= freq_range(2);
        FreqPlot = Gsel(1).Freq(idxFreq);

        Cmean = Cmean(idxFreq, :);

        Cmeans{ig} = Cmean;
        Fplots{ig} = FreqPlot;
        Tplot = Gsel(1).Time_percent;

        cmin = min(cmin, min(Cmean(:), [], 'omitnan'));
        cmax = max(cmax, max(Cmean(:), [], 'omitnan'));
    end

    % ---------- Second pass: plot ----------
    ax = gobjects(nG,1);

    for ig = 1:nG
        ax(ig) = nexttile;
        gv = groupVals(ig);

        if isempty(Cmeans{ig})
            axis off;
            continue;
        end

        imagesc(Tplot, Fplots{ig}, Cmeans{ig});
        axis xy;

        xlim([0 100]);
        ylim(freq_range);

        xticks([0 20 40 60 80 100]);

        yStep = 20;
        yt = unique([freq_range(1), ...
                     ceil(freq_range(1)/yStep)*yStep : yStep : floor(freq_range(2)/yStep)*yStep, ...
                     freq_range(2)]);
        yticks(yt);

        caxis([cmin cmax]);

        xlabel('% Cycle');
        if ig == 1
            ylabel('Frequency (Hz)');
        else
            ylabel('');
        end

        prettyLabel = get_pretty_group_label(gv, groupField);

        % smaller title to avoid overlap
        title(sprintf('%s = %s (n=%d)', ...
            strrep(groupField,'_',' '), prettyLabel, nPerGroup(ig)), ...
            'Interpreter','none', 'FontSize', 12, 'FontWeight','bold');

        box on;
        set(gca, 'Layer','top', 'LineWidth',1.1);
    end

    % Shared colorbar for all tiles
    cb = colorbar;
    cb.Layout.Tile = 'east';

    if strcmp(mapField, 'Coherence_sig')
        mapLabel = 'Significant coherence map';
        fileTag = 'SIG';
    else
        mapLabel = 'Mean coherence map';
        fileTag = 'RAW';
    end

    % Global title with more space
    title(tl, sprintf('%s | %s | grouped by %s', ...
        mapLabel, pairName, strrep(groupField,'_',' ')), ...
        'Interpreter','none', 'FontSize', 18, 'FontWeight','bold');

    fname = sprintf('GROUP_MAP__%s__BY_%s__%s.png', pairName, upper(groupField), fileTag);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end
