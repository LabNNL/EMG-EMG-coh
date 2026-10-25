function h_power_control_models(T_subj, HC, ANALYSIS_TAG)
% H_POWER_CONTROL_MODELS  Categorical-age models with band log-power as a
% covariate. Runs when HC.analysis.run_power_control_models.

    %% ===================== POWER-CONTROL MODELS =====================

    runPowerControlModels = ...
        isfield(HC.analysis, 'run_power_control_models') && ...
        HC.analysis.run_power_control_models;

    if runPowerControlModels

        fprintf('\nRunning power-control models...\n');

        powerPairs = HC.analysis.power_pairs;

        includeCycleCov = ...
            isfield(HC.analysis, 'include_cycle_count_covariate') && ...
            HC.analysis.include_cycle_count_covariate;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            fprintf('\nPair: %s\n', HC.analysis.pairs_to_analyze{ip});

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            Tp.age_group = removecats(Tp.age_group);
            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for im = 1:size(powerPairs,1)
                dv = powerPairs{im,1};
                powVar = powerPairs{im,2};

                if ~ismember(dv, Tp.Properties.VariableNames) || ~ismember(powVar, Tp.Properties.VariableNames)

                    fprintf('Missing variable(s) for power control model, skipping: %s or %s\n', dv, powVar);
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.(powVar)), :);

                includeCycleCovRequested = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

                [Tm, useCycleCovInThisModel, cycleCovSource] = add_log_cycle_covariate_for_dv(Tm, dv, includeCycleCovRequested);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                if height(Tm) < 10
                    fprintf('Not enough data for modeling (n = %d), skipping power-control model for this pair and DV.\n', height(Tm));
                    continue;
                end

                % z-score power so coefficient is interpretable
                Tm.(powVar) = zscore(Tm.(powVar));

                if useCycleCovInThisModel
                    formula = sprintf('%s ~ age_group * condition + %s + log_n_cycles + (1|subject)', dv, powVar);

                    fprintf('Power-control model WITH cycle-count covariate:\n');
                    fprintf('Formula: %s\n', formula);
                    fprintf('Cycle-count source: %s\n', cycleCovSource);

                    cycleTag = "cyclecov";
                else
                    formula = sprintf('%s ~ age_group * condition + %s + (1|subject)', dv, powVar);

                    fprintf('Power-control model WITHOUT cycle-count covariate:\n');
                    fprintf('Formula: %s\n', formula);

                    cycleTag = "nocyclecov";
                end

                if exist('ANALYSIS_TAG', 'var')
                    outTxt = fullfile(HC.io.models_dir, sprintf('MODEL_POWER_CONTROL__%s__%s__%s.txt', char(pairName), dv, ANALYSIS_TAG));
                else
                    outTxt = fullfile(HC.io.models_dir, sprintf('MODEL_POWER_CONTROL__%s__%s__%s_%s.txt', char(pairName), dv, string(HC.analysis.coherence_source), cycleTag));
                end

                lme = write_lme_report(Tm, dv, formula, outTxt, HC);
            end
        end
    else
        fprintf('Power-control models are disabled.\n');
    end
end
