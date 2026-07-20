function method = classify_burst_exclusion_method(burstReason, burstKeep)

    if burstKeep
        method = "kept";
        return;
    end

    s = lower(char(string(burstReason)));

    % ---------- explicit combined bad ----------
    if contains(s, 'rule_based_bad+cluster_bad') || contains(s, 'cluster_bad+rule_based_bad')
        method = "both";
        return;
    end

    % ---------- disagreement cases ----------
    if contains(s, 'disagreement_conservative_rule_based_bad_cluster_good')
        method = "rule_based";
        return;
    end

    if contains(s, 'disagreement_conservative_rule_based_good_cluster_bad')
        method = "cluster_based";
        return;
    end

    % ---------- generic fallbacks ----------
    hasRuleBad    = contains(s, 'rule_based_bad');
    hasClusterBad = contains(s, 'cluster_bad');

    if hasRuleBad && hasClusterBad
        method = "both";
    elseif hasRuleBad
        method = "rule_based";
    elseif hasClusterBad
        method = "cluster_based";
    elseif contains(s, 'signal_fail') || contains(s, 'signal fail')
        method = "signal_fail";
    elseif strlength(string(burstReason)) == 0
        method = "unknown_bad";
    else
        method = "other_bad";
    end
end