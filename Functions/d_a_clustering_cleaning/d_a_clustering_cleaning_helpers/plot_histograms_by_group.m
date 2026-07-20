function plot_histograms_by_group(T, featureVars, nbins, outDir, groupVar, groupLabel, C)

    groups = unique(string(T.(groupVar)));
    groups(ismissing(groups) | groups == "") = [];
    groups = groups(:);

    % Use preferred plotting order when available
    switch string(groupVar)
        case "age_group"
            preferredOrder = string(C.plotting.age_order);
        case "condition"
            preferredOrder = string(C.plotting.condition_order);
        case "sex"
            preferredOrder = string(C.plotting.sex_order);
        case "phase"
            preferredOrder = string(C.plotting.phase_order);
        case "band"
            preferredOrder = string(C.plotting.band_order);
        otherwise
            preferredOrder = groups;
    end

    preferredOrder = preferredOrder(:);

    % Keep only groups that are actually present, in preferred order
    groups = preferredOrder(ismember(preferredOrder, groups));

    % If some present groups were not in preferredOrder, append them
    allPresent = unique(string(T.(groupVar)));
    allPresent(ismissing(allPresent) | allPresent == "") = [];
    allPresent = allPresent(:);

    extraGroups = setdiff(allPresent, groups, 'stable');
    groups = [groups; extraGroups];

    nF = numel(featureVars);
    nRows = ceil(nF/3);
    nCols = 3;

    fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1400 900]);

    for i = 1:nF
        subplot(nRows, nCols, i); hold on;
        feat = featureVars{i};

        legendHandles = gobjects(0);
        legendLabels = {};

        for g = 1:numel(groups)
            thisGroup = groups(g);
            idx = string(T.(groupVar)) == thisGroup;
            x = T.(feat)(idx);
            x = x(~isnan(x));
            if isempty(x), continue; end

            thisColor = get_group_color(thisGroup, C);

            h = histogram(x, nbins, ...
                'Normalization', 'probability', ...
                'DisplayStyle', 'stairs', ...
                'LineWidth', 1.8, ...
                'EdgeColor', thisColor);

            legendHandles(end+1) = h; %#ok<AGROW>
            legendLabels{end+1} = prettify_group_label(thisGroup, groupVar); %#ok<AGROW>
        end

        title(strrep(feat, '_', '\_'));
        xlabel(feat);
        ylabel('Probability');
        if ~isempty(legendHandles)
            legend(legendHandles, legendLabels, 'Location', 'best');
        end
        grid on;
    end

    sgtitle(sprintf('Feature distributions by %s', groupLabel));
    fname = sprintf('hist_by_%s.png', groupVar);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end


function thisColor = get_group_color(groupName, C)

    groupName = string(groupName);
    fieldName = matlab.lang.makeValidName(char(groupName));

    if isfield(C, 'plotting') && isfield(C.plotting, 'colors') && ...
            isfield(C.plotting.colors, fieldName)
        thisColor = C.plotting.colors.(fieldName);
    else
        thisColor = [0.2 0.2 0.2]; % fallback dark gray
    end
end

function label = prettify_group_label(groupName, groupVar)

    label = char(string(groupName));

    % Special cleaning for muscles
    if strcmp(string(groupVar), "muscle")
        label = erase(label, "EMG_");
        label = erase(label, "_Concat");

        % nicer muscle names
        label = strrep(label, "TAprox", "TA prox");
        label = strrep(label, "TAdist", "TA dist");
        label = strrep(label, "GMED", "GMED");
        label = strrep(label, "GM", "GM");
        label = strrep(label, "SOL", "SOL");
        label = strrep(label, "RF", "RF");
        label = strrep(label, "ST", "ST");
        label = strrep(label, "VL", "VL");
    else
        % generic cleanup for other group types
        label = strrep(label, "_", " ");
    end
end