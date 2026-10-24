function st = get_lme_term_stats(lme, HC, termName)
% F test of one model term (anova with HC.lme.df_method, default
% 'satterthwaite') plus, for a term carried by a single coefficient (e.g. a
% continuous covariate), its estimate, SE and 95% CI.
% Interaction terms match in any order ('AgeYears_z:condition' = 'condition:AgeYears_z').

    dfMethod = 'satterthwaite';
    if isfield(HC, 'lme') && isfield(HC.lme, 'df_method'), dfMethod = HC.lme.df_method; end

    st = struct('found', false, 'F', NaN, 'df1', NaN, 'df2', NaN, 'p', NaN, ...
        'estimate', NaN, 'se', NaN, 'ci_low', NaN, 'ci_high', NaN, 'df_method', string(dfMethod));

    A = anova(lme, 'DFMethod', dfMethod);
    target = normalize_term_name(termName);
    terms = string(cellstr(A.Term));
    idx = find(arrayfun(@normalize_term_name, terms) == target, 1);
    if isempty(idx)
        return;
    end
    st.found = true;
    st.F   = double(A.FStat(idx));
    st.df1 = double(A.DF1(idx));
    st.df2 = double(A.DF2(idx));
    st.p   = double(A.pValue(idx));

    [~, ~, FE] = fixedEffects(lme, 'DFMethod', dfMethod);
    names = arrayfun(@normalize_term_name, string(FE.Name));
    k = find(names == target, 1);
    if ~isempty(k)
        st.estimate = FE.Estimate(k);
        st.se       = FE.SE(k);
        st.ci_low   = FE.Lower(k);
        st.ci_high  = FE.Upper(k);
    end
end

function termOut = normalize_term_name(termIn)
    termIn = string(strtrim(termIn));
    if contains(termIn, ":")
        parts = sort(strtrim(split(termIn, ":")));
        termOut = strjoin(parts, ":");
    else
        termOut = termIn;
    end
end
