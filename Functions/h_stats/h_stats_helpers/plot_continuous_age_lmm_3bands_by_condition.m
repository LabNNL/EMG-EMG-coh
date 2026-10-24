function plot_continuous_age_lmm_3bands_by_condition(PLOT_3BANDS, C, HC, outFile)

    P = HC.plot.continuous_age_lmm_3bands;

    bandOrder = ["Alpha", "Beta", "Gamma"];

    fig = figure( 'Visible', P.visible, 'Color', 'w', 'Position', [100 100 1500 520]);

    tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

    axAll = gobjects(1,3);

    for ib = 1:numel(bandOrder)

        bandName = bandOrder(ib);
        bandField = char(bandName);

        ax = nexttile(tl, ib);
        axAll(ib) = ax;
        hold(ax, 'on');

        if ~isfield(PLOT_3BANDS, bandField)
            title(ax, bandName);
            axis(ax, 'off');
            continue;
        end

        S = PLOT_3BANDS.(bandField);

        Tm = S.Tm;
        lme = S.lme;
        dv = char(S.dv);

        powerVar = string(S.powerVar);
        cycleVar = string(S.cycleVar);

        ageVarRaw = "AgeYears";
        ageVarModel = "AgeYears_z";
        conditionVar = "condition";
        subjectVar = "subject";

        Tm = Tm(~isnan(Tm.(dv)) & ~isnan(Tm.(ageVarRaw)), :);

        if height(Tm) < 5
            title(ax, bandName);
            axis(ax, 'off');
            continue;
        end

        % ---------- condition order ----------
        condLevels = categories(removecats(Tm.(conditionVar)));

        if isfield(C, 'plotting') && isfield(C.plotting, 'condition_order')
            wanted = cellstr(C.plotting.condition_order);
            condOrder = wanted(ismember(wanted, condLevels));
            extras = setdiff(condLevels, condOrder, 'stable');
            condOrder = [condOrder(:); extras(:)];
        else
            condOrder = condLevels;
        end

        % ---------- age group order ----------
        ageLevels = categories(removecats(Tm.age_group));

        % ---------- x grid ----------
        xMin = min(Tm.(ageVarRaw));
        xMax = max(Tm.(ageVarRaw));

        if xMin == xMax
            xMin = xMin - 1;
            xMax = xMax + 1;
        end

        xGrid = linspace(xMin, xMax, P.n_grid)';

        ageFit = polyfit(Tm.(ageVarRaw), Tm.(ageVarModel), 1);
        xGridZ = polyval(ageFit, xGrid);

        % ============================================================
        % 1) Raw points colored by CONDITION
        % ============================================================
        for ic = 1:numel(condOrder)

            condName = condOrder{ic};
            idxCond = Tm.(conditionVar) == condName;

            if ~any(idxCond)
                continue;
            end

            colCond = get_condition_color(condName, C);

            try
                scatter(ax, Tm.(ageVarRaw)(idxCond), Tm.(dv)(idxCond), P.point_size, 'filled', 'MarkerFaceColor', colCond, 'MarkerEdgeColor', colCond, 'MarkerFaceAlpha', P.point_alpha, 'MarkerEdgeAlpha', P.point_alpha, 'DisplayName', char(condName));
            catch
                scatter(ax, Tm.(ageVarRaw)(idxCond), Tm.(dv)(idxCond), P.point_size, 'filled', 'MarkerFaceColor', colCond, 'MarkerEdgeColor', colCond, 'DisplayName', char(condName));
            end
        end

        % ============================================================
        % 2) LMM predictions by CONDITION
        % ============================================================
        for ic = 1:numel(condOrder)

            condName = condOrder{ic};
            idxCond = Tm.(conditionVar) == condName;

            if ~any(idxCond)
                continue;
            end

            colCond = get_condition_color(condName, C);

            firstIdx = find(idxCond, 1, 'first');

            newTbl = Tm(firstIdx, :);
            newTbl = newTbl(ones(P.n_grid,1), :);

            % Preserve exact categorical type
            newTbl.(conditionVar) = repmat(Tm.(conditionVar)(firstIdx), P.n_grid, 1);

            newTbl.(ageVarRaw) = xGrid;
            newTbl.(ageVarModel) = xGridZ;

            if ismember(subjectVar, string(Tm.Properties.VariableNames))
                newTbl.(subjectVar) = repmat(Tm.(subjectVar)(1), P.n_grid, 1);
            end

            if powerVar ~= "" && ismember(powerVar, string(Tm.Properties.VariableNames))
                newTbl.(powerVar) = repmat(mean(Tm.(powerVar), 'omitnan'), P.n_grid, 1);
            end

            if cycleVar ~= "" && ismember(cycleVar, string(Tm.Properties.VariableNames))
                newTbl.(cycleVar) = repmat(mean(Tm.(cycleVar), 'omitnan'), P.n_grid, 1);
            end

            try
                [yHat, yCI] = predict(lme, newTbl, 'Conditional', false);
            catch
                [yHat, yCI] = predict(lme, newTbl);
            end

            if P.show_ci && ~isempty(yCI)
                patch(ax, [xGrid; flipud(xGrid)], [yCI(:,1); flipud(yCI(:,2))], colCond, 'FaceAlpha', P.ci_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            end

            plot(ax, xGrid, yHat, '-', 'Color', colCond, 'LineWidth', P.line_width, 'DisplayName', char(condName));
        end

        % ============================================================
        % 3) Significance annotation
        % ============================================================
        if isfield(P, 'show_significance') && P.show_significance

            pLab = "";
            if isfield(S, 'p_label') && strlength(S.p_label) > 0
                pLab = " (" + S.p_label + ")";
            end
            txt = sprintf('Age%s: %s\nCond%s: %s\nAge×Cond%s: %s', pLab, p_to_stars_with_p(S.p_age), pLab, p_to_stars_with_p(S.p_condition), pLab, p_to_stars_with_p(S.p_interaction));

            if isfield(S, 'p_power') && isfinite(S.p_power)
                txt = sprintf('%s\nPower: %s', txt, p_to_stars_with_p(S.p_power));
            end

            if isfield(S, 'p_cycle') && isfinite(S.p_cycle)
                txt = sprintf('%s\nCycles: %s', txt, p_to_stars_with_p(S.p_cycle));
            end

            text(ax, 0.04, 0.96, txt, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 3);
        end

        xlabel(ax, 'Age (years)');
        ylabel(ax, strrep(dv, '_', ' '));
        title(ax, sprintf('%s', bandName), 'Interpreter', 'none');

        grid(ax, 'on');
        box(ax, 'off');

        if P.use_fixed_ylim && isfield(P, 'ylim') && numel(P.ylim) == 2
            ylim(ax, P.ylim);
        end
    end

    % ---------- Shared title ----------
    pairName = "";
    modelTxt = "";
    fields = fieldnames(PLOT_3BANDS);
    if ~isempty(fields)
        pairName = string(PLOT_3BANDS.(fields{1}).pairName);
        modelTxt = strrep(PLOT_3BANDS.(fields{1}).formula, PLOT_3BANDS.(fields{1}).dv, "DV");
    end

    sgtitle(tl, {sprintf('%s | Continuous-age LMM predictions', pairName), ...
        sprintf('%s | %s coding, %s, %s DF | p Holm-adjusted across the models of CONTINUOUS_AGE_LME_TABLE', ...
        modelTxt, HC.lme.dummy_var_coding, HC.lme.fit_method, HC.lme.df_method)}, 'Interpreter', 'none', 'FontSize', 10);

    % ---------- Legends ----------
    % Age-group legend from scatter handles
    allAxes = findall(fig, 'Type', 'axes');
    scatters = findobj(allAxes, 'Type', 'Scatter');

    if ~isempty(scatters)
        labels = get(scatters, 'DisplayName');
        if ischar(labels), labels = {labels}; end

        valid = ~cellfun(@isempty, labels);
        scatters = scatters(valid);
        labels = labels(valid);

        [uniqueLabels, ia] = unique(labels, 'stable');
        scatters = scatters(ia);

        legendAx1 = axes(fig, 'Position', [0.20 0.01 0.35 0.05], 'Visible', 'off');

        lgd1 = legend(legendAx1, scatters, uniqueLabels, 'Orientation', 'horizontal', 'Interpreter', 'none');

        lgd1.Box = 'off';
        title(lgd1, 'Age group');
    end

    % Condition legend from line handles
    lines = findobj(allAxes, 'Type', 'Line');

    if ~isempty(lines)
        labels = get(lines, 'DisplayName');
        if ischar(labels), labels = {labels}; end

        valid = ~cellfun(@isempty, labels);
        lines = lines(valid);
        labels = labels(valid);

        % only condition names, avoid weird entries
        [uniqueLabels, ia] = unique(labels, 'stable');
        lines = lines(ia);

        legendAx2 = axes(fig, 'Position', [0.62 0.01 0.30 0.05], 'Visible', 'off');

        lgd2 = legend(legendAx2, lines, uniqueLabels, 'Orientation', 'horizontal', 'Interpreter', 'none');

        lgd2.Box = 'off';
        title(lgd2, 'Condition lines');
    end

    outDir = fileparts(outFile);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    saveas(fig, outFile);
    close(fig);
end