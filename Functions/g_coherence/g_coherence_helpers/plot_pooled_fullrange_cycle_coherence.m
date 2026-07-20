function plot_pooled_fullrange_cycle_coherence(COHERENCE_RESULTS, outDir, nBins)

    if nargin < 3 || isempty(nBins)
        nBins = 20;
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    entries = {};
    subjFields = fieldnames(COHERENCE_RESULTS);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        condFields = fieldnames(COHERENCE_RESULTS.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};
            legFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};
                pairFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};

                    R = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
                    if isempty(R) || ~isfield(R, 'CycleBandCoherence'), continue; end
                    C = R.CycleBandCoherence;
                    if ~isfield(C, 'FullRange') || all(isnan(C.FullRange)), continue; end

                    entries(end+1,:) = {subjID, cond, leg, pairName}; %#ok<AGROW>
                end
            end
        end
    end

    if isempty(entries)
        fprintf('No FullRange cycle coherence found.\n');
        return;
    end

    M = nan(size(entries,1), nBins);
    xbin = linspace(0,100,nBins);

    outer_pos_left  = nan(size(entries,1),1);
    outer_pos_right = nan(size(entries,1),1);
    retained_outer_left  = nan(size(entries,1),1);
    retained_outer_right = nan(size(entries,1),1);

    for iE = 1:size(entries,1)
        subjID = entries{iE,1};
        cond   = entries{iE,2};
        leg    = entries{iE,3};
        pairName = entries{iE,4};

        R = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
        C = R.CycleBandCoherence;

        vals = C.FullRange(:);
        nCyc = numel(vals);
        if nCyc < 3, continue; end

        relPos = linspace(0,100,nCyc)';
        M(iE,:) = interp1(relPos, vals, xbin, 'linear', NaN);

        idx = find(C.mask_real_outer(:));
        if numel(idx) >= 2
            outer_pos_left(iE)  = relPos(idx(1));
            outer_pos_right(iE) = relPos(idx(end));
        end

        idx = find(C.mask_analysis_outer(:));
        if numel(idx) >= 2
            retained_outer_left(iE)  = relPos(idx(1));
            retained_outer_right(iE) = relPos(idx(end));
        end
    end

    mu  = mean(M,1,'omitnan');
    sd  = std(M,0,1,'omitnan');
    n   = sum(~isnan(M),1);
    sem = sd ./ max(sqrt(n),1);

    fig = figure('Visible','off','Color','w','Position',[100 100 1000 500]); hold on;

    for i = 1:size(M,1)
        row = M(i,:);
        if all(isnan(row)), continue; end
        plot(xbin, row, '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.8);
    end

    patch([xbin fliplr(xbin)], [mu-sem fliplr(mu+sem)], [0.3 0.3 0.3], ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none');

    plot(xbin, mu, 'k-', 'LineWidth', 2.5);

    if any(isfinite(outer_pos_left))
        xline(mean(outer_pos_left,'omitnan'), '--', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.4);
    end
    if any(isfinite(outer_pos_right))
        xline(mean(outer_pos_right,'omitnan'), '--', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.4);
    end
    if any(isfinite(retained_outer_left))
        xline(mean(retained_outer_left,'omitnan'), ':', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.4);
    end
    if any(isfinite(retained_outer_right))
        xline(mean(retained_outer_right,'omitnan'), ':', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.4);
    end

    ylim([0 1]);
    xlim([0 100]);
    xlabel('Relative cycle position in concatenated signal (%)');
    ylabel('Full-range cycle coherence');
    title(sprintf('Pooled full-range cycle coherence across signals (n=%d)', size(entries,1)));
    grid on; box on;

    saveas(fig, fullfile(outDir, 'POOLED_FULLRANGE_CYCLE_COHERENCE.png'));
    close(fig);
end

