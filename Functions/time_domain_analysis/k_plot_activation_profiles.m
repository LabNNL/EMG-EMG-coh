%% k_plot_activation_profiles.m
% Plot activation profiles for each muscle
% Top row   = participant-first mean
% Bottom row = pooled cycle mean (exploratory)

function k_plot_activation_profiles()


    C   = config_emg();
    IO  = C.k_activation_profiles.io;
    P   = C.k_activation_profiles.params;
    PLT = C.plotting;

    addpath(genpath(C.paths.toolboxes.spm1d));

    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end

    %% ===================== LOAD =====================
    fprintf('Loading data from:\n%s\n', IO.in_mat);
    assert(isfile(IO.in_mat), 'Input mat not found: %s', IO.in_mat);

    L = load(IO.in_mat);
    assert(isfield(L, 'TIME_DOMAIN_SINGLE_MUSCLE'), 'TIME_DOMAIN_SINGLE_MUSCLE not found in input mat.');

    TD = L.TIME_DOMAIN_SINGLE_MUSCLE;
    subjFields = fieldnames(TD);

    %% ===================== MAIN =====================
    muscles_to_plot    = string(P.muscles_to_plot);
    conditions_to_plot = string(P.conditions_to_plot);
    age_groups_to_plot = string(P.age_groups_to_plot);

    for iM = 1:numel(muscles_to_plot)
        muscleName = muscles_to_plot(iM);

        switch string(P.normalization_mode)
            case "none"
                normalizedStr = "raw";
            case "cycle_max"
                normalizedStr = "cycleMaxNormalized";
            case "flat_subject_mean_peak"
                normalizedStr = "flatRefNormalized";
            case "flat_subject_percentile"
                normalizedStr = "flatPercentileNormalized";
            otherwise
                error('Unknown normalization_mode: %s', string(P.normalization_mode));
        end

        % -------------------------------------------------------------
        % Figure 1: compare AGE GROUPS within each CONDITION
        % columns = conditions
        % -------------------------------------------------------------
        fig1 = plot_activation_profile_grid( TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, "compare_agegroups_within_condition", P, PLT);

        saveas(fig1, fullfile(IO.out_dir, sprintf('activation_profiles_agegroups_%s_%s.png', muscleName, normalizedStr)));
        close(fig1);

        % -------------------------------------------------------------
        % Figure 2: compare CONDITIONS within each AGE GROUP
        % columns = age groups
        % -------------------------------------------------------------
        fig2 = plot_activation_profile_grid( TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, "compare_conditions_within_agegroup", P, PLT);

        saveas(fig2, fullfile(IO.out_dir, sprintf('activation_profiles_conditions_%s_%s.png', muscleName, normalizedStr)));
        close(fig2);

        % -------------------------------------------------------------
        % Figure 3: all age groups merged, compare CONDITIONS
        % -------------------------------------------------------------
        fig3 = plot_activation_profile_merged( TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, "conditions_merged_over_age", P, PLT);

        saveas(fig3, fullfile(IO.out_dir, sprintf('activation_profiles_conditionsMerged_%s_%s.png', muscleName, normalizedStr)));
        close(fig3);

        % -------------------------------------------------------------
        % Figure 4: all conditions merged, compare AGE GROUPS
        % -------------------------------------------------------------
        fig4 = plot_activation_profile_merged( TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, "agegroups_merged_over_condition", P, PLT);

        saveas(fig4, fullfile(IO.out_dir, sprintf('activation_profiles_agegroupsMerged_%s_%s.png', muscleName, normalizedStr)));
        close(fig4);

        % -------------------------------------------------------------
        % Figure 5: all conditions + all age groups pooled
        % -------------------------------------------------------------
        fig5 = plot_activation_profile_all_pooled( TD, subjFields, muscleName, P, PLT);

        saveas(fig5, fullfile(IO.out_dir, sprintf('activation_profiles_allPooled_%s_%s.png', muscleName, normalizedStr)));
        close(fig5);
    end

    fprintf('\nDone. Activation profile plots saved in:\n%s\n', IO.out_dir);

    %% Example diagnostic call
    % diagnose_random_activation_examples( ...
    %     TD, ...
    %     "EMG_TAprox_Concat", ...
    %     10, ...
    %     [1 2 3], ...
    %     'seed', 1);
end

%% ===================== LOCAL FUNCTIONS =====================
function fig = plot_activation_profile_grid(TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, modeName, P, PLT)

    normTitleStr = get_normalization_title_str(P);
    prettymuscleName = prettymuscle(muscleName);

    switch string(modeName)
        case "compare_agegroups_within_condition"
            nCols = numel(conditions_to_plot);
            mainTitle = sprintf('%s activation profiles', prettymuscleName);
            subTitle  = sprintf('Age-group comparison within each condition (%s)', normTitleStr);

        case "compare_conditions_within_agegroup"
            nCols = numel(age_groups_to_plot);
            mainTitle = sprintf('%s activation profiles', prettymuscleName);
            subTitle  = sprintf('Condition comparison within each age group (%s)', normTitleStr);

        otherwise
            error('Unknown modeName: %s', string(modeName));
    end

    [nRows, showParticipant, showCycle] = get_profile_plot_layout(P);

    figHeight = 420 * nRows;
    fig = figure('Color','w','Position',[100 100 420*nCols figHeight]);

    sgtitle({mainTitle, subTitle}, 'Interpreter','none', 'FontWeight','bold');

    for iCol = 1:nCols

        rowNow = 0;

        % =========================================================
        % SUBJECT-LEVEL AVERAGE
        % =========================================================
        if showParticipant
            rowNow = rowNow + 1;
            ax1 = subplot(nRows, nCols, (rowNow-1)*nCols + iCol);
            hold(ax1, 'on');
            format_activation_axis(ax1, P);

            switch string(modeName)
                case "compare_agegroups_within_condition"
                    condName = conditions_to_plot(iCol);

                    for iA = 1:numel(age_groups_to_plot)
                        ageName = age_groups_to_plot(iA);

                        D = collect_profiles( TD, subjFields, muscleName, condName, "", ageName, P);

                        if isempty(D.subject_means), continue; end

                        plot_mean_sem(ax1, D.subject_means, get_color_safe(PLT.colors, char(ageName), [0 0 0]), sprintf('%s (n=%d)', ageName, size(D.subject_means,1)), PLT.AlphaTransparency);
                    end

                    title(ax1, sprintf('%s | Subject-level average', condName), 'Interpreter','none', 'FontWeight','normal');

                case "compare_conditions_within_agegroup"
                    ageName = age_groups_to_plot(iCol);

                    for iC = 1:numel(conditions_to_plot)
                        condName = conditions_to_plot(iC);

                        D = collect_profiles( TD, subjFields, muscleName, condName, "", ageName, P);

                        if isempty(D.subject_means), continue; end

                        plot_mean_sem(ax1, D.subject_means, get_color_safe(PLT.colors, char(condName), [0 0 0]), sprintf('%s (n=%d)', condName, size(D.subject_means,1)), PLT.AlphaTransparency);
                    end

                    title(ax1, sprintf('%s | Subject-level average', ageName), 'Interpreter','none', 'FontWeight','normal');
            end

            plot_toeoff_line(ax1, P.default_toeoff_fraction);
            lgd = legend(ax1, 'Location','best');
            lgd.AutoUpdate = 'off';
            grid(ax1, 'on');
        end

        % =========================================================
        % CYCLE-LEVEL POOLED AVERAGE
        % =========================================================
        if showCycle
            rowNow = rowNow + 1;
            ax2 = subplot(nRows, nCols, (rowNow-1)*nCols + iCol);
            hold(ax2, 'on');
            format_activation_axis(ax2, P);

            switch string(modeName)
                case "compare_agegroups_within_condition"
                    condName = conditions_to_plot(iCol);

                    for iA = 1:numel(age_groups_to_plot)
                        ageName = age_groups_to_plot(iA);

                        D = collect_profiles( TD, subjFields, muscleName, condName, "", ageName, P);

                        if isempty(D.all_cycles), continue; end

                        plot_mean_sem(ax2, D.all_cycles, get_color_safe(PLT.colors, char(ageName), [0 0 0]), sprintf('%s (n cycles=%d)', ageName, size(D.all_cycles,1)), PLT.AlphaTransparency);
                    end

                    title(ax2, sprintf('%s | Cycle-level pooled average', condName), 'Interpreter','none', 'FontWeight','normal');

                case "compare_conditions_within_agegroup"
                    ageName = age_groups_to_plot(iCol);

                    for iC = 1:numel(conditions_to_plot)
                        condName = conditions_to_plot(iC);

                        D = collect_profiles( TD, subjFields, muscleName, condName, "", ageName, P);

                        if isempty(D.all_cycles), continue; end

                        plot_mean_sem(ax2, D.all_cycles, get_color_safe(PLT.colors, char(condName), [0 0 0]), sprintf('%s (n cycles=%d)', condName, size(D.all_cycles,1)), PLT.AlphaTransparency);
                    end

                    title(ax2, sprintf('%s | Cycle-level pooled average', ageName), 'Interpreter','none', 'FontWeight','normal');
            end

            plot_toeoff_line(ax2, P.default_toeoff_fraction);
            lgd = legend(ax2, 'Location','best');
            lgd.AutoUpdate = 'off';
            grid(ax2, 'on');
        end
    end
end

function normTitleStr = get_normalization_title_str(P)
    switch string(P.normalization_mode)
        case "none"
            normTitleStr = "raw amplitude";
        case "cycle_max"
            normTitleStr = "cycle-max normalized";
        case "flat_subject_mean_peak"
            normTitleStr = "normalized to Flat mean peak";
        case "flat_subject_percentile"
            normTitleStr = sprintf('normalized to Flat %.0fth percentile', P.norm_reference_percentile);
        otherwise
            error('Unknown normalization_mode: %s', string(P.normalization_mode));
    end
end

function D = collect_profiles(TD, subjFields, muscleName, condName, legName, ageName, P)

    allCycles = {};
    subjectMeans = {};
    subjectIDs = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        if ~isfield(TD.(subjID), char(condName))
            continue;
        end

        condStruct = TD.(subjID).(char(condName));
        legFields = fieldnames(condStruct);

        subjCycleProfiles = {};

        for il = 1:numel(legFields)
            leg = legFields{il};

            if legName ~= "" && string(leg) ~= legName
                continue;
            end

            if ~isfield(condStruct.(leg), char(muscleName))
                continue;
            end

            S = condStruct.(leg).(char(muscleName));

            if isfield(P, 'use_only_included_signals') && P.use_only_included_signals
                if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                    continue;
                end
            end

            if isfield(S, 'age_group') && string(S.age_group) ~= ageName
                continue;
            end

            if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                continue;
            end

            VC = S.valid_cycles;
            nCycles = numel(VC.cycle_number);

            for iC = 1:nCycles
                x = extract_profile_from_valid_cycles(VC, iC, P);

                if isempty(x) || ~isnumeric(x)
                    continue;
                end

                x = x(:)';
                x = apply_profile_normalization(x, TD, subjID, muscleName, P);

                subjCycleProfiles{end+1,1} = x; %#ok<AGROW>
                allCycles{end+1,1} = x; %#ok<AGROW>
            end
        end

        if ~isempty(subjCycleProfiles)
            Xs = vertcat(subjCycleProfiles{:});
            subjectMeans{end+1,1} = mean(Xs, 1, 'omitnan'); %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(allCycles)
        D.all_cycles = [];
    else
        D.all_cycles = vertcat(allCycles{:});
    end

    if isempty(subjectMeans)
        D.subject_means = [];
    else
        D.subject_means = vertcat(subjectMeans{:});
    end

    D.subject_ids = subjectIDs;
end

function x = extract_profile_from_valid_cycles(VC, iC, P)
    x = [];
    sigName = string(P.profile_signal_name);

    if isfield(P, 'use_time_normalized') && P.use_time_normalized
        fn = ['time_normalized_' char(sigName)];
        if isfield(VC, fn) && numel(VC.(fn)) >= iC && ~isempty(VC.(fn){iC})
            x = VC.(fn){iC};
            return;
        end
    end

    if isfield(VC, char(sigName)) && numel(VC.(char(sigName))) >= iC && ~isempty(VC.(char(sigName)){iC})
        x = VC.(char(sigName)){iC};
    end
end

function plot_mean_sem(ax, X, col, labelText, alphaVal)
    if isempty(X), return; end

    M = mean(X, 1, 'omitnan');
    S = std(X, 0, 1, 'omitnan') ./ sqrt(size(X,1));
    x = linspace(0, 100, numel(M));

    fill(ax, [x fliplr(x)], [M-S fliplr(M+S)], col, 'FaceAlpha', alphaVal, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax, x, M, 'LineWidth', 2, 'Color', col, 'DisplayName', labelText);
end

function format_activation_axis(ax, P)
    xlabel(ax, 'Gait cycle (%)');
    ylabel(ax, get_ylabel_text(P));
    xlim(ax, [0 100]);
end

function ytxt = get_ylabel_text(P)

    modeName = string(P.normalization_mode);

    switch modeName
        case "none"
            if isfield(P, 'use_time_normalized') && P.use_time_normalized
                ytxt = P.ylabel_text_time_normalized;
            else
                ytxt = P.ylabel_text_raw;
            end

        case "cycle_max"
            % ytxt = 'Normalized EMG envelope (%% of cycle max)';
            ytxt = 'Normalized EMG envelope';

        case "flat_subject_mean_peak"
            ytxt = 'Normalized EMG envelope (%% of subject Flat mean peak)';
            ytxt = 'Normalized EMG envelope';

        case "flat_subject_percentile"
            % ytxt = sprintf('Normalized EMG envelope (%% of subject Flat %.0fth percentile)', ...
            %     P.norm_reference_percentile);
            ytxt = 'Normalized EMG envelope';

        otherwise
            error('Unknown normalization_mode: %s', modeName);
    end
end

function col = get_color_safe(colorStruct, fieldName, fallback)
    if isfield(colorStruct, fieldName)
        col = colorStruct.(fieldName);
    else
        col = fallback;
    end
end

function plot_toeoff_line(ax, toeFrac)
    xline(ax, 100 * toeFrac, '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
end
function fig = plot_activation_profile_merged(TD, subjFields, muscleName, conditions_to_plot, age_groups_to_plot, modeName, P, PLT)

    [nRows, showParticipant, showCycle] = get_profile_plot_layout(P);

    figHeight = 420 * nRows;
    fig = figure('Color','w','Position',[100 100 900 figHeight]);

    prettymuscleName = prettymuscle(muscleName);

    switch string(modeName)
        case "conditions_merged_over_age"
            sgtitle({ sprintf('%s activation profiles', prettymuscleName), sprintf('Condition comparison, all age groups pooled (%s)', get_normalization_title_str(P)) }, 'Interpreter','none', 'FontWeight','bold');

            rowNow = 0;

            if showParticipant
                rowNow = rowNow + 1;
                ax1 = subplot(nRows, 1, rowNow); hold(ax1, 'on');
                format_activation_axis(ax1, P);

                for iC = 1:numel(conditions_to_plot)
                    condName = conditions_to_plot(iC);

                    D = collect_profiles_merged(TD, subjFields, muscleName, condName, "", "", P);

                    if isempty(D.subject_means), continue; end

                    plot_mean_sem(ax1, D.subject_means, get_color_safe(PLT.colors, char(condName), [0 0 0]), sprintf('%s (n=%d)', condName, size(D.subject_means,1)), PLT.AlphaTransparency);
                end

                title(ax1, 'Subject-level average', 'FontWeight','normal');
                plot_toeoff_line(ax1, P.default_toeoff_fraction);
                legend(ax1, 'Location','best');
                grid(ax1, 'on');
            end

            if showCycle
                rowNow = rowNow + 1;
                ax2 = subplot(nRows, 1, rowNow); hold(ax2, 'on');
                format_activation_axis(ax2, P);

                for iC = 1:numel(conditions_to_plot)
                    condName = conditions_to_plot(iC);

                    D = collect_profiles_merged(TD, subjFields, muscleName, condName, "", "", P);

                    if isempty(D.all_cycles), continue; end

                    plot_mean_sem(ax2, D.all_cycles, get_color_safe(PLT.colors, char(condName), [0 0 0]), sprintf('%s (n cycles=%d)', condName, size(D.all_cycles,1)), PLT.AlphaTransparency);
                end

                title(ax2, 'Cycle-level pooled average', 'FontWeight','normal');
                plot_toeoff_line(ax2, P.default_toeoff_fraction);
                legend(ax2, 'Location','best');
                grid(ax2, 'on');
            end

        case "agegroups_merged_over_condition"
            sgtitle({ sprintf('%s activation profiles', prettymuscleName), sprintf('Age-group comparison, all conditions pooled (%s)', get_normalization_title_str(P)) }, 'Interpreter','none', 'FontWeight','bold');

            rowNow = 0;

            if showParticipant
                rowNow = rowNow + 1;
                ax1 = subplot(nRows, 1, rowNow); hold(ax1, 'on');
                format_activation_axis(ax1, P);

                for iA = 1:numel(age_groups_to_plot)
                    ageName = age_groups_to_plot(iA);

                    D = collect_profiles_merged(TD, subjFields, muscleName, "", "", ageName, P);

                    if isempty(D.subject_means), continue; end

                    plot_mean_sem(ax1, D.subject_means, get_color_safe(PLT.colors, char(ageName), [0 0 0]), sprintf('%s (n=%d)', ageName, size(D.subject_means,1)), PLT.AlphaTransparency);
                end

                title(ax1, 'Subject-level average', 'FontWeight','normal');
                plot_toeoff_line(ax1, P.default_toeoff_fraction);
                legend(ax1, 'Location','best');
                grid(ax1, 'on');
            end

            if showCycle
                rowNow = rowNow + 1;
                ax2 = subplot(nRows, 1, rowNow); hold(ax2, 'on');
                format_activation_axis(ax2, P);

                for iA = 1:numel(age_groups_to_plot)
                    ageName = age_groups_to_plot(iA);

                    D = collect_profiles_merged(TD, subjFields, muscleName, "", "", ageName, P);

                    if isempty(D.all_cycles), continue; end

                    plot_mean_sem(ax2, D.all_cycles, get_color_safe(PLT.colors, char(ageName), [0 0 0]), sprintf('%s (n cycles=%d)', ageName, size(D.all_cycles,1)), PLT.AlphaTransparency);
                end

                title(ax2, 'Cycle-level pooled average', 'FontWeight','normal');
                plot_toeoff_line(ax2, P.default_toeoff_fraction);
                legend(ax2, 'Location','best');
                grid(ax2, 'on');
            end

        otherwise
            error('Unknown modeName: %s', string(modeName));
    end
end

function D = collect_profiles_merged(TD, subjFields, muscleName, condName, legName, ageName, P)

    allCycles = {};
    subjectMeans = {};
    subjectIDs = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        subjCycleProfiles = {};

        subjCondFields = fieldnames(TD.(subjID));

        for ic = 1:numel(subjCondFields)
            cond = subjCondFields{ic};

            if condName ~= "" && string(cond) ~= string(condName)
                continue;
            end

            condStruct = TD.(subjID).(cond);
            legFields = fieldnames(condStruct);

            for il = 1:numel(legFields)
                leg = legFields{il};

                if legName ~= "" && string(leg) ~= string(legName)
                    continue;
                end

                if ~isfield(condStruct.(leg), char(muscleName))
                    continue;
                end

                S = condStruct.(leg).(char(muscleName));

                if isfield(P, 'use_only_included_signals') && P.use_only_included_signals
                    if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                        continue;
                    end
                end

                if ageName ~= "" && isfield(S, 'age_group')
                    if string(S.age_group) ~= string(ageName)
                        continue;
                    end
                end

                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                    continue;
                end

                VC = S.valid_cycles;
                nCycles = numel(VC.cycle_number);

                for iC = 1:nCycles
                    x = extract_profile_from_valid_cycles(VC, iC, P);

                    if isempty(x) || ~isnumeric(x)
                        continue;
                    end

                    x = x(:)';
                    x = apply_profile_normalization(x, TD, subjID, muscleName, P);

                    subjCycleProfiles{end+1,1} = x; %#ok<AGROW>
                    allCycles{end+1,1} = x; %#ok<AGROW>
                end
            end
        end

        if ~isempty(subjCycleProfiles)
            Xs = vertcat(subjCycleProfiles{:});
            subjectMeans{end+1,1} = mean(Xs, 1, 'omitnan'); %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(allCycles)
        D.all_cycles = [];
    else
        D.all_cycles = vertcat(allCycles{:});
    end

    if isempty(subjectMeans)
        D.subject_means = [];
    else
        D.subject_means = vertcat(subjectMeans{:});
    end

    D.subject_ids = subjectIDs;
end

function diagnose_random_activation_examples(TD, muscleName, nExamples, cycleIdxList, varargin)
    p = inputParser;
    addParameter(p, 'seed', 1);
    parse(p, varargin{:});
    seed = p.Results.seed;

    rng(seed);

    subjFields = fieldnames(TD);
    candidates = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        condFields = fieldnames(TD.(subjID));

        for ic = 1:numel(condFields)
            cond = condFields{ic};
            legFields = fieldnames(TD.(subjID).(cond));

            for il = 1:numel(legFields)
                leg = legFields{il};

                if ~isfield(TD.(subjID).(cond).(leg), char(muscleName))
                    continue;
                end

                S = TD.(subjID).(cond).(leg).(char(muscleName));
                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles) || isempty(S.valid_cycles.cycle_number)
                    continue;
                end

                candidates(end+1,:) = {subjID, cond, leg}; %#ok<AGROW>
            end
        end
    end

    if isempty(candidates)
        error('No candidates found for muscle %s.', muscleName);
    end

    nExamples = min(nExamples, size(candidates,1));
    idxPick = randperm(size(candidates,1), nExamples);

    for i = 1:nExamples
        subjID = candidates{idxPick(i), 1};
        cond   = candidates{idxPick(i), 2};
        leg    = candidates{idxPick(i), 3};

        fprintf('\nRandom example %d/%d: %s | %s | %s | %s\n', i, nExamples, subjID, cond, leg, muscleName);

        diagnose_activation_profile_start( TD, subjID, cond, leg, char(muscleName), cycleIdxList);
    end
end

function diagnose_activation_profile_start(TD, subjID, cond, leg, mf, cycleIdxList, varargin)

    p = inputParser;
    addParameter(p, 'zoom_fraction', 0.15);
    parse(p, varargin{:});
    zoom_fraction = p.Results.zoom_fraction;

    assert(isfield(TD, subjID), 'Subject not found.');
    assert(isfield(TD.(subjID), cond), 'Condition not found.');
    assert(isfield(TD.(subjID).(cond), leg), 'Leg not found.');
    assert(isfield(TD.(subjID).(cond).(leg), mf), 'Muscle not found.');

    S = TD.(subjID).(cond).(leg).(mf);
    assert(isfield(S,'valid_cycles') && ~isempty(S.valid_cycles), 'No valid cycles found.');

    VC = S.valid_cycles;
    nAvail = numel(VC.cycle_number);

    nReq = numel(cycleIdxList);
    nRows = nReq;
    nCols = 4;

    fig = figure('Color','w','Position',[100 100 1500 max(350,260*nRows)]);
    tl = tiledlayout(nRows, nCols, 'TileSpacing','compact', 'Padding','compact');
    title(tl, sprintf('Diagnostic | %s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');

    for i = 1:nReq
        idx = cycleIdxList(i);
        if idx < 1 || idx > nAvail
            warning('Cycle index %d out of range. Skipping.', idx);
            continue;
        end

        x_bp   = get_cell_field_or_empty(VC, 'bandpassed', idx);
        x_rect = get_cell_field_or_empty(VC, 'rectified', idx);
        x_env  = get_cell_field_or_empty(VC, 'envelope', idx);

        x_tn_bp  = get_cell_field_or_empty(VC, 'time_normalized_bandpassed', idx);
        x_tn_env = get_cell_field_or_empty(VC, 'time_normalized_envelope', idx);

        toeFrac = get_toe_fraction_from_valid_cycles(VC, idx, 0.60);

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_bp), plot(ax, x_bp, 'b', 'LineWidth', 1); end
        title(ax, sprintf('Cycle %d | bandpassed', idx));
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_rect), plot(ax, x_rect, 'Color', [0.6 0.6 0.6], 'LineWidth', 1); end
        if ~isempty(x_env),  plot(ax, x_env,  'r', 'LineWidth', 2); end
        title(ax, 'rectified + envelope');
        legend_if_needed(ax, {'rectified','envelope'}, [~isempty(x_rect), ~isempty(x_env)]);
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_tn_bp),  plot(ax, linspace(0,100,numel(x_tn_bp)),  x_tn_bp,  'b', 'LineWidth', 1); end
        if ~isempty(x_tn_env), plot(ax, linspace(0,100,numel(x_tn_env)), x_tn_env, 'r', 'LineWidth', 2); end
        xline(ax, 100*toeFrac, '--', 'Color', [0.4 0.4 0.4], 'HandleVisibility','off');
        title(ax, 'time-normalized');
        xlabel(ax, 'Cycle (%)');
        legend_if_needed(ax, {'tn bandpassed','tn envelope'}, [~isempty(x_tn_bp), ~isempty(x_tn_env)]);
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        nZoom = max(5, round(zoom_fraction * get_max_len(x_bp, x_rect, x_env)));

        if ~isempty(x_bp)
            n1 = min(numel(x_bp), nZoom);
            plot(ax, 1:n1, x_bp(1:n1), 'b', 'LineWidth', 1);
        end
        if ~isempty(x_rect)
            n1 = min(numel(x_rect), nZoom);
            plot(ax, 1:n1, x_rect(1:n1), 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
        if ~isempty(x_env)
            n1 = min(numel(x_env), nZoom);
            plot(ax, 1:n1, x_env(1:n1), 'r', 'LineWidth', 2);
        end

        title(ax, sprintf('start zoom (first %.0f%%)', 100*zoom_fraction));
        legend_if_needed(ax, {'bp','rect','env'}, [~isempty(x_bp), ~isempty(x_rect), ~isempty(x_env)]);
        grid(ax,'on');
    end
end

function x = get_cell_field_or_empty(S, fn, idx)
    if isfield(S, fn) && numel(S.(fn)) >= idx && ~isempty(S.(fn){idx})
        x = S.(fn){idx}(:);
    else
        x = [];
    end
end

function n = get_max_len(varargin)
    lens = zeros(numel(varargin),1);
    for i = 1:numel(varargin)
        if ~isempty(varargin{i})
            lens(i) = numel(varargin{i});
        end
    end
    n = max(lens);
    if n == 0, n = 10; end
end

function legend_if_needed(ax, labels, keepMask)
    labels = labels(keepMask);
    if ~isempty(labels)
        legend(ax, labels, 'Location','best');
    end
end
function fig = plot_activation_profile_all_pooled(TD, subjFields, muscleName, P, PLT)

    D = collect_profiles_merged(TD, subjFields, muscleName, "", "", "", P);
    prettymuscleName = prettymuscle(muscleName);

    [nRows, showParticipant, showCycle] = get_profile_plot_layout(P);

    figHeight = 420 * nRows;
    fig = figure('Color','w','Position',[100 100 900 figHeight]);

    sgtitle({ sprintf('%s activation profiles', prettymuscleName), sprintf('All conditions and age groups pooled (%s)', get_normalization_title_str(P)) }, 'Interpreter','none', 'FontWeight','bold');

    rowNow = 0;

    if showParticipant
        rowNow = rowNow + 1;
        ax1 = subplot(nRows, 1, rowNow); hold(ax1, 'on');
        format_activation_axis(ax1, P);

        if ~isempty(D.subject_means)
            plot_mean_sem(ax1, D.subject_means, get_color_safe(PLT.colors, char(muscleName), [0 0 0]), sprintf('subject-level average (n=%d)', size(D.subject_means,1)), PLT.AlphaTransparency);
        end

        title(ax1, 'Subject-level average', 'FontWeight','normal');
        plot_toeoff_line(ax1, P.default_toeoff_fraction);
        legend(ax1, 'Location','best');
        grid(ax1, 'on');
    end

    if showCycle
        rowNow = rowNow + 1;
        ax2 = subplot(nRows, 1, rowNow); hold(ax2, 'on');
        format_activation_axis(ax2, P);

        if ~isempty(D.all_cycles)
            plot_mean_sem(ax2, D.all_cycles, get_color_safe(PLT.colors, char(muscleName), [0 0 0]), sprintf('cycle-level pooled average (n=%d)', size(D.all_cycles,1)), PLT.AlphaTransparency);
        end

        title(ax2, 'Cycle-level pooled average', 'FontWeight','normal');
        plot_toeoff_line(ax2, P.default_toeoff_fraction);
        legend(ax2, 'Location','best');
        grid(ax2, 'on');
    end
end

function prettymuscleName = prettymuscle(muscleName)
    % Convert internal muscle names to more readable format
    % Take out EMG and Concat first
    prettymuscleName = regexprep(muscleName, 'EMG_|_Concat', '');
    % Replace underscores with spaces
    prettymuscleName = strrep(prettymuscleName, '_', ' ');
    %if contains TA replace by 'Tibialis Anterior'
    if contains(prettymuscleName, 'TAdist')
        prettymuscleName = strrep(prettymuscleName, 'TAdist', 'Tibialis Anterior dist');
    elseif contains(prettymuscleName, 'TAprox')
        prettymuscleName = strrep(prettymuscleName, 'TAprox', 'Tibialis Anterior prox');
    elseif contains(prettymuscleName, 'SOL')
        prettymuscleName = strrep(prettymuscleName, 'SOL', 'Soleus');
    elseif contains(prettymuscleName, 'GMED')
        prettymuscleName = strrep(prettymuscleName, 'GMED', 'Gluteus Medius');
    elseif contains(prettymuscleName, 'GM')
        prettymuscleName = strrep(prettymuscleName, 'GM', 'Gastrocnemius Medialis');
    elseif contains(prettymuscleName, 'VL')
        prettymuscleName = strrep(prettymuscleName, 'VL', 'Vastus Lateralis');
    elseif contains(prettymuscleName, 'RF')
        prettymuscleName = strrep(prettymuscleName, 'RF', 'Rectus Femoris');
    elseif contains(prettymuscleName, 'ST')
        prettymuscleName = strrep(prettymuscleName, 'ST', 'Semitendinosus');
    end
end

function [Y, subjectIDs] = collect_subject_mean_envelopes(TD, subjFields, muscleName, condName, ageName)

    subjectMeans = {};
    subjectIDs = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        if ~isfield(TD.(subjID), char(condName))
            continue;
        end

        condStruct = TD.(subjID).(char(condName));
        legFields = fieldnames(condStruct);

        subjCycleProfiles = {};

        for il = 1:numel(legFields)
            leg = legFields{il};

            if ~isfield(condStruct.(leg), char(muscleName))
                continue;
            end

            S = condStruct.(leg).(char(muscleName));

            if ~isfield(S, 'age_group') || string(S.age_group) ~= string(ageName)
                continue;
            end

            if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                continue;
            end

            VC = S.valid_cycles;

            if ~isfield(VC, 'time_normalized_envelope') || isempty(VC.time_normalized_envelope)
                continue;
            end

            for iC = 1:numel(VC.time_normalized_envelope)
                x = VC.time_normalized_envelope{iC};
                if isempty(x)
                    continue;
                end
                subjCycleProfiles{end+1,1} = x(:)'; %#ok<AGROW>
            end
        end

        if ~isempty(subjCycleProfiles)
            X = vertcat(subjCycleProfiles{:});
            subjectMeans{end+1,1} = mean(X, 1, 'omitnan'); %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(subjectMeans)
        Y = [];
    else
        Y = vertcat(subjectMeans{:});
    end
end

function refVal = get_subject_flat_reference(TD, subjID, muscleName, P)

    refVal = NaN;

    if ~isfield(TD, subjID) || ~isfield(TD.(subjID), 'Flat')
        return;
    end

    condStruct = TD.(subjID).Flat;
    legFields = fieldnames(condStruct);

    allFlatCycles = {};

    for il = 1:numel(legFields)
        leg = legFields{il};

        if ~isfield(condStruct.(leg), char(muscleName))
            continue;
        end

        S = condStruct.(leg).(char(muscleName));

        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
            continue;
        end

        xcell = get_profile_cell_from_valid_cycles_for_plot(S.valid_cycles, P);
        if isempty(xcell)
            continue;
        end

        for iC = 1:numel(xcell)
            x = xcell{iC};
            if isempty(x) || ~isnumeric(x)
                continue;
            end
            allFlatCycles{end+1,1} = x(:)'; %#ok<AGROW>
        end
    end

    if isempty(allFlatCycles)
        return;
    end

    X = vertcat(allFlatCycles{:});
    meanFlatProfile = mean(X, 1, 'omitnan');
    refVal = max(meanFlatProfile, [], 'omitnan');

    if isempty(refVal) || isnan(refVal) || refVal <= 0
        refVal = NaN;
    end
end

function xcell = get_profile_cell_from_valid_cycles_for_plot(VC, P)

    xcell = {};
    sigName = string(P.profile_signal_name);

    if isfield(P, 'use_time_normalized') && P.use_time_normalized
        fn = "time_normalized_" + sigName;
        if isfield(VC, char(fn))
            xcell = VC.(char(fn));
            return;
        end
    end

    if isfield(VC, char(sigName))
        xcell = VC.(char(sigName));
    end
end

function x = apply_profile_normalization(x, TD, subjID, muscleName, P)

    modeName = string(P.normalization_mode);

    switch modeName
        case "none"
            return

        case "cycle_max"
            mx = max(x, [], 'omitnan');
            if ~isempty(mx) && ~isnan(mx) && mx > 0
                x = x ./ mx;
            end

        case "flat_subject_mean_peak"
            refVal = get_subject_flat_reference(TD, subjID, muscleName, P);
            if ~isnan(refVal) && refVal > 0
                x = x ./ refVal;
            end

        case "flat_subject_percentile"
            refVal = get_subject_flat_percentile_reference(TD, subjID, muscleName, P);
            if isfinite(refVal) && refVal > 0
                x = 100 * x ./ refVal;
            end

        otherwise
            error('Unknown normalization_mode: %s', modeName);
    end
end

function T_out = keep_only_complete_subjects_for_conditions(T_in, conditionOrder)
% Keep only subjects who have all requested conditions

    T_out = T_in;

    if isempty(T_in) || ~ismember('subject', T_in.Properties.VariableNames) || ~ismember('condition', T_in.Properties.VariableNames)
        return;
    end

    reqConds = string(conditionOrder(:));
    reqConds(reqConds == "") = [];

    if isempty(reqConds)
        return;
    end

    subjList = categories(removecats(T_in.subject));
    keepSubs = strings(0,1);

    for iS = 1:numel(subjList)
        s = subjList{iS};
        Ts = T_in(T_in.subject == s, :);

        condsHere = categories(removecats(Ts.condition));
        condsHere = string(condsHere(:));

        if all(ismember(reqConds, condsHere))
            keepSubs(end+1,1) = string(s); %#ok<AGROW>
        end
    end

    if isempty(keepSubs)
        T_out = T_in([]);
        return;
    end

    T_out = T_in(ismember(string(T_in.subject), keepSubs), :);

    if iscategorical(T_out.subject),   T_out.subject   = removecats(T_out.subject); end
    if iscategorical(T_out.condition), T_out.condition = removecats(T_out.condition); end
    if iscategorical(T_out.age_group), T_out.age_group = removecats(T_out.age_group); end
    if iscategorical(T_out.pair_name), T_out.pair_name = removecats(T_out.pair_name); end
end

function refVal = get_subject_flat_percentile_reference(TD, subjID, muscleName, P)

    refVal = NaN;

    if ~isfield(TD, subjID) || ~isfield(TD.(subjID), 'Flat')
        return;
    end

    if isfield(P, 'norm_reference_percentile') && ~isempty(P.norm_reference_percentile)
        prc = P.norm_reference_percentile;
    else
        prc = 95;
    end

    flatStruct = TD.(subjID).Flat;
    legFields = fieldnames(flatStruct);

    candidateVals = [];

    for il = 1:numel(legFields)
        leg = legFields{il};

        if ~isfield(flatStruct.(leg), char(muscleName))
            continue;
        end

        S = flatStruct.(leg).(char(muscleName));

        if isfield(P, 'use_only_included_signals') && P.use_only_included_signals
            if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                continue;
            end
        end

        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
            continue;
        end

        xcell = get_profile_cell_from_valid_cycles_for_plot(S.valid_cycles, P);

        for iC = 1:numel(xcell)
            x = xcell{iC};
            if isnumeric(x) && ~isempty(x)
                vals = x(:);
                vals = vals(isfinite(vals));
                candidateVals = [candidateVals; vals]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(candidateVals)
        refVal = prctile(candidateVals, prc);
    end

    if isempty(refVal) || ~isfinite(refVal) || refVal <= 0
        refVal = NaN;
    end
end

function [nRows, showParticipant, showCycle] = get_profile_plot_layout(P)

    showParticipant = P.show_participant_level_mean;
    showCycle       = P.show_cycle_level_mean;

    if ~showParticipant && ~showCycle
        error('At least one of show_participant_level_mean or show_cycle_level_mean must be true.');
    end

    nRows = double(showParticipant) + double(showCycle);
end