function col = get_exclusion_method_color(methodName, C)

    methodName = string(methodName);
    
    switch methodName
        case "rule_based"
            col = C.plotting.colors.exclude_rule_based;
        case "cluster_based"
            col = C.plotting.colors.exclude_cluster_based;
        case "both"
            if isfield(C.plotting.colors.reason, 'exclude')
                col = C.plotting.colors.reason.exclude;
            else
                col = [0.4 0.4 0.4]; %
            end
        case "signal_fail"
            if isfield(C.plotting.colors.reason, 'signal_fail')
                col = C.plotting.colors.reason.signal_fail;
            else
                col = [0.5 0 0];
            end
        case "other_bad"
            if isfield(C.plotting.colors.reason, 'other')
                col = C.plotting.colors.reason.other;
            else
                col = [0.6 0.6 0.6];
            end
        otherwise
            col = C.plotting.colors.exclude;
    end
end