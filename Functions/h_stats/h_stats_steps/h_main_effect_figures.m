function h_main_effect_figures(T_subj, C, HC, CONTINUOUS_AGE_LME_TABLE)
% H_MAIN_EFFECT_FIGURES  The main effects of the primary model, one panel per
% pair (rows) x band (columns), annotated with the Holm-adjusted p-values of
% CONTINUOUS_AGE_LME_TABLE:
%   MAIN_EFFECT_AGE_CONTINUOUS  one dot per participant (mean over conditions)
%                               vs age, the model's age slope averaged over
%                               conditions with its 95% CI, and optionally the
%                               log(age) fit (dashed)
%   MAIN_EFFECT_AGE_GROUPS      the same participant values by age group (for
%                               display; the test is continuous age)
%   MAIN_EFFECT_CONDITION       the model's estimated mean per condition (at the
%                               mean age) with 95% CI, and each participant's
%                               conditions linked
% Each model is refitted from the formula stored in the table with fit_h_lme
% and checked against the table, so the lines are the tested effects.
% Settings: HC.plot.main_effects (enable, show_log_age).

    P = struct('enable', true, 'show_log_age', true);
    if isfield(HC.plot, 'main_effects')
        for f = fieldnames(P)'
            if isfield(HC.plot.main_effects, f{1}), P.(f{1}) = HC.plot.main_effects.(f{1}); end
        end
    end
    if ~HC.plot.enable || ~P.enable || isempty(CONTINUOUS_AGE_LME_TABLE)
        return;
    end
    fprintf('\nMain-effect figures...\n');

    outDir = fullfile(HC.io.plots_dir, 'main_effects');
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    tbl = CONTINUOUS_AGE_LME_TABLE;
    pairs = string(HC.analysis.pairs_to_analyze);
    dvs = string(HC.analysis.dv_list);
    ageOrder = string(C.plotting.age_order);
    condOrder = string(C.plotting.condition_order);

    % age <-> AgeYears_z, and log(age) standardized like the sensitivity table
    [~, iu] = unique(T_subj.subject);
    b = polyfit(T_subj.AgeYears(iu), T_subj.AgeYears_z(iu), 1);
    toZ = @(years) b(1) * years + b(2);
    logAge = log(T_subj.AgeYears);
    okL = isfinite(logAge(iu));
    T_subj.AgeLog_z = (logAge - mean(logAge(iu(okL)))) ./ std(logAge(iu(okL)));
    toLogZ = @(years) (log(years) - mean(logAge(iu(okL)))) ./ std(logAge(iu(okL)));

    ageGrid = linspace(min(T_subj.AgeYears), max(T_subj.AgeYears), 200)';
    setName = string(C.analysis.band_set);

    figA = new_figure(numel(pairs), numel(dvs), HC);
    figG = new_figure(numel(pairs), numel(dvs), HC);
    figC = new_figure(numel(pairs), numel(dvs), HC);
    tlA = tiledlayout(figA, numel(pairs), numel(dvs), 'TileSpacing', 'compact', 'Padding', 'compact');
    tlG = tiledlayout(figG, numel(pairs), numel(dvs), 'TileSpacing', 'compact', 'Padding', 'compact');
    tlC = tiledlayout(figC, numel(pairs), numel(dvs), 'TileSpacing', 'compact', 'Padding', 'compact');

    for ip = 1:numel(pairs)
        for id = 1:numel(dvs)
            pairName = pairs(ip);
            dv = dvs(id);
            band = infer_band_from_metric_name(dv);
            axA = nexttile(tlA); axG = nexttile(tlG); axC = nexttile(tlC);

            r = find(tbl.pair_name == pairName & tbl.metric == dv, 1);
            if isempty(r)
                axis([axA axG axC], 'off');
                continue;
            end

            % ---------- the primary model, refitted exactly as in h_continuous_age_models ----------
            Tp = T_subj(T_subj.pair_name == pairName, :);
            Tp.condition = removecats(Tp.condition);
            Tp.subject = removecats(Tp.subject);
            Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.AgeYears_z), :);
            lme = fit_h_lme(Tm, char(tbl.model_formula(r)), HC);
            [beta, names] = fixedEffects(lme);
            names = string(names.Name);
            bAge = beta(names == "AgeYears_z");
            assert(abs(bAge - tbl.est_age_per_sd(r)) < 1e-8, 'Refit of %s %s does not match the table.', pairName, dv);

            % one value per participant: mean over the conditions they have
            [G, subj] = findgroups(Tm.subject);
            yS = splitapply(@(v) mean(v, 'omitnan'), Tm.(char(dv)), G);
            ageS = splitapply(@(v) v(1), Tm.AgeYears, G);
            grpS = string(splitapply(@(v) v(1), Tm.age_group, G));

            pAge = tbl.p_age_linear_holm(r);
            pCond = tbl.p_condition_holm(r);
            pInt = tbl.p_age_condition_holm(r);
            ttl = sprintf('%s | %s', strrep(pairName, '_', '–'), band);

            % ---------- 1. continuous age ----------
            hold(axA, 'on');
            hG = gobjects(0); lG = strings(0);
            for k = 1:numel(ageOrder)
                sel = grpS == ageOrder(k);
                if ~any(sel), continue; end
                hG(end+1) = scatter(axA, ageS(sel), yS(sel), 22, get_age_color(ageOrder(k), C), 'filled', ...
                    'MarkerFaceAlpha', 0.8, 'MarkerEdgeColor', 'none'); %#ok<AGROW>
                lG(end+1) = ageOrder(k); %#ok<AGROW>
            end
            if ip == 1 && id == 1
                lgd = legend(axA, hG, lG, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 9, 'AutoUpdate', 'off');
                lgd.Layout.Tile = 'south';   % one legend for the figure, below the panels
            end
            % condition-averaged line: under effects coding this is intercept + slope * age_z
            V = lme.CoefficientCovariance;
            i0 = find(names == "(Intercept)"); i1 = find(names == "AgeYears_z");
            z = toZ(ageGrid);
            yHat = beta(i0) + beta(i1) * z;
            se = sqrt(V(i0,i0) + z.^2 * V(i1,i1) + 2 * z * V(i0,i1));
            tcrit = tinv(0.975, lme.DFE);
            fill(axA, [ageGrid; flipud(ageGrid)], [yHat - tcrit*se; flipud(yHat + tcrit*se)], [0 0 0], ...
                'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            plot(axA, ageGrid, yHat, 'k-', 'LineWidth', 2);
            if P.show_log_age
                fL = strrep(char(tbl.model_formula(r)), 'AgeYears_z', 'AgeLog_z');
                lmeL = fit_h_lme(Tm, fL, HC);   % Tm carries AgeLog_z (added to T_subj above)
                [bL, nL] = fixedEffects(lmeL); nL = string(nL.Name);
                plot(axA, ageGrid, bL(nL == "(Intercept)") + bL(nL == "AgeLog_z") * toLogZ(ageGrid), 'k--', 'LineWidth', 1.2);
            end
            slopeDecade = tbl.est_age_per_year(r) * 10;
            title(axA, ttl, 'Interpreter', 'none');
            xlabel(axA, 'Age (years)'); ylabel(axA, sprintf('%s AUC_{norm} (POI)', band));
            text(axA, 0.98, 0.97, {sprintf('Age: p_{Holm} = %s', fmt_p(pAge)), ...
                sprintf('%+.3f per 10 years', slopeDecade), sprintf('n = %d', numel(yS))}, ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9);
            grid(axA, 'on'); box(axA, 'off');

            % ---------- 2. age groups (display) ----------
            hold(axG, 'on');
            for k = 1:numel(ageOrder)
                v = yS(grpS == ageOrder(k));
                if isempty(v), continue; end
                col = get_age_color(ageOrder(k), C);
                xj = k + 0.18 * (rand(size(v)) - 0.5);
                scatter(axG, xj, v, 18, col, 'filled', 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
                m = mean(v); ci = tinv(0.975, max(numel(v)-1, 1)) * std(v) / sqrt(numel(v));
                errorbar(axG, k + 0.3, m, ci, 'o', 'Color', col * 0.7, 'MarkerFaceColor', col * 0.7, 'LineWidth', 1.5, 'CapSize', 6);
            end
            tickLab = arrayfun(@(g) sprintf('%s\\newline%s', g, age_range_text(T_subj, g)), ageOrder, 'UniformOutput', false);
            set(axG, 'XTick', 1:numel(ageOrder), 'XTickLabel', tickLab, 'TickLabelInterpreter', 'tex');
            xlim(axG, [0.5 numel(ageOrder) + 0.6]);
            title(axG, ttl, 'Interpreter', 'none'); ylabel(axG, sprintf('%s AUC_{norm} (POI)', band));
            text(axG, 0.98, 0.97, sprintf('Age (continuous): p_{Holm} = %s', fmt_p(pAge)), ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9);
            grid(axG, 'on'); box(axG, 'off');

            % ---------- 3. condition ----------
            hold(axC, 'on');
            conds = condOrder(ismember(condOrder, string(categories(Tm.condition))));
            for s = 1:numel(subj)
                Ts = Tm(Tm.subject == subj(s), :);
                [tf, x] = ismember(string(Ts.condition), conds);
                [x, o] = sort(x(tf)); y = Ts.(char(dv))(tf); y = y(o);
                plot(axC, x, y, '-', 'Color', [0.6 0.6 0.6 0.25], 'LineWidth', 0.6);
            end
            % one row per condition at the mean age (z = 0); the condition values are
            % taken from the data so they keep its (ordinal) categorical type
            rowsK = arrayfun(@(cc) find(string(Tm.condition) == cc, 1), conds);
            newT = Tm(rowsK, :);
            newT.AgeYears_z(:) = 0;
            [mu, muCI] = predict(lme, newT, 'Conditional', false);
            for k = 1:numel(conds)
                col = get_condition_color(conds(k), C);
                errorbar(axC, k, mu(k), mu(k) - muCI(k,1), muCI(k,2) - mu(k), 'o', 'Color', col, ...
                    'MarkerFaceColor', col, 'MarkerSize', 7, 'LineWidth', 2, 'CapSize', 8);
            end
            plot(axC, 1:numel(conds), mu, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.2);
            set(axC, 'XTick', 1:numel(conds), 'XTickLabel', conds);
            xlim(axC, [0.6 numel(conds) + 0.4]);
            title(axC, ttl, 'Interpreter', 'none'); ylabel(axC, sprintf('%s AUC_{norm} (POI)', band));
            text(axC, 0.98, 0.97, {sprintf('Condition: p_{Holm} = %s', fmt_p(pCond)), ...
                sprintf('Age × condition: p_{Holm} = %s', fmt_p(pInt))}, ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9);
            grid(axC, 'on'); box(axC, 'off');
        end
    end

    model = 'Model: DV ~ age * condition + (1|subject), effects coding, REML; p Holm-adjusted across the models of the band set';
    legendA = 'Line: age slope averaged over conditions, with 95% CI';
    if P.show_log_age
        legendA = [legendA '. Dashed: log(age) model (sensitivity analysis)'];
    end
    title(tlA, {sprintf('Age effect | band set %s', setName), ...
        'Dots: one per participant, mean over conditions, coloured by age group', legendA, model}, ...
        'FontSize', 10, 'Interpreter', 'none');
    title(tlG, {sprintf('Age groups (display only; the test is continuous age) | band set %s', setName), ...
        'Dots: one per participant, mean over conditions. Markers: group mean with 95% CI', model}, 'FontSize', 10, 'Interpreter', 'none');
    title(tlC, {sprintf('Condition effect | band set %s', setName), ...
        'Markers: model estimate at the mean age, with 95% CI. Grey lines: each participant across conditions', model}, 'FontSize', 10, 'Interpreter', 'none');

    save_fig(figA, fullfile(outDir, 'MAIN_EFFECT_AGE_CONTINUOUS.png'));
    save_fig(figG, fullfile(outDir, 'MAIN_EFFECT_AGE_GROUPS.png'));
    save_fig(figC, fullfile(outDir, 'MAIN_EFFECT_CONDITION.png'));
    fprintf('Saved main-effect figures in %s\n', outDir);
end

function fig = new_figure(nRows, nCols, HC)
    fig = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [80 80 430 * nCols 360 * nRows + 90]);
end

function save_fig(fig, f)
    exportgraphics(fig, f, 'Resolution', 150);
    close(fig);
end

function s = fmt_p(p)
    if ~isfinite(p)
        s = 'NA';
    elseif p < 0.001
        s = sprintf('%.1e', p);
    else
        s = sprintf('%.3f', p);
    end
end

function s = age_range_text(T, group)
% '2.6-5.9 y' style range of the participants in an age group
    a = T.AgeYears(string(T.age_group) == group);
    if isempty(a)
        s = '';
    else
        s = sprintf('%.1f–%.1f y', min(a), max(a));
    end
end
