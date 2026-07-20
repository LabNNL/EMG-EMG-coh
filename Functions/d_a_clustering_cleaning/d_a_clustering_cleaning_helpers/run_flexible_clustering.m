function [CLUSTER_RESULTS, T_out] = run_flexible_clustering(T, CL)

    T_out = T;
    T_out.cluster_group   = strings(height(T_out),1);
    T_out.cluster_id      = nan(height(T_out),1);
    T_out.cluster_k_best  = nan(height(T_out),1);
    T_out.cluster_valid   = false(height(T_out),1);

    validRows = true(height(T),1);
    for iF = 1:numel(CL.featureVars)
        validRows = validRows & ~isnan(T.(CL.featureVars{iF}));
    end

    if CL.groupVar == "ALL"
        groupLabels = "ALL";
        groupIndexList = {find(validRows)};
    else
        allGroups = unique(T.(CL.groupVar));
        allGroups(ismissing(allGroups)) = [];
        groupLabels = sort(allGroups);
        groupIndexList = cell(numel(groupLabels),1);

        for g = 1:numel(groupLabels)
            groupIndexList{g} = find(validRows & T.(CL.groupVar) == groupLabels(g));
        end
    end

    CLUSTER_RESULTS = struct();
    CLUSTER_RESULTS.meta.groupVar            = CL.groupVar;
    CLUSTER_RESULTS.meta.featureVars         = CL.featureVars;
    CLUSTER_RESULTS.meta.kList               = CL.kList;
    CLUSTER_RESULTS.meta.replicates          = CL.replicates;
    CLUSTER_RESULTS.meta.distance            = CL.distance;
    CLUSTER_RESULTS.meta.k_selection_method  = CL.k_selection_method;

    for g = 1:numel(groupLabels)
        thisGroup = groupLabels(g);
        idxRows   = groupIndexList{g};

        fprintf('\n=== Clustering group: %s ===\n', string(thisGroup));
        fprintf('N bursts: %d\n', numel(idxRows));

        if numel(idxRows) < CL.minBurstsPerGroup
            fprintf('Skipping %s (too few bursts)\n', string(thisGroup));
            res = struct();
            res.group_label = thisGroup;
            res.n_bursts = numel(idxRows);
            res.skipped = true;
            res.reason = sprintf('Too few bursts (< %d)', CL.minBurstsPerGroup);
            CLUSTER_RESULTS.groups.(make_valid_fieldname(thisGroup)) = res;
            continue;
        end

        X = zeros(numel(idxRows), numel(CL.featureVars));
        for iF = 1:numel(CL.featureVars)
            X(:,iF) = T.(CL.featureVars{iF})(idxRows);
        end

        Xz = zscore(X);
        % Apply feature weights after z-scoring
        if isfield(CL, 'featureWeights') && ~isempty(CL.featureWeights)
            for iF = 1:numel(CL.featureVars)
                feat = CL.featureVars{iF};
                if isfield(CL.featureWeights, feat)
                    Xz(:,iF) = Xz(:,iF) * CL.featureWeights.(feat);
                end
            end
        end

        silhouette_mean   = nan(numel(CL.kList),1);
        calinski_harabasz = nan(numel(CL.kList),1);
        davies_bouldin    = nan(numel(CL.kList),1);
        wcss              = nan(numel(CL.kList),1);

        cluster_assignments = cell(numel(CL.kList),1);
        centroids = cell(numel(CL.kList),1);

        for ik = 1:numel(CL.kList)
            k = CL.kList(ik);

            [idx_k, C_k, sumd] = kmeans(Xz, k, ...
                'Replicates', CL.replicates, ...
                'Distance', CL.distance, ...
                'MaxIter', CL.maxIter, ...
                'Display', 'final');

            cluster_assignments{ik} = idx_k;
            centroids{ik} = C_k;
            wcss(ik) = sum(sumd);

            if numel(idx_k) > CL.maxSilhouetteN
                idx_sub = randperm(numel(idx_k), CL.maxSilhouetteN);
            else
                idx_sub = 1:numel(idx_k);
            end

            try
                silVals = silhouette(Xz(idx_sub,:), idx_k(idx_sub), CL.distance);
                silhouette_mean(ik) = mean(silVals);
            catch
                silhouette_mean(ik) = NaN;
            end

            try
                calinski_harabasz(ik) = compute_calinski_harabasz(Xz, idx_k, C_k);
            catch
                calinski_harabasz(ik) = NaN;
            end

            try
                davies_bouldin(ik) = compute_davies_bouldin(Xz, idx_k, C_k);
            catch
                davies_bouldin(ik) = NaN;
            end

            fprintf(['  k = %d | silhouette = %.4f | CH = %.4f | DB = %.4f | WCSS = %.4f\n'], ...
                k, silhouette_mean(ik), calinski_harabasz(ik), davies_bouldin(ik), wcss(ik));
        end

        % Choose best k according to config
        switch string(CL.k_selection_method)
            case "silhouette"
                [~, bestIdx] = max(silhouette_mean);

            case "calinski_harabasz"
                [~, bestIdx] = max(calinski_harabasz);

            case "davies_bouldin"
                [~, bestIdx] = min(davies_bouldin);

            case "manual"
                assert(isfield(CL, 'manual_k') && ~isnan(CL.manual_k), ...
                    'manual_k must be set when k_selection_method = "manual".');
                bestIdx = find(CL.kList == CL.manual_k, 1);
                assert(~isempty(bestIdx), 'manual_k = %d is not in CL.kList.', CL.manual_k);
            case "elbow"
                % Elbow method on WCSS: find point of maximum curvature
                wcssDiff = diff(wcss);
                wcssDiff2 = diff(wcssDiff);
                [~, idxElbow] = max(abs(wcssDiff2));
                bestIdx = idxElbow + 1;
            case "mixed"
                % rank for all methods, take the highest average rank
                r1 = tiedrank_with_nan(-silhouette_mean);
                r2 = tiedrank_with_nan(-calinski_harabasz);
                r3 = tiedrank_with_nan(davies_bouldin);

                ranks = [r1 r2 r3];
                avgRank = mean(ranks, 2, 'omitnan');
                [~, bestIdx] = min(avgRank);
            otherwise
                error('Unknown k_selection_method: %s', CL.k_selection_method);
        end

        kBest   = CL.kList(bestIdx);
        idxBest = cluster_assignments{bestIdx};
        CBest   = centroids{bestIdx};

        T_out.cluster_group(idxRows)  = string(thisGroup);
        T_out.cluster_id(idxRows)     = idxBest;
        T_out.cluster_k_best(idxRows) = kBest;
        T_out.cluster_valid(idxRows)  = true;

        cluster_summary = table();
        for c = 1:kBest
            idxc = (idxBest == c);
            if ~any(idxc), continue; end

            row = table(string(thisGroup), c, sum(idxc), ...
                'VariableNames', {'group_label','cluster_id','n_bursts'});

            for iF = 1:numel(CL.featureVars)
                feat = CL.featureVars{iF};
                row.([feat '_mean'])   = mean(X(idxc,iF), 'omitnan');
                row.([feat '_median']) = median(X(idxc,iF), 'omitnan');
                row.([feat '_std'])    = std(X(idxc,iF), 'omitnan');
            end

            cluster_summary = [cluster_summary; row];
        end

        res = struct();
        res.group_label          = thisGroup;
        res.n_bursts             = numel(idxRows);
        res.skipped              = false;
        res.k_values             = CL.kList;
        res.silhouette_mean      = silhouette_mean;
        res.calinski_harabasz    = calinski_harabasz;
        res.davies_bouldin       = davies_bouldin;
        res.wcss                 = wcss;
        res.best_k               = kBest;
        res.best_cluster_labels  = idxBest;
        res.best_centroids_z     = CBest;
        res.featureVars          = CL.featureVars;
        res.row_indices_in_table = idxRows;
        res.cluster_summary      = cluster_summary;

        CLUSTER_RESULTS.groups.(make_valid_fieldname(thisGroup)) = res;
    end
end

function ch = compute_calinski_harabasz(X, idx, C)
    n = size(X,1);
    k = size(C,1);
    grandMean = mean(X,1);

    B = 0;
    W = 0;

    for c = 1:k
        Xc = X(idx == c, :);
        nc = size(Xc,1);
        if nc == 0, continue; end

        mu_c = mean(Xc,1);
        B = B + nc * sum((mu_c - grandMean).^2);
        W = W + sum(sum((Xc - mu_c).^2));
    end

    ch = (B / (k - 1)) / (W / (n - k));
end


function db = compute_davies_bouldin(X, idx, C)
    k = size(C,1);
    S = nan(k,1);

    for c = 1:k
        Xc = X(idx == c, :);
        if isempty(Xc)
            S(c) = NaN;
        else
            d = sqrt(sum((Xc - C(c,:)).^2, 2));
            S(c) = mean(d, 'omitnan');
        end
    end

    M = squareform(pdist(C));
    R = nan(k,k);

    for i = 1:k
        for j = 1:k
            if i ~= j
                R(i,j) = (S(i) + S(j)) / M(i,j);
            end
        end
    end

    db = mean(max(R, [], 2, 'omitnan'), 'omitnan');
end


function out = make_valid_fieldname(x)
    out = matlab.lang.makeValidName(char(string(x)));
end

function r = tiedrank_with_nan(x)
    r = nan(size(x));
    ok = ~isnan(x);
    if any(ok)
        r(ok) = tiedrank(x(ok));
    end
end