%% l_spm_envelope_analysis.m
% SPM1D analysis on participant-level mean time-normalized envelope profiles
%
% INPUT:
%   - TIME_DOMAIN_DATA.mat
%
% ANALYSES:
%   1) condition effect within one age group
%      - 2 conditions  -> paired t-test
%      - 3+ conditions -> repeated-measures one-way ANOVA (complete cases only)
%
%   2) age-group effect within one condition
%      - 2 groups      -> two-sample t-test
%      - 3+ groups     -> one-way ANOVA
%
% IMPORTANT:
%   - uses participant-level mean profiles, not pooled cycles
%   - for repeated-measures condition analyses, only complete-case subjects
%     are retained across all requested conditions
function l_spm_envelope_analysis()
    fprintf('Starting SPM envelope analysis...\n');

    set(0, 'DefaultFigureVisible', 'off');
    set(groot, 'DefaultFigureVisible', 'off');


    C   = config_emg();
    IO  = C.l_spm.io;
    P   = C.l_spm.params;
    PLT = C.plotting;

    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.csv_dir, 'dir')
        mkdir(IO.csv_dir);
    end
    delete_if_exists(IO.age_effects_csv);
    delete_if_exists(IO.condition_effects_csv);
    delete_if_exists(IO.interaction_effects_csv);

    if ~isfield(P, 'run_age_condition_interaction') || ~P.run_age_condition_interaction
        write_not_computed_interaction_csv(IO.interaction_effects_csv);
    end

    %% ===================== LOAD =====================
    fprintf('Loading input data from:\n%s\n', IO.in_mat);
    assert(isfile(IO.in_mat), 'Input mat not found: %s', IO.in_mat);

    L = load(IO.in_mat);
    assert(isfield(L, 'TIME_DOMAIN_SINGLE_MUSCLE'), 'TIME_DOMAIN_SINGLE_MUSCLE not found in input mat.');

    TD = L.TIME_DOMAIN_SINGLE_MUSCLE;
    subjFields = fieldnames(TD);

    %% ===================== PREPROCESSING =====================
    % Add Flat-max normalized envelope fields without overwriting raw data
    %TD = add_normalized_signal_fields(TD, subjFields, P);
    TD = add_all_needed_normalized_signal_fields(TD, subjFields, P);

    % % ---------- Normalized amplitude QC ----------
    if ~isfield(P, 'run_normalized_amplitude_qc')
        P.run_normalized_amplitude_qc = true;
    end

    if P.run_normalized_amplitude_qc

        if ~isfield(P, 'outlier_detection_mode') || strlength(string(P.outlier_detection_mode)) == 0
            P.outlier_detection_mode = "fixed";
        end

        outlierMode = string(P.outlier_detection_mode);

        T_outlier_cycles_all  = table();
        T_outlier_signals_all = table();

        % -------------------------
        % Fixed threshold QC
        % -------------------------
        if outlierMode == "fixed" || outlierMode == "both"

            if isfield(P, 'fixed_outlier_threshold_percent')
                outlierThresholdPct = P.fixed_outlier_threshold_percent;
            else
                outlierThresholdPct = 250;
            end

            [T_fixed_cycles, T_fixed_signals] = detect_spm_normalized_outliers( TD, subjFields, P, outlierThresholdPct);

            if ~isempty(T_fixed_cycles)
                T_fixed_cycles.qc_method = repmat("fixed", height(T_fixed_cycles), 1);
            end

            if ~isempty(T_fixed_signals)
                T_fixed_signals.qc_method = repmat("fixed", height(T_fixed_signals), 1);
                T_fixed_signals_only = T_fixed_signals(T_fixed_signals.n_cycles_over_threshold > 0, :);
            else
                T_fixed_signals_only = table();
            end

            writetable(T_fixed_cycles, fullfile(IO.csv_dir, sprintf('NORMALIZED_OUTLIER_CYCLES_FIXED_OVER_%d.csv', outlierThresholdPct)));

            writetable(T_fixed_signals_only, fullfile(IO.csv_dir, sprintf('NORMALIZED_OUTLIER_SIGNAL_SUMMARY_FIXED_OVER_%d.csv', outlierThresholdPct)));

            T_outlier_cycles_all  = append_tables_safe(T_outlier_cycles_all, T_fixed_cycles);
            T_outlier_signals_all = append_tables_safe(T_outlier_signals_all, T_fixed_signals_only);
        end

        % -------------------------
        % Adaptive MAD threshold QC
        % -------------------------
        if outlierMode == "adaptive" || outlierMode == "both"

            [T_adaptive_cycles, T_adaptive_signals] = detect_spm_adaptive_normalized_outliers( TD, subjFields, P);

            if ~isempty(T_adaptive_cycles)
                T_adaptive_cycles.qc_method = repmat("adaptive_mad", height(T_adaptive_cycles), 1);
            end

            if ~isempty(T_adaptive_signals)
                T_adaptive_signals.qc_method = repmat("adaptive_mad", height(T_adaptive_signals), 1);
                T_adaptive_signals_only = T_adaptive_signals(T_adaptive_signals.n_cycles_over_threshold > 0, :);
            else
                T_adaptive_signals_only = table();
            end

            writetable(T_adaptive_cycles, fullfile(IO.csv_dir, 'NORMALIZED_OUTLIER_CYCLES_ADAPTIVE_MAD.csv'));

            writetable(T_adaptive_signals_only, fullfile(IO.csv_dir, 'NORMALIZED_OUTLIER_SIGNAL_SUMMARY_ADAPTIVE_MAD.csv'));

            T_outlier_cycles_all  = append_tables_safe(T_outlier_cycles_all, T_adaptive_cycles);
            T_outlier_signals_all = append_tables_safe(T_outlier_signals_all, T_adaptive_signals_only);
        end

        % -------------------------
        % Combined QC files
        % -------------------------
        writetable(T_outlier_cycles_all, fullfile(IO.csv_dir, 'NORMALIZED_OUTLIER_CYCLES_ALL_METHODS.csv'));

        writetable(T_outlier_signals_all, fullfile(IO.csv_dir, 'NORMALIZED_OUTLIER_SIGNAL_SUMMARY_ALL_METHODS.csv'));

        fprintf('\nTop normalized outlier signal summaries:\n');

        if ~isempty(T_outlier_signals_all)
            if ismember('pct_cycles_over_threshold', T_outlier_signals_all.Properties.VariableNames)
                disp(head(sortrows(T_outlier_signals_all, 'pct_cycles_over_threshold', 'descend'), 20));
            else
                disp(head(T_outlier_signals_all, 20));
            end
        else
            fprintf('No signal-level normalized outliers found.\n');
        end

        % -------------------------
        % Random signal-level outlier plots
        % -------------------------
        if P.plot_random_outlier_signal_examples && ~isempty(T_outlier_signals_all)

            if ~exist(IO.outlier_signal_plot_dir, 'dir')
                mkdir(IO.outlier_signal_plot_dir);
            end

            plot_random_outlier_signal_examples( TD, T_outlier_signals_all, P, IO, NaN);
        end
    end

    % ---------- Apply amplitude QC exclusion to TD ----------
    if isfield(P, 'apply_amplitude_qc_exclusion') && P.apply_amplitude_qc_exclusion

        fprintf('\nApplying amplitude QC exclusion to TD...\n');

        [TD, T_ampqc_cycles, T_ampqc_signals] = apply_amplitude_qc_exclusion_to_TD( TD, subjFields, P);

        writetable(T_ampqc_cycles, fullfile(IO.csv_dir, 'AMPLITUDE_QC_EXCLUDED_CYCLES.csv'));

        writetable(T_ampqc_signals, fullfile(IO.csv_dir, 'AMPLITUDE_QC_SIGNAL_SUMMARY.csv'));

        fprintf('Amplitude QC exclusion applied.\n');
        fprintf('Excluded cycles: %d\n', sum(T_ampqc_cycles.exclude_cycle));
        fprintf('Signal summaries saved.\n');

    else
        fprintf('\nAmplitude QC exclusion is OFF. No cycles removed from SPM analysis.\n');
    end

    %% ===================== SPM MAIN =====================

    muscles_to_run    = string(P.muscles_to_run);
    age_groups_to_run = string(P.age_groups_to_run);
    conditions_to_run = string(P.conditions_to_run);

    fprintf('\n====================================================\n');
    fprintf('Running full SPM batch analysis\n');
    fprintf('Muscles: %s\n', strjoin(muscles_to_run, ', '));
    fprintf('Age groups: %s\n', strjoin(age_groups_to_run, ', '));
    fprintf('Conditions: %s\n', strjoin(conditions_to_run, ', '));
    if P.use_nonparametric
        fprintf('SPM mode: NON-PARAMETRIC | iterations = %d\n', P.nonparam_iterations);
    else
        fprintf('SPM mode: PARAMETRIC\n');
    end
    fprintf('====================================================\n');

    for iM = 1:numel(muscles_to_run)
        muscleName = muscles_to_run(iM);
        fprintf('\n####################################################\n');
        fprintf('Muscle: %s\n', muscleName);
        fprintf('####################################################\n');

        % -------------------------------------------------
        % 1) Condition effect within each age group
        % -------------------------------------------------
        if P.run_condition_within_age && isempty(conditions_to_run)
            fprintf('\n[WARNING] No conditions specified to run for condition-within-age analyses. Skipping this step.\n');
        elseif P.run_condition_within_age
            for iA = 1:numel(age_groups_to_run)
                ageName = age_groups_to_run(iA);

                Ptmp = P;
                Ptmp.muscle_name = muscleName;
                Ptmp.age_name = ageName;
                Ptmp.conditions_to_compare = conditions_to_run;

                try
                    run_conditions_within_age(TD, subjFields, Ptmp, PLT, IO);
                catch ME
                    fprintf('\n[WARNING] Failed: conditions within age | muscle=%s | age=%s\n', muscleName, ageName);
                    fprintf('%s\n', ME.message);
                end
            end
        else
            fprintf('\n[INFO] Skipping condition-within-age analyses as per configuration.\n');
        end

        % -------------------------------------------------
        % 2) Age-group effect within each condition
        % -------------------------------------------------
        if P.run_age_within_condition && isempty(age_groups_to_run)
            fprintf('\n[WARNING] No age groups specified to run for age-within-condition analyses. Skipping this step.\n');
        elseif P.run_age_within_condition
            for iC = 1:numel(conditions_to_run)
                condName = conditions_to_run(iC);

                Ptmp = P;
                Ptmp.muscle_name = muscleName;
                Ptmp.condition_name = condName;
                Ptmp.age_groups_to_compare = age_groups_to_run;

                try
                    run_ages_within_condition(TD, subjFields, Ptmp, PLT, IO);
                catch ME
                    fprintf('\n[WARNING] Failed: ages within condition | muscle=%s | condition=%s\n', muscleName, condName);
                    fprintf('%s\n', ME.message);
                end
            end
        else
            fprintf('\n[INFO] Skipping age-within-condition analyses as per configuration.\n');
        end

        % -------------------------------------------------
        % 3) Condition effect across all age groups pooled
        % -------------------------------------------------
        if P.run_conditions_all_ages_pooled && isempty(conditions_to_run)
            fprintf('\n[WARNING] No conditions specified to run for condition-all-ages-pooled analyses. Skipping this step.\n');
        elseif P.run_conditions_all_ages_pooled
            Ptmp = P;
            Ptmp.muscle_name = muscleName;
            Ptmp.conditions_to_compare = conditions_to_run;

            try
                run_conditions_all_ages_pooled(TD, subjFields, Ptmp, PLT, IO);
            catch ME
                fprintf('\n[WARNING] Failed: conditions pooled across ages | muscle=%s\n', muscleName);
                fprintf('%s\n', ME.message);
            end
        else
            fprintf('\n[INFO] Skipping condition-all-ages-pooled analyses as per configuration.\n');
        end

        % -------------------------------------------------
        % 4) Age-group effect across all conditions pooled
        % -------------------------------------------------
        if P.run_ages_all_conditions_pooled && isempty(age_groups_to_run)
            fprintf('\n[WARNING] No age groups specified to run for ages-all-conditions-pooled analyses. Skipping this step.\n');
        elseif P.run_ages_all_conditions_pooled
            Ptmp = P;
            Ptmp.muscle_name = muscleName;
            Ptmp.age_groups_to_compare = age_groups_to_run;
            Ptmp.conditions_to_compare = conditions_to_run;

            try
                run_ages_all_conditions_pooled(TD, subjFields, Ptmp, PLT, IO);
            catch ME
                fprintf('\n[WARNING] Failed: ages pooled across conditions | muscle=%s\n', muscleName);
                fprintf('%s\n', ME.message);
            end
        else
            fprintf('\n[INFO] Skipping ages-all-conditions-pooled analyses as per configuration.\n');
        end

        % -------------------------------------------------
        % 5) Age group × condition interaction
        % -------------------------------------------------
        if isfield(P, 'run_age_condition_interaction') && P.run_age_condition_interaction

            Ptmp = P;
            Ptmp.muscle_name = muscleName;
            Ptmp.age_groups_to_compare = age_groups_to_run;
            Ptmp.conditions_to_compare = conditions_to_run;
            Ptmp.normalization_mode = string(P.normalization_mode_interaction);

            try
                run_age_condition_interaction(TD, subjFields, Ptmp, PLT, IO);
            catch ME
                fprintf('\n[WARNING] Failed: age × condition interaction | muscle=%s\n', muscleName);
                fprintf('%s\n', ME.message);
            end

        else
            fprintf('\n[INFO] Skipping age × condition interaction as per configuration.\n');
        end

        % -------------------------------------------------
        % 5) Symmetry: within-condition leg differences
        % -------------------------------------------------
        % if P.run_symmetry_within_condition
        %     for iA = 1:numel(age_groups_to_run)
        %         for iC = 1:numel(conditions_to_run)

        %             Tsi = compute_symmetry_index_table(TD, subjFields, P);

        %             writetable(Tsi, IO.symmetry_csv);

        %             for iM = 1:numel(string(P.muscles_to_run))
        %                 muscleName = string(P.muscles_to_run(iM));

        %                 plot_symmetry_boxplot_by_condition(Tsi, muscleName, P, PLT, IO);
        %                 plot_symmetry_boxplot_by_age(Tsi, muscleName, P, PLT, IO);
        %                 plot_symmetry_grouped_condition_by_age(Tsi, muscleName, P, PLT, IO);
        %             end

        %         end
        %     end
        % else
        %     fprintf('\n[INFO] Skipping symmetry-within-condition analyses as per configuration.\n');
        % end
    end

    if isfield(P, 'run_symmetry_indices') && P.run_symmetry_indices

        if ~exist(IO.symmetry_plot_dir, 'dir')
            mkdir(IO.symmetry_plot_dir);
        end

        Tsi = compute_symmetry_index_table(TD, subjFields, P);

        writetable(Tsi, IO.symmetry_csv);
        fprintf('\nSymmetry index table saved to:\n%s\n', IO.symmetry_csv);

        for iM = 1:numel(string(P.muscles_to_run))
            muscleName = string(P.muscles_to_run(iM));

            plot_symmetry_boxplot_by_condition(Tsi, muscleName, P, PLT, IO);
            plot_symmetry_boxplot_by_age(Tsi, muscleName, P, PLT, IO);
            plot_symmetry_grouped_condition_by_age(Tsi, muscleName, P, PLT, IO);
        end
    end

    fprintf('\nDone. Full SPM batch results saved in:\n%s\n', IO.out_dir);

    close all force;
    set(0, 'DefaultFigureVisible', 'on');
    set(groot, 'DefaultFigureVisible', 'on');
end

%% ===================== MAIN ANALYSIS FUNCTIONS =====================

function run_conditions_within_age(TD, subjFields, P, PLT, IO)

    muscleName = string(P.muscle_name);
    ageName    = string(P.age_name);
    condNames  = string(P.conditions_to_compare);
    methodLabel = get_spm_method_label(P);

    P.normalization_mode = P.normalization_mode_condition;

    fprintf('\n====================================================\n');
    fprintf('%s analysis: condition effect within age group\n', methodLabel);
    fprintf('Muscle: %s\n', muscleName);
    fprintf('Age group: %s\n', ageName);
    fprintf('Conditions: %s\n', strjoin(condNames, ', '));
    fprintf('====================================================\n');

    nCond = numel(condNames);
    assert(nCond >= 2, 'Need at least 2 conditions to compare.');

    % ---------- collect subject-level mean profiles per condition ----------
    Ycell = cell(1, nCond);
    subjCell = cell(1, nCond);

    for k = 1:nCond
        [Ycell{k}, subjCell{k}] = collect_subject_mean_profiles( TD, subjFields, muscleName, condNames(k), ageName, P);
    end

    % ---------- keep only complete-case subjects across all conditions ----------
    [Ymatched, commonSubj] = keep_only_complete_subjects(Ycell, subjCell);

    print_condition_counts(condNames, subjCell, commonSubj);
    assert(~isempty(commonSubj), 'No complete-case subjects found across all requested conditions.');

    % ---------- descriptive plot ----------
    if P.show_spm_bottom_plot
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 850]);
        ax1 = subplot(2,1,1);
    else
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 500]);
        ax1 = axes(fig); %#ok<LAXES>
    end

    hold(ax1, 'on');

    for k = 1:nCond
        Yk = Ymatched{k};
        col = get_color_safe(PLT.colors, char(condNames(k)), [0 0 0]);

        if P.show_sem
            plot_mean_sem(ax1, Yk, col, sprintf('%s (n=%d)', condNames(k), size(Yk,1)), PLT.AlphaTransparency);
        else
            x = linspace(0,100,size(Yk,2));
            plot(ax1, x, mean(Yk,1), 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', condNames(k), size(Yk,1)));
        end
    end

    xlabel(ax1, 'Gait cycle (%)');
    ylabel(ax1, get_ylabel_text(P));
    title(ax1, sprintf('%s | %s | condition effect', muscleName, ageName), 'Interpreter','none');
    legend(ax1, 'Location','best');
    grid(ax1, 'on');
    xlim(ax1, [0 100]);

    % default
    nTimePoints = [];

    % ---------- run SPM ----------
    if nCond == 2
        Y1 = Ymatched{1};
        Y2 = Ymatched{2};

        [spmi, testName] = run_spm_paired_ttest(Y1, Y2, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y1, 2);

        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();
            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s vs %s', methodLabel, prettyTest, condNames(1), condNames(2)), 'Interpreter','none');
        end
        outName = sprintf('%s_conditionsWithinAge_%s_%s_%s_vs_%s.png', methodLabel, muscleName, ageName, condNames(1), condNames(2));

        fprintf('\nTest used: %s\n', char(testName));
        fprintf('Matched subjects: %d\n', numel(commonSubj));
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.condition_effects_csv, spmi, "condition_within_age", muscleName, ageName, "", strjoin(condNames, "|"), "", testName, nTimePoints, size(Ymatched{1},1), P);
    else
        % repeated-measures one-way ANOVA
        [Y, A, SUBJ] = build_rm_design(Ymatched);

        try
            [spmi, testName] = run_spm_anova1rm(Y, A, SUBJ, P);
            prettyTest = get_pretty_test_name(testName);
            if ~isempty(get_spmi_clusters_safe(spmi))
                csvFile = fullfile(IO.csv_dir, sprintf( 'POSTHOC_conditionsWithinAge_%s_%s.csv', muscleName, ageName));

                run_posthoc_spm_paired(Ymatched, condNames, P, csvFile);
            end

            nTimePoints = size(Y, 2);

            if P.show_spm_bottom_plot
                ax2 = subplot(2,1,2);
                axes(ax2); %#ok<LAXES>
                spmi.plot();
                set(gcf, 'Visible', 'off');
                spmi.plot_threshold_label();
                spmi.plot_p_values();
                format_spm_axis_as_gait_cycle(ax2, nTimePoints);
                title(ax2, sprintf('%s %s | %s', methodLabel, prettyTest, strjoin(condNames, ', ')), 'Interpreter','none');
            end

            outName = sprintf('%s_conditionsWithinAge_%s_%s_ANOVA.png', methodLabel, muscleName, ageName);

            fprintf('\nTest used: %s\n', char(prettyTest));
            fprintf('Complete-case subjects: %d\n', numel(commonSubj));
            print_spm_clusters(spmi);
            append_spm_results_to_csv(IO.condition_effects_csv, spmi, "condition_within_age", muscleName, ageName, "", strjoin(condNames, "|"), "", testName, nTimePoints, size(Ymatched{1},1), P);
        catch ME
            close(fig);
            error(['Repeated-measures ANOVA failed. ', 'Check your local SPM1D version / syntax. Original error:\n%s'], ME.message);
        end
    end

    % ---------- significance bars on top descriptive plot ----------
    add_spm_significance_bars(ax1, spmi, nTimePoints, 'y_frac', 0.90, 'line_width', 1.5, 'color', [0 0 0]);

    set(fig, 'Visible', 'off');
    saveas(fig, fullfile(IO.out_dir, outName));
    close(fig);
end

function run_ages_within_condition(TD, subjFields, P, PLT, IO)

    muscleName = string(P.muscle_name);
    condName   = string(P.condition_name);
    ageNames   = string(P.age_groups_to_compare);
    methodLabel = get_spm_method_label(P);

    P.normalization_mode = P.normalization_mode_age;

    fprintf('\n====================================================\n');
    fprintf('%s analysis: age-group effect within condition\n', methodLabel);
    fprintf('Muscle: %s\n', muscleName);
    fprintf('Condition: %s\n', condName);
    fprintf('Age groups: %s\n', strjoin(ageNames, ', '));
    fprintf('====================================================\n');

    nAge = numel(ageNames);
    assert(nAge >= 2, 'Need at least 2 age groups to compare.');

    % ---------- collect subject-level mean profiles per age group ----------
    Ycell = cell(1, nAge);
    subjCell = cell(1, nAge);

    for k = 1:nAge
        [Ycell{k}, subjCell{k}] = collect_subject_mean_profiles( TD, subjFields, muscleName, condName, ageNames(k), P);
    end

    % ---------- descriptive plot ----------
    if P.show_spm_bottom_plot
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 850]);
        ax1 = subplot(2,1,1);
    else
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 500]);
        ax1 = axes(fig); %#ok<LAXES>
    end
    hold(ax1, 'on');
    for k = 1:nAge
        Yk = Ycell{k};
        if isempty(Yk), continue; end

        col = get_color_safe(PLT.colors, char(ageNames(k)), [0 0 0]);

        if P.show_sem
            plot_mean_sem(ax1, Yk, col, sprintf('%s (n=%d)', ageNames(k), size(Yk,1)), PLT.AlphaTransparency);
        else
            x = linspace(0,100,size(Yk,2));
            plot(ax1, x, mean(Yk,1), 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', ageNames(k), size(Yk,1)));
        end
    end

    xlabel(ax1, 'Gait cycle (%)');
    ylabel(ax1, get_ylabel_text(P));
    title(ax1, sprintf('%s | %s | age-group effect', muscleName, condName), 'Interpreter','none');
    legend(ax1, 'Location','best');
    grid(ax1, 'on');
    xlim(ax1, [0 100]);

    % default
    nTimePoints = [];

    % ---------- run SPM ----------
    if nAge == 2
        Y1 = Ycell{1};
        Y2 = Ycell{2};

        assert(~isempty(Y1) && ~isempty(Y2), 'Not enough data for two-sample SPM.');

        [spmi, testName] = run_spm_ttest2(Y1, Y2, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y1, 2);
        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();

            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s vs %s', methodLabel, prettyTest, ageNames(1), ageNames(2)), 'Interpreter','none');
        end

        outName = sprintf('%s_agesWithinCondition_%s_%s_%s_vs_%s.png', methodLabel, muscleName, condName, ageNames(1), ageNames(2));

        fprintf('\nTest used: %s\n', char(prettyTest));
        fprintf('%s: n=%d\n', ageNames(1), size(Y1,1));
        fprintf('%s: n=%d\n', ageNames(2), size(Y2,1));
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.age_effects_csv, spmi, "age_within_condition", muscleName, "", condName, "", strjoin(ageNames, "|"), testName, nTimePoints, size(Y1,1) + size(Y2,1), P);

    else
        [Y, A] = build_oneway_design(Ycell);

        try
            [spmi, testName] = run_spm_anova1(Y, A, P);
            prettyTest = get_pretty_test_name(testName);
            if ~isempty(get_spmi_clusters_safe(spmi))
                csvFile = fullfile(IO.csv_dir, sprintf( 'POSTHOC_agesWithinCondition_%s_%s.csv', muscleName, condName));

                run_posthoc_spm(Ycell, ageNames, P, csvFile);
            end

            nTimePoints = size(Y, 2);
            if P.show_spm_bottom_plot
                ax2 = subplot(2,1,2);
                axes(ax2); %#ok<LAXES>
                spmi.plot();
                set(gcf, 'Visible', 'off');
                spmi.plot_threshold_label();
                spmi.plot_p_values();
                format_spm_axis_as_gait_cycle(ax2, nTimePoints);
                title(ax2, sprintf('%s %s | %s', methodLabel, prettyTest, strjoin(ageNames, ', ')), 'Interpreter','none');
            end

            outName = sprintf('%s_agesWithinCondition_%s_%s_ANOVA.png', methodLabel, muscleName, condName);

            fprintf('\nTest used: %s\n', char(prettyTest));
            for k = 1:nAge
                fprintf('%s: n=%d\n', ageNames(k), size(Ycell{k},1));
            end
            print_spm_clusters(spmi);
            append_spm_results_to_csv(IO.age_effects_csv, spmi, "age_within_condition", muscleName, "", condName, "", strjoin(ageNames, "|"), testName, nTimePoints, size(Y,1), P);

        catch ME
            close(fig);
            error(['One-way ANOVA failed. ', 'Check your local SPM1D version / syntax. Original error:\n%s'], ME.message);
        end
    end

    % ---------- significance bars on top descriptive plot ----------
    add_spm_significance_bars(ax1, spmi, nTimePoints, 'y_frac', 0.90, 'line_width', 1.5, 'color', [0 0 0]);

    set(fig, 'Visible', 'off');
    saveas(fig, fullfile(IO.out_dir, outName));
    close(fig);
end

%% ===================== DATA COLLECTION FUNCTIONS =====================

function [Y, subjectIDs] = collect_subject_mean_profiles(TD, subjFields, muscleName, condName, ageName, P)

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

            if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                continue;
            end

            if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                continue;
            end

            VC = S.valid_cycles;
            xcell = get_profile_cell_from_valid_cycles(VC, P);

            if isempty(xcell)
                continue;
            end

            for iC = 1:numel(xcell)
                x = xcell{iC};
                if isempty(x) || ~isnumeric(x) || any(~isfinite(x(:)))
                    continue;
                end
                subjCycleProfiles{end+1,1} = x(:)'; %#ok<AGROW>
            end
        end

        if ~isempty(subjCycleProfiles)
            X = vertcat(subjCycleProfiles{:});

            % remove invalid cycles first
            validRows = all(isfinite(X), 2);
            X = X(validRows, :);

            if isempty(X)
                continue;
            end

            m = mean(X, 1);

            % SPM cannot handle NaNs/Infs in subject profiles
            if any(~isfinite(m))
                continue;
            end

            subjectMeans{end+1,1} = m; %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(subjectMeans)
        Y = [];
    else
        Y = vertcat(subjectMeans{:});
    end
end

function xcell = get_profile_cell_from_valid_cycles(VC, P)

    xcell = {};
    sigName = string(P.signal_name);
    normMode = string(P.normalization_mode);

    if normMode ~= "none"
        sigName = sigName + "_norm" + "_" + normMode;
    end

    if P.use_time_normalized
        fn = "time_normalized_" + sigName;
        if isfield(VC, char(fn))
            xcell = VC.(char(fn));
        end
    end

    if isempty(xcell)
        if isfield(VC, char(sigName))
            xcell = VC.(char(sigName));
        end
    end

    if isempty(xcell)
        return;
    end

    % -------------------------------------------------
    % Optional amplitude QC cycle exclusion
    % -------------------------------------------------
    if isfield(P, 'apply_amplitude_qc_exclusion') && P.apply_amplitude_qc_exclusion

        maskField = char("amplitude_qc_keep_" + string(P.normalization_mode));

        if isfield(VC, maskField)
            keepMask = VC.(maskField);

            keepMask = logical(keepMask(:));
            n = min(numel(keepMask), numel(xcell));

            xcell = xcell(1:n);
            keepMask = keepMask(1:n);

            xcell = xcell(keepMask);
        end

        % Signal-level rule after cycle exclusion
        if isfield(P, 'min_cycles_after_amplitude_qc') && ~isempty(P.min_cycles_after_amplitude_qc)
            if numel(xcell) < P.min_cycles_after_amplitude_qc
                xcell = {};
                return;
            end
        end
    end
end

function TD = add_normalized_signal_fields(TD, subjFields, P)

    normMode = string(P.normalization_mode);
    sigName  = string(P.signal_name);

    if normMode == "none"
        fprintf('\nNo amplitude normalization applied.\n');
        return;
    end

    fprintf('\nAdding normalized signal fields...\n');
    fprintf('Normalization mode: %s\n', normMode);

    if isfield(P, 'norm_reference_percentile') && ~isempty(P.norm_reference_percentile)
        prc = P.norm_reference_percentile;
    else
        prc = 100;
    end

    for iS = 1:numel(subjFields)

        subjID = subjFields{iS};

        % ---------------------------------------------------------
        % 1) Compute reference value per subject x muscle
        % ---------------------------------------------------------
        refByLegMuscle = struct();

        % ---------------------------------------------------------
        % Reference definition
        %
        % flatmax:
        %   subject × leg × muscle × Flat condition × max
        %
        % flat_percentile:
        %   subject × leg × muscle × Flat condition × percentile
        %
        % subject_percentile:
        %   subject × leg × muscle × all included conditions × percentile
        %
        % cyclemax:
        %   each cycle normalized to its own maximum
        % ---------------------------------------------------------

        switch normMode

            case "flatmax"
                refByLegMuscle = compute_subject_muscle_reference( TD, subjID, sigName, "Flat", 100);

            case "flat_percentile"
                refByLegMuscle = compute_subject_muscle_reference( TD, subjID, sigName, "Flat", prc);

            case "subject_percentile"
                refByLegMuscle = compute_subject_muscle_reference( TD, subjID, sigName, "__ALL_CONDITIONS__", prc);

            case "cyclemax"
                % handled later cycle-by-cycle
                refByLegMuscle = struct();

            otherwise
                error('Unknown normalization_mode: %s', normMode);
        end

        % ---------------------------------------------------------
        % 2) Apply normalization to all conditions / legs / muscles
        % ---------------------------------------------------------
        condFields = fieldnames(TD.(subjID));

        for ic = 1:numel(condFields)

            cond = condFields{ic};
            legFields = fieldnames(TD.(subjID).(cond));

            for il = 1:numel(legFields)

                leg = legFields{il};
                muscleFields = fieldnames(TD.(subjID).(cond).(leg));

                for iM = 1:numel(muscleFields)

                    muscleName = muscleFields{iM};
                    S = TD.(subjID).(cond).(leg).(muscleName);

                    if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                        continue;
                    end

                    VC = S.valid_cycles;

                    if normMode == "cyclemax"
                        VC = add_cyclemax_normalized_fields(VC, sigName, P);
                    else
                        if ~isfield(refByLegMuscle, leg) || ~isfield(refByLegMuscle.(leg), muscleName)
                            VC = add_nan_normalized_fields_to_VC(VC, sigName, P);
                        else
                            refVal = refByLegMuscle.(leg).(muscleName);

                            if isempty(refVal) || ~isfinite(refVal) || refVal <= 0
                                VC = add_nan_normalized_fields_to_VC(VC, sigName, P);
                            else
                                VC = add_reference_normalized_fields_to_VC(VC, sigName, refVal, P);
                            end
                        end
                    end

                    TD.(subjID).(cond).(leg).(muscleName).valid_cycles = VC;
                end
            end
        end
    end

    fprintf('Done adding normalized signal fields.\n');
end

%% ===================== SUBJECT MATCHING / DESIGN MATRICES =====================

function [Ycell_matched, commonSubj] = keep_only_complete_subjects(Ycell, subjCell)

    nCond = numel(Ycell);
    assert(nCond == numel(subjCell), 'Ycell and subjCell must have same length.');

    commonSubj = subjCell{1};
    for k = 2:nCond
        commonSubj = intersect(commonSubj, subjCell{k}, 'stable');
    end

    Ycell_matched = cell(1, nCond);

    for k = 1:nCond
        [~, ia, ~] = intersect(subjCell{k}, commonSubj, 'stable');
        Ycell_matched{k} = Ycell{k}(ia, :);
    end
end

function print_condition_counts(condNames, subjCell, commonSubj)
    fprintf('\n=== CONDITION COUNTS ===\n');
    for k = 1:numel(condNames)
        fprintf('%s: %d subjects\n', string(condNames(k)), numel(subjCell{k}));
    end
    fprintf('Complete subjects across all requested conditions: %d\n', numel(commonSubj));
end

function [Y, A, SUBJ] = build_rm_design(Ycell)

    nCond = numel(Ycell);
    nSubj = size(Ycell{1},1);

    Y = [];
    A = [];
    SUBJ = [];

    for k = 1:nCond
        Y = [Y; Ycell{k}]; %#ok<AGROW>
        A = [A; k * ones(nSubj,1)]; %#ok<AGROW>
        SUBJ = [SUBJ; (1:nSubj)']; %#ok<AGROW>
    end
end

function [Y, A] = build_oneway_design(Ycell)

    nGroups = numel(Ycell);

    Y = [];
    A = [];

    for k = 1:nGroups
        Yk = Ycell{k};
        if isempty(Yk), continue; end

        nk = size(Yk,1);
        Y = [Y; Yk]; %#ok<AGROW>
        A = [A; k * ones(nk,1)]; %#ok<AGROW>
    end
end

%% ===================== PLOTTING FUNCTIONS =====================

function plot_mean_sem(ax, X, col, labelText, alphaVal)
    if isempty(X), return; end

    M = mean(X, 1, 'omitnan');
    S = std(X, 0, 1, 'omitnan') ./ sqrt(size(X,1));
    x = linspace(0, 100, numel(M));

    fill(ax, [x fliplr(x)], [M-S fliplr(M+S)], col, 'FaceAlpha', alphaVal, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    plot(ax, x, M, 'LineWidth', 2, 'Color', col, 'DisplayName', labelText);
end

function col = get_color_safe(colorStruct, fieldName, fallback)
    if isfield(colorStruct, fieldName)
        col = colorStruct.(fieldName);
    else
        col = fallback;
    end
end
function ytxt = get_ylabel_text(P)


    normMode = string(P.normalization_mode);
    sigName  = string(P.signal_name);

    if normMode == "none"
        if P.use_time_normalized
            ytxt = sprintf('Time-normalized %s amplitude', sigName);
        else
            ytxt = sprintf('%s amplitude', sigName);
        end
        return;
    end

    if isfield(P, 'norm_reference_percentile') && ~isempty(P.norm_reference_percentile)
        prc = P.norm_reference_percentile;
    else
        prc = 100;
    end

    switch normMode
        case "cyclemax"
            ytxt = sprintf('%s (%% cycle max)', sigName);

        case "flatmax"
            ytxt = sprintf('%s (%% Flat max)', sigName);

        case "flat_percentile"
            ytxt = sprintf('%s (%% Flat P%d)', sigName, prc);

        case "subject_percentile"
            ytxt = sprintf('%s (%% subject P%d)', sigName, prc);

        otherwise
            ytxt = sprintf('%s normalized amplitude', sigName);
    end
end

%% ===================== CONSOLE SUMMARY =====================
function clusters = get_spmi_clusters_safe(spmi)

    clusters = [];

    try
        if isprop(spmi, 'clusters')
            raw = spmi.clusters;
        elseif isstruct(spmi) && isfield(spmi, 'clusters')
            raw = spmi.clusters;
        else
            return;
        end

        if isempty(raw)
            return;
        end

        if iscell(raw)
            raw = [raw{:}];
        end

        clusters = raw;

    catch
        fprintf('\n[WARNING] Unable to extract clusters from SPM inference object.\n');
        clusters = [];
    end
end


function print_spm_clusters(spmi)

    fprintf('\n=== SPM CLUSTER SUMMARY ===\n');

    clusters = get_spmi_clusters_safe(spmi);

    if isempty(clusters)
        fprintf('No significant clusters.\n');
        return;
    end

    fprintf('Number of significant clusters: %d\n', numel(clusters));

    for i = 1:numel(clusters)
        c = clusters(i);
        fprintf('Cluster %d:\n', i);

        if isobject(c)
            if isprop(c, 'endpoints') && ~isempty(c.endpoints)
                fprintf('  endpoints: [%.2f, %.2f]\n', c.endpoints(1), c.endpoints(2));
            end
            if isprop(c, 'P') && ~isempty(c.P)
                fprintf('  p-value: %.5f\n', c.P);
            end
            if isprop(c, 'extent') && ~isempty(c.extent)
                fprintf('  extent: %.3f\n', c.extent);
            end
        elseif isstruct(c)
            if isfield(c, 'endpoints') && ~isempty(c.endpoints)
                fprintf('  endpoints: [%.2f, %.2f]\n', c.endpoints(1), c.endpoints(2));
            end
            if isfield(c, 'P') && ~isempty(c.P)
                fprintf('  p-value: %.5f\n', c.P);
            end
            if isfield(c, 'extent') && ~isempty(c.extent)
                fprintf('  extent: %.3f\n', c.extent);
            end
        else
            fprintf('  (unable to extract cluster details)\n');
        end
    end
end


function add_spm_significance_bars(ax, spmi, nTimePoints, varargin)
% Add horizontal bars on top of the descriptive plot for significant SPM clusters

    p = inputParser;
    addParameter(p, 'y_frac', 0.90);
    addParameter(p, 'line_width', 2);              % thinner default
    addParameter(p, 'color', [0 0 0]);
    addParameter(p, 'show_p_text', false);
    addParameter(p, 'show_stars', true);
    addParameter(p, 'star_font_size', 11);
    addParameter(p, 'show_edge_lines', true);
    addParameter(p, 'edge_line_color', [0.85 0.85 0.85]); % very light grey
    addParameter(p, 'edge_line_style', '-');
    addParameter(p, 'edge_line_width', 0.8);
    parse(p, varargin{:});

    y_frac          = p.Results.y_frac;
    lw              = p.Results.line_width;
    col             = p.Results.color;
    show_p_text     = p.Results.show_p_text;
    show_stars      = p.Results.show_stars;
    star_font_size  = p.Results.star_font_size;
    show_edge_lines = p.Results.show_edge_lines;
    edge_col        = p.Results.edge_line_color;
    edge_ls         = p.Results.edge_line_style;
    edge_lw         = p.Results.edge_line_width;

    hold(ax, 'on');

    clusters = get_spmi_clusters_safe(spmi);
    if isempty(clusters)
        return;
    end

    yl = ylim(ax);
    y  = yl(1) + y_frac * (yl(2) - yl(1));
    tick_h = 0.012 * (yl(2) - yl(1));   % smaller ticks
    text_offset = 0.018 * (yl(2) - yl(1));

    % optional: expand ylim a little if needed
    if y >= yl(2)
        ylim(ax, [yl(1), yl(1) + 1.08*(yl(2)-yl(1))]);
        yl = ylim(ax);
        y  = yl(1) + y_frac * (yl(2) - yl(1));
        tick_h = 0.012 * (yl(2) - yl(1));
        text_offset = 0.018 * (yl(2) - yl(1));
    end

    for i = 1:numel(clusters)
        c = clusters(i);

        endpoints = [];
        pval = [];

        if isobject(c)
            if isprop(c, 'endpoints')
                endpoints = c.endpoints;
            end
            if isprop(c, 'P')
                pval = c.P;
            end
        elseif isstruct(c)
            if isfield(c, 'endpoints')
                endpoints = c.endpoints;
            end
            if isfield(c, 'P')
                pval = c.P;
            end
        end

        if isempty(endpoints) || numel(endpoints) < 2
            continue;
        end

        % convert SPM sample coordinates to gait cycle %
        x1 = 100 * (endpoints(1) - 1) / max(1, nTimePoints - 1);
        x2 = 100 * (endpoints(2) - 1) / max(1, nTimePoints - 1);
        xm = mean([x1 x2]);

        % optional very light vertical delimiter lines
        if show_edge_lines
            plot(ax, [x1 x1], yl, edge_ls, 'Color', edge_col, 'LineWidth', edge_lw, 'HandleVisibility', 'off');
            plot(ax, [x2 x2], yl, edge_ls, 'Color', edge_col, 'LineWidth', edge_lw, 'HandleVisibility', 'off');
        end

        % main significance bar
        plot(ax, [x1 x2], [y y], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

        % end ticks
        plot(ax, [x1 x1], [y-tick_h y+tick_h], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');
        plot(ax, [x2 x2], [y-tick_h y+tick_h], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

        % stars
        if show_stars && ~isempty(pval)
            stars = p_to_stars(pval);
            if ~isempty(stars)
                text(ax, xm, y + text_offset, stars, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', col, 'FontWeight', 'bold', 'FontSize', star_font_size, 'Clipping', 'off');
            end
        end

        % optional p-value text instead of stars
        if show_p_text && ~isempty(pval)
            text(ax, xm, y + text_offset, sprintf('p=%.3g', pval), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', col, 'FontSize', 9, 'Clipping', 'off');
        end
    end
end


function stars = p_to_stars(p)
    if isempty(p) || isnan(p)
        stars = '';
    elseif p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = '';
    end
end

function run_conditions_all_ages_pooled(TD, subjFields, P, PLT, IO)

    muscleName = string(P.muscle_name);
    condNames  = string(P.conditions_to_compare);
    methodLabel = get_spm_method_label(P);

    P.normalization_mode = P.normalization_mode_condition;

    fprintf('\n====================================================\n');
    fprintf('%s analysis: condition effect across all age groups pooled\n', methodLabel);
    fprintf('Muscle: %s\n', muscleName);
    fprintf('Conditions: %s\n', strjoin(condNames, ', '));
    fprintf('====================================================\n');

    nCond = numel(condNames);
    assert(nCond >= 2, 'Need at least 2 conditions to compare.');

    Ycell = cell(1, nCond);
    subjCell = cell(1, nCond);

    for k = 1:nCond
        [Ycell{k}, subjCell{k}] = collect_subject_mean_profiles_all_ages( TD, subjFields, muscleName, condNames(k), P);
    end

    [Ymatched, commonSubj] = keep_only_complete_subjects(Ycell, subjCell);

    print_condition_counts(condNames, subjCell, commonSubj);
    assert(~isempty(commonSubj), 'No complete-case subjects found across all requested conditions.');

    if P.show_spm_bottom_plot
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 850]);
        ax1 = subplot(2,1,1);
    else
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 500]);
        ax1 = axes(fig); %#ok<LAXES>
    end

    hold(ax1, 'on');

    for k = 1:nCond
        Yk = Ymatched{k};
        col = get_color_safe(PLT.colors, char(condNames(k)), [0 0 0]);

        if P.show_sem
            plot_mean_sem(ax1, Yk, col, sprintf('%s (n=%d)', condNames(k), size(Yk,1)), PLT.AlphaTransparency);
        else
            x = linspace(0,100,size(Yk,2));
            plot(ax1, x, mean(Yk,1), 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', condNames(k), size(Yk,1)));
        end
    end

    xlabel(ax1, 'Gait cycle (%)');
    ylabel(ax1, get_ylabel_text(P));
    title(ax1, sprintf('%s | condition effect | all age groups pooled', prettymuscle(muscleName)), 'Interpreter','none');
    legend(ax1, 'Location','best');
    grid(ax1, 'on');
    xlim(ax1, [0 100]);

    nTimePoints = [];

    if nCond == 2
        Y1 = Ymatched{1};
        Y2 = Ymatched{2};

        [spmi, testName] = run_spm_paired_ttest(Y1, Y2, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y1, 2);

        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();
            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s vs %s', methodLabel, prettyTest, condNames(1), condNames(2)), 'Interpreter','none');
        end

        outName = sprintf('%s_conditionsAllAgesPooled_%s_%s_vs_%s.png', methodLabel, muscleName, condNames(1), condNames(2));

        fprintf('\nTest used: %s\n', char(prettyTest));
        fprintf('Matched subjects: %d\n', numel(commonSubj));
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.condition_effects_csv, spmi, "condition_all_ages_pooled", muscleName, "ALL_AGES", "", strjoin(condNames, "|"), "", "paired_ttest", nTimePoints, size(Ymatched{1},1), P);

    else
        [Y, A, SUBJ] = build_rm_design(Ymatched);

        [spmi, testName] = run_spm_anova1rm(Y, A, SUBJ, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y, 2);

        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();
            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s', methodLabel, prettyTest, strjoin(condNames, ', ')), 'Interpreter','none');
        end

        outName = sprintf('%s_conditionsAllAgesPooled_%s_ANOVA.png', methodLabel, muscleName);

        prettyTest = get_pretty_test_name(testName);
        fprintf('\nTest used: %s\n', char(prettyTest));
        fprintf('Complete-case subjects: %d\n', numel(commonSubj));
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.condition_effects_csv, spmi, "condition_all_ages_pooled", muscleName, "ALL_AGES", "", strjoin(condNames, "|"), "", "anova1rm", nTimePoints, size(Y,1), P);
    end

    add_spm_significance_bars(ax1, spmi, nTimePoints, 'y_frac', 0.90, 'line_width', 1.5, 'color', [0 0 0]);
    set(fig, 'Visible', 'off');
    saveas(fig, fullfile(IO.out_dir, outName));
    close(fig);
end

function run_ages_all_conditions_pooled(TD, subjFields, P, PLT, IO)

    muscleName = string(P.muscle_name);
    ageNames   = string(P.age_groups_to_compare);
    condNames  = string(P.conditions_to_compare);
    methodLabel = get_spm_method_label(P);

    P.normalization_mode = P.normalization_mode_age;

    fprintf('\n====================================================\n');
    fprintf('SPM analysis: age-group effect across all conditions pooled\n');
    fprintf('Muscle: %s\n', muscleName);
    fprintf('Age groups: %s\n', strjoin(ageNames, ', '));
    fprintf('Conditions pooled: %s\n', strjoin(condNames, ', '));
    fprintf('====================================================\n');

    nAge = numel(ageNames);
    assert(nAge >= 2, 'Need at least 2 age groups to compare.');

    Ycell = cell(1, nAge);
    subjCell = cell(1, nAge);

    for k = 1:nAge
        [Ycell{k}, subjCell{k}] = collect_subject_mean_profiles_all_conditions( TD, subjFields, muscleName, condNames, ageNames(k), P);
    end

    if P.show_spm_bottom_plot
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 850]);
        ax1 = subplot(2,1,1);
    else
        fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1000 500]);
        ax1 = axes(fig); %#ok<LAXES>
    end
    hold(ax1, 'on');

    for k = 1:nAge
        Yk = Ycell{k};
        if isempty(Yk), continue; end

        col = get_color_safe(PLT.colors, char(ageNames(k)), [0 0 0]);

        if P.show_sem
            plot_mean_sem(ax1, Yk, col, sprintf('%s (n=%d)', ageNames(k), size(Yk,1)), PLT.AlphaTransparency);
        else
            x = linspace(0,100,size(Yk,2));
            plot(ax1, x, mean(Yk,1), 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', ageNames(k), size(Yk,1)));
        end
    end

    xlabel(ax1, 'Gait cycle (%)');
    ylabel(ax1, get_ylabel_text(P));
    title(ax1, sprintf('%s | age-group effect | all conditions pooled', prettymuscle(muscleName)), 'Interpreter','none');
    legend(ax1, 'Location','best');
    grid(ax1, 'on');
    xlim(ax1, [0 100]);

    nTimePoints = [];

    if nAge == 2
        Y1 = Ycell{1};
        Y2 = Ycell{2};

        assert(~isempty(Y1) && ~isempty(Y2), 'Not enough data for two-sample SPM.');

        [spmi, testName] = run_spm_ttest2(Y1, Y2, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y1, 2);

        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();
            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s vs %s', methodLabel, prettyTest, ageNames(1), ageNames(2)), 'Interpreter','none');
        end

        outName = sprintf('%s_agesAllConditionsPooled_%s_%s_vs_%s.png', methodLabel, muscleName, ageNames(1), ageNames(2));

        fprintf('\nTest used: %s\n', char(prettyTest));
        fprintf('%s: n=%d\n', ageNames(1), size(Y1,1));
        fprintf('%s: n=%d\n', ageNames(2), size(Y2,1));
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.age_effects_csv, spmi, "age_all_conditions_pooled", muscleName, "", "ALL_CONDITIONS", "", strjoin(ageNames, "|"), "ttest2", nTimePoints, size(Y1,1) + size(Y2,1), P);
    else
        [Y, A] = build_oneway_design(Ycell);

        [spmi, testName] = run_spm_anova1(Y, A, P);
        prettyTest = get_pretty_test_name(testName);

        nTimePoints = size(Y, 2);

        if P.show_spm_bottom_plot
            ax2 = subplot(2,1,2);
            axes(ax2); %#ok<LAXES>
            spmi.plot();
            set(gcf, 'Visible', 'off');
            spmi.plot_threshold_label();
            spmi.plot_p_values();

            format_spm_axis_as_gait_cycle(ax2, nTimePoints);
            title(ax2, sprintf('%s %s | %s', methodLabel, prettyTest, strjoin(ageNames, ', ')), 'Interpreter','none');
        end
        outName = sprintf('%s_agesAllConditionsPooled_%s_ANOVA.png', methodLabel, muscleName);

        fprintf('\nTest used: %s\n', char(prettyTest));
        for k = 1:nAge
            fprintf('%s: n=%d\n', ageNames(k), size(Ycell{k},1));
        end
        print_spm_clusters(spmi);
        append_spm_results_to_csv(IO.age_effects_csv, spmi, "age_all_conditions_pooled", muscleName, "", "ALL_CONDITIONS", "", strjoin(ageNames, "|"), "anova1", nTimePoints, size(Y,1), P);
    end

    add_spm_significance_bars(ax1, spmi, nTimePoints, 'y_frac', 0.90, 'line_width', 1.5, 'color', [0 0 0]);

    set(fig, 'Visible', 'off');
    saveas(fig, fullfile(IO.out_dir, outName));
    close(fig);
end


function [Y, subjectIDs] = collect_subject_mean_profiles_all_ages(TD, subjFields, muscleName, condName, P)

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

            if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                continue;
            end

            if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                continue;
            end

            VC = S.valid_cycles;
            xcell = get_profile_cell_from_valid_cycles(VC, P);

            if isempty(xcell)
                continue;
            end

            for iC = 1:numel(xcell)
                x = xcell{iC};
                if isempty(x) || ~isnumeric(x) || any(~isfinite(x(:)))
                    continue;
                end
                subjCycleProfiles{end+1,1} = x(:)'; %#ok<AGROW>
            end
        end

        if ~isempty(subjCycleProfiles)
            X = vertcat(subjCycleProfiles{:});

            % remove invalid cycles first
            validRows = all(isfinite(X), 2);
            X = X(validRows, :);

            if isempty(X)
                continue;
            end

            m = mean(X, 1);

            % SPM cannot handle NaNs/Infs in subject profiles
            if any(~isfinite(m))
                continue;
            end

            subjectMeans{end+1,1} = m; %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(subjectMeans)
        Y = [];
    else
        Y = vertcat(subjectMeans{:});
    end
end

function [Y, subjectIDs] = collect_subject_mean_profiles_all_conditions(TD, subjFields, muscleName, condNames, ageName, P)

    subjectMeans = {};
    subjectIDs = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        subjCycleProfiles = {};

        for k = 1:numel(condNames)
            condName = condNames(k);

            if ~isfield(TD.(subjID), char(condName))
                continue;
            end

            condStruct = TD.(subjID).(char(condName));
            legFields = fieldnames(condStruct);

            for il = 1:numel(legFields)
                leg = legFields{il};

                if ~isfield(condStruct.(leg), char(muscleName))
                    continue;
                end

                S = condStruct.(leg).(char(muscleName));

                if ~isfield(S, 'age_group') || string(S.age_group) ~= string(ageName)
                    continue;
                end

                if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                    continue;
                end

                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                    continue;
                end

                VC = S.valid_cycles;
                xcell = get_profile_cell_from_valid_cycles(VC, P);

                if isempty(xcell)
                    continue;
                end

                for iC = 1:numel(xcell)
                    x = xcell{iC};
                    if isempty(x) || ~isnumeric(x) || any(~isfinite(x(:)))
                        continue;
                    end
                    subjCycleProfiles{end+1,1} = x(:)'; %#ok<AGROW>
                end
            end
        end

        if ~isempty(subjCycleProfiles)
            X = vertcat(subjCycleProfiles{:});

            % remove invalid cycles first
            validRows = all(isfinite(X), 2);
            X = X(validRows, :);

            if isempty(X)
                continue;
            end

            m = mean(X, 1);

            % SPM cannot handle NaNs/Infs in subject profiles
            if any(~isfinite(m))
                continue;
            end

            subjectMeans{end+1,1} = m; %#ok<AGROW>
            subjectIDs{end+1,1} = subjID; %#ok<AGROW>
        end
    end

    if isempty(subjectMeans)
        Y = [];
    else
        Y = vertcat(subjectMeans{:});
    end
end

function format_spm_axis_as_gait_cycle(ax, nTimePoints)
    xlim(ax, [1 nTimePoints]);

    xt = linspace(1, nTimePoints, 6);
    xticks(ax, xt);
    xticklabels(ax, compose('%.0f', linspace(0, 100, numel(xt))));

    xlabel(ax, 'Gait cycle (%)');
    grid(ax, 'on');
end

function T = run_posthoc_spm(Ycell, groupNames, P, csvFile)

    nGroups = numel(Ycell);
    nComp = nchoosek(nGroups, 2);
    alpha_corr = P.alpha / nComp;

    fprintf('\n--- POST HOC SPM TESTS ---\n');

    rows = {};
    rowIdx = 1;

    for i = 1:nGroups-1
        for j = i+1:nGroups

            Y1 = Ycell{i};
            Y2 = Ycell{j};

            if isempty(Y1) || isempty(Y2)
                continue;
            end

            Ptmp = P;
            Ptmp.alpha = alpha_corr;
            [spmi, testName] = run_spm_ttest2(Y1, Y2, Ptmp);

            fprintf('\n%s vs %s\n', groupNames(i), groupNames(j));
            print_spm_clusters(spmi);

            clusters = get_spmi_clusters_safe(spmi);
            nTimePoints = size(Y1, 2);

            % no significant clusters: still save one row
            if isempty(clusters)
                rows(rowIdx,:) = { char(groupNames(i)), char(groupNames(j)), size(Y1,1), size(Y2,1), alpha_corr, char(testName), false, NaN, NaN, NaN, NaN, NaN, NaN, "" };
                rowIdx = rowIdx + 1;
                continue;
            end

            % save one row per cluster
            for cIdx = 1:numel(clusters)
                c = clusters(cIdx);

                endpoints = [];
                pval = NaN;
                extent = NaN;

                if isobject(c)
                    if isprop(c, 'endpoints'), endpoints = c.endpoints; end
                    if isprop(c, 'P'), pval = c.P; end
                    if isprop(c, 'extent'), extent = c.extent; end
                elseif isstruct(c)
                    if isfield(c, 'endpoints'), endpoints = c.endpoints; end
                    if isfield(c, 'P'), pval = c.P; end
                    if isfield(c, 'extent'), extent = c.extent; end
                end

                if isempty(endpoints) || numel(endpoints) < 2
                    start_idx = NaN;
                    end_idx   = NaN;
                    start_pct = NaN;
                    end_pct   = NaN;
                else
                    start_idx = endpoints(1);
                    end_idx   = endpoints(2);
                    start_pct = 100 * (start_idx - 1) / max(1, nTimePoints - 1);
                    end_pct   = 100 * (end_idx   - 1) / max(1, nTimePoints - 1);
                end

                rows(rowIdx,:) = { char(groupNames(i)), char(groupNames(j)), size(Y1,1), size(Y2,1), alpha_corr, char(testName), true, cIdx, start_idx, end_idx, start_pct, end_pct, pval, extent };
                rowIdx = rowIdx + 1;
            end
        end
    end

    T = cell2table(rows, 'VariableNames', { 'group1', 'group2', 'n_group1', 'n_group2', 'alpha_corrected', 'test_name', 'has_significant_cluster', 'cluster_index', 'start_idx', 'end_idx', 'start_pct', 'end_pct', 'p_value', 'extent'});

    writetable(T, csvFile);
    fprintf('\nPost hoc CSV saved to:\n%s\n', csvFile);
end

function T = run_posthoc_spm_paired(Ycell, groupNames, P, csvFile)

    nGroups = numel(Ycell);
    nComp = nchoosek(nGroups, 2);
    alpha_corr = P.alpha / nComp;

    fprintf('\n--- POST HOC SPM TESTS (paired) ---\n');

    rows = {};
    rowIdx = 1;

    for i = 1:nGroups-1
        for j = i+1:nGroups

            Y1 = Ycell{i};
            Y2 = Ycell{j};

            if isempty(Y1) || isempty(Y2)
                continue;
            end

            Ptmp = P;
            Ptmp.alpha = alpha_corr;
            [spmi, testName] = run_spm_paired_ttest(Y1, Y2, Ptmp);

            fprintf('\n%s vs %s\n', groupNames(i), groupNames(j));
            print_spm_clusters(spmi);

            clusters = get_spmi_clusters_safe(spmi);
            nTimePoints = size(Y1, 2);

            if isempty(clusters)
                rows(rowIdx,:) = { char(groupNames(i)), char(groupNames(j)), size(Y1,1), size(Y2,1), alpha_corr, char(testName), false, NaN, NaN, NaN, NaN, NaN, NaN, NaN };
                rowIdx = rowIdx + 1;
                continue;
            end

            for cIdx = 1:numel(clusters)
                c = clusters(cIdx);

                endpoints = [];
                pval = NaN;
                extent = NaN;

                if isobject(c)
                    if isprop(c, 'endpoints'), endpoints = c.endpoints; end
                    if isprop(c, 'P'), pval = c.P; end
                    if isprop(c, 'extent'), extent = c.extent; end
                elseif isstruct(c)
                    if isfield(c, 'endpoints'), endpoints = c.endpoints; end
                    if isfield(c, 'P'), pval = c.P; end
                    if isfield(c, 'extent'), extent = c.extent; end
                end

                if isempty(endpoints) || numel(endpoints) < 2
                    start_idx = NaN;
                    end_idx   = NaN;
                    start_pct = NaN;
                    end_pct   = NaN;
                else
                    start_idx = endpoints(1);
                    end_idx   = endpoints(2);
                    start_pct = 100 * (start_idx - 1) / max(1, nTimePoints - 1);
                    end_pct   = 100 * (end_idx   - 1) / max(1, nTimePoints - 1);
                end

                rows(rowIdx,:) = { char(groupNames(i)), char(groupNames(j)), size(Y1,1), size(Y2,1), alpha_corr, char(testName), true, cIdx, start_idx, end_idx, start_pct, end_pct, pval, extent };
                rowIdx = rowIdx + 1;
            end
        end
    end

    T = cell2table(rows, 'VariableNames', { 'group1', 'group2', 'n_group1', 'n_group2', 'alpha_corrected', 'test_name', 'has_significant_cluster', 'cluster_index', 'start_idx', 'end_idx', 'start_pct', 'end_pct', 'p_value', 'extent'});

    writetable(T, csvFile);
    fprintf('\nPost hoc CSV saved to:\n%s\n', csvFile);
end

function TD = assign_nan_normalized_fields_for_subject(TD, subjID)

    condFields = fieldnames(TD.(subjID));

    for ic = 1:numel(condFields)
        cond = condFields{ic};
        legFields = fieldnames(TD.(subjID).(cond));

        for il = 1:numel(legFields)
            leg = legFields{il};
            muscleFields = fieldnames(TD.(subjID).(cond).(leg));

            for iM = 1:numel(muscleFields)
                muscleName = muscleFields{iM};
                S = TD.(subjID).(cond).(leg).(muscleName);

                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                    continue;
                end

                VC = S.valid_cycles;

                if isfield(VC, 'envelope') && ~isempty(VC.envelope)
                    VC.envelope_norm_flatmax = cell(size(VC.envelope));
                    for iC = 1:numel(VC.envelope)
                        x = VC.envelope{iC};
                        if isnumeric(x) && ~isempty(x)
                            VC.envelope_norm_flatmax{iC} = nan(size(x));
                        else
                            VC.envelope_norm_flatmax{iC} = x;
                        end
                    end
                end

                if isfield(VC, 'time_normalized_envelope') && ~isempty(VC.time_normalized_envelope)
                    VC.time_normalized_envelope_norm_flatmax = cell(size(VC.time_normalized_envelope));
                    for iC = 1:numel(VC.time_normalized_envelope)
                        x = VC.time_normalized_envelope{iC};
                        if isnumeric(x) && ~isempty(x)
                            VC.time_normalized_envelope_norm_flatmax{iC} = nan(size(x));
                        else
                            VC.time_normalized_envelope_norm_flatmax{iC} = x;
                        end
                    end
                end

                TD.(subjID).(cond).(leg).(muscleName).valid_cycles = VC;
            end
        end
    end
end

function delete_if_exists(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end


function write_not_computed_interaction_csv(csvFile)

    T = table( "interaction_not_computed", "Current script does not run a formal age x condition interaction model.", "Do not report interaction effects from this output.", 'VariableNames', {'status','reason','note'});

    writetable(T, csvFile);
end


function append_spm_results_to_csv(csvFile, spmi, analysisType, muscleName, ageName, condName, condList, ageList, testName, nTimePoints, nObservations, P)

    clusters = get_spmi_clusters_safe(spmi);

    rows = {};
    rowIdx = 1;

    if isempty(clusters)
        rows(rowIdx,:) = { string(analysisType), string(muscleName), string(ageName), string(condName), string(condList), string(ageList), string(testName), string(P.signal_name), logical(P.use_time_normalized), P.alpha, nTimePoints, nObservations, false, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN };
    else
        for cIdx = 1:numel(clusters)
            c = clusters(cIdx);

            endpoints = [];
            pval = NaN;
            extent = NaN;
            h = NaN;
            extentR = NaN;

            if isobject(c)
                if isprop(c, 'endpoints'), endpoints = c.endpoints; end
                if isprop(c, 'P'), pval = c.P; end
                if isprop(c, 'extent'), extent = c.extent; end
                if isprop(c, 'h'), h = c.h; end
                if isprop(c, 'extentR'), extentR = c.extentR; end
            elseif isstruct(c)
                if isfield(c, 'endpoints'), endpoints = c.endpoints; end
                if isfield(c, 'P'), pval = c.P; end
                if isfield(c, 'extent'), extent = c.extent; end
                if isfield(c, 'h'), h = c.h; end
                if isfield(c, 'extentR'), extentR = c.extentR; end
            end

            if isempty(endpoints) || numel(endpoints) < 2
                start_idx = NaN;
                end_idx = NaN;
                start_pct = NaN;
                end_pct = NaN;
            else
                start_idx = endpoints(1);
                end_idx = endpoints(2);
                start_pct = 100 * (start_idx - 1) / max(1, nTimePoints - 1);
                end_pct   = 100 * (end_idx   - 1) / max(1, nTimePoints - 1);
            end

            rows(rowIdx,:) = { string(analysisType), string(muscleName), string(ageName), string(condName), string(condList), string(ageList), string(testName), string(P.signal_name), logical(P.use_time_normalized), P.alpha, nTimePoints, nObservations, true, cIdx, start_idx, end_idx, start_pct, end_pct, pval, extent, h, extentR };

            rowIdx = rowIdx + 1;
        end
    end

    T = cell2table(rows, 'VariableNames', { 'analysis_type', 'muscle', 'age_group_context', 'condition_context', 'conditions_tested', 'age_groups_tested', 'test_name', 'signal_name', 'use_time_normalized', 'alpha', 'n_timepoints', 'n_observations', 'has_significant_cluster', 'cluster_index', 'start_idx', 'end_idx', 'start_pct_gait_cycle', 'end_pct_gait_cycle', 'p_value', 'extent', 'cluster_height', 'extentR'});

    if isfile(csvFile)
        writetable(T, csvFile, 'WriteMode', 'append', 'WriteVariableNames', false);
    else
        writetable(T, csvFile);
    end
end

function [spmi, testName] = run_spm_paired_ttest(Y1, Y2, P)

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.ttest_paired')), 'Non-parametric paired t-test not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.ttest_paired(Y1, Y2);
        testName = "nonparam_paired_ttest";
        spmi = infer_spm_object(spm, P, true);
    else
        spm = spm1d.stats.ttest_paired(Y1, Y2);
        testName = "paired_ttest";
        spmi = infer_spm_object(spm, P, true);
    end
end


function [spmi, testName] = run_spm_ttest2(Y1, Y2, P)

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.ttest2')), 'Non-parametric two-sample t-test not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.ttest2(Y1, Y2);
        testName = "nonparam_ttest2";
        spmi = infer_spm_object(spm, P, true);
    else
        spm = spm1d.stats.ttest2(Y1, Y2);
        testName = "ttest2";
        spmi = infer_spm_object(spm, P, true);
    end
end


function [spmi, testName] = run_spm_anova1(Y, A, P)

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.anova1')), 'Non-parametric one-way ANOVA not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.anova1(Y, A);
        testName = "nonparam_anova1";
        spmi = infer_spm_object(spm, P, false);
    else
        spm = spm1d.stats.anova1(Y, A);
        testName = "anova1";
        spmi = infer_spm_object(spm, P, false);
    end
end


function [spmi, testName] = run_spm_anova1rm(Y, A, SUBJ, P)

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.anova1rm')), 'Non-parametric repeated-measures one-way ANOVA not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.anova1rm(Y, A, SUBJ);
        testName = "nonparam_anova1rm";
        spmi = infer_spm_object(spm, P, false);
    else
        spm = spm1d.stats.anova1rm(Y, A, SUBJ);
        testName = "anova1rm";
        spmi = infer_spm_object(spm, P, false);
    end
end


function spmi = infer_spm_object(spm, P, isTTest)

    if P.use_nonparametric
        if isfield(P, 'nonparam_iterations') && ~isempty(P.nonparam_iterations)
            nIter = P.nonparam_iterations;
        else
            nIter = 5000;
        end

        if isTTest
            try
                spmi = spm.inference(P.alpha, 'two_tailed', P.two_tailed, 'iterations', nIter);
            catch
                spmi = spm.inference(P.alpha, 'two_tailed', P.two_tailed);
            end
        else
            try
                spmi = spm.inference(P.alpha, 'iterations', nIter);
            catch
                spmi = spm.inference(P.alpha);
            end
        end

    else
        if isTTest
            spmi = spm.inference(P.alpha, 'two_tailed', P.two_tailed);
        else
            spmi = spm.inference(P.alpha);
        end
    end
end

function methodLabel = get_spm_method_label(P)

    if isfield(P, 'use_nonparametric') && P.use_nonparametric
        methodLabel = "SnPM";
    else
        methodLabel = "SPM";
    end
end

function prettyName = get_pretty_test_name(testName)

    t = lower(string(testName));

    if contains(t, "paired") && contains(t, "ttest")
        prettyName = "paired t-test";

    elseif contains(t, "ttest2") || contains(t, "two") || contains(t, "independent")
        prettyName = "two-sample t-test";

    elseif contains(t, "anova1rm")
        prettyName = "repeated-measures ANOVA";

    elseif contains(t, "anova1")
        prettyName = "one-way ANOVA";

    else
        % fallback → keep raw name
        prettyName = string(testName);
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

% Symmetry analyses

function [Y_left, Y_right, subjectIDs] = collect_subject_mean_profiles_by_leg( TD, subjFields, muscleName, condName, ageName, P)

    Y_left = [];
    Y_right = [];
    subjectIDs = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        if ~isfield(TD.(subjID), char(condName))
            continue;
        end

        condStruct = TD.(subjID).(char(condName));

        if ~isfield(condStruct, 'left') || ~isfield(condStruct, 'right')
            continue;
        end

        legs = {'left','right'};
        Ytmp = cell(1,2);

        for il = 1:2
            leg = legs{il};

            if ~isfield(condStruct.(leg), char(muscleName))
                continue;
            end

            S = condStruct.(leg).(char(muscleName));

            if ~isfield(S, 'age_group') || string(S.age_group) ~= string(ageName)
                continue;
            end

            if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                continue;
            end

            VC = S.valid_cycles;
            xcell = get_profile_cell_from_valid_cycles(VC, P);

            if isempty(xcell)
                continue;
            end

            X = vertcat(xcell{:});
            Ytmp{il} = mean(X,1,'omitnan');
        end

        % keep only subjects with BOTH legs
        if ~isempty(Ytmp{1}) && ~isempty(Ytmp{2})
            Y_left  = [Y_left;  Ytmp{1}];
            Y_right = [Y_right; Ytmp{2}];
            subjectIDs{end+1} = subjID;
        end
    end
end

function run_symmetry_within_condition(TD, subjFields, P, PLT, IO)

    muscleName = string(P.muscle_name);
    condName   = string(P.condition_name);
    ageName    = string(P.age_name);

    P.normalization_mode = P.normalization_mode_symmetry;

    fprintf('\n====================================================\n');
    fprintf('SPM symmetry analysis (L vs R)\n');
    fprintf('Muscle: %s | Condition: %s | Age: %s\n', muscleName, condName, ageName);
    fprintf('====================================================\n');

    [YL, YR, subjIDs] = collect_subject_mean_profiles_by_leg( TD, subjFields, muscleName, condName, ageName, P);

    assert(~isempty(YL), 'No valid symmetry data');

    % --- SPM paired test ---
    spm = spm1d.stats.ttest_paired(YL, YR);
    spmi = spm.inference(P.alpha, 'two_tailed', true);

    % --- Plot ---
    fig = figure('Color','w');

    ax1 = subplot(2,1,1); hold on;
    x = linspace(0,100,size(YL,2));

    plot(x, mean(YL,1), 'b', 'LineWidth',2, 'DisplayName','Left');
    plot(x, mean(YR,1), 'r', 'LineWidth',2, 'DisplayName','Right');

    legend; grid on;
    title('Left vs Right');

    ax2 = subplot(2,1,2);
    spmi.plot();
    spmi.plot_threshold_label();
    spmi.plot_p_values();

    format_spm_axis_as_gait_cycle(ax2, size(YL,2));
    title('SPM paired t-test (symmetry)');

    add_spm_significance_bars(ax1, spmi, size(YL,2));

    set(fig, 'Visible', 'off');
    saveas(fig, fullfile(IO.out_dir, sprintf('SPM_symmetry_%s_%s_%s.png', muscleName, condName, ageName)));

    close(fig);
end

function T = compute_symmetry_index_table(TD, subjFields, P)

    muscles = string(P.muscles_to_run);
    conds   = string(P.conditions_to_run);

    rows = {};
    rowIdx = 1;

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        for iC = 1:numel(conds)
            condName = conds(iC);

            if ~isfield(TD.(subjID), char(condName))
                continue;
            end

            condStruct = TD.(subjID).(char(condName));

            if ~isfield(condStruct, 'left') || ~isfield(condStruct, 'right')
                continue;
            end

            for iM = 1:numel(muscles)
                muscleName = muscles(iM);

                if ~isfield(condStruct.left, char(muscleName)) || ~isfield(condStruct.right, char(muscleName))
                    continue;
                end

                S_L = condStruct.left.(char(muscleName));
                S_R = condStruct.right.(char(muscleName));

                if ~isfield(S_L, 'included_for_analysis') || ~S_L.included_for_analysis
                    continue;
                end
                if ~isfield(S_R, 'included_for_analysis') || ~S_R.included_for_analysis
                    continue;
                end
                if ~isfield(S_L, 'valid_cycles') || isempty(S_L.valid_cycles)
                    continue;
                end
                if ~isfield(S_R, 'valid_cycles') || isempty(S_R.valid_cycles)
                    continue;
                end

                xL = get_profile_cell_from_valid_cycles(S_L.valid_cycles, P);
                xR = get_profile_cell_from_valid_cycles(S_R.valid_cycles, P);

                XL = cell_to_valid_matrix(xL);
                XR = cell_to_valid_matrix(xR);

                if isempty(XL) || isempty(XR)
                    continue;
                end

                profL = mean(XL, 1);
                profR = mean(XR, 1);

                if any(~isfinite(profL)) || any(~isfinite(profR))
                    continue;
                end

                meanL = mean(profL);
                meanR = mean(profR);

                denom = (meanL + meanR);

                if ~isfinite(denom) || abs(denom) < eps
                    continue;
                end

                % Robinson index expressed as percentage
                SI_percent = 2 * 100 * ((meanL - meanR) / denom);
                absSI_percent = abs(SI_percent);

                if isfield(S_L, 'age_group')
                    ageGroup = string(S_L.age_group);
                elseif isfield(S_R, 'age_group')
                    ageGroup = string(S_R.age_group);
                else
                    ageGroup = "";
                end

                rows(rowIdx,:) = { string(subjID), ageGroup, string(condName), string(muscleName), meanL, meanR, SI_percent, absSI_percent, size(XL,1), size(XR,1), string(P.signal_name), logical(P.use_time_normalized) };

                rowIdx = rowIdx + 1;
            end
        end
    end

    T = cell2table(rows, 'VariableNames', { 'subject', 'age_group', 'condition', 'muscle', 'mean_left', 'mean_right', 'SI_percent', 'absSI_percent', 'n_cycles_left', 'n_cycles_right', 'signal_name', 'use_time_normalized'});
end

function X = cell_to_valid_matrix(xcell)

    X = [];

    for i = 1:numel(xcell)
        x = xcell{i};

        if isempty(x) || ~isnumeric(x)
            continue;
        end

        x = x(:)';

        if any(~isfinite(x))
            continue;
        end

        X = [X; x]; %#ok<AGROW>
    end
end

function plot_symmetry_boxplot_by_condition(Tsi, muscleName, P, PLT, IO)

    T = Tsi(Tsi.muscle == muscleName, :);
    if isempty(T), return; end

    T.condition = categorical(T.condition);
    T.age_group = categorical(T.age_group);

    condOrder = cellstr(string(P.conditions_to_run));
    present = categories(T.condition);
    condLevels = keep_present_in_order_local(condOrder, present);

    if isempty(condLevels), return; end

    fig = figure('Visible','off', 'Color','w', 'Position',[100 100 950 550]);
    ax = axes(fig); hold(ax, 'on');

    legendHandles = gobjects(0);

    for i = 1:numel(condLevels)
        gName = condLevels{i};
        idx = T.condition == gName;

        x = categorical(T.condition(idx), condLevels, condLevels, 'Ordinal', true);
        b = boxchart(ax, x, T.absSI_percent(idx), 'DisplayName', gName);

        col = get_color_safe(PLT.colors, gName, [0 0 0]);
        apply_boxchart_color_local(b, col);

        legendHandles(end+1) = b; %#ok<AGROW>
    end

    ymax = max(T.absSI_percent, [], 'omitnan');
    if isempty(ymax) || isnan(ymax) || ymax <= 0
        ymax = 1;
    end

    ylim(ax, [0 1.20*ymax]);
    xlabel(ax, 'Condition');
    ylabel(ax, '|Symmetry index| (%)');
    title(ax, sprintf('%s | asymmetry by condition', muscleName), 'Interpreter','none');
    grid(ax, 'on');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, condLevels, 'Location','best');
    end

    outFile = fullfile(IO.symmetry_plot_dir, sprintf('SYM_absSI_byCondition_%s.png', muscleName));

    set(fig, 'Visible', 'off');
    saveas(fig, outFile);
    close(fig);
end

function plot_symmetry_boxplot_by_age(Tsi, muscleName, P, PLT, IO)

    T = Tsi(Tsi.muscle == muscleName, :);
    if isempty(T), return; end

    T.age_group = categorical(T.age_group);

    ageOrder = cellstr(string(P.age_groups_to_run));
    present = categories(T.age_group);
    ageLevels = keep_present_in_order_local(ageOrder, present);

    if isempty(ageLevels), return; end

    fig = figure('Visible','off', 'Color','w', 'Position',[100 100 950 550]);
    ax = axes(fig); hold(ax, 'on');

    legendHandles = gobjects(0);

    for i = 1:numel(ageLevels)
        gName = ageLevels{i};
        idx = T.age_group == gName;

        x = categorical(T.age_group(idx), ageLevels, ageLevels, 'Ordinal', true);
        b = boxchart(ax, x, T.absSI_percent(idx), 'DisplayName', gName);

        col = get_color_safe(PLT.colors, gName, [0 0 0]);
        apply_boxchart_color_local(b, col);

        legendHandles(end+1) = b; %#ok<AGROW>
    end

    ymax = max(T.absSI_percent, [], 'omitnan');
    if isempty(ymax) || isnan(ymax) || ymax <= 0
        ymax = 1;
    end

    ylim(ax, [0 1.20*ymax]);
    xlabel(ax, 'Age group');
    ylabel(ax, '|Symmetry index| (%)');
    title(ax, sprintf('%s | asymmetry by age group', muscleName), 'Interpreter','none');
    grid(ax, 'on');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, ageLevels, 'Location','best');
    end

    outFile = fullfile(IO.symmetry_plot_dir, sprintf('SYM_absSI_byAge_%s.png', muscleName));

    set(fig, 'Visible', 'off');
    saveas(fig, outFile);
    close(fig);
end

function plot_symmetry_grouped_condition_by_age(Tsi, muscleName, P, PLT, IO)

    T = Tsi(Tsi.muscle == muscleName, :);
    if isempty(T), return; end

    T.condition = categorical(T.condition);
    T.age_group = categorical(T.age_group);

    condOrder = cellstr(string(P.conditions_to_run));
    ageOrder  = cellstr(string(P.age_groups_to_run));

    condLevels = keep_present_in_order_local(condOrder, categories(T.condition));
    ageLevels  = keep_present_in_order_local(ageOrder, categories(T.age_group));

    if isempty(condLevels) || isempty(ageLevels)
        return;
    end

    fig = figure('Visible','off', 'Color','w', 'Position',[100 100 1150 550]);
    ax = axes(fig); hold(ax, 'on');

    nAge = numel(ageLevels);
    offsets = linspace(-0.32, 0.32, max(nAge,2));
    if nAge == 1
        offsets = 0;
    end

    legendHandles = gobjects(0);

    for ia = 1:nAge
        ageName = ageLevels{ia};
        idxAge = T.age_group == ageName;

        if ~any(idxAge)
            continue;
        end

        xBase = grp2idx(categorical(T.condition(idxAge), condLevels, condLevels, 'Ordinal', true));
        xPos = xBase + offsets(ia);

        b = boxchart(ax, xPos, T.absSI_percent(idxAge), 'BoxWidth', 0.16, 'DisplayName', ageName);

        col = get_color_safe(PLT.colors, ageName, [0 0 0]);
        apply_boxchart_color_local(b, col);

        legendHandles(end+1) = b; %#ok<AGROW>
    end

    ymax = max(T.absSI_percent, [], 'omitnan');
    if isempty(ymax) || isnan(ymax) || ymax <= 0
        ymax = 1;
    end

    xlim(ax, [0.5 numel(condLevels)+0.5]);
    set(ax, 'XTick', 1:numel(condLevels), 'XTickLabel', condLevels);

    ylim(ax, [0 1.25*ymax]);
    xlabel(ax, 'Condition');
    ylabel(ax, '|Symmetry index| (%)');
    title(ax, sprintf('%s | asymmetry by condition and age group', muscleName), 'Interpreter','none');
    grid(ax, 'on');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, ageLevels, 'Location','best');
    end

    outFile = fullfile(IO.symmetry_plot_dir, sprintf('SYM_absSI_conditionByAge_%s.png', muscleName));

    set(fig, 'Visible', 'off');
    saveas(fig, outFile);
    close(fig);
end

function levels = keep_present_in_order_local(orderList, presentList)

    orderList = cellstr(string(orderList));
    presentList = cellstr(string(presentList));

    levels = {};
    for i = 1:numel(orderList)
        if any(strcmp(orderList{i}, presentList))
            levels{end+1} = orderList{i}; %#ok<AGROW>
        end
    end
end

function apply_boxchart_color_local(b, col)

    try
        b.BoxFaceColor = col;
    catch
    end

    try
        b.MarkerColor = col;
    catch
    end

    try
        b.WhiskerLineColor = col;
    catch
    end

    try
        b.BoxFaceAlpha = 0.45;
    catch
    end
end

function refByLegMuscle = compute_subject_muscle_reference(TD, subjID, sigName, condMode, prc)

    refByLegMuscle = struct();

    if condMode == "Flat"
        if ~isfield(TD.(subjID), 'Flat')
            return;
        end
        condFields = {'Flat'};
    else
        condFields = fieldnames(TD.(subjID));
    end

    allValsByLegMuscle = struct();

    for ic = 1:numel(condFields)

        cond = condFields{ic};

        if ~isfield(TD.(subjID), cond)
            continue;
        end

        legFields = fieldnames(TD.(subjID).(cond));

        for il = 1:numel(legFields)

            leg = legFields{il};

            if ~isfield(allValsByLegMuscle, leg)
                allValsByLegMuscle.(leg) = struct();
            end

            muscleFields = fieldnames(TD.(subjID).(cond).(leg));

            for iM = 1:numel(muscleFields)

                muscleName = muscleFields{iM};
                S = TD.(subjID).(cond).(leg).(muscleName);

                if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                    continue;
                end

                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                    continue;
                end

                VC = S.valid_cycles;
                vals = collect_values_from_VC(VC, sigName);

                if isempty(vals)
                    continue;
                end

                if ~isfield(allValsByLegMuscle.(leg), muscleName)
                    allValsByLegMuscle.(leg).(muscleName) = vals;
                else
                    allValsByLegMuscle.(leg).(muscleName) = [ allValsByLegMuscle.(leg).(muscleName); vals]; %#ok<AGROW>
                end
            end
        end
    end

    legNames = fieldnames(allValsByLegMuscle);

    for il = 1:numel(legNames)

        leg = legNames{il};
        muscleNames = fieldnames(allValsByLegMuscle.(leg));

        if ~isfield(refByLegMuscle, leg)
            refByLegMuscle.(leg) = struct();
        end

        for iM = 1:numel(muscleNames)

            muscleName = muscleNames{iM};
            vals = allValsByLegMuscle.(leg).(muscleName);
            vals = vals(isfinite(vals));

            if isempty(vals)
                continue;
            end

            refByLegMuscle.(leg).(muscleName) = prctile(vals, prc);
        end
    end
end

function vals = collect_values_from_VC(VC, sigName)

    vals = [];

    rawField  = char(sigName);
    timeField = char("time_normalized_" + string(sigName));

    % Prefer time-normalized signal if available, because this is what SPM uses
    if isfield(VC, timeField) && ~isempty(VC.(timeField))
        xcell = VC.(timeField);
    elseif isfield(VC, rawField) && ~isempty(VC.(rawField))
        xcell = VC.(rawField);
    else
        return;
    end

    for iC = 1:numel(xcell)
        x = xcell{iC};
        if isnumeric(x) && ~isempty(x)
            tmp = x(:);
            tmp = tmp(isfinite(tmp));
            vals = [vals; tmp]; %#ok<AGROW>
        end
    end
end

function VC = add_reference_normalized_fields_to_VC(VC, sigName, refVal, P)

    suffix = "_" + string(P.normalization_mode);

    rawNormField  = char(string(sigName) + "_norm" + suffix);
    timeNormField = char("time_normalized_" + string(sigName) + "_norm" + suffix);
    rawField      = char(sigName);
    timeField     = char("time_normalized_" + string(sigName));


    if isfield(VC, rawField) && ~isempty(VC.(rawField))
        VC.(rawNormField) = cell(size(VC.(rawField)));

        for iC = 1:numel(VC.(rawField))
            x = VC.(rawField){iC};
            if isnumeric(x) && ~isempty(x)
                VC.(rawNormField){iC} = 100 * x ./ refVal;
            else
                VC.(rawNormField){iC} = x;
            end
        end
    end

    if isfield(VC, timeField) && ~isempty(VC.(timeField))
        VC.(timeNormField) = cell(size(VC.(timeField)));

        for iC = 1:numel(VC.(timeField))
            x = VC.(timeField){iC};
            if isnumeric(x) && ~isempty(x)
                VC.(timeNormField){iC} = 100 * x ./ refVal;
            else
                VC.(timeNormField){iC} = x;
            end
        end
    end
end

function VC = add_nan_normalized_fields_to_VC(VC, sigName, P)

    rawField      = char(sigName);
    rawNormField  = char(string(sigName) + "_norm" + "_" + string(P.normalization_mode));

    timeField     = char("time_normalized_" + string(sigName));
    timeNormField = char("time_normalized_" + string(sigName) + "_norm" + "_" + string(P.normalization_mode));

    if isfield(VC, rawField) && ~isempty(VC.(rawField))
        VC.(rawNormField) = cell(size(VC.(rawField)));

        for iC = 1:numel(VC.(rawField))
            x = VC.(rawField){iC};
            if isnumeric(x) && ~isempty(x)
                VC.(rawNormField){iC} = nan(size(x));
            else
                VC.(rawNormField){iC} = x;
            end
        end
    end

    if isfield(VC, timeField) && ~isempty(VC.(timeField))
        VC.(timeNormField) = cell(size(VC.(timeField)));

        for iC = 1:numel(VC.(timeField))
            x = VC.(timeField){iC};
            if isnumeric(x) && ~isempty(x)
                VC.(timeNormField){iC} = nan(size(x));
            else
                VC.(timeNormField){iC} = x;
            end
        end
    end
end

function VC = add_cyclemax_normalized_fields(VC, sigName, P)

    rawField      = char(sigName);
    rawNormField  = char(string(sigName) + "_norm" + "_" + string(P.normalization_mode));

    timeField     = char("time_normalized_" + string(sigName));
    timeNormField = char("time_normalized_" + string(sigName) + "_norm" + "_" + string(P.normalization_mode));

    if isfield(VC, rawField) && ~isempty(VC.(rawField))
        VC.(rawNormField) = cell(size(VC.(rawField)));

        for iC = 1:numel(VC.(rawField))
            x = VC.(rawField){iC};
            if isnumeric(x) && ~isempty(x)
                refVal = max(x(:), [], 'omitnan');
                if isfinite(refVal) && refVal > 0
                    VC.(rawNormField){iC} = 100 * x ./ refVal;
                else
                    VC.(rawNormField){iC} = nan(size(x));
                end
            else
                VC.(rawNormField){iC} = x;
            end
        end
    end

    if isfield(VC, timeField) && ~isempty(VC.(timeField))
        VC.(timeNormField) = cell(size(VC.(timeField)));

        for iC = 1:numel(VC.(timeField))
            x = VC.(timeField){iC};
            if isnumeric(x) && ~isempty(x)
                refVal = max(x(:), [], 'omitnan');
                if isfinite(refVal) && refVal > 0
                    VC.(timeNormField){iC} = 100 * x ./ refVal;
                else
                    VC.(timeNormField){iC} = nan(size(x));
                end
            else
                VC.(timeNormField){iC} = x;
            end
        end
    end
end

function TD = add_all_needed_normalized_signal_fields(TD, subjFields, P)

    modes = strings(0,1);

    % Condition-effect normalization
    if isfield(P, 'normalization_mode_condition') && ~isempty(P.normalization_mode_condition)
        modes(end+1,1) = string(P.normalization_mode_condition);
    end

    % Age-effect normalization
    if isfield(P, 'normalization_mode_age') && ~isempty(P.normalization_mode_age)
        modes(end+1,1) = string(P.normalization_mode_age);
    end

    % Age x condition interaction normalization
    if isfield(P, 'normalization_mode_interaction') && ~isempty(P.normalization_mode_interaction)
        modes(end+1,1) = string(P.normalization_mode_interaction);
    end

    % Symmetry normalization, optional
    if isfield(P, 'normalization_mode_symmetry') && ~isempty(P.normalization_mode_symmetry)
        modes(end+1,1) = string(P.normalization_mode_symmetry);
    end

    % Fallback if none of the specific modes exist
    if isempty(modes)
        if isfield(P, 'normalization_mode') && ~isempty(P.normalization_mode)
            modes(end+1,1) = string(P.normalization_mode);
        else
            modes(end+1,1) = "none";
        end
    end

    % Remove duplicates and empty values
    modes = unique(modes);
    modes(modes == "") = [];

    fprintf('\nNormalization modes needed in this run:\n');
    for i = 1:numel(modes)
        fprintf('  - %s\n', modes(i));
    end

    for i = 1:numel(modes)
        Ptmp = P;
        Ptmp.normalization_mode = modes(i);

        TD = add_normalized_signal_fields(TD, subjFields, Ptmp);
    end
end

function [T_cycles, T_signals] = detect_spm_normalized_outliers(TD, subjFields, P, thresholdPct)

    muscles = string(P.muscles_to_run);
    conds   = string(P.conditions_to_run);

    normModes = [
        string(P.normalization_mode_condition)
        string(P.normalization_mode_age)
    ];

    if isfield(P, 'normalization_mode_symmetry')
        normModes(end+1) = string(P.normalization_mode_symmetry);
    end

    normModes = unique(normModes);

    cycleRows  = {};
    signalRows = {};

    rCycle  = 1;
    rSignal = 1;

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        for iMode = 1:numel(normModes)

            Ptmp = P;
            Ptmp.normalization_mode = normModes(iMode);

            for iC = 1:numel(conds)
                condName = conds(iC);

                if ~isfield(TD.(subjID), char(condName))
                    continue;
                end

                condStruct = TD.(subjID).(char(condName));
                legFields = fieldnames(condStruct);

                for il = 1:numel(legFields)
                    leg = legFields{il};

                    for iM = 1:numel(muscles)
                        muscleName = muscles(iM);

                        if ~isfield(condStruct.(leg), char(muscleName))
                            continue;
                        end

                        S = condStruct.(leg).(char(muscleName));

                        if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                            continue;
                        end

                        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                            continue;
                        end

                        xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, Ptmp);

                        if isempty(xcell)
                            continue;
                        end

                        nTotal = 0;
                        nOver  = 0;
                        signalMax = NaN;

                        for iCycle = 1:numel(xcell)
                            x = xcell{iCycle};

                            if isempty(x) || ~isnumeric(x)
                                continue;
                            end

                            if any(~isfinite(x(:)))
                                continue;
                            end

                            nTotal = nTotal + 1;
                            maxVal = max(x(:), [], 'omitnan');

                            if ~isnan(maxVal)
                                if isnan(signalMax)
                                    signalMax = maxVal;
                                else
                                    signalMax = max(signalMax, maxVal);
                                end
                            end

                            if isfinite(maxVal) && maxVal > thresholdPct
                                nOver = nOver + 1;

                                cycleRows(rCycle,:) = { string(subjID), string(normModes(iMode)), string(condName), string(leg), string(muscleName), iCycle, maxVal, thresholdPct };
                                rCycle = rCycle + 1;
                            end
                        end

                        if nTotal > 0
                            pctOver = 100 * nOver / nTotal;

                            signalRows(rSignal,:) = { string(subjID), string(normModes(iMode)), string(condName), string(leg), string(muscleName), nTotal, nOver, pctOver, signalMax, thresholdPct };
                            rSignal = rSignal + 1;
                        end
                    end
                end
            end
        end
    end

    if isempty(cycleRows)
        T_cycles = table();
    else
        T_cycles = cell2table(cycleRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'cycle_index', 'max_value_percent', 'threshold_percent'});
    end

    if isempty(signalRows)
        T_signals = table();
    else
        T_signals = cell2table(signalRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'n_total_cycles', 'n_cycles_over_threshold', 'pct_cycles_over_threshold', 'max_value_percent', 'threshold_percent'});
    end

    fprintf('\nNormalized amplitude QC:\n');
    fprintf('Threshold: %.1f%%\n', thresholdPct);
    fprintf('Outlier cycles: %d\n', height(T_cycles));
    fprintf('Signals checked: %d\n', height(T_signals));

end

function plot_normalized_outlier_examples(TD, T_outlier_cycles, P, IO, outlierThresholdPct)

    T = T_outlier_cycles;

    % -----------------------------------------
    % Optional filter by normalization mode
    % -----------------------------------------
    if isfield(P, 'outlier_plot_normalization_mode') && string(P.outlier_plot_normalization_mode) ~= "all"

        keep = string(T.normalization_mode) == string(P.outlier_plot_normalization_mode);
        T = T(keep, :);
    end

    if isempty(T)
        fprintf('\nNo outlier cycles available for the requested normalization mode.\n');
        return;
    end

    % -----------------------------------------
    % Selection of examples
    % -----------------------------------------
    nPlot = min(P.n_outlier_examples_to_plot, height(T));

    if isfield(P, 'outlier_plot_selection') && string(P.outlier_plot_selection) == "random"
        rng(1);
        idx = randperm(height(T), nPlot);
        Tsel = T(idx, :);
    else
        % default = top outliers by max amplitude
        if ismember('max_value_percent', T.Properties.VariableNames)
            T = sortrows(T, 'max_value_percent', 'descend');
        end
        Tsel = T(1:nPlot, :);
    end

    % -----------------------------------------
    % Multi-panel figure
    % -----------------------------------------
    nCols = 2;
    nRows = ceil(nPlot / nCols);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1300 320*nRows]);

    tl = tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i = 1:nPlot

        row = Tsel(i,:);

        subjID   = char(string(row.subject));
        condName = char(string(row.condition));
        leg      = char(string(row.leg));
        muscle   = char(string(row.muscle));

        cycleIdx = get_cycle_index_from_outlier_row(row);

        % Important: use the normalization mode from this outlier row
        Ptmp = P;
        if ismember('normalization_mode', row.Properties.VariableNames)
            Ptmp.normalization_mode = string(row.normalization_mode);
        end

        nexttile;
        hold on;

        % --- retrieve signal ---
        try
            S = TD.(subjID).(condName).(leg).(muscle);
            VC = S.valid_cycles;
            xcell = get_profile_cell_from_valid_cycles(VC, Ptmp);

            if isempty(xcell) || cycleIdx < 1 || cycleIdx > numel(xcell)
                title(sprintf('%s | %s | %s | %s\ncycle %d not found', subjID, condName, leg, muscle, cycleIdx), 'Interpreter', 'none');
                axis off;
                continue;
            end

            x = xcell{cycleIdx};

            if isempty(x) || ~isnumeric(x)
                title(sprintf('%s | %s | %s | %s\ninvalid cycle %d', subjID, condName, leg, muscle, cycleIdx), 'Interpreter', 'none');
                axis off;
                continue;
            end

            gx = linspace(0, 100, numel(x));

            plot(gx, x, 'k', 'LineWidth', 1.5);

            yline(100, '--', '100%', 'Color', [0.2 0.2 0.8], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');

            yline(outlierThresholdPct, '--', sprintf('%d%%', outlierThresholdPct), 'Color', [0.85 0.2 0.2], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');

            xlim([0 100]);
            grid on;
            xlabel('Gait cycle (%)');
            ylabel(get_ylabel_text(Ptmp));

            if ismember('max_value_percent', row.Properties.VariableNames)
                maxValTxt = sprintf('max = %.1f%%', row.max_value_percent);
            else
                maxValTxt = '';
            end

            if ismember('normalization_mode', row.Properties.VariableNames)
                normTxt = char(string(row.normalization_mode));
            else
                normTxt = char(string(Ptmp.normalization_mode));
            end

            title(sprintf('%s | %s | %s | %s | cyc %d\n%s | %s', subjID, condName, leg, muscle, cycleIdx, normTxt, maxValTxt), 'Interpreter', 'none');

        catch ME
            title(sprintf('%s | %s | %s | %s\nERROR: %s', subjID, condName, leg, muscle, ME.message), 'Interpreter', 'none');
            axis off;
        end
    end

    sgtitle(tl, sprintf('Normalized envelope outlier examples (%s)', char(string(P.outlier_plot_normalization_mode))), 'Interpreter', 'none');

    outFile = fullfile(IO.outlier_plot_dir, sprintf('NORMALIZED_OUTLIER_EXAMPLES_%s_top%d.png', char(string(P.outlier_plot_normalization_mode)), nPlot));

    saveas(fig, outFile);
    close(fig);

    fprintf('\nNormalized outlier example plot saved to:\n%s\n', outFile);
end

function cycleIdx = get_cycle_index_from_outlier_row(row)

    varNames = row.Properties.VariableNames;

    candidateNames = { 'cycle_index', 'cycle_idx', 'iCycle', 'cycle_number'};

    cycleIdx = [];

    for i = 1:numel(candidateNames)
        if ismember(candidateNames{i}, varNames)
            cycleIdx = row.(candidateNames{i});
            return;
        end
    end

    error('No cycle index column found in T_outlier_cycles.');
end

function plot_random_outlier_signal_examples(TD, T_outlier_signals, P, IO, outlierThresholdPct)
% Plot random outlier signal examples using adaptive MAD threshold.
%
% STYLE:
%   Top plot:
%       - all non-flagged cycles in grey
%       - flagged cycles in red
%       - signal mean in black
%       - reference mean in blue dashed
%       - adaptive threshold in red/orange dashed
%       - adaptive median in dark grey dotted
%
%   Bottom plot:
%       - normalization reference pool cycles
%       - normalization reference mean
%
% IMPORTANT:
%   This plot no longer draws fixed 100% / 250% horizontal thresholds.
%   The QC threshold shown is the adaptive threshold over gait cycle.

    %#ok<INUSD> % outlierThresholdPct kept only for compatibility with old calls

    T = T_outlier_signals;

    % -----------------------------------------
    % Optional filter by normalization mode
    % -----------------------------------------
    if isfield(P, 'outlier_signal_plot_mode') && string(P.outlier_signal_plot_mode) ~= "all"
        T = T(string(T.normalization_mode) == string(P.outlier_signal_plot_mode), :);
    end

    if isempty(T)
        fprintf('\nNo outlier signals available for requested plot mode.\n');
        return;
    end

    % -----------------------------------------
    % Random selection
    % -----------------------------------------
    if isfield(P, 'n_random_outlier_signal_examples') && ~isempty(P.n_random_outlier_signal_examples)
        nPlot = min(P.n_random_outlier_signal_examples, height(T));
    else
        nPlot = min(10, height(T));
    end

    if isfield(P, 'outlier_signal_plot_random_seed') && ~isempty(P.outlier_signal_plot_random_seed)
        rng(P.outlier_signal_plot_random_seed);
    else
        rng('shuffle');
    end

    idx = randperm(height(T), nPlot);
    Tsel = T(idx, :);

    fprintf('\nSaving %d random adaptive-threshold outlier signal plots...\n', nPlot);

    for i = 1:nPlot

        row = Tsel(i,:);

        subjID   = char(string(row.subject));
        condName = char(string(row.condition));
        leg      = char(string(row.leg));
        muscle   = char(string(row.muscle));
        normMode = string(row.normalization_mode);

        Ptmp = P;
        Ptmp.normalization_mode = normMode;

        try
            % -----------------------------------------
            % Get signal cycles
            % -----------------------------------------
            Xsig = get_signal_cycle_matrix(TD, subjID, condName, leg, muscle, Ptmp);

            if isempty(Xsig)
                fprintf('[WARNING] No signal cycles found for %s | %s | %s | %s\n', subjID, condName, leg, muscle);
                continue;
            end

            nTotal = size(Xsig, 1);
            nTime  = size(Xsig, 2);
            x      = linspace(0, 100, nTime);

            signalMean = mean(Xsig, 1, 'omitnan');
            maxVal     = max(Xsig(:), [], 'omitnan');

            % -----------------------------------------
            % Compute adaptive threshold directly from this signal
            % subject × condition × leg × muscle
            % -----------------------------------------
            [adaptiveMedian, adaptiveMAD, adaptiveThreshold, thrInfo] = compute_adaptive_mad_threshold_profile(Xsig, Ptmp);

            % -----------------------------------------
            % Flag cycles based on adaptive threshold
            % -----------------------------------------
            if isfield(Ptmp, 'adaptive_outlier_min_pct_points') && ~isempty(Ptmp.adaptive_outlier_min_pct_points)
                minPctPoints = Ptmp.adaptive_outlier_min_pct_points;
            else
                minPctPoints = 2;
            end

            if isfield(Ptmp, 'adaptive_outlier_min_consecutive_pct') && ~isempty(Ptmp.adaptive_outlier_min_consecutive_pct)
                minConsecPct = Ptmp.adaptive_outlier_min_consecutive_pct;
            else
                minConsecPct = 1;
            end

            isOut = false(nTotal, 1);
            pctOverByCycle = nan(nTotal,1);
            longestRunPctByCycle = nan(nTotal,1);

            for iCyc = 1:nTotal
                overMask = Xsig(iCyc,:) > adaptiveThreshold;

                pctOver = 100 * sum(overMask) / nTime;
                longestRunPct = 100 * longest_true_run(overMask) / nTime;

                pctOverByCycle(iCyc) = pctOver;
                longestRunPctByCycle(iCyc) = longestRunPct;

                isOut(iCyc) = pctOver >= minPctPoints || longestRunPct >= minConsecPct;
            end

            nOver = sum(isOut);

            % -----------------------------------------
            % Get normalization reference cycles
            % -----------------------------------------
            Xref = get_reference_cycle_matrix(TD, subjID, leg, muscle, Ptmp);

            % -----------------------------------------
            % Plot
            % -----------------------------------------
            fig = figure('Visible','off', 'Color','w', 'Position',[100 100 1200 850]);

            % ============================================================
            % TOP: problematic signal with adaptive threshold
            % ============================================================
            ax1 = subplot(2,1,1);
            hold(ax1,'on');

            legendHandles = gobjects(0);
            legendLabels  = {};

            % ----- non-flagged cycles -----
            idxValid = find(~isOut);
            hValid = gobjects(0);

            for ii = 1:numel(idxValid)
                iCyc = idxValid(ii);

                h = plot(ax1, x, Xsig(iCyc,:), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8, 'HandleVisibility', 'off');

                if ii == 1
                    hValid = h;
                end
            end

            if isgraphics(hValid)
                legendHandles(end+1) = hValid;
                legendLabels{end+1} = 'Non-flagged cycles';
            end

            % ----- flagged cycles -----
            idxOut = find(isOut);
            hOut = gobjects(0);

            for ii = 1:numel(idxOut)
                iCyc = idxOut(ii);

                h = plot(ax1, x, Xsig(iCyc,:), '-', 'Color', [0.85 0.20 0.20], 'LineWidth', 1.6, 'HandleVisibility', 'off');

                if ii == 1
                    hOut = h;
                end
            end

            if isgraphics(hOut)
                legendHandles(end+1) = hOut;
                legendLabels{end+1} = 'Flagged cycle(s)';
            end

            % ----- signal mean -----
            hSigMean = plot(ax1, x, signalMean, 'k-', 'LineWidth', 2.2);

            legendHandles(end+1) = hSigMean;
            legendLabels{end+1} = 'Signal mean';

            % ----- reference mean -----
            if ~isempty(Xref)
                hRefMean = plot(ax1, x, mean(Xref,1,'omitnan'), '--', 'Color', [0.10 0.35 0.85], 'LineWidth', 2.0);

                legendHandles(end+1) = hRefMean;
                legendLabels{end+1} = 'Reference mean';
            end

            % ----- adaptive median -----
            hMedian = plot(ax1, x, adaptiveMedian, ':', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.4);

            legendHandles(end+1) = hMedian;
            legendLabels{end+1} = 'Adaptive median';

            % ----- adaptive threshold -----
            if isfield(Ptmp, 'adaptive_outlier_k_mad') && ~isempty(Ptmp.adaptive_outlier_k_mad)
                kMAD = thrInfo.kMAD;
            else
                kMAD = 6;
            end

            hAdaptive = plot(ax1, x, adaptiveThreshold, '--', 'Color', [0.90 0.35 0.10], 'LineWidth', 2.2);

            legendHandles(end+1) = hAdaptive;
            legendLabels{end+1} = sprintf('Adaptive threshold: median + %.1f MAD, smoothed %d pts', thrInfo.kMAD, thrInfo.smooth_window);

            xlabel(ax1, 'Gait cycle (%)');
            ylabel(ax1, get_ylabel_text(Ptmp));
            xlim(ax1, [0 100]);
            grid(ax1, 'on');

            title(ax1, sprintf(['Signal QC: %s | %s | %s | %s\n' 'Adaptive MAD threshold | Normalization: %s | flagged cycles: %d/%d | max = %.1f%%'], subjID, condName, leg, muscle, normMode, nOver, nTotal, maxVal), 'Interpreter','none');

            legend(ax1, legendHandles, legendLabels, 'Location', 'northeast');

            % ============================================================
            % BOTTOM: normalization reference pool
            % ============================================================
            ax2 = subplot(2,1,2);
            hold(ax2,'on');

            if ~isempty(Xref)

                xr = linspace(0,100,size(Xref,2));

                hRefCycles = gobjects(0);

                for iR = 1:size(Xref,1)
                    h = plot(ax2, xr, Xref(iR,:), '-', 'Color', [0.70 0.82 1.00], 'LineWidth', 0.8, 'HandleVisibility', 'off');

                    if iR == 1
                        hRefCycles = h;
                    end
                end

                hRefMean2 = plot(ax2, xr, mean(Xref,1,'omitnan'), '-', 'Color', [0.10 0.35 0.85], 'LineWidth', 2.2);

                xlabel(ax2, 'Gait cycle (%)');
                ylabel(ax2, get_ylabel_text(Ptmp));
                xlim(ax2, [0 100]);
                grid(ax2, 'on');

                title(ax2, sprintf('Normalization reference pool (%d cycles)', size(Xref,1)), 'Interpreter','none');

                if isgraphics(hRefCycles)
                    legend(ax2, [hRefCycles, hRefMean2], {'Reference cycles', 'Reference mean'}, 'Location', 'northeast');
                else
                    legend(ax2, hRefMean2, {'Reference mean'}, 'Location', 'northeast');
                end

            else
                axis(ax2, 'off');
                title(ax2, 'No reference pool available for this normalization mode', 'Interpreter','none');
            end

            % -----------------------------------------
            % Save figure
            % -----------------------------------------
            safeSubj = matlab.lang.makeValidName(subjID);
            safeCond = matlab.lang.makeValidName(condName);
            safeLeg  = matlab.lang.makeValidName(leg);
            safeMuscle = matlab.lang.makeValidName(muscle);
            safeNorm = matlab.lang.makeValidName(char(normMode));

            outFile = fullfile(IO.outlier_signal_plot_dir, sprintf( 'OUTLIER_SIGNAL_ADAPTIVE_%02d_%s_%s_%s_%s_%s.png', i, safeSubj, safeCond, safeLeg, safeMuscle, safeNorm));

            saveas(fig, outFile);
            close(fig);

        catch ME
            fprintf('[WARNING] Failed adaptive outlier plot for %s | %s | %s | %s\n', subjID, condName, leg, muscle);
            fprintf('%s\n', ME.message);
        end
    end

    fprintf('Done saving adaptive outlier signal plots in:\n%s\n', IO.outlier_signal_plot_dir);
end

function X = get_signal_cycle_matrix(TD, subjID, condName, leg, muscleName, P)

    X = [];

    if ~isfield(TD, subjID), return; end
    if ~isfield(TD.(subjID), condName), return; end
    if ~isfield(TD.(subjID).(condName), leg), return; end
    if ~isfield(TD.(subjID).(condName).(leg), muscleName), return; end

    S = TD.(subjID).(condName).(leg).(muscleName);

    if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
        return;
    end

    if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
        return;
    end

    xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, P);
    X = cell_to_valid_matrix(xcell);
end

function Xref = get_reference_cycle_matrix(TD, subjID, legName, muscleName, P)
% Return the normalized reference cycles used for plotting QC.
%
% Reference pool:
%   flatmax / flat_percentile:
%       subject × same leg × same muscle × Flat condition
%
%   subject_percentile:
%       subject × same leg × same muscle × all included conditions
%
%   cyclemax / none:
%       no common reference pool, so returns [].

    Xref = [];

    if ~isfield(TD, subjID)
        return;
    end

    normMode = string(P.normalization_mode);

    switch normMode
        case {"flatmax", "flat_percentile"}
            condList = "Flat";

        case "subject_percentile"
            condList = string(fieldnames(TD.(subjID)));

        otherwise
            return;
    end

    legName = char(string(legName));
    muscleName = char(string(muscleName));

    rows = {};

    for iC = 1:numel(condList)

        condName = char(condList(iC));

        if ~isfield(TD.(subjID), condName)
            continue;
        end

        if ~isfield(TD.(subjID).(condName), legName)
            continue;
        end

        if ~isfield(TD.(subjID).(condName).(legName), muscleName)
            continue;
        end

        S = TD.(subjID).(condName).(legName).(muscleName);

        if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
            continue;
        end

        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
            continue;
        end

        xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, P);

        if isempty(xcell)
            continue;
        end

        for iX = 1:numel(xcell)
            x = xcell{iX};

            if isempty(x) || ~isnumeric(x)
                continue;
            end

            x = x(:)';

            if any(~isfinite(x))
                continue;
            end

            rows{end+1,1} = x; %#ok<AGROW>
        end
    end

    if ~isempty(rows)
        Xref = vertcat(rows{:});
    end
end

function run_age_condition_interaction(TD, subjFields, P, PLT, IO)

    muscleName  = string(P.muscle_name);
    ageNames    = string(P.age_groups_to_compare);
    condNames   = string(P.conditions_to_compare);
    methodLabel = get_spm_method_label(P);

    fprintf('\n====================================================\n');
    fprintf('%s factorial analysis: age group × condition interaction\n', methodLabel);
    fprintf('Muscle: %s\n', muscleName);
    fprintf('Age groups: %s\n', strjoin(ageNames, ', '));
    fprintf('Conditions: %s\n', strjoin(condNames, ', '));
    fprintf('Normalization mode: %s\n', string(P.normalization_mode));
    fprintf('====================================================\n');

    assert(numel(ageNames) >= 2, 'Need at least 2 age groups.');
    assert(numel(condNames) >= 2, 'Need at least 2 conditions.');

    [Y, A, B, SUBJ, plotData] = build_age_condition_interaction_design( TD, subjFields, muscleName, ageNames, condNames, P);

    assert(~isempty(Y), 'No complete interaction data found.');

    fprintf('\nInteraction design:\n');
    fprintf('Subjects included: %d\n', numel(unique(SUBJ)));
    fprintf('Observations: %d\n', size(Y,1));
    fprintf('Time points: %d\n', size(Y,2));

    for iA = 1:numel(ageNames)
        nSub = numel(unique(SUBJ(A == iA)));
        fprintf('%s: n=%d complete subjects\n', ageNames(iA), nSub);
    end

    % ---------- run SPM factorial model ----------
    [spmiAge, spmiCondition, spmiInteraction, testName] = run_spm_anova2onerm(Y, A, B, SUBJ, P);

    nTimePoints = size(Y, 2);

    fprintf('\nTest used: %s\n', char(testName));

    fprintf('\n--- Main effect of age ---\n');
    print_spm_clusters(spmiAge);

    fprintf('\n--- Main effect of condition ---\n');
    print_spm_clusters(spmiCondition);

    fprintf('\n--- Interaction age × condition ---\n');
    print_spm_clusters(spmiInteraction);

    % ---------- save CSV outputs ----------
    append_spm_results_to_csv(IO.age_effects_csv, spmiAge, "factorial_age_main_effect", muscleName, "ALL_AGES", "ALL_CONDITIONS", strjoin(condNames, "|"), strjoin(ageNames, "|"), testName + "_age_main", nTimePoints, size(Y,1), P);

    append_spm_results_to_csv(IO.condition_effects_csv, spmiCondition, "factorial_condition_main_effect", muscleName, "ALL_AGES", "ALL_CONDITIONS", strjoin(condNames, "|"), strjoin(ageNames, "|"), testName + "_condition_main", nTimePoints, size(Y,1), P);

    append_spm_results_to_csv(IO.interaction_effects_csv, spmiInteraction, "age_x_condition_interaction", muscleName, "ALL_AGES", "ALL_CONDITIONS", strjoin(condNames, "|"), strjoin(ageNames, "|"), testName + "_interaction", nTimePoints, size(Y,1), P);

    % ---------- plot interaction figure ----------
    fig = figure('Visible','off', 'Color','w', 'Position', [100 100 1800 400]);

    if isfield(P, 'show_spm_bottom_plot') && P.show_spm_bottom_plot
        tl = tiledlayout(2, numel(condNames), 'TileSpacing','compact', 'Padding','compact');
    else
        tl = tiledlayout(1, numel(condNames), 'TileSpacing','compact', 'Padding','compact');
    end

    for iC = 1:numel(condNames)

        ax = nexttile(tl, iC);
        hold(ax, 'on');

        for iA = 1:numel(ageNames)

            Yk = plotData.Ycell{iA, iC};
            if isempty(Yk)
                continue;
            end

            col = get_color_safe(PLT.colors, char(ageNames(iA)), [0 0 0]);

            if P.show_sem
                plot_mean_sem(ax, Yk, col, sprintf('%s (n=%d)', ageNames(iA), size(Yk,1)), PLT.AlphaTransparency);
            else
                x = linspace(0,100,size(Yk,2));
                plot(ax, x, mean(Yk,1), 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', ageNames(iA), size(Yk,1)));
            end
        end

        add_spm_significance_bars(ax, spmiInteraction, nTimePoints, 'y_frac', 0.92, 'line_width', 1.3, 'color', [0 0 0]);

        xlabel(ax, 'Gait cycle (%)');
        ylabel(ax, get_ylabel_text(P));
        title(ax, sprintf('%s | %s', prettymuscle(muscleName), condNames(iC)), 'Interpreter','none');
        xlim(ax, [0 100]);
        grid(ax, 'on');

        if iC == numel(condNames)
            legend(ax, 'Location','best');
        end
    end

    if isfield(P, 'show_spm_bottom_plot') && P.show_spm_bottom_plot
        axSPM = nexttile(tl, numel(condNames)+1, [1 numel(condNames)]);
        axes(axSPM); %#ok<LAXES>
        spmiInteraction.plot();
        spmiInteraction.plot_threshold_label();
        spmiInteraction.plot_p_values();
        format_spm_axis_as_gait_cycle(axSPM, nTimePoints);

        title(axSPM, sprintf('%s age × condition interaction | %s', methodLabel, prettymuscle(muscleName)), 'Interpreter','none');
    end

    sgtitle(tl, sprintf('%s | age group × condition interaction | %s', prettymuscle(muscleName), methodLabel), 'Interpreter','none');

    outName = sprintf('%s_ageConditionInteraction_%s.png', methodLabel, muscleName);

    saveas(fig, fullfile(IO.out_dir, outName));
    close(fig);
end

function [Y, A, B, SUBJ, plotData] = build_age_condition_interaction_design( TD, subjFields, muscleName, ageNames, condNames, P)

    nAge  = numel(ageNames);
    nCond = numel(condNames);

    Y = [];
    A = [];
    B = [];
    SUBJ = [];

    plotData = struct();
    plotData.Ycell = cell(nAge, nCond);

    subjCounter = 0;

    for iS = 1:numel(subjFields)

        subjID = subjFields{iS};

        subjProfiles = cell(1, nCond);
        subjAge = "";

        % collect one subject-level profile per condition
        for iC = 1:nCond

            condName = condNames(iC);

            [prof, ageHere] = collect_one_subject_condition_profile( TD, subjID, muscleName, condName, P);

            if isempty(prof)
                subjProfiles{iC} = [];
            else
                subjProfiles{iC} = prof;
            end

            if subjAge == "" && ageHere ~= ""
                subjAge = ageHere;
            end
        end

        % must have all requested conditions
        hasAllConditions = true;
        for iC = 1:nCond
            if isempty(subjProfiles{iC})
                hasAllConditions = false;
                break;
            end
        end

        if ~hasAllConditions
            continue;
        end

        ageIdx = find(ageNames == subjAge, 1);

        if isempty(ageIdx)
            continue;
        end

        subjCounter = subjCounter + 1;

        for iC = 1:nCond

            prof = subjProfiles{iC};

            Y = [Y; prof]; %#ok<AGROW>
            A = [A; ageIdx]; %#ok<AGROW>
            B = [B; iC]; %#ok<AGROW>
            SUBJ = [SUBJ; subjCounter]; %#ok<AGROW>

            plotData.Ycell{ageIdx, iC} = [plotData.Ycell{ageIdx, iC}; prof]; %#ok<AGROW>
        end
    end
end

function [prof, ageName] = collect_one_subject_condition_profile( TD, subjID, muscleName, condName, P)

    prof = [];
    ageName = "";

    subjID = char(string(subjID));
    condName = char(string(condName));
    muscleName = char(string(muscleName));

    if ~isfield(TD, subjID)
        return;
    end

    if ~isfield(TD.(subjID), condName)
        return;
    end

    condStruct = TD.(subjID).(condName);
    legFields = fieldnames(condStruct);

    cycleProfiles = {};

    for il = 1:numel(legFields)

        leg = legFields{il};

        if ~isfield(condStruct.(leg), muscleName)
            continue;
        end

        S = condStruct.(leg).(muscleName);

        if isfield(S, 'age_group') && ageName == ""
            ageName = string(S.age_group);
        end

        if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
            continue;
        end

        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
            continue;
        end

        xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, P);

        if isempty(xcell)
            continue;
        end

        for iX = 1:numel(xcell)
            x = xcell{iX};

            if isempty(x) || ~isnumeric(x)
                continue;
            end

            x = x(:)';

            if any(~isfinite(x))
                continue;
            end

            cycleProfiles{end+1,1} = x; %#ok<AGROW>
        end
    end

    if isempty(cycleProfiles)
        return;
    end

    X = vertcat(cycleProfiles{:});
    prof = mean(X, 1, 'omitnan');

    if any(~isfinite(prof))
        prof = [];
    end
end

function [spmiAge, spmiCondition, spmiInteraction, testName] = run_spm_anova2onerm(Y, A, B, SUBJ, P)

    if P.use_nonparametric

        assert(~isempty(which('spm1d.stats.nonparam.anova2onerm')), ['Non-parametric anova2onerm not found in this SPM1D installation. ', 'Try parametric mode or check your SPM1D version.']);

        testName = "nonparam_anova2onerm";

        spmList = spm1d.stats.nonparam.anova2onerm(Y, A, B, SUBJ);

    else

        assert(~isempty(which('spm1d.stats.anova2onerm')), ['Parametric anova2onerm not found in this SPM1D installation. ', 'Check your SPM1D version.']);

        testName = "anova2onerm";

        spmList = spm1d.stats.anova2onerm(Y, A, B, SUBJ);
    end

    % -------------------------------------------------
    % IMPORTANT:
    % anova2onerm returns an SPM/SnPM list object with 3 effects:
    %   1 = Main A = age group
    %   2 = Main B = condition
    %   3 = Interaction AB = age × condition
    %
    % Inference must be run on the full list first, then indexed.
    % -------------------------------------------------
    spmiList = infer_spm_object(spmList, P, false);

    spmiAge         = spmiList(1);
    spmiCondition   = spmiList(2);
    spmiInteraction = spmiList(3);
end

function [T_cycles, T_signals] = detect_spm_adaptive_normalized_outliers(TD, subjFields, P)
% Detect normalized envelope outliers using an adaptive threshold:
%
% For each subject × normalization_mode × condition × leg × muscle:
%   threshold(t) = median(t) + k * MAD(t)
%
% A cycle is flagged if:
%   - percentage of points over threshold >= adaptive_outlier_min_pct_points
%   OR
%   - longest consecutive run over threshold >= adaptive_outlier_min_consecutive_pct
%
% IMPORTANT:
%   This function detects candidate outlier cycles. It does not remove them.

    fprintf('\nAdaptive normalized amplitude QC:\n');

    if isfield(P, 'adaptive_outlier_k_mad')
        kMAD = P.adaptive_outlier_k_mad;
    else
        kMAD = 6;
    end

    if isfield(P, 'adaptive_outlier_min_pct_points')
        minPctPoints = P.adaptive_outlier_min_pct_points;
    else
        minPctPoints = 2;
    end

    if isfield(P, 'adaptive_outlier_min_consecutive_pct')
        minConsecPct = P.adaptive_outlier_min_consecutive_pct;
    else
        minConsecPct = 1;
    end

    fprintf('  Method: median + %.2f MAD\n', kMAD);
    fprintf('  Flag if pct points over threshold >= %.2f%%\n', minPctPoints);
    fprintf('  OR longest consecutive exceedance >= %.2f%% cycle\n', minConsecPct);

    normModes = get_qc_normalization_modes(P);

    muscles = string(P.muscles_to_run);
    conds   = string(P.conditions_to_run);

    cycleRows = {};
    signalRows = {};
    cRow = 1;
    sRow = 1;

    for iNorm = 1:numel(normModes)

        Ptmp = P;
        Ptmp.normalization_mode = normModes(iNorm);

        for iS = 1:numel(subjFields)

            subjID = string(subjFields{iS});

            if ~isfield(TD, char(subjID))
                continue;
            end

            for iC = 1:numel(conds)

                condName = conds(iC);

                if ~isfield(TD.(char(subjID)), char(condName))
                    continue;
                end

                condStruct = TD.(char(subjID)).(char(condName));
                legFields = string(fieldnames(condStruct));

                for il = 1:numel(legFields)

                    leg = legFields(il);

                    if ~isfield(condStruct, char(leg))
                        continue;
                    end

                    for iM = 1:numel(muscles)

                        muscleName = muscles(iM);

                        if ~isfield(condStruct.(char(leg)), char(muscleName))
                            continue;
                        end

                        S = condStruct.(char(leg)).(char(muscleName));

                        if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                            continue;
                        end

                        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                            continue;
                        end

                        xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, Ptmp);

                        X = cell_to_valid_matrix(xcell);

                        if isempty(X)
                            continue;
                        end

                        nCycles = size(X, 1);
                        nTime   = size(X, 2);

                        [medProf, madProfSafe, thresholdProf, thrInfo] = compute_adaptive_mad_threshold_profile(X, Ptmp);

                        nOverCycles = 0;
                        maxValueSignal = max(X(:), [], 'omitnan');
                        maxPctOverSignal = 0;
                        maxLongestRunPctSignal = 0;

                        for iCycle = 1:nCycles

                            x = X(iCycle, :);

                            overMask = x > thresholdProf;

                            nOver = sum(overMask);
                            pctOver = 100 * nOver / nTime;
                            longestRun = longest_true_run(overMask);
                            longestRunPct = 100 * longestRun / nTime;

                            maxVal = max(x, [], 'omitnan');
                            maxThr = max(thresholdProf, [], 'omitnan');

                            if isempty(maxThr) || ~isfinite(maxThr) || maxThr <= 0
                                maxRatioToThreshold = NaN;
                            else
                                maxRatioToThreshold = maxVal / maxThr;
                            end

                            isOutlier = pctOver >= minPctPoints || longestRunPct >= minConsecPct;

                            if isOutlier
                                nOverCycles = nOverCycles + 1;
                            end

                            maxPctOverSignal = max(maxPctOverSignal, pctOver);
                            maxLongestRunPctSignal = max(maxLongestRunPctSignal, longestRunPct);

                            cycleRows(cRow,:) = { subjID, string(Ptmp.normalization_mode), condName, leg, muscleName, iCycle, nCycles, thrInfo.kMAD, minPctPoints, minConsecPct, isOutlier, nOver, pctOver, longestRun, longestRunPct, maxVal, maxThr, maxRatioToThreshold, thrInfo.smooth_window, thrInfo.mad_floor_frac, thrInfo.madFloor
                                }; %#ok<AGROW>

                            cRow = cRow + 1;
                        end

                        pctCyclesOver = 100 * nOverCycles / nCycles;

                        signalRows(sRow,:) = { subjID, string(Ptmp.normalization_mode), condName, leg, muscleName, nCycles, nOverCycles, pctCyclesOver, maxValueSignal, kMAD, minPctPoints, minConsecPct, maxPctOverSignal, maxLongestRunPctSignal }; %#ok<AGROW>

                        sRow = sRow + 1;
                    end
                end
            end
        end
    end

    if isempty(cycleRows)
        T_cycles = table();
    else
        T_cycles = cell2table(cycleRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'cycle_index', 'n_total_cycles', 'k_mad', 'min_pct_points', 'min_consecutive_pct', 'is_outlier_cycle', 'n_points_over_threshold', 'pct_points_over_threshold', 'longest_run_points', 'longest_run_pct', 'max_value_percent', 'max_adaptive_threshold_percent', 'max_ratio_to_threshold', 'smooth_window', 'mad_floor_frac', 'mad_floor'
            });
    end

    if isempty(signalRows)
        T_signals = table();
    else
        T_signals = cell2table(signalRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'n_total_cycles', 'n_cycles_over_threshold', 'pct_cycles_over_threshold', 'max_value_percent', 'k_mad', 'min_pct_points', 'min_consecutive_pct', 'max_pct_points_over_threshold', 'max_longest_run_pct'});
    end

    fprintf('Adaptive QC done.\n');
    fprintf('  Cycles checked: %d\n', height(T_cycles));
    if ~isempty(T_cycles)
        fprintf('  Outlier cycles: %d\n', sum(T_cycles.is_outlier_cycle));
    end
    fprintf('  Signals checked: %d\n', height(T_signals));
end

function modes = get_qc_normalization_modes(P)

    modes = strings(0,1);

    if isfield(P, 'normalization_mode_condition') && ~isempty(P.normalization_mode_condition)
        modes(end+1,1) = string(P.normalization_mode_condition);
    end

    if isfield(P, 'normalization_mode_age') && ~isempty(P.normalization_mode_age)
        modes(end+1,1) = string(P.normalization_mode_age);
    end

    if isfield(P, 'normalization_mode_interaction') && ~isempty(P.normalization_mode_interaction)
        modes(end+1,1) = string(P.normalization_mode_interaction);
    end

    if isfield(P, 'normalization_mode') && ~isempty(P.normalization_mode)
        modes(end+1,1) = string(P.normalization_mode);
    end

    modes = unique(modes);
    modes(modes == "" | modes == "none") = [];

    if isempty(modes)
        modes = "none";
    end
end

function n = longest_true_run(mask)

    mask = logical(mask(:));

    if isempty(mask) || ~any(mask)
        n = 0;
        return;
    end

    d = diff([false; mask; false]);
    runStarts = find(d == 1);
    runEnds   = find(d == -1) - 1;

    n = max(runEnds - runStarts + 1);
end

function [thresholdProf, medProf, madProfSafe, info] = compute_adaptive_threshold_for_signal( TD, subjID, condName, legName, muscleName, P)

    thresholdProf = [];
    medProf = [];
    madProfSafe = [];
    info = struct();

    subjID = char(string(subjID));
    condName = char(string(condName));
    legName = char(string(legName));
    muscleName = char(string(muscleName));

    if ~isfield(TD, subjID), return; end
    if ~isfield(TD.(subjID), condName), return; end
    if ~isfield(TD.(subjID).(condName), legName), return; end
    if ~isfield(TD.(subjID).(condName).(legName), muscleName), return; end

    S = TD.(subjID).(condName).(legName).(muscleName);

    if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
        return;
    end

    xcell = get_profile_cell_from_valid_cycles(S.valid_cycles, P);
    X = cell_to_valid_matrix(xcell);

    if isempty(X)
        return;
    end

    [medProf, madProfSafe, thresholdProf, info] = compute_adaptive_mad_threshold_profile(X, P);
end

function T_out = append_tables_safe(T1, T2)
% Append two tables safely by harmonizing variable names and types.

    if isempty(T1) && isempty(T2)
        T_out = table();
        return;
    end

    if isempty(T1)
        T_out = T2;
        return;
    end

    if isempty(T2)
        T_out = T1;
        return;
    end

    vars1 = string(T1.Properties.VariableNames);
    vars2 = string(T2.Properties.VariableNames);
    allVars = unique([vars1 vars2], 'stable');

    for i = 1:numel(allVars)
        v = char(allVars(i));

        if ~ismember(string(v), vars1)
            T1.(v) = create_missing_like(T2.(v), height(T1));
        end

        if ~ismember(string(v), vars2)
            T2.(v) = create_missing_like(T1.(v), height(T2));
        end
    end

    T1 = T1(:, cellstr(allVars));
    T2 = T2(:, cellstr(allVars));

    % Force type compatibility variable by variable
    for i = 1:numel(allVars)
        v = char(allVars(i));

        if ~strcmp(class(T1.(v)), class(T2.(v)))
            T1.(v) = string(T1.(v));
            T2.(v) = string(T2.(v));
        end
    end

    T_out = [T1; T2];
end

function x = create_missing_like(exampleCol, n)

    if isnumeric(exampleCol)
        x = nan(n,1);

    elseif islogical(exampleCol)
        x = false(n,1);

    elseif isstring(exampleCol)
        x = strings(n,1);
        x(:) = "";

    elseif iscellstr(exampleCol) || iscell(exampleCol)
        x = repmat({''}, n, 1);

    elseif iscategorical(exampleCol)
        x = categorical(repmat({''}, n, 1));

    else
        x = strings(n,1);
        x(:) = "";
    end
end

function [medianProfile, madProfile, thrProfile] = compute_adaptive_threshold_profile(X, P)
% X = cycles x timepoints matrix for one subject x condition x leg x muscle

    medianProfile = median(X, 1, 'omitnan');

    % true median absolute deviation profile
    absDev = abs(X - medianProfile);
    madProfile = median(absDev, 1, 'omitnan');

    if isfield(P, 'adaptive_mad_multiplier') && ~isempty(P.adaptive_mad_multiplier)
        k = P.adaptive_mad_multiplier;
    else
        k = 6;
    end

    thrProfile = medianProfile + k * madProfile;
end

function [medianProfileSmooth, madProfileSmooth, thresholdProfile, info] = compute_adaptive_mad_threshold_profile(X, P)
% Compute adaptive MAD threshold for one signal matrix.
%
% X = cycles × timepoints
%
% Threshold:
%   threshold(t) = smoothed_median(t) + kMAD * smoothed_MAD(t)
%
% This function should be used BOTH for:
%   1) adaptive outlier detection
%   2) adaptive threshold plotting
%
% so that QC detection and plotted threshold match exactly.

    info = struct();

    if isempty(X)
        medianProfileSmooth = [];
        madProfileSmooth = [];
        thresholdProfile = [];
        return;
    end

    % -----------------------------
    % Parameters
    % -----------------------------
    if isfield(P, 'adaptive_outlier_k_mad') && ~isempty(P.adaptive_outlier_k_mad)
        kMAD = P.adaptive_outlier_k_mad;
    else
        kMAD = 7;
    end

    if isfield(P, 'adaptive_outlier_smooth_window') && ~isempty(P.adaptive_outlier_smooth_window)
        w = P.adaptive_outlier_smooth_window;
    else
        w = 41;
    end

    if isfield(P, 'adaptive_outlier_mad_floor_frac') && ~isempty(P.adaptive_outlier_mad_floor_frac)
        madFloorFrac = P.adaptive_outlier_mad_floor_frac;
    else
        madFloorFrac = 0.20;
    end

    w = max(3, round(w));
    if mod(w, 2) == 0
        w = w + 1;
    end

    % -----------------------------
    % Raw median and MAD profiles
    % -----------------------------
    medianProfileRaw = median(X, 1, 'omitnan');

    absDev = abs(X - medianProfileRaw);
    madProfileRaw = median(absDev, 1, 'omitnan');

    % -----------------------------
    % Smooth over gait cycle
    % -----------------------------
    medianProfileSmooth = movmean(medianProfileRaw, w, 2, 'omitnan');
    madProfileSmooth    = movmean(madProfileRaw,    w, 2, 'omitnan');

    % -----------------------------
    % MAD floor
    % Prevents threshold from becoming unrealistically low where MAD ~ 0.
    % -----------------------------
    validMAD = madProfileSmooth(isfinite(madProfileSmooth) & madProfileSmooth > 0);

    if isempty(validMAD)
        globalMAD = median(abs(X(:) - median(X(:), 'omitnan')), 'omitnan');
    else
        globalMAD = median(validMAD, 'omitnan');
    end

    if isempty(globalMAD) || ~isfinite(globalMAD) || globalMAD <= 0
        globalMAD = eps;
    end

    madFloor = madFloorFrac * globalMAD;
    madProfileSmooth = max(madProfileSmooth, madFloor);

    % -----------------------------
    % Final threshold
    % -----------------------------
    thresholdProfile = medianProfileSmooth + kMAD * madProfileSmooth;

    info.kMAD = kMAD;
    info.smooth_window = w;
    info.mad_floor_frac = madFloorFrac;
    info.globalMAD = globalMAD;
    info.madFloor = madFloor;
end

function [TD, T_cycles, T_signals] = apply_amplitude_qc_exclusion_to_TD(TD, subjFields, P)

    fprintf('\n=== Applying adaptive amplitude QC exclusion ===\n');

    normModes = get_qc_normalization_modes(P);

    muscles = string(P.muscles_to_run);
    conds   = string(P.conditions_to_run);

    if isfield(P, 'min_cycles_after_amplitude_qc')
        minCyclesAfterQC = P.min_cycles_after_amplitude_qc;
    else
        minCyclesAfterQC = 7;
    end

    cycleRows = {};
    signalRows = {};
    cRow = 1;
    sRow = 1;

    for iNorm = 1:numel(normModes)

        normMode = normModes(iNorm);

        Ptmp = P;
        Ptmp.normalization_mode = normMode;
        Ptmp.apply_amplitude_qc_exclusion = false;
        % Important: do not apply masks while computing masks

        fprintf('Applying amplitude QC masks for normalization mode: %s\n', normMode);

        for iS = 1:numel(subjFields)

            subjID = string(subjFields{iS});

            if ~isfield(TD, char(subjID))
                continue;
            end

            for iC = 1:numel(conds)

                condName = conds(iC);

                if ~isfield(TD.(char(subjID)), char(condName))
                    continue;
                end

                condStruct = TD.(char(subjID)).(char(condName));
                legFields = string(fieldnames(condStruct));

                for il = 1:numel(legFields)

                    leg = legFields(il);

                    if ~isfield(condStruct, char(leg))
                        continue;
                    end

                    for iM = 1:numel(muscles)

                        muscleName = muscles(iM);

                        if ~isfield(condStruct.(char(leg)), char(muscleName))
                            continue;
                        end

                        S = condStruct.(char(leg)).(char(muscleName));

                        if ~isfield(S, 'included_for_analysis') || ~S.included_for_analysis
                            continue;
                        end

                        if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles)
                            continue;
                        end

                        VC = S.valid_cycles;

                        xcell = get_profile_cell_from_valid_cycles(VC, Ptmp);

                        if isempty(xcell)
                            continue;
                        end

                        [X, originalIdx] = cell_to_valid_matrix_with_indices(xcell);

                        if isempty(X)
                            continue;
                        end

                        nCyclesOriginal = numel(xcell);
                        nCyclesValidForQC = size(X, 1);
                        nTime = size(X, 2);

                        [~, ~, thresholdProf, thrInfo] = compute_adaptive_mad_threshold_profile(X, Ptmp);

                        if isempty(thresholdProf)
                            continue;
                        end

                        if isfield(P, 'adaptive_outlier_min_pct_points')
                            minPctPoints = P.adaptive_outlier_min_pct_points;
                        else
                            minPctPoints = 2;
                        end

                        if isfield(P, 'adaptive_outlier_min_consecutive_pct')
                            minConsecPct = P.adaptive_outlier_min_consecutive_pct;
                        else
                            minConsecPct = 1;
                        end

                        keepMask = true(nCyclesOriginal, 1);
                        excludeMaskOriginal = false(nCyclesOriginal, 1);

                        pctOverOriginal = nan(nCyclesOriginal, 1);
                        longestRunPctOriginal = nan(nCyclesOriginal, 1);
                        maxValueOriginal = nan(nCyclesOriginal, 1);
                        maxThresholdOriginal = max(thresholdProf, [], 'omitnan');

                        for iRow = 1:nCyclesValidForQC

                            origCycleIdx = originalIdx(iRow);
                            x = X(iRow, :);

                            overMask = x > thresholdProf;

                            pctOver = 100 * sum(overMask) / nTime;
                            longestRunPct = 100 * longest_true_run(overMask) / nTime;
                            maxVal = max(x, [], 'omitnan');

                            excludeCycle = pctOver >= minPctPoints || longestRunPct >= minConsecPct;

                            keepMask(origCycleIdx) = ~excludeCycle;
                            excludeMaskOriginal(origCycleIdx) = excludeCycle;

                            pctOverOriginal(origCycleIdx) = pctOver;
                            longestRunPctOriginal(origCycleIdx) = longestRunPct;
                            maxValueOriginal(origCycleIdx) = maxVal;
                        end

                        nExcluded = sum(excludeMaskOriginal);
                        nRemaining = sum(keepMask);

                        signalExcludedByTooFewCycles = nRemaining < minCyclesAfterQC;

                        % Store mask inside TD
                        keepField = char("amplitude_qc_keep_" + normMode);
                        excludeField = char("amplitude_qc_exclude_" + normMode);

                        VC.(keepField) = keepMask;
                        VC.(excludeField) = excludeMaskOriginal;

                        TD.(char(subjID)).(char(condName)).(char(leg)).(char(muscleName)).valid_cycles = VC;

                        % Cycle-level table
                        for iCycle = 1:nCyclesOriginal
                            cycleRows(cRow,:) = { subjID, normMode, condName, leg, muscleName, iCycle, nCyclesOriginal, logical(excludeMaskOriginal(iCycle)), logical(keepMask(iCycle)), pctOverOriginal(iCycle), longestRunPctOriginal(iCycle), maxValueOriginal(iCycle), maxThresholdOriginal, thrInfo.kMAD, thrInfo.smooth_window, thrInfo.mad_floor_frac }; %#ok<AGROW>

                            cRow = cRow + 1;
                        end

                        % Signal-level summary
                        signalRows(sRow,:) = { subjID, normMode, condName, leg, muscleName, nCyclesOriginal, nCyclesValidForQC, nExcluded, nRemaining, 100 * nExcluded / max(1, nCyclesOriginal), signalExcludedByTooFewCycles, minCyclesAfterQC, max(maxValueOriginal, [], 'omitnan'), maxThresholdOriginal, thrInfo.kMAD, thrInfo.smooth_window, thrInfo.mad_floor_frac }; %#ok<AGROW>

                        sRow = sRow + 1;
                    end
                end
            end
        end
    end

    if isempty(cycleRows)
        T_cycles = table();
    else
        T_cycles = cell2table(cycleRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'cycle_index', 'n_total_cycles', 'exclude_cycle', 'keep_cycle', 'pct_points_over_threshold', 'longest_run_pct', 'max_value_percent', 'max_adaptive_threshold_percent', 'k_mad', 'smooth_window', 'mad_floor_frac'});
    end

    if isempty(signalRows)
        T_signals = table();
    else
        T_signals = cell2table(signalRows, 'VariableNames', { 'subject', 'normalization_mode', 'condition', 'leg', 'muscle', 'n_total_cycles', 'n_cycles_valid_for_qc', 'n_cycles_excluded', 'n_cycles_remaining', 'pct_cycles_excluded', 'signal_excluded_by_too_few_cycles', 'min_cycles_required', 'max_value_percent', 'max_adaptive_threshold_percent', 'k_mad', 'smooth_window', 'mad_floor_frac'});
    end

    fprintf('Adaptive amplitude QC exclusion completed.\n');
    fprintf('Cycle rows: %d\n', height(T_cycles));
    fprintf('Signal rows: %d\n', height(T_signals));
end

function [X, validIdx] = cell_to_valid_matrix_with_indices(xcell)

    X = [];
    validIdx = [];

    for i = 1:numel(xcell)
        x = xcell{i};

        if isempty(x) || ~isnumeric(x)
            continue;
        end

        x = x(:)';

        if any(~isfinite(x))
            continue;
        end

        X = [X; x]; %#ok<AGROW>
        validIdx = [validIdx; i]; %#ok<AGROW>
    end
end