%% participant_summary_matlab.m
% Equivalent MATLAB of the Python participant summary script
% - Loads CSV/TSV metadata file
% - Creates AgeYears from AgeMonths if needed
% - Detects numeric-like columns
% - Saves summary tables
% - Generates a few basic plots

clear; clc; close all;

%% =========================
% CONFIG
% ==========================
C = config_emg();

FILE = fullfile(C.paths.code_dir, "Metadata", "participants_metadata_EMG.csv");  
OUT_DIR = fullfile(C.paths.results_dir, "participant_summary_outputs");

if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

PLOT_DIR = fullfile(C.paths.plot_dir, "participant_summary_plots");
if ~exist(PLOT_DIR, 'dir')
    mkdir(PLOT_DIR);
end

% ---------- Custom colors ----------
AGEGROUP_COLORS = struct();
AGEGROUP_COLORS.(matlab.lang.makeValidName("Jeunes Enfants")) = [0.84 0.73 0.92];
AGEGROUP_COLORS.(matlab.lang.makeValidName("Enfants"))        = [0.72 0.55 0.86];
AGEGROUP_COLORS.(matlab.lang.makeValidName("Adolescents"))    = [0.56 0.37 0.75];
AGEGROUP_COLORS.(matlab.lang.makeValidName("Adultes"))        = [0.38 0.20 0.54];

SEX_COLORS = struct();
SEX_COLORS.F       = [0.2980 0.4706 0.6588];  % #4C78A8
SEX_COLORS.M       = [0.9608 0.5216 0.1294];  % #F58518
SEX_COLORS.Female  = [0.2980 0.4706 0.6588];
SEX_COLORS.Male    = [0.9608 0.5216 0.1294];
SEX_COLORS.Femmes  = [0.2980 0.4706 0.6588];
SEX_COLORS.Hommes  = [0.9608 0.5216 0.1294];

AGE_ORDER = ["Jeunes Enfants", "Enfants", "Adolescents", "Adultes"];

%% =========================
% LOAD TABLE
% ==========================
opts = detectImportOptions(FILE);
T = readtable(FILE, opts);

% Clean variable names a bit if needed
T.Properties.VariableNames = matlab.lang.makeValidName(strtrim(T.Properties.VariableNames));

% Keep original display names if you want
disp(" ");
disp("====================");
disp("PARTICIPANT SUMMARY");
disp("====================");
disp(" ");

nParticipants = height(T);
fprintf("Total participants: %d\n\n", nParticipants);

%% =========================
% CREATE AgeYears IF NEEDED
% ==========================
vars = string(T.Properties.VariableNames);

if any(vars == "AgeMonths") && ~any(vars == "AgeYears")
    T = addvars(T, T.AgeMonths ./ 12, 'Before', 1, 'NewVariableNames', 'AgeYears');
end

%% =========================
% CONVERT NUMERIC-LIKE COLUMNS
% ==========================
vars = string(T.Properties.VariableNames);

for i = 1:numel(vars)
    v = vars(i);
    col = T.(v);

    if isnumeric(col)
        continue;
    end

    % Convert strings / cells / categoricals to string first
    if iscell(col)
        s = string(col);
    elseif isstring(col)
        s = col;
    elseif iscategorical(col)
        s = string(col);
    else
        continue;
    end

    s = strtrim(s);
    s(ismissing(s) | s == "" | lower(s) == "na" | lower(s) == "nan") = missing;

    numCol = str2double(s);
    propNumeric = mean(~isnan(numCol) | ismissing(s));

    % Same spirit as Python: if at least ~50% numeric-looking, convert
    if propNumeric >= 0.5
        T.(v) = numCol;
    else
        T.(v) = s;
    end
end

%% =========================
% SPLIT NUMERIC / CATEGORICAL
% ==========================
vars = string(T.Properties.VariableNames);
numericMask = false(size(vars));

for i = 1:numel(vars)
    numericMask(i) = isnumeric(T.(vars(i))) || islogical(T.(vars(i)));
end

numericVars = vars(numericMask);
categoricalVars = vars(~numericMask);

%% =========================
% 1) SAVE RAW PARTICIPANT TABLE
% ==========================
writetable(T, fullfile(OUT_DIR, "PARTICIPANT_SUMMARY.csv"));

%% =========================
% 2) OVERALL NUMERIC SUMMARY
% ==========================
overallNumeric = table();

for i = 1:numel(numericVars)
    v = numericVars(i);
    x = T.(v);

    if ~isnumeric(x)
        continue;
    end

    valid = ~isnan(x);
    s = x(valid);

    if isempty(s)
        continue;
    end

    newRow = table( ...
        string(v), ...
        sum(valid), ...
        sum(~valid), ...
        mean(s), ...
        std(s, 0), ...
        median(s), ...
        min(s), ...
        max(s), ...
        'VariableNames', {'variable','N','missing','mean','sd','median','min','max'} ...
    );

    overallNumeric = [overallNumeric; newRow]; %#ok<AGROW>
end

writetable(overallNumeric, fullfile(OUT_DIR, "OVERALL_NUMERIC_SUMMARY.csv"));

%% =========================
% 3) OVERALL CATEGORICAL SUMMARY
% ==========================
overallCategorical = table();

for i = 1:numel(categoricalVars)
    v = categoricalVars(i);
    col = T.(v);

    if iscell(col)
        s = string(col);
    elseif isstring(col)
        s = col;
    elseif iscategorical(col)
        s = string(col);
    else
        continue;
    end

    s = strtrim(s);
    s(ismissing(s) | s == "") = "Missing";

    [u, ~, idx] = unique(s);
    counts = accumarray(idx, 1);

    temp = table( ...
        repmat(string(v), numel(u), 1), ...
        string(u), ...
        counts, ...
        100 * counts / height(T), ...
        'VariableNames', {'variable','level','count','percent'} ...
    );

    overallCategorical = [overallCategorical; temp]; %#ok<AGROW>
end

writetable(overallCategorical, fullfile(OUT_DIR, "OVERALL_CATEGORICAL_SUMMARY.csv"));

%% =========================
% 4) NUMERIC SUMMARY BY AGE GROUP
% ==========================
agegroupNumeric = table();

if any(vars == "AgeGroup")
    ageGroupStr = string(T.AgeGroup);

    for g = 1:numel(AGE_ORDER)
        groupName = AGE_ORDER(g);
        maskGroup = ageGroupStr == groupName;

        if ~any(maskGroup)
            continue;
        end

        Tg = T(maskGroup, :);

        for i = 1:numel(numericVars)
            v = numericVars(i);
            x = Tg.(v);

            if ~isnumeric(x)
                continue;
            end

            valid = ~isnan(x);
            s = x(valid);

            if isempty(s)
                continue;
            end

            newRow = table( ...
                string(groupName), ...
                string(v), ...
                sum(valid), ...
                sum(~valid), ...
                mean(s), ...
                std(s, 0), ...
                median(s), ...
                min(s), ...
                max(s), ...
                'VariableNames', {'AgeGroup','variable','N','missing','mean','sd','median','min','max'} ...
            );

            agegroupNumeric = [agegroupNumeric; newRow]; %#ok<AGROW>
        end
    end
end

writetable(agegroupNumeric, fullfile(OUT_DIR, "AGEGROUP_NUMERIC_SUMMARY.csv"));

%% =========================
% 5) CATEGORICAL SUMMARY BY AGE GROUP
% ==========================
agegroupCategorical = table();

if any(vars == "AgeGroup")
    ageGroupStr = string(T.AgeGroup);

    for g = 1:numel(AGE_ORDER)
        groupName = AGE_ORDER(g);
        maskGroup = ageGroupStr == groupName;

        if ~any(maskGroup)
            continue;
        end

        Tg = T(maskGroup, :);

        for i = 1:numel(categoricalVars)
            v = categoricalVars(i);

            if v == "AgeGroup"
                continue;
            end

            col = Tg.(v);

            if iscell(col)
                s = string(col);
            elseif isstring(col)
                s = col;
            elseif iscategorical(col)
                s = string(col);
            else
                continue;
            end

            s = strtrim(s);
            s(ismissing(s) | s == "") = "Missing";

            [u, ~, idx] = unique(s);
            counts = accumarray(idx, 1);

            temp = table( ...
                repmat(string(groupName), numel(u), 1), ...
                repmat(string(v), numel(u), 1), ...
                string(u), ...
                counts, ...
                100 * counts / height(Tg), ...
                'VariableNames', {'AgeGroup','variable','level','count','percent_within_agegroup'} ...
            );

            agegroupCategorical = [agegroupCategorical; temp]; %#ok<AGROW>
        end
    end
end

writetable(agegroupCategorical, fullfile(OUT_DIR, "AGEGROUP_CATEGORICAL_SUMMARY.csv"));

%% =========================
% PRINT SHORT RECAP
% ==========================
disp("Saved files:");
disp(fullfile(OUT_DIR, "PARTICIPANT_SUMMARY.csv"));
disp(fullfile(OUT_DIR, "OVERALL_NUMERIC_SUMMARY.csv"));
disp(fullfile(OUT_DIR, "OVERALL_CATEGORICAL_SUMMARY.csv"));
disp(fullfile(OUT_DIR, "AGEGROUP_NUMERIC_SUMMARY.csv"));
disp(fullfile(OUT_DIR, "AGEGROUP_CATEGORICAL_SUMMARY.csv"));

if ~isempty(overallNumeric)
    disp(" ");
    disp("OVERALL NUMERIC SUMMARY");
    disp(overallNumeric);
end

if ~isempty(overallCategorical)
    disp(" ");
    disp("OVERALL CATEGORICAL SUMMARY");
    disp(overallCategorical(1:min(20,height(overallCategorical)), :));
end

if ~isempty(agegroupNumeric)
    disp(" ");
    disp("AGE GROUP NUMERIC SUMMARY");
    disp(agegroupNumeric);
end

if ~isempty(agegroupCategorical)
    disp(" ");
    disp("AGE GROUP CATEGORICAL SUMMARY");
    disp(agegroupCategorical(1:min(30,height(agegroupCategorical)), :));
end

%% =========================
% 7) PLOTS
% ==========================

% ------------------------------------------------------------
% A) Boxplot of AgeYears by AgeGroup
% ------------------------------------------------------------
if any(vars == "AgeGroup") && any(string(T.Properties.VariableNames) == "AgeYears")

    ageGroupStr = categorical(string(T.AgeGroup), AGE_ORDER, AGE_ORDER, 'Ordinal', true);
    validIdx = ~isundefined(ageGroupStr) & ~isnan(T.AgeYears);

    if any(validIdx)
        fig = figure('Color','w','Position',[100 100 950 550]);
        ax = axes(fig); hold(ax, 'on');

        presentGroups = categories(removecats(ageGroupStr(validIdx)));
        presentGroups = AGE_ORDER(ismember(AGE_ORDER, presentGroups));

        legendHandles = gobjects(0);

        for k = 1:numel(presentGroups)
            gName = presentGroups(k);
            idx = validIdx & (string(T.AgeGroup) == gName);

            if ~any(idx)
                continue;
            end

            x = categorical(string(T.AgeGroup(idx)), presentGroups, presentGroups, 'Ordinal', true);
            b = boxchart(ax, x, T.AgeYears(idx), 'DisplayName', char(gName));

            apply_boxchart_color(b, AGEGROUP_COLORS.(matlab.lang.makeValidName(char(gName))));
            legendHandles(end+1) = b; %#ok<AGROW>
        end

        xlabel(ax, "Groupe d'âge");
        ylabel(ax, "Âge (années)");
        title(ax, "Âge par groupe d'âge", 'Interpreter', 'none');

        grid(ax, 'on');
        ax.GridAlpha = 0.12;
        ax.FontSize = 11;
        ax.LineWidth = 1.1;
        box(ax, 'off');
        xtickangle(ax, 20);

        if ~isempty(legendHandles)
            legend(ax, legendHandles, cellstr(presentGroups), 'Location', 'best');
        end

        exportgraphics(fig, fullfile(PLOT_DIR, "boxplot_age_by_agegroup.png"), 'Resolution', 300);
        close(fig);
    end
end

% ------------------------------------------------------------
% B) Number of participants per AgeGroup
% ------------------------------------------------------------
if any(vars == "AgeGroup")
    ageGroupStr = string(T.AgeGroup);
    availableGroups = AGE_ORDER(ismember(AGE_ORDER, unique(ageGroupStr)));

    counts = zeros(size(availableGroups));
    barColors = zeros(numel(availableGroups), 3);

    for k = 1:numel(availableGroups)
        counts(k) = sum(ageGroupStr == availableGroups(k));
        barColors(k,:) = AGEGROUP_COLORS.(matlab.lang.makeValidName(availableGroups(k)));
    end

    if ~isempty(availableGroups)
        fig = figure('Color','w','Position',[100 100 700 500]);
        b = bar(counts, 'FaceColor', 'flat');
        b.CData = barColors;

        ax = gca;
        ax.XTick = 1:numel(availableGroups);
        ax.XTickLabel = cellstr(availableGroups);
        xtickangle(20);

        title("Répartition des participants par groupe d'âge");
        xlabel("Groupe d'âge");
        ylabel("Nombre de participants");
        box off;
        set(gca, 'FontSize', 11, 'LineWidth', 1.1);

        for k = 1:numel(counts)
            text(k, counts(k) + 0.3, sprintf('%d', counts(k)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
        end

        exportgraphics(fig, fullfile(PLOT_DIR, "barplot_n_by_agegroup.png"), 'Resolution', 300);
        close(fig);
    end
end

% ------------------------------------------------------------
% C) Sex distribution overall
% ------------------------------------------------------------
sexCandidates = ["Sex", "Gender", "Sexe"];
sexVar = "";

for i = 1:numel(sexCandidates)
    if any(string(T.Properties.VariableNames) == sexCandidates(i))
        sexVar = sexCandidates(i);
        break;
    end
end

if sexVar ~= ""
    sexStr = string(T.(sexVar));
    sexStr(ismissing(sexStr) | strtrim(sexStr) == "") = "Missing";

    levels = unique(sexStr, 'stable');
    counts = zeros(size(levels));
    colors = repmat([0.6 0.6 0.6], numel(levels), 1);

    for k = 1:numel(levels)
        counts(k) = sum(sexStr == levels(k));
        if isfield(SEX_COLORS, matlab.lang.makeValidName(levels(k)))
            colors(k,:) = SEX_COLORS.(matlab.lang.makeValidName(levels(k)));
        end
    end

    fig = figure('Color','w','Position',[100 100 600 500]);
    b = bar(counts, 'FaceColor', 'flat');
    b.CData = colors;

    ax = gca;
    ax.XTick = 1:numel(levels);
    ax.XTickLabel = cellstr(levels);

    title("Répartition femmes / hommes");
    xlabel("Sexe");
    ylabel("Nombre de participants");
    box off;
    set(gca, 'FontSize', 11, 'LineWidth', 1.1);

    for k = 1:numel(counts)
        text(k, counts(k) + 0.3, sprintf('%d', counts(k)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
    end

    exportgraphics(fig, fullfile(PLOT_DIR, "barplot_sex_overall.png"), 'Resolution', 300);
    close(fig);
end

% ------------------------------------------------------------
% D) Sex distribution by AgeGroup
% ------------------------------------------------------------
if any(vars == "AgeGroup") && sexVar ~= ""
    ageGroupStr = string(T.AgeGroup);
    sexStr = string(T.(sexVar));
    sexStr(ismissing(sexStr) | strtrim(sexStr) == "") = "Missing";

    availableGroups = AGE_ORDER(ismember(AGE_ORDER, unique(ageGroupStr)));
    sexLevels = unique(sexStr, 'stable');

    crossMat = zeros(numel(availableGroups), numel(sexLevels));

    for i = 1:numel(availableGroups)
        for j = 1:numel(sexLevels)
            crossMat(i,j) = sum(ageGroupStr == availableGroups(i) & sexStr == sexLevels(j));
        end
    end

    fig = figure('Color','w','Position',[100 100 800 500]);
    b = bar(crossMat, 'stacked');
    hold on;

    for j = 1:numel(sexLevels)
        fld = matlab.lang.makeValidName(sexLevels(j));
        if isfield(SEX_COLORS, fld)
            b(j).FaceColor = SEX_COLORS.(fld);
        else
            b(j).FaceColor = [0.6 0.6 0.6];
        end
    end

    ax = gca;
    ax.XTick = 1:numel(availableGroups);
    ax.XTickLabel = cellstr(availableGroups);
    xtickangle(20);

    title("Répartition femmes / hommes par groupe d'âge");
    xlabel("Groupe d'âge");
    ylabel("Nombre de participants");
    legend(cellstr(sexLevels), 'Location', 'best');
    box off;
    set(gca, 'FontSize', 11, 'LineWidth', 1.1);

    exportgraphics(fig, fullfile(PLOT_DIR, "stacked_barplot_sex_by_agegroup.png"), 'Resolution', 300);
    close(fig);
end

fprintf('\nPlots saved in: %s\n', PLOT_DIR);

function apply_boxchart_color(b, baseColor)
% Apply a "pretty MATLAB" boxchart style:
% - darker edge / lines
% - lighter fill
% - coherent median / whisker colors

    if isempty(baseColor) || numel(baseColor) ~= 3
        baseColor = [0.4 0.4 0.4];
    end

    % Lighter fill from same base color
    fillColor = lighten_color(baseColor, 0.65);
    edgeColor = darken_color(baseColor, 0.20);
    b.LineWidth = 1.5;

    % Main box
    b.BoxFaceColor = fillColor;
    b.BoxFaceAlpha = 1.0;
    b.BoxEdgeColor = edgeColor;
    b.LineWidth = 1.4;

    % Lines
    try
        b.WhiskerLineColor = edgeColor;
    catch
    end

    try
        b.MedianLineColor = edgeColor;
    catch
    end

    % Outliers if shown
    try
        b.MarkerColor = edgeColor;
    catch
    end
end

function cLight = lighten_color(c, amount)
% amount in [0,1]
% 0   -> original color
% 1   -> white
    c = max(0, min(1, c));
    cLight = c + (1 - c) * amount;
    cLight = max(0, min(1, cLight));
end

function cDark = darken_color(c, amount)
% amount in [0,1]
% 0   -> original color
% 1   -> black
    c = max(0, min(1, c));
    cDark = c * (1 - amount);
    cDark = max(0, min(1, cDark));
end