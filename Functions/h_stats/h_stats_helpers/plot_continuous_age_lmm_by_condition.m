function plot_continuous_age_lmm_by_condition(Tm, lme, dv, pairName, C, HC, outFile, varargin)

    p = inputParser;
    addParameter(p, 'powerVar', "", @(x) ischar(x) || isstring(x));
    addParameter(p, 'cycleVar', "", @(x) ischar(x) || isstring(x));
    addParameter(p, 'ageVarRaw', "AgeYears", @(x) ischar(x) || isstring(x));
    addParameter(p, 'ageVarModel', "AgeYears_z", @(x) ischar(x) || isstring(x));
    addParameter(p, 'conditionVar', "condition", @(x) ischar(x) || isstring(x));
    addParameter(p, 'subjectVar', "subject", @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});

    powerVar    = string(p.Results.powerVar);
    cycleVar    = string(p.Results.cycleVar);
    ageVarRaw   = string(p.Results.ageVarRaw);
    ageVarModel = string(p.Results.ageVarModel);
    conditionVar = string(p.Results.conditionVar);
    subjectVar   = string(p.Results.subjectVar);

    P = HC.plot.continuous_age_lmm;

    % ---------------- Basic checks ----------------
    if isempty(Tm) || height(Tm) < 5
        return;
    end

    if ~ismember(dv, Tm.Properties.VariableNames)
        warning('DV %s not found in Tm. Skipping continuous-age plot.', dv);
        return;
    end

    if ~ismember(ageVarRaw, string(Tm.Properties.VariableNames))
        warning('Age variable %s not found in Tm. Skipping continuous-age plot.', ageVarRaw);
        return;
    end

    if ~ismember(conditionVar, string(Tm.Properties.VariableNames))
        warning('Condition variable %s not found in Tm. Skipping continuous-age plot.', conditionVar);
        return;
    end

    Tm = Tm(~isnan(Tm.(dv)) & ~isnan(Tm.(ageVarRaw)), :);

    if height(Tm) < 5
        return;
    end

    % If AgeYears_z missing, recreate locally as fallback
    if ~ismember(ageVarModel, string(Tm.Properties.VariableNames))
        muAge = mean(Tm.(ageVarRaw), 'omitnan');
        sdAge = std(Tm.(ageVarRaw), 0, 'omitnan');
        if sdAge > 0
            Tm.(ageVarModel) = (Tm.(ageVarRaw) - muAge) ./ sdAge;
        else
            Tm.(ageVarModel) = zeros(height(Tm),1);
        end
    end

    % ---------------- Condition order ----------------
    condLevels = categories(removecats(Tm.(conditionVar)));

    if isfield(C, 'plotting') && isfield(C.plotting, 'condition_order')
        wanted = cellstr(C.plotting.condition_order);
        condOrder = wanted(ismember(wanted, condLevels));
        extras = setdiff(condLevels, condOrder, 'stable');
        condOrder = [condOrder(:); extras(:)];
    else
        condOrder = condLevels;
    end

    % ---------------- X grid for predictions ----------------
    xMin = min(Tm.(ageVarRaw));
    xMax = max(Tm.(ageVarRaw));

    if xMin == xMax
        xMin = xMin - 1;
        xMax = xMax + 1;
    end

    xGrid = linspace(xMin, xMax, P.n_grid)';

    % Linear mapping AgeYears -> AgeYears_z
    % (works because z-score is linear)
    ageFit = polyfit(Tm.(ageVarRaw), Tm.(ageVarModel), 1);
    xGridZ = polyval(ageFit, xGrid);

    % ---------------- Figure ----------------
    fig = figure( 'Visible', P.visible, 'Color', 'w', 'Position', [100 100 820 560]);

    ax = axes(fig);
    hold(ax, 'on');

    % ---------------- Scatter points + model predictions ----------------
    for ic = 1:numel(condOrder)

        condName = condOrder{ic};
        idx = Tm.(conditionVar) == condName;

        if ~any(idx)
            continue;
        end

        col = get_condition_color(condName, C);

        % ----- raw points -----
        try
            scatter(ax, Tm.(ageVarRaw)(idx), Tm.(dv)(idx), P.point_size, 'filled', 'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'MarkerFaceAlpha', P.point_alpha, 'MarkerEdgeAlpha', P.point_alpha, 'DisplayName', char(condName));
        catch
            % fallback if transparency unsupported
            scatter(ax, Tm.(ageVarRaw)(idx), Tm.(dv)(idx), P.point_size, 'filled', 'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'DisplayName', char(condName));
        end

        % ----- prediction table -----
        % start from one existing row, then replicate
        firstIdx = find(idx, 1, 'first');
        newTbl = Tm(firstIdx, :);
        newTbl = newTbl(ones(P.n_grid,1), :);

        % set condition while preserving the exact categorical type
        % including categories order and ordinal/non-ordinal status
        newTbl.(conditionVar) = repmat(Tm.(conditionVar)(firstIdx), P.n_grid, 1);

        % set age
        newTbl.(ageVarRaw) = xGrid;
        newTbl.(ageVarModel) = xGridZ;

        % set subject (needed structurally for fitlme new data)
        if ismember(subjectVar, string(Tm.Properties.VariableNames))
            newTbl.(subjectVar) = repmat(Tm.(subjectVar)(1), P.n_grid, 1);
        end

        % fix optional covariates at their mean
        if powerVar ~= "" && ismember(powerVar, string(Tm.Properties.VariableNames))
            newTbl.(powerVar) = repmat(mean(Tm.(powerVar), 'omitnan'), P.n_grid, 1);
        end

        if cycleVar ~= "" && ismember(cycleVar, string(Tm.Properties.VariableNames))
            newTbl.(cycleVar) = repmat(mean(Tm.(cycleVar), 'omitnan'), P.n_grid, 1);
        end

        % ----- predict from LMM -----
        try
            [yHat, yCI] = predict(lme, newTbl, 'Conditional', false);
        catch
            % fallback
            [yHat, yCI] = predict(lme, newTbl);
            warning('predict(...,''Conditional'',false) failed. Used default predict() instead.');
        end

        % ----- CI ribbon -----
        if P.show_ci && ~isempty(yCI)
            patch(ax, [xGrid; flipud(xGrid)], [yCI(:,1); flipud(yCI(:,2))], col, 'FaceAlpha', P.ci_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end

        % ----- predicted line -----
        plot(ax, xGrid, yHat, '-', 'Color', col, 'LineWidth', P.line_width, 'HandleVisibility', 'off');
    end

    % ---------------- Labels ----------------
    xlabel(ax, 'Age (years)');
    ylabel(ax, strrep(dv, '_', ' '));

    title(ax, sprintf('%s | %s | Continuous age LMM', char(pairName), strrep(dv, '_', ' ')), 'Interpreter', 'none');

    grid(ax, 'on');
    box(ax, 'off');

    if P.use_fixed_ylim && isfield(P, 'ylim') && numel(P.ylim) == 2
        ylim(ax, P.ylim);
    end

    legend(ax, 'Location', 'best', 'Interpreter', 'none');

    % ---------------- Save ----------------
    outDir = fileparts(outFile);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    saveas(fig, outFile);
    close(fig);
end

% function col = local_get_condition_color(condName, C)

%     % if you already have a function get_condition_color, use it
%     if exist('get_condition_color', 'file') == 2
%         try
%             col = get_condition_color(condName, C);
%             return;
%         catch
%         end
%     end

%     % fallback colors
%     switch char(string(condName))
%         case 'Flat'
%             col = [0.35 0.35 0.35];
%         case 'Medium'
%             col = [0.20 0.55 0.85];
%         case 'High'
%             col = [0.85 0.35 0.35];
%         otherwise
%             col = [0.50 0.50 0.50];
%     end
% end
