function plot_pooled_cycle_band_coherence(COHERENCE_RESULTS, outDir, nBins)

    if nargin < 2 || isempty(outDir)
        error('Need COHERENCE_RESULTS and outDir.');
    end
    if nargin < 3 || isempty(nBins)
        nBins = 20;
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    entries = {};
    bandNames = {};
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
                    if isempty(R) || ~isfield(R, 'CycleBandCoherence')
                        continue;
                    end

                    C = R.CycleBandCoherence;
                    if isempty(bandNames)
                        bandNames = cycle_band_names(C);
                    end
                    if isempty(bandNames) || all(cellfun(@(b) ~isfield(C, b) || all(isnan(C.(b))), bandNames))
                        continue;
                    end

                    entries(end+1,:) = {subjID, cond, leg, pairName}; %#ok<AGROW>
                end
            end
        end
    end

    if isempty(entries)
        fprintf('No cycle-band coherence diagnostics found.\n');
        return;
    end

    nBands = numel(bandNames);
    band_mat = repmat({nan(size(entries,1), nBins)}, 1, nBands);

    outer_pos_left  = nan(size(entries,1),1);
    outer_pos_right = nan(size(entries,1),1);
    retained_outer_left  = nan(size(entries,1),1);
    retained_outer_right = nan(size(entries,1),1);

    xbin = linspace(0, 100, nBins);

    for iE = 1:size(entries,1)
        subjID = entries{iE,1};
        cond   = entries{iE,2};
        leg    = entries{iE,3};
        pairName = entries{iE,4};

        R = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
        C = R.CycleBandCoherence;

        cyc = C.cycle_number(:);

        nCyc = numel(cyc);
        if nCyc < 3
            continue;
        end

        relPos = linspace(0, 100, nCyc)';

        for ib = 1:nBands
            if isfield(C, bandNames{ib})
                band_mat{ib}(iE,:) = interp1(relPos, C.(bandNames{ib})(:), xbin, 'linear', NaN);
            end
        end

        if isfield(C, 'mask_real_outer')
            idx = find(C.mask_real_outer(:));
            if numel(idx) >= 2
                outer_pos_left(iE)  = relPos(idx(1));
                outer_pos_right(iE) = relPos(idx(end));
            end
        end

        if isfield(C, 'mask_analysis_outer')
            idx = find(C.mask_analysis_outer(:));
            if numel(idx) >= 2
                retained_outer_left(iE)  = relPos(idx(1));
                retained_outer_right(iE) = relPos(idx(end));
            end
        end
    end

    fig = figure('Visible','off','Color','w','Position',[100 100 1100 900]);

    for ib = 1:nBands
        plot_one_pooled_band_panel(band_mat{ib}, xbin, outer_pos_left, outer_pos_right, retained_outer_left, retained_outer_right, bandNames{ib}, ib, nBands);
    end

    sgtitle(sprintf('Pooled cycle-band coherence across signals (n=%d)', size(entries,1)));

    saveas(fig, fullfile(outDir, 'POOLED_CYCLE_BAND_COHERENCE.png'));
    close(fig);

    fprintf('Saved pooled cycle-band coherence plot in:\n%s\n', fullfile(outDir, 'POOLED_CYCLE_BAND_COHERENCE.png'));
end


function plot_one_pooled_band_panel(M, xbin, outer_pos_left, outer_pos_right, retained_outer_left, retained_outer_right, bandLabel, panelIdx, nPanels)

    subplot(nPanels,1,panelIdx); hold on;

    % thin grey individual profiles
    for i = 1:size(M,1)
        row = M(i,:);
        if all(isnan(row)), continue; end
        plot(xbin, row, '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.8);
    end

    mu = mean(M, 1, 'omitnan');
    sd = std(M, 0, 1, 'omitnan');
    n  = sum(~isnan(M), 1);
    sem = sd ./ max(sqrt(n), 1);

    xfill = [xbin, fliplr(xbin)];
    yfill = [mu-sem, fliplr(mu+sem)];
    valid = isfinite(yfill);

    if all(valid)
        patch(xfill, yfill, [0.3 0.3 0.3], ...
            'FaceAlpha', 0.18, 'EdgeColor', 'none');
    end

    plot(xbin, mu, 'k-', 'LineWidth', 2.5);

    % average positions of special cycles
    if any(isfinite(outer_pos_left))
        xline(mean(outer_pos_left, 'omitnan'), '--', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.4);
    end
    if any(isfinite(outer_pos_right))
        xline(mean(outer_pos_right, 'omitnan'), '--', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.4);
    end
    if any(isfinite(retained_outer_left))
        xline(mean(retained_outer_left, 'omitnan'), ':', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.4);
    end
    if any(isfinite(retained_outer_right))
        xline(mean(retained_outer_right, 'omitnan'), ':', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.4);
    end

    ylim([0 1]);
    xlim([0 100]);
    ylabel(sprintf('%s coherence', bandLabel));
    grid on; box on;

    if panelIdx == 1
        title('Mean coherence as a function of relative cycle position');
        legend({'Individual signals','Mean \pm SEM','Grand mean','Orig outer','Orig outer','Retained outer','Retained outer'}, ...
            'Location', 'best');
    end

    if panelIdx == 3
        xlabel('Relative cycle position in concatenated signal (%)');
    end
end
