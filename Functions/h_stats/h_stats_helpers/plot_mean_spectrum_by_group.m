function [legendHandles, legendLabels] = plot_mean_spectrum_by_group(ax, T, groupVar, groupLevels, colorFun, freqRef, HS)

    legendHandles = gobjects(0);
    legendLabels = {};

    if isempty(T)
        return;
    end

    for ig = 1:numel(groupLevels)
        gName = groupLevels{ig};
        Tg = T(T.(groupVar) == gName, :);

        if isempty(Tg)
            continue;
        end

        if ismember('subject', Tg.Properties.VariableNames)
            nRows = height(Tg);
            nSubjects = numel(unique(Tg.subject));

            if strcmpi(string(groupVar), "age_group") && nRows > nSubjects
                warning(['plot_mean_spectrum_by_group: group %s has %d rows but only %d unique subjects. ', 'This suggests repeated condition-level curves are being plotted for age-group spectrum. ', 'Use average_spectrum_conditions before age plotting.'], string(gName), nRows, nSubjects);
            end
        end

        X = collect_curve_matrix_from_table(Tg.Spectrum);
        if isempty(X)
            continue;
        end

        X = double(X);

        nFreq = min(numel(freqRef), size(X,2));
        x = freqRef(1:nFreq);
        X = X(:,1:nFreq);

        col = colorFun(gName);

        % ---------- individual curves ----------
        if isfield(HS, 'show_individual_lines') && HS.show_individual_lines
            a = 0.18;
            if isfield(HS, 'individual_line_alpha')
                a = HS.individual_line_alpha;
            end

            lw = 0.6;
            if isfield(HS, 'individual_line_width')
                lw = HS.individual_line_width;
            end

            for ii = 1:size(X,1)
                hInd = plot(ax, x, X(ii,:), 'Color', [col a], 'LineWidth', lw, 'HandleVisibility', 'off');
            end
        end

        % ---------- group mean ----------
        mu = mean(X, 1, 'omitnan');
        sem = std(X, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(X), 1));

        % ---------- SEM shading ----------
        if isfield(HS, 'show_sem') && HS.show_sem
            patch(ax, [x(:)' fliplr(x(:)')], [mu-sem fliplr(mu+sem)], col, 'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end

        nSubjects = numel(unique(Tg.subject));
        label = sprintf('%s (n=%d)', char(string(gName)), nSubjects);
        h = plot(ax, x, mu, 'Color', col, 'LineWidth', 2.5, 'DisplayName', label);

        legendHandles(end+1) = h; %#ok<AGROW>
        legendLabels{end+1} = label; %#ok<AGROW>
    end
end
