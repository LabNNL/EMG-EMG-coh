function txt = get_exclusion_reason_for_plot(Tsig, i)

    fr = string(Tsig.final_reason(i));

    % ---------- Signal-level visual rejection ----------
    if fr == "visual_signal_3"
        if ismember('signal_visual_reason', Tsig.Properties.VariableNames) && ...
                strlength(string(Tsig.signal_visual_reason(i))) > 0
            txt = "Visual: " + string(Tsig.signal_visual_reason(i));
        elseif ismember('visual_score', Tsig.Properties.VariableNames) && ...
                ~isnan(Tsig.visual_score(i))
            txt = "Visual score = " + string(Tsig.visual_score(i));
        else
            txt = "Visual rejection";
        end
        return;
    end

    % ---------- Signal-level rule-based rejection ----------
    if fr == "rule_based_signal_fail"
        if ismember('signal_rule_based_reason', Tsig.Properties.VariableNames) && ...
                strlength(string(Tsig.signal_rule_based_reason(i))) > 0
            txt = "Signal-level: " + string(Tsig.signal_rule_based_reason(i));
        else
            txt = "Signal-level rule-based fail";
        end
        return;
    end

    % ---------- Burst-level reasons ----------
    rb = "";
    cl = "";

    if ismember('rule_based_reason', Tsig.Properties.VariableNames)
        rb = string(Tsig.rule_based_reason(i));
    end

    if ismember('cluster_reason', Tsig.Properties.VariableNames)
        cl = string(Tsig.cluster_reason(i));
    end

    ruleBad = false;
    cluBad  = false;

    if ismember('rule_based_keep', Tsig.Properties.VariableNames)
        ruleBad = ~logical(Tsig.rule_based_keep(i));
    end

    if ismember('cluster_good', Tsig.Properties.VariableNames)
        cluBad = ~logical(Tsig.cluster_good(i));
    end

    if ruleBad && cluBad
        if strlength(rb) > 0 && strlength(cl) > 0
            txt = "Both: rule=" + rb + " | cluster=" + cl;
        elseif strlength(rb) > 0
            txt = "Both: rule=" + rb;
        elseif strlength(cl) > 0
            txt = "Both: cluster=" + cl;
        else
            txt = "Both bad";
        end
        return;
    end

    if ruleBad
        if strlength(rb) > 0
            txt = "Rule-only: " + rb;
        else
            txt = "Rule-only bad";
        end
        return;
    end

    if cluBad
        if strlength(cl) > 0
            txt = "Cluster-only: " + cl;
        else
            txt = "Cluster-only bad";
        end
        return;
    end

    % ---------- Fallback ----------
    if strlength(fr) > 0
        txt = fr;
    else
        txt = "Excluded";
    end
end

