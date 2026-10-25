function CONTINUOUS_AGE_LME_TABLE = h_continuous_age_models(T_subj, C, HC, ANALYSIS_TAG)
% H_CONTINUOUS_AGE_MODELS  The primary analysis: per pair and DV,
%   DV ~ AgeYears_z * condition + (1|subject)
% fitted with fit_h_lme (HC.lme), Holm-adjusted across models, with model
% reports, residual diagnostics, per-condition and 3-band figures, and the
% sensitivity table. Returns the primary table (empty when switched off).

    CONTINUOUS_AGE_LME_TABLE = table();
    dvList = HC.analysis.dv_list;

    contAgeLmmPlotDir = fullfile(HC.io.plots_dir, 'continuous_age_lmm_by_condition');
    if ~exist(contAgeLmmPlotDir, 'dir')
        mkdir(contAgeLmmPlotDir);
    end

    %% ===================== CONTINUOUS AGE LME MODELS =====================
    runContinuousAgeLME = isfield(HC.analysis, 'run_continuous_age_lme') && HC.analysis.run_continuous_age_lme;

    if runContinuousAgeLME

        contAgeLmm3BandPlotDir = fullfile(HC.io.plots_dir, 'continuous_age_lmm_3bands');
        if ~exist(contAgeLmm3BandPlotDir, 'dir')
            mkdir(contAgeLmm3BandPlotDir);
        end

        fprintf('\nRunning continuous-age LME models...\n');

        CONT_AGE_ROWS = {};
        riCA = 0;

        PLOT_3BANDS_BY_PAIR = struct();
        contAgeDiagDir = fullfile(HC.io.models_dir, 'continuous_age_lmm_diagnostics');
        if ~exist(contAgeDiagDir, 'dir')
            mkdir(contAgeDiagDir);
        end

        contAgeDir = fullfile(HC.io.models_dir, 'continuous_age_models');
        if ~exist(contAgeDir, 'dir')
            mkdir(contAgeDir);
        end

        useAgeConditionInteraction = isfield(HC.analysis, 'continuous_age_condition_interaction') && HC.analysis.continuous_age_condition_interaction;

        includePowerContAge = isfield(HC.analysis, 'continuous_age_include_power') && HC.analysis.continuous_age_include_power;

        includeCycleContAge = isfield(HC.analysis, 'continuous_age_include_cycle_count') && HC.analysis.continuous_age_include_cycle_count;

        includeQuadraticAge = isfield(HC.analysis, 'continuous_age_include_quadratic') && HC.analysis.continuous_age_include_quadratic;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);
            PLOT_3BANDS = struct();


            if isempty(Tp)
                continue;
            end

            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for idv = 1:numel(dvList)

                dv = dvList{idv};

                if ~ismember(dv, Tp.Properties.VariableNames)
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.AgeYears_z), :);

                if height(Tm) < 10
                    fprintf('Not enough data for continuous-age LME: %s | %s | n=%d\n', pairName, string(dv), height(Tm));
                    continue;
                end

                % ---------- age terms ----------
                Tm.AgeYears_z2 = Tm.AgeYears_z.^2;

                % ---------- optional power covariate ----------
                powerVar = "";
                usePowerInThisModel = false;

                if includePowerContAge
                    powerVar = get_power_var_for_metric(dv);

                    if strlength(powerVar) > 0 && ismember(powerVar, string(Tm.Properties.VariableNames))
                        Tm = Tm(~isnan(Tm.(char(powerVar))), :);

                        if height(Tm) >= 10
                            Tm.(char(powerVar)) = zscore(Tm.(char(powerVar)));
                            usePowerInThisModel = true;
                        end
                    end
                end

                % ---------- optional cycle-count covariate ----------
                [Tm, useCycleCovInThisModel, cycleCovSource] = add_log_cycle_covariate_for_dv(Tm, dv, includeCycleContAge);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                if height(Tm) < 10
                    fprintf('Not enough data after covariate filtering: %s | %s | n=%d\n', pairName, string(dv), height(Tm));
                    continue;
                end

                % ---------- build formula ----------
                if useAgeConditionInteraction
                    ageConditionTerm = "AgeYears_z * condition";
                else
                    ageConditionTerm = "AgeYears_z + condition";
                end

                if includeQuadraticAge
                    if useAgeConditionInteraction
                        ageTerm = "AgeYears_z * condition + AgeYears_z2";
                    else
                        ageTerm = "AgeYears_z + AgeYears_z2 + condition";
                    end
                else
                    ageTerm = ageConditionTerm;
                end

                extraTerms = strings(0,1);

                if usePowerInThisModel
                    extraTerms(end+1) = powerVar; %#ok<SAGROW>
                end

                if useCycleCovInThisModel
                    extraTerms(end+1) = "log_n_cycles"; %#ok<SAGROW>
                end

                if isempty(extraTerms)
                    formula = sprintf('%s ~ %s + (1|subject)', dv, ageTerm);
                else
                    formula = sprintf('%s ~ %s + %s + (1|subject)', dv, ageTerm, strjoin(extraTerms, ' + '));
                end

                outTxt = fullfile(contAgeDir, sprintf('MODEL_CONTINUOUS_AGE__%s__%s__%s.txt', char(pairName), dv, ANALYSIS_TAG));

                fprintf('\nRunning continuous-age LME for %s | %s\n', pairName, string(dv));
                fprintf('Formula: %s\n', formula);

                qqPng = fullfile(contAgeDiagDir, sprintf('QQ__%s__%s__%s.png', char(pairName), dv, ANALYSIS_TAG));
                [lme, lmeDiag] = write_lme_report(Tm, dv, formula, outTxt, HC, qqPng);

                if isempty(lme)
                    continue;
                end

                if isfield(HC.plot, 'continuous_age_lmm') && HC.plot.continuous_age_lmm.enable

                    outPng = fullfile(contAgeLmmPlotDir, sprintf('CONTINUOUS_AGE_LMM__%s__%s__%s__%s.png', char(pairName), dv, char(string(HC.analysis.coherence_source)), lower(char(string(HC.analysis.metric_scope)))));

                    plot_continuous_age_lmm_by_condition( Tm, lme, dv, pairName, C, HC, outPng, 'powerVar', powerVar, 'cycleVar', "", 'ageVarRaw', 'AgeYears', 'ageVarModel', 'AgeYears_z', 'conditionVar', 'condition', 'subjectVar', 'subject');
                end

                % ---------- term statistics, all from the model fitted above ----------
                % Under effects coding the AgeYears_z term is the age slope averaged over conditions.
                stAge  = get_lme_term_stats(lme, HC, 'AgeYears_z');
                stCond = get_lme_term_stats(lme, HC, 'condition');
                stInt  = get_lme_term_stats(lme, HC, 'AgeYears_z:condition');
                stQuad = get_lme_term_stats(lme, HC, 'AgeYears_z2');
                stPow  = struct('p', NaN);
                stCyc  = struct('p', NaN);
                if usePowerInThisModel
                    stPow = get_lme_term_stats(lme, HC, char(powerVar));
                end
                if useCycleCovInThisModel
                    stCyc = get_lme_term_stats(lme, HC, 'log_n_cycles');
                end

                % years per SD of AgeYears_z, to report the slope per year
                ageSd = NaN;
                if ismember('AgeYears', Tm.Properties.VariableNames) && numel(unique(Tm.AgeYears_z)) > 1
                    b = polyfit(Tm.AgeYears_z, Tm.AgeYears, 1);
                    ageSd = b(1);
                end

                % ---------- store model for the 3-band plot (drawn after the Holm correction) ----------
                if isfield(HC.plot, 'continuous_age_lmm_3bands') && HC.plot.continuous_age_lmm_3bands.enable

                    bandField = char(infer_band_from_metric_name(dv));

                    PLOT_3BANDS.(bandField).Tm = Tm;
                    PLOT_3BANDS.(bandField).lme = lme;
                    PLOT_3BANDS.(bandField).dv = string(dv);
                    PLOT_3BANDS.(bandField).pairName = pairName;
                    PLOT_3BANDS.(bandField).formula = string(formula);
                    PLOT_3BANDS.(bandField).powerVar = string(powerVar);
                    PLOT_3BANDS.(bandField).cycleVar = "";
                    if useCycleCovInThisModel
                        PLOT_3BANDS.(bandField).cycleVar = "log_n_cycles";
                    end
                    PLOT_3BANDS.(bandField).p_power = stPow.p;
                    PLOT_3BANDS.(bandField).p_cycle = stCyc.p;
                end

                riCA = riCA + 1;
                CONT_AGE_ROWS(riCA,:) = { pairName, string(dv), string(HC.analysis.coherence_source), string(HC.analysis.metric_scope), string(formula), height(Tm), numel(unique(Tm.subject)), useAgeConditionInteraction, includeQuadraticAge, usePowerInThisModel, string(powerVar), useCycleCovInThisModel, string(cycleCovSource), ...
                    stAge.p, stQuad.p, stCond.p, stInt.p, stPow.p, stCyc.p, ...
                    stAge.F, stAge.df1, stAge.df2, stCond.F, stCond.df1, stCond.df2, stInt.F, stInt.df1, stInt.df2, ...
                    stAge.estimate, stAge.se, stAge.ci_low, stAge.ci_high, ageSd, stAge.estimate / ageSd, stAge.ci_low / ageSd, stAge.ci_high / ageSd, ...
                    lmeDiag.skewness, lmeDiag.kurtosis, lmeDiag.p_lilliefors, ...
                    string(HC.lme.dummy_var_coding), string(HC.lme.fit_method), string(HC.lme.df_method) };
            end

            if ~isempty(fieldnames(PLOT_3BANDS))
                PLOT_3BANDS_BY_PAIR.(matlab.lang.makeValidName(pairName)) = PLOT_3BANDS;
            end
        end

        if ~isempty(CONT_AGE_ROWS)

            CONTINUOUS_AGE_LME_TABLE = cell2table(CONT_AGE_ROWS, 'VariableNames', { 'pair_name','metric', 'coherence_source','metric_scope', 'model_formula', 'n_rows','n_subjects', 'age_condition_interaction_included', 'quadratic_age_included', 'power_covariate_included','power_covariate', 'cycle_count_covariate_included','cycle_count_source', ...
                'p_age_linear','p_age_quadratic','p_condition','p_age_condition', 'p_power','p_cycle', ...
                'F_age','df1_age','df2_age','F_condition','df1_condition','df2_condition','F_age_condition','df1_age_condition','df2_age_condition', ...
                'est_age_per_sd','se_age_per_sd','ci_low_age_per_sd','ci_high_age_per_sd','age_sd_years','est_age_per_year','ci_low_age_per_year','ci_high_age_per_year', ...
                'resid_skewness','resid_kurtosis','resid_p_lilliefors', ...
                'dummy_var_coding','fit_method','df_method'});

            % Holm across all models of the table (one family per term)
            for pv = ["p_age_linear", "p_condition", "p_age_condition"]
                s = struct('p', num2cell(CONTINUOUS_AGE_LME_TABLE.(pv)));
                s = apply_pairwise_p_correction(s, 'holm');
                CONTINUOUS_AGE_LME_TABLE.(pv + "_holm") = [s.p]';
            end
            CONTINUOUS_AGE_LME_TABLE.holm_family_size = repmat(height(CONTINUOUS_AGE_LME_TABLE), height(CONTINUOUS_AGE_LME_TABLE), 1);

            writetable(CONTINUOUS_AGE_LME_TABLE, fullfile(HC.io.tables_dir, sprintf('CONTINUOUS_AGE_LME_TABLE__%s.csv', ANALYSIS_TAG)));

            writetable(CONTINUOUS_AGE_LME_TABLE, fullfile(HC.io.tables_dir, 'CONTINUOUS_AGE_LME_TABLE.csv'));

            disp(CONTINUOUS_AGE_LME_TABLE(:, {'pair_name','metric','p_age_linear','p_age_linear_holm','p_condition','p_condition_holm','p_age_condition','p_age_condition_holm'}));

            % ---------- 3-band plots, annotated with the Holm-adjusted p-values ----------
            for pairKey = string(fieldnames(PLOT_3BANDS_BY_PAIR))'
                PLOT_3BANDS = PLOT_3BANDS_BY_PAIR.(pairKey);
                for bandField = string(fieldnames(PLOT_3BANDS))'
                    S3 = PLOT_3BANDS.(bandField);
                    r = find(CONTINUOUS_AGE_LME_TABLE.pair_name == S3.pairName & CONTINUOUS_AGE_LME_TABLE.metric == S3.dv, 1);
                    PLOT_3BANDS.(bandField).p_age = CONTINUOUS_AGE_LME_TABLE.p_age_linear_holm(r);
                    PLOT_3BANDS.(bandField).p_condition = CONTINUOUS_AGE_LME_TABLE.p_condition_holm(r);
                    PLOT_3BANDS.(bandField).p_interaction = CONTINUOUS_AGE_LME_TABLE.p_age_condition_holm(r);
                    PLOT_3BANDS.(bandField).p_label = "Holm";
                end
                pairName = PLOT_3BANDS.(bandField).pairName;
                fprintf('Plotting continuous-age LMM 3-band plot for pair: %s\n', pairName);
                outPng = fullfile(contAgeLmm3BandPlotDir, sprintf('CONTINUOUS_AGE_LMM_3BANDS__%s__%s__%s.png', char(pairName), char(string(HC.analysis.coherence_source)), lower(char(string(HC.analysis.metric_scope)))));
                plot_continuous_age_lmm_3bands_by_condition( PLOT_3BANDS, C, HC, outPng);
            end

            % ---------- Sensitivity of the primary model ----------
            if ~isfield(HC.analysis, 'run_continuous_age_sensitivity') || HC.analysis.run_continuous_age_sensitivity
                SENSITIVITY_CONTINUOUS_AGE = run_continuous_age_sensitivity(T_subj, HC, fullfile(HC.io.tables_dir, 'SENSITIVITY_CONTINUOUS_AGE.csv'));
                disp(SENSITIVITY_CONTINUOUS_AGE(:, {'pair_name','metric','variant','est_age_per_sd','p_age_linear_holm','p_condition_holm','p_age_condition_holm'}));
            end
        else
            warning('No continuous-age LME models were computed.');
        end
    end
end
