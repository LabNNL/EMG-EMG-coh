function [lme, diag] = write_lme_report(T, dvName, formula, outTxt, HC, qqPng)
% Fits the model with the stage-h settings (fit_h_lme) and writes a text
% report: settings, model summary, fixed effects and ANOVA (both with
% HC.lme.df_method), and residual diagnostics. With qqPng, also saves a
% normal QQ plot of the conditional residuals.

    if nargin < 5 || isempty(HC)
        C = config_emg();
        HC = C.h_stats;
    end
    if nargin < 6
        qqPng = '';
    end

    lme = [];
    diag = struct('n', height(T), 'skewness', NaN, 'kurtosis', NaN, 'p_lilliefors', NaN);

    fid = fopen(outTxt, 'w');
    if fid == -1
        warning('Could not open model report file:\n%s', outTxt);
        return;
    end

    L = struct('dummy_var_coding', 'effects', 'fit_method', 'REML', 'df_method', 'satterthwaite');
    if isfield(HC, 'lme')
        for f = fieldnames(L)'
            if isfield(HC.lme, f{1}), L.(f{1}) = HC.lme.(f{1}); end
        end
    end

    fprintf(fid, 'Dependent variable: %s\n', dvName);
    fprintf(fid, 'Formula: %s\n', formula);
    fprintf(fid, 'Coding: %s | Fit: %s | DF: %s\n\n', L.dummy_var_coding, L.fit_method, L.df_method);
    fprintf(fid, 'N rows: %d\n', height(T));
    fprintf(fid, 'N subjects: %d\n\n', numel(unique(T.subject)));

    try
        lme = fit_h_lme(T, formula, HC);

        fprintf(fid, '===== MODEL SUMMARY =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(lme)'));

        [~, ~, FE] = fixedEffects(lme, 'DFMethod', L.df_method);
        fprintf(fid, '===== FIXED EFFECTS (DF: %s) =====\n', L.df_method);
        fprintf(fid, '%s\n\n', evalc('disp(FE)'));

        fprintf(fid, '===== ANOVA (DF: %s) =====\n', L.df_method);
        fprintf(fid, '%s\n\n', evalc('disp(anova(lme, ''DFMethod'', L.df_method))'));

        r = residuals(lme, 'ResidualType', 'Pearson');
        r = r(isfinite(r));
        diag.skewness = skewness(r);
        diag.kurtosis = kurtosis(r);
        diag.p_lilliefors = try_lilliefors_test(r);

        fprintf(fid, '===== RESIDUALS (conditional, Pearson) =====\n');
        fprintf(fid, 'Skewness: %.3f\nKurtosis: %.3f (normal = 3)\nLilliefors p: %.4g\n', ...
            diag.skewness, diag.kurtosis, diag.p_lilliefors);

        if ~isempty(qqPng)
            fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 420 400]);
            qqplot(r);
            title(sprintf('%s | QQ of residuals', dvName), 'Interpreter', 'none');
            saveas(fig, qqPng);
            close(fig);
        end

    catch ME
        fprintf(fid, 'Model failed.\n');
        fprintf(fid, '%s\n', ME.message);
    end

    fclose(fid);
end
