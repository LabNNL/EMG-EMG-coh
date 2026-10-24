function make_band_triplet_figure(T, pairName, metricFamily, plotMode, outFile, visibleMode, C, HC, primaryTbl)
% metricFamily = 'mean' or 'auc'
% plotMode = 'condition', 'age', or 'age_condition'
% primaryTbl = CONTINUOUS_AGE_LME_TABLE: the omnibus p-values shown are the
% Holm-adjusted ones of the primary model (continuous age x condition); the
% figure never fits a model of its own. Age groups are for display only.

    if nargin < 9
        primaryTbl = table();
    end

    fig = figure('Visible', visibleMode, 'Color', 'w', 'Position', [100 100 1800 520]);

    legendHandlesMaster = gobjects(0);
    legendLabelsMaster = {};

    switch lower(metricFamily)
        case 'mean'
            dvList = {'Alpha','Beta','Gamma'};
            familyLabel = 'Mean coherence';
        case 'auc'
            dvList = {'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm'};
            familyLabel = 'Normalized AUC';
        case 'peak'
            dvList = {'Alpha_Peak','Beta_Peak','Gamma_Peak'};
            familyLabel = 'Peak coherence';
        otherwise
            error('Unknown metricFamily: %s', metricFamily);
    end

    scopeLabel = get_metric_scope_label(HC.analysis.metric_scope);

    bandNames = {'Alpha','Beta','Gamma'};

    for i = 1:3
        ax = subplot(1,3,i);
        hold(ax, 'on');

        dv = dvList{i};
        bandName = bandNames{i};

        if ~ismember(dv, T.Properties.VariableNames)
            axis(ax, 'off');
            title(ax, sprintf('%s not found', dv), 'Interpreter', 'none');
            continue;
        end

        Tsub = T(~isnan(T.(dv)), :);
        if isempty(Tsub)
            axis(ax, 'off');
            title(ax, sprintf('%s | no data', dv), 'Interpreter', 'none');
            continue;
        end
        nSubj = numel(unique(Tsub.subject));
        panelTitle = sprintf('%s (n = %d)', bandName, nSubj);

        switch lower(plotMode)

            case 'condition'
                groupVar = 'condition';
                groupOrder = cellstr(C.plotting.condition_order);
                colorFun = @(x)get_condition_color(x, C);
                xLabel = 'Condition';

                [groupLevels, legH, legL] = plot_simple_boxpanel(ax, Tsub, dv, groupVar, groupOrder, colorFun, xLabel, panelTitle, pairName, C);

                if i == 1
                    legendHandlesMaster = legH;
                    legendLabelsMaster = legL;
                end

                [~, p_main, ~, ok] = primary_model_p(primaryTbl, pairName, dv);

                txtLines = omnibus_lines(ok, {format_p_text('Condition p_{Holm}', p_main)});
                add_omnibus_text(ax, txtLines);

                pw = get_condition_pairwise_stats(Tsub, dv, HC.posthoc);
                pw = apply_pairwise_p_correction(pw, HC.posthoc.correction);
                % ymax = max(Tsub.(dv), [], 'omitnan');
                % if isempty(ymax) || isnan(ymax) || ymax <= 0, ymax = 1; end
                % add_sig_bars(ax, pw, groupLevels, 0.88*ymax, 0.06*ymax, HC);
                apply_shared_coherence_ylim(ax, HC);
                add_sig_bars(ax, pw, groupLevels, [], [], HC);

            case 'age'
                groupVar = 'age_group';
                groupOrder = cellstr(C.plotting.age_order);
                colorFun = @(x)get_age_color(x, C);
                xLabel = 'Age group';

                panelTitle = sprintf('%s (n = %d)', bandName, nSubj);
                [groupLevels, legH, legL] = plot_simple_boxpanel(ax, Tsub, dv, groupVar, groupOrder, colorFun, xLabel, panelTitle, pairName, C);
                if i == 1
                    legendHandlesMaster = legH;
                    legendLabelsMaster = legL;
                end

                [p_main, ~, ~, ok] = primary_model_p(primaryTbl, pairName, dv);

                txtLines = omnibus_lines(ok, {format_p_text('Age (continuous) p_{Holm}', p_main)});
                add_omnibus_text(ax, txtLines);

                pw = get_age_pairwise_stats(Tsub, dv, HC.posthoc);
                pw = apply_pairwise_p_correction(pw, HC.posthoc.correction);
                apply_shared_coherence_ylim(ax, HC);
                add_sig_bars(ax, pw, groupLevels, [], [], HC);

            case 'age_condition'
                mainGroupVar = 'age_group';
                mainGroupOrder = cellstr(C.plotting.age_order);
                subGroupVar = 'condition';
                subGroupOrder = cellstr(C.plotting.condition_order);
                subColorFun = @(x)get_condition_color(x, C);

                panelTitle = sprintf('%s (n = %d)', bandName, nSubj);

                [offsets, mainLevels, subLevels, legH, legL] = plot_grouped_boxpanel(ax, Tsub, dv, mainGroupVar, mainGroupOrder, subGroupVar, subGroupOrder, subColorFun, panelTitle, pairName, C);

                if i == 1
                    legendHandlesMaster = legH;
                    legendLabelsMaster = legL;
                end

                [p_age, p_cond, p_int, ok] = primary_model_p(primaryTbl, pairName, dv);

                txtLines = omnibus_lines(ok, { format_p_text('Age (continuous) p_{Holm}', p_age), format_p_text('Condition p_{Holm}', p_cond), format_p_text('Age x Condition p_{Holm}', p_int)});
                add_omnibus_text(ax, txtLines);

                pw = get_condition_pairwise_stats_within_age_simple(Tsub, dv, HC.posthoc);
                pw = apply_pairwise_p_correction(pw, HC.posthoc.correction);
                % ymax = max(Tsub.(dv), [], 'omitnan');
                % if isempty(ymax) || isnan(ymax) || ymax <= 0, ymax = 1; end
                % add_sig_bars_grouped_boxes(ax, pw, mainLevels, subLevels, offsets, 0.82*ymax, 0.06*ymax, HC);
                apply_shared_coherence_ylim(ax, HC);
                add_sig_bars_grouped_boxes(ax, pw, mainLevels, subLevels, offsets, [], [], HC);

            case 'condition_age'
                mainGroupVar = 'condition';
                mainGroupOrder = cellstr(C.plotting.condition_order);
                subGroupVar = 'age_group';
                subGroupOrder = cellstr(C.plotting.age_order);
                subColorFun = @(x)get_age_color(x, C);

                panelTitle = sprintf('%s (n = %d)', bandName, nSubj);

                [offsets, mainLevels, subLevels, legH, legL] = plot_grouped_boxpanel(ax, Tsub, dv, mainGroupVar, mainGroupOrder, subGroupVar, subGroupOrder, subColorFun, panelTitle, pairName, C);

                if i == 1
                    legendHandlesMaster = legH;
                    legendLabelsMaster = legL;
                end

                [p_age, p_cond, p_int, ok] = primary_model_p(primaryTbl, pairName, dv);

                txtLines = omnibus_lines(ok, { format_p_text('Age (continuous) p_{Holm}', p_age), format_p_text('Condition p_{Holm}', p_cond), format_p_text('Age x Condition p_{Holm}', p_int)});
                add_omnibus_text(ax, txtLines);

                pw = get_age_pairwise_stats_within_condition_simple(Tsub, dv, HC.posthoc);
                pw = apply_pairwise_p_correction(pw, HC.posthoc.correction);
                apply_shared_coherence_ylim(ax, HC);
                add_sig_bars_grouped_boxes(ax, pw, mainLevels, subLevels, offsets, [], [], HC);

            otherwise
                error('Unknown plotMode: %s', plotMode);
        end
    end

    phaseTxt = get_pair_phase_text(pairName, C);

    mainTitle = strtrim(sprintf('%s | %s %s', pairName, familyLabel, scopeLabel));
    sgtitle({mainTitle, phaseTxt}, 'Interpreter', 'none');

    if ~isempty(legendHandlesMaster)
        lgd = legend(legendHandlesMaster, legendLabelsMaster, 'Orientation', 'horizontal', 'Interpreter', 'none');

        % Remove the ugly big box
        lgd.Box = 'off';

        % Make it compact
        lgd.ItemTokenSize = [12 8];   % smaller color boxes
        lgd.FontSize = 10;

        % Precise positioning (this is the key)
        lgd.Units = 'normalized';
        lgd.Position = [0.70 0.93 0.20 0.04];
    end

    footer = sprintf(['Omnibus p: primary model DV ~ AgeYears_z * condition + (1|subject), %s coding, %s, %s DF, ' ...
        'Holm-adjusted across the models of CONTINUOUS_AGE_LME_TABLE. Bars: %s post hoc, %s-corrected. ' ...
        'Age groups are for display only.'], HC.lme.dummy_var_coding, HC.lme.fit_method, HC.lme.df_method, HC.posthoc.mode, HC.posthoc.correction);
    annotation(fig, 'textbox', [0 0 1 0.04], 'String', footer, 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Interpreter', 'none');

    saveas(fig, outFile);
    close(fig);
end

function [pAge, pCond, pInt, ok] = primary_model_p(primaryTbl, pairName, dv)
% Holm-adjusted p-values of the primary model for this pair and metric
    pAge = NaN; pCond = NaN; pInt = NaN; ok = false;
    if ~istable(primaryTbl) || isempty(primaryTbl) || ~ismember('p_age_linear_holm', primaryTbl.Properties.VariableNames)
        return;
    end
    r = find(string(primaryTbl.pair_name) == string(pairName) & string(primaryTbl.metric) == string(dv), 1);
    if isempty(r)
        return;
    end
    ok = true;
    pAge  = primaryTbl.p_age_linear_holm(r);
    pCond = primaryTbl.p_condition_holm(r);
    pInt  = primaryTbl.p_age_condition_holm(r);
end

function txtLines = omnibus_lines(ok, txtLines)
    if ~ok
        txtLines = {'not in primary model'};
    end
end

function [groupLevels, legendHandles, legendLabels] = plot_simple_boxpanel(ax, T, dv, groupVar, groupOrder, colorFun, xLabel, panelTitle, pairName, C)
    if iscategorical(T.(groupVar))
        T.(groupVar) = removecats(T.(groupVar));
    end

    presentGroups = categories(T.(groupVar));
    groupLevels = keep_present_in_order(groupOrder, presentGroups);

    legendHandles = gobjects(0);
    legendLabels = {};

    for ig = 1:numel(groupLevels)
        gName = groupLevels{ig};
        idx = T.(groupVar) == gName;

        if ~any(idx)
            continue;
        end

        x = categorical(T.(groupVar)(idx), groupLevels, groupLevels, 'Ordinal', true);
        b = boxchart(ax, x, T.(dv)(idx), 'DisplayName', gName);
        apply_boxchart_color(b, colorFun(gName));

        legendHandles(end+1) = b; %#ok<AGROW>
        legendLabels{end+1} = gName; %#ok<AGROW>
    end

    ymax = max(T.(dv), [], 'omitnan');
    if isempty(ymax) || isnan(ymax) || ymax <= 0
        ymax = 1;
    end

    ylim(ax, [0 1.20*ymax]);
    xlabel(ax, xLabel);
    ylabel(ax, dv, 'Interpreter', 'none');
    title(ax, panelTitle, 'Interpreter', 'none');
    grid(ax, 'on');
end




function [offsets, mainLevels, subLevels, legendHandles, legendLabels] = plot_grouped_boxpanel(ax, T, dv, mainGroupVar, mainGroupOrder, subGroupVar, subGroupOrder, subColorFun, panelTitle, pairName, C)

    if iscategorical(T.(mainGroupVar))
        T.(mainGroupVar) = removecats(T.(mainGroupVar));
    end
    if iscategorical(T.(subGroupVar))
        T.(subGroupVar) = removecats(T.(subGroupVar));
    end

    mainPresent = categories(T.(mainGroupVar));
    subPresent  = categories(T.(subGroupVar));

    mainLevels = keep_present_in_order(mainGroupOrder, mainPresent);
    subLevels  = keep_present_in_order(subGroupOrder, subPresent);

    nSub = numel(subLevels);
    offsets = linspace(-0.32, 0.32, max(nSub,2));
    if nSub == 1
        offsets = 0;
    end

    legendHandles = gobjects(0);
    legendLabels = {};

    for isub = 1:nSub
        subName = subLevels{isub};
        idxSub = T.(subGroupVar) == subName;

        if ~any(idxSub)
            continue;
        end

        xBase = grp2idx(categorical(T.(mainGroupVar)(idxSub), mainLevels, mainLevels, 'Ordinal', true));
        xPos = xBase + offsets(isub);

        b = boxchart(ax, xPos, T.(dv)(idxSub), 'BoxWidth', 0.16, 'DisplayName', subName);

        apply_boxchart_color(b, subColorFun(subName));

        legendHandles(end+1) = b; %#ok<AGROW>
        legendLabels{end+1} = subName; %#ok<AGROW>
    end

    ymax = max(T.(dv), [], 'omitnan');
    if isempty(ymax) || isnan(ymax) || ymax <= 0
        ymax = 1;
    end

    xlim(ax, [0.5 numel(mainLevels)+0.5]);
    set(ax, 'XTick', 1:numel(mainLevels), 'XTickLabel', mainLevels);
    xlabel(ax, mainGroupVar, 'Interpreter', 'none');
    ylabel(ax, dv, 'Interpreter', 'none');
    ylim(ax, [0 1.25*ymax]);
    title(ax, panelTitle, 'Interpreter', 'none');
    grid(ax, 'on');
end
