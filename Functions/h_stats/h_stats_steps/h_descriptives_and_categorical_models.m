function [DESCRIPTIVE_ALL, OMNIBUS_TABLE, POSTHOC_TABLE] = h_descriptives_and_categorical_models(T_row, T_subj, C, HC, ANALYSIS_TAG)
% H_DESCRIPTIVES_AND_CATEGORICAL_MODELS  Descriptive tables per pair x age group
% x condition, and (when HC.analysis.run_categorical_age_lme) the categorical
% age_group * condition models with post hoc tests.

    bandNames = fieldnames(C.g_coherence.params.FreqBands)';
    perBand = @(suffix) strcat(bandNames, suffix);
    dvList = HC.analysis.dv_list;
    includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    %% ===================== DESCRIPTIVE TABLES =====================


    fprintf('\nT_row variables:\n');
    disp(T_row.Properties.VariableNames(:));

    fprintf('\nT_subj variables:\n');
    disp(T_subj.Properties.VariableNames(:));

    fprintf('\nHC.analysis.dv_list:\n');
    disp(HC.analysis.dv_list(:));

    missingFromTsubj = setdiff(HC.analysis.dv_list, T_subj.Properties.VariableNames);
    fprintf('\nVariables in HC.analysis.dv_list but missing from T_subj:\n');
    disp(missingFromTsubj(:));

    missingFromTrow = setdiff(HC.analysis.dv_list, T_row.Properties.VariableNames);
    fprintf('\nVariables in HC.analysis.dv_list but missing from T_row:\n');
    disp(missingFromTrow(:));

    powerVars = perBand('_LogPower');

    fprintf('\nPower vars in T_row?\n');
    disp(ismember(powerVars, T_row.Properties.VariableNames));

    fprintf('\nPower vars in T_subj?\n');
    disp(ismember(powerVars, T_subj.Properties.VariableNames));

    fprintf('\nBuilding descriptive tables...\n');

    DESCRIPTIVE_ALL = table();

    for idv = 1:numel(dvList)
        dv = dvList{idv};
        Td = descriptive_table(T_subj, dv, {'pair_name','age_group','condition'});
        Td.metric = repmat(string(dv), height(Td), 1);

        if isempty(DESCRIPTIVE_ALL)
            DESCRIPTIVE_ALL = Td;
        else
            DESCRIPTIVE_ALL = [DESCRIPTIVE_ALL; Td]; %#ok<AGROW>
        end
    end

    writetable(DESCRIPTIVE_ALL, fullfile(HC.io.tables_dir, 'DESCRIPTIVE_TABLE_ALL.csv'));

    runCategoricalAgeLME = ...
        isfield(HC.analysis, 'run_categorical_age_lme') && ...
        HC.analysis.run_categorical_age_lme;

    % Initialize so later workspace saving still works
    OMNIBUS_TABLE = table();
    POSTHOC_TABLE = table();

    if runCategoricalAgeLME

        fprintf('\nRunning categorical-age pair-specific models...\n');

        OMNIBUS_ROWS = {};
        riO = 0;

        POSTHOC_ROWS = {};
        riP = 0;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            Tp.age_group = removecats(Tp.age_group);
            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for idv = 1:numel(dvList)

                dv = dvList{idv};

                if ~ismember(dv, Tp.Properties.VariableNames)
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)), :);

                if isempty(Tm)
                    continue;
                end

                outTxt = fullfile( ...
                    HC.io.models_dir, ...
                    sprintf('MODEL__%s__%s__%s.txt', ...
                    char(pairName), dv, ANALYSIS_TAG));

                includeCycleCovRequested = ...
                    isfield(HC.analysis, 'include_cycle_count_covariate') && ...
                    HC.analysis.include_cycle_count_covariate;

                [Tm, useCycleCovInThisModel, cycleCovSource] = ...
                    add_log_cycle_covariate_for_dv( ...
                    Tm, dv, includeCycleCovRequested);

                if useCycleCovInThisModel
                    formula = sprintf( ...
                        '%s ~ age_group * condition + log_n_cycles + (1|subject)', ...
                        dv);
                else
                    formula = sprintf( ...
                        '%s ~ age_group * condition + (1|subject)', ...
                        dv);
                end

                fprintf('\nRunning categorical-age LME for %s | %s\n', ...
                    pairName, string(dv));
                fprintf('Formula: %s\n', formula);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                lme = write_lme_report(Tm, dv, formula, outTxt, HC);

                % ---------- omnibus ----------
                p_age = NaN; p_condition = NaN; p_interaction = NaN;
                if ~isempty(lme)
                    p_age = get_lme_term_stats(lme, HC, 'age_group').p;
                    p_condition = get_lme_term_stats(lme, HC, 'condition').p;
                    p_interaction = get_lme_term_stats(lme, HC, 'age_group:condition').p;
                end

                if useCycleCovInThisModel
                    cycleCovariate = "log_n_cycles";
                else
                    cycleCovariate = "";
                end

                riO = riO + 1;

                OMNIBUS_ROWS(riO,:) = { ...
                    pairName, string(dv), ...
                    string(HC.analysis.coherence_source), ...
                    string(HC.analysis.metric_scope), ...
                    useCycleCovInThisModel, ...
                    cycleCovariate, ...
                    string(cycleCovSource), ...
                    string(formula), ...
                    height(Tm), ...
                    numel(unique(Tm.subject)), ...
                    p_age, ...
                    p_condition, ...
                    p_interaction };

                % ---------- post hoc: condition within age ----------
                stats_cond_within_age = ...
                    get_condition_pairwise_stats_within_age_simple( ...
                    Tm, dv, HC.posthoc);

                if ~isempty(stats_cond_within_age)

                    stats_cond_within_age = ...
                        apply_pairwise_p_correction( ...
                        stats_cond_within_age, ...
                        HC.posthoc.correction);

                    for k = 1:numel(stats_cond_within_age)

                        riP = riP + 1;

                        POSTHOC_ROWS(riP,:) = { ...
                            pairName, ...
                            string(dv), ...
                            "condition_within_age", ...
                            string(stats_cond_within_age(k).group), ...
                            string(stats_cond_within_age(k).g1), ...
                            string(stats_cond_within_age(k).g2), ...
                            stats_cond_within_age(k).p_raw, ...
                            stats_cond_within_age(k).p, ...
                            string(stats_cond_within_age(k).test_used), ...
                            mat2str(stats_cond_within_age(k).n) };
                    end
                end

                % ---------- post hoc: age within condition ----------
                stats_age_within_condition = ...
                    get_age_pairwise_stats_within_condition_simple( ...
                    Tm, dv, HC.posthoc);

                if ~isempty(stats_age_within_condition)

                    stats_age_within_condition = ...
                        apply_pairwise_p_correction( ...
                        stats_age_within_condition, ...
                        HC.posthoc.correction);

                    for k = 1:numel(stats_age_within_condition)

                        riP = riP + 1;

                        POSTHOC_ROWS(riP,:) = { ...
                            pairName, ...
                            string(dv), ...
                            "age_within_condition", ...
                            string(stats_age_within_condition(k).group), ...
                            string(stats_age_within_condition(k).g1), ...
                            string(stats_age_within_condition(k).g2), ...
                            stats_age_within_condition(k).p_raw, ...
                            stats_age_within_condition(k).p, ...
                            string(stats_age_within_condition(k).test_used), ...
                            mat2str(stats_age_within_condition(k).n) };
                    end
                end
            end
        end

        if ~isempty(OMNIBUS_ROWS)
            OMNIBUS_TABLE = cell2table( ...
                OMNIBUS_ROWS, ...
                'VariableNames', { ...
                'pair_name','metric', ...
                'coherence_source','metric_scope', ...
                'include_cycle_count_covariate', ...
                'cycle_count_covariate', ...
                'cycle_count_source', ...
                'model_formula', ...
                'n_rows','n_subjects', ...
                'p_age_group','p_condition','p_age_condition'});
        end

        writetable(OMNIBUS_TABLE, ...
            fullfile(HC.io.tables_dir, ...
            sprintf('OMNIBUS_TABLE__%s.csv', ANALYSIS_TAG)));

        writetable(OMNIBUS_TABLE, ...
            fullfile(HC.io.tables_dir, 'OMNIBUS_TABLE.csv'));

        if ~isempty(POSTHOC_ROWS)

            POSTHOC_TABLE = cell2table( ...
                POSTHOC_ROWS, ...
                'VariableNames', { ...
                'pair_name','metric','comparison_family', ...
                'stratification_group', ...
                'level_1','level_2', ...
                'p_raw','p_adj','test_used','n_used'});

            POSTHOC_TABLE.coherence_source = ...
                repmat(string(HC.analysis.coherence_source), ...
                height(POSTHOC_TABLE), 1);

            POSTHOC_TABLE.metric_scope = ...
                repmat(string(HC.analysis.metric_scope), ...
                height(POSTHOC_TABLE), 1);

            POSTHOC_TABLE.include_cycle_count_covariate = ...
                repmat(includeCycleCov, height(POSTHOC_TABLE), 1);

        end

        writetable(POSTHOC_TABLE, ...
            fullfile(HC.io.tables_dir, ...
            sprintf('POSTHOC_TABLE__%s.csv', ANALYSIS_TAG)));

        writetable(POSTHOC_TABLE, ...
            fullfile(HC.io.tables_dir, 'POSTHOC_TABLE.csv'));

    else

        fprintf('\nCategorical-age LME disabled.\n');

    end
end
