function make_cycle_triplet_figure(fig, T, pairName, groupVar, groupOrder, colorFun, C, HC, groupLabel)

    bands = {'Alpha','Beta','Gamma'};
    curveVars = {'Alpha_curve','Beta_curve','Gamma_curve'};

    if isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "sig")
        yLabelTxt = 'Significant coherence';
        spectrumTxt = 'significant coherence';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "equalized")
        yLabelTxt = 'Coherence (equalized number of cycles)';
        spectrumTxt = 'Coherence (equalized number of cycles)';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "sig_equalized")
        yLabelTxt = 'Significant coherence (equalized)';
        spectrumTxt = 'significant coherence (equalized)';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "sig_common_threshold")
        yLabelTxt = 'Significant coherence (common threshold)';
        spectrumTxt = 'significant coherence (common threshold)';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "zcoh_bokil")
        yLabelTxt = 'Z-coherence (Bokil method)';
        spectrumTxt = 'Z-coherence (Bokil method)';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "surrogate_delta")
        yLabelTxt = 'Surrogate delta coherence';
        spectrumTxt = 'Surrogate delta coherence';
    elseif isfield(HC, 'analysis') && isfield(HC.analysis, 'cycle_triplet_source') && strcmpi(string(HC.analysis.cycle_triplet_source), "cycle_bias_corrected")
        yLabelTxt = 'Cycle-bias-corrected coherence';
        spectrumTxt = 'Cycle-bias-corrected coherence';
    else
        yLabelTxt = 'Raw coherence';
        spectrumTxt = 'raw coherence';
    end

    presentGroups = categories(removecats(T.(groupVar)));
    groupLevels = keep_present_in_order(groupOrder, presentGroups);

    for ib = 1:3
        ax = subplot(1,3,ib, 'Parent', fig); hold(ax, 'on');

        curveVar = curveVars{ib};

        poiStart = mean(T.POI_StartPercent, 'omitnan');
        poiEnd   = mean(T.POI_EndPercent, 'omitnan');

        legendHandles = gobjects(0);
        legendLabels = {};

        ymax = -inf;
        ymin = inf;

        for ig = 1:numel(groupLevels)
            gName = groupLevels{ig};
            Tg = T(T.(groupVar) == gName, :);
            if isempty(Tg)
                continue;
            end

            x = unwrap_table_vector_entry(Tg.Time_percent, 1);
            X = collect_curve_matrix_from_table(Tg.(curveVar));

            if isempty(x)
                fprintf('x is empty\n');
                continue;
            end

            if isempty(X)
                fprintf('X is empty\n');
                continue;
            end

            x = x(:)';
            X = double(X);

            nTime = min(numel(x), size(X,2));
            x = x(1:nTime);
            X = X(:,1:nTime);

            mu  = mean(X, 1, 'omitnan');
            sem = std(X, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(X),1));

            mu  = mu(:)';
            sem = sem(:)';

            col = colorFun(gName);

            if HC.plot.cycle_triplets.show_sem
                patch(ax, [x, fliplr(x)], [mu-sem, fliplr(mu+sem)], col, 'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            end

            h = plot(ax, x, mu, 'LineWidth', 2, 'Color', col, 'DisplayName', sprintf('%s (n=%d)', gName, size(X,1)));

            legendHandles(end+1) = h; %#ok<AGROW>
            legendLabels{end+1} = sprintf('%s (n=%d)', gName, size(X,1)); %#ok<AGROW>

            ymax = max(ymax, max(mu+sem, [], 'omitnan'));
            ymin = min(ymin, min(mu-sem, [], 'omitnan'));
        end

        title(ax, bands{ib}, 'Interpreter', 'none');
        xlabel(ax, 'Gait cycle (%)');

        ylabel(ax, yLabelTxt, 'Interpreter', 'none');
        xlim(ax, [0 100]);
        grid(ax, 'on');

        if isfinite(ymin) && isfinite(ymax)
            yr = ymax - ymin;
            if yr <= 0, yr = 0.1; end
            ylim(ax, [ymin - 0.05*yr, ymax + 0.18*yr]);
        end
        apply_shared_coherence_ylim(ax, HC);

        add_poi_patch(ax, poiStart, poiEnd, HC.plot.cycle_triplets.poi_face_alpha);

        if ib == 3 && ~isempty(legendHandles)
            legendAx = axes(fig, 'Position', [0.35 0.01 0.30 0.05], 'Visible', 'off');

            lgd = legend(legendAx, legendHandles, legendLabels, 'Orientation', 'horizontal', 'Interpreter', 'none');

            lgd.Box = 'off';
            lgd.FontSize = 10;
            lgd.ItemTokenSize = [16 10];
            lgd.Units = 'normalized';
            lgd.Position = [0.35 0.01 0.30 0.05];
        end
    end

    phaseTxt = get_pair_phase_text(pairName, C);
    sgtitle(fig, {sprintf('%s | %s over gait cycle by %s', string(pairName), spectrumTxt, lower(groupLabel)), phaseTxt}, 'Interpreter', 'none');
end