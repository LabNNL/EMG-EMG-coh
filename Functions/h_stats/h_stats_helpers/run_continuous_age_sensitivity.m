function S = run_continuous_age_sensitivity(T_subj, HC, outCsv)
% Refits the primary continuous-age model under alternative choices, to show
% whether a conclusion depends on them. For each pair and DV of
% HC.analysis.dv_list:
%   primary          DV ~ AgeYears_z * condition + (1|subject)
%   quadratic_age    + AgeYears_z2
%   fisher_z         atanh(sqrt(DV)) as the outcome (variance-stabilised coherence)
%   raw_logcycles    raw (non-equalized) coherence + log(n cycles)
%   cycle_bias_corr  cycle-bias-corrected coherence
% All fits use fit_h_lme / get_lme_term_stats (same coding, fit and DF as the
% primary table). p-values are Holm-adjusted within each variant across the
% pair x DV models, as in CONTINUOUS_AGE_LME_TABLE.

    variants = ["primary", "quadratic_age", "fisher_z", "raw_logcycles", "cycle_bias_corr"];
    rows = {};

    for pairName = string(HC.analysis.pairs_to_analyze)
        Tp = T_subj(T_subj.pair_name == pairName, :);
        if isempty(Tp), continue; end
        Tp.condition = removecats(Tp.condition);
        Tp.subject   = removecats(Tp.subject);

        for dv = string(HC.analysis.dv_list)
            band = string(infer_band_from_metric_name(dv));

            for v = variants
                T = Tp;
                y = dv;
                extra = "";
                switch v
                    case "quadratic_age"
                        T.AgeYears_z2 = T.AgeYears_z .^ 2;
                        extra = " + AgeYears_z2";
                    case "fisher_z"
                        y = dv + "__fisher_z";
                        T.(y) = atanh(sqrt(min(max(T.(dv), 0), 1 - 1e-12)));
                    case "raw_logcycles"
                        y = dv + "__raw";
                        nVar = band + "_n_cycles__raw";
                        if ~all(ismember([y, nVar], string(T.Properties.VariableNames))), continue; end
                        T.log_n_cycles = log(T.(nVar));
                        extra = " + log_n_cycles";
                    case "cycle_bias_corr"
                        y = dv + "__cycle_bias_corrected";
                end
                if ~ismember(y, string(T.Properties.VariableNames)), continue; end

                ok = isfinite(T.(y)) & isfinite(T.AgeYears_z);
                if contains(extra, "log_n_cycles"), ok = ok & isfinite(T.log_n_cycles); end
                T = T(ok, :);
                if height(T) < 10, continue; end

                formula = sprintf('%s ~ AgeYears_z * condition%s + (1|subject)', y, extra);
                try
                    lme = fit_h_lme(T, formula, HC);
                catch ME
                    warning('Sensitivity model failed (%s | %s | %s): %s', pairName, dv, v, ME.message);
                    continue;
                end
                a = get_lme_term_stats(lme, HC, 'AgeYears_z');
                c = get_lme_term_stats(lme, HC, 'condition');
                i = get_lme_term_stats(lme, HC, 'AgeYears_z:condition');

                rows(end+1, :) = {pairName, dv, v, string(formula), height(T), numel(unique(T.subject)), ...
                    a.estimate, a.ci_low, a.ci_high, a.p, c.p, i.p}; %#ok<AGROW>
            end
        end
    end

    S = cell2table(rows, 'VariableNames', {'pair_name','metric','variant','model_formula','n_rows','n_subjects', ...
        'est_age_per_sd','ci_low_age_per_sd','ci_high_age_per_sd','p_age_linear','p_condition','p_age_condition'});

    for pv = ["p_age_linear", "p_condition", "p_age_condition"]
        S.(pv + "_holm") = NaN(height(S), 1);
        for v = unique(S.variant)'
            k = S.variant == v;
            s = struct('p', num2cell(S.(pv)(k)));
            s = apply_pairwise_p_correction(s, 'holm');
            S.(pv + "_holm")(k) = [s.p]';
        end
    end

    if nargin >= 3 && ~isempty(outCsv)
        writetable(S, outCsv);
    end
end
