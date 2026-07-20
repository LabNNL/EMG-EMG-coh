function [T, CLUSTER_RESULTS] = apply_manual_cluster_keep_map(T, CLUSTER_RESULTS, DC_P, KEEP)

    n = height(T);

    T.cluster_good = false(n,1);
    T.cluster_keep_defined = false(n,1);
    T.cluster_decision_reason = strings(n,1);

    % Which grouping variable determines the mapping?
    if DC_P.groupVar == "ALL"
        groupValues = repmat("ALL", n, 1);
    else
        groupValues = string(T.(DC_P.groupVar));
    end

    for i = 1:n
        if ~T.cluster_valid(i) || isnan(T.cluster_id(i))
            T.cluster_good(i) = false;
            T.cluster_keep_defined(i) = false;
            T.cluster_decision_reason(i) = "not_clustered";
            continue;
        end

        g = char(groupValues(i));

        if isfield(KEEP, matlab.lang.makeValidName(g))
            keepClusters = KEEP.(matlab.lang.makeValidName(g));
            T.cluster_good(i) = ismember(T.cluster_id(i), keepClusters);
            T.cluster_keep_defined(i) = true;

            if T.cluster_good(i)
                T.cluster_decision_reason(i) = "cluster_in_keep_list";
            else
                T.cluster_decision_reason(i) = "cluster_not_in_keep_list";
            end
        else
            T.cluster_good(i) = false;
            T.cluster_keep_defined(i) = false;
            T.cluster_decision_reason(i) = "no_keep_rule_for_group";
        end
    end

    % Save mapping into CLUSTER_RESULTS too
    CLUSTER_RESULTS.manual_keep_map = KEEP;
    CLUSTER_RESULTS.manual_keep_groupVar = DC_P.groupVar;

    % Optional summary table
    groups = unique(groupValues);
    summaryRows = table();

    for ig = 1:numel(groups)
        g = groups(ig);
        idxg = groupValues == g & T.cluster_valid;

        if ~any(idxg), continue; end

        clusters = unique(T.cluster_id(idxg));
        clusters = clusters(~isnan(clusters));

        for ic = 1:numel(clusters)
            c = clusters(ic);
            idxc = idxg & T.cluster_id == c;

            row = table( ...
                string(g), c, sum(idxc), sum(T.cluster_good(idxc)), ...
                'VariableNames', {'group_value','cluster_id','n_bursts','n_marked_good'});

            summaryRows = [summaryRows; row];
        end
    end

    CLUSTER_RESULTS.cluster_keep_summary = summaryRows;
end
