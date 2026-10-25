function p = get_term_pvalue_from_lme_formula(T, formula, termName, HC)
% p-value of one term of a model fitted with the stage-h settings
% (fit_h_lme, get_lme_term_stats). Refits the model; when the model is
% already fitted, call get_lme_term_stats on it instead.

    if nargin < 4
        C = config_emg();
        HC = C.h_stats;
    end

    p = NaN;
    try
        st = get_lme_term_stats(fit_h_lme(T, formula, HC), HC, termName);
        p = st.p;
    catch
        p = NaN;
    end
end
