function p = get_term_pvalue_from_lme_formula(T, formula, termName)

    p = NaN;

    try

        lme = fitlme(T, formula);
        A = anova(lme);

        termStrings = string(cellstr(A.Term));
        pValues = double(A.pValue);

        target = normalize_term_name(termName);
        termNorm = strings(size(termStrings));

        for i = 1:numel(termStrings)
            termNorm(i) = normalize_term_name(termStrings(i));
        end

        idx = find(termNorm == target, 1, 'first');
        if ~isempty(idx)
            p = pValues(idx);
        end
    catch
        p = NaN;
    end
end

function termOut = normalize_term_name(termIn)
    termIn = string(strtrim(termIn));
    if contains(termIn, ":")
        parts = split(termIn, ":");
        parts = sort(strtrim(parts));
        termOut = strjoin(parts, ":");
    else
        termOut = termIn;
    end
end