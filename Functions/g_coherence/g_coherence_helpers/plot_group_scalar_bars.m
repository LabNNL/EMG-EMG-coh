function plot_group_scalar_bars(Gpair, groupVals, groupField, pairName, outDir, scalarVars)

    M = nan(numel(groupVals), numel(scalarVars));

    for ig = 1:numel(groupVals)
        gv = groupVals(ig);

        idx = false(numel(Gpair),1);
        for k = 1:numel(Gpair)
            idx(k) = (string(Gpair(k).(groupField)) == gv);
        end
        Gsel = Gpair(idx);

        if isempty(Gsel), continue; end

        for iv = 1:numel(scalarVars)
            vname = scalarVars{iv};

            vals = nan(numel(Gsel),1);
            for k = 1:numel(Gsel)
                if isfield(Gsel(k), vname)
                    vals(k) = Gsel(k).(vname);
                end
            end

            M(ig, iv) = mean(vals, 'omitnan');
        end
    end

    % Optional: drop columns that are completely NaN
    keepCols = ~all(isnan(M), 1);
    M = M(:, keepCols);
    scalarVars = scalarVars(keepCols);

    if isempty(M) || isempty(scalarVars)
        warning('No valid scalar values to plot for %s grouped by %s.', pairName, groupField);
        return;
    end

    fig = figure('Visible','off','Color','w','Position',[100 100 950 500]);
    b = bar(M, 'grouped');
    hold on;

    for iv = 1:min(numel(scalarVars), numel(b))
        if ~isgraphics(b(iv)) || ~isprop(b(iv), 'FaceColor')
            continue;
        end

        vname = scalarVars{iv};

        if contains(vname, 'Alpha')
            b(iv).FaceColor = get_band_color('Alpha');
        elseif contains(vname, 'Beta')
            b(iv).FaceColor = get_band_color('Beta');
        elseif contains(vname, 'Gamma')
            b(iv).FaceColor = get_band_color('Gamma');
        elseif contains(vname, 'FullBand')
            b(iv).FaceColor = [0.35 0.35 0.35];
        else
            b(iv).FaceColor = [0.5 0.5 0.5];
        end
    end

    prettyGroups = cell(size(groupVals));
    for i = 1:numel(groupVals)
        prettyGroups{i} = char(get_pretty_group_label(groupVals(i), groupField));
    end

    set(gca, 'XTick', 1:numel(groupVals), 'XTickLabel', prettyGroups);
    legend(strrep(scalarVars, '_', '\_'), 'Location', 'best');
    ylabel('Value');
    title(sprintf('Scalar coherence summary | %s | grouped by %s', ...
        pairName, strrep(groupField,'_',' ')), 'Interpreter','none');
    grid on;
    box on;
    set(gca, 'Layer','top', 'LineWidth',1.1);

    plotTag = strjoin(scalarVars, '__');
    plotTag = regexprep(plotTag, '[^\w]', '_');
    fname = sprintf('GROUP_SCALARS__%s__BY_%s__%s.png', pairName, upper(groupField), plotTag);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end