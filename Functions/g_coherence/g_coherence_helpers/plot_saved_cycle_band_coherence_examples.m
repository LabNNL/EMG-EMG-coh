function plot_saved_cycle_band_coherence_examples(COHERENCE_RESULTS, outDir, maxPlots)

    if nargin < 2 || isempty(outDir)
        error('Need COHERENCE_RESULTS and outDir.');
    end
    if nargin < 3 || isempty(maxPlots)
        maxPlots = 10;
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
                    if isempty(R) || ~isfield(R, 'CycleBandCoherence')
                        continue;
                    end

                    C = R.CycleBandCoherence;
                    bandNames = cycle_band_names(C);
                    if isempty(bandNames) || all(cellfun(@(b) all(isnan(C.(b))), bandNames))
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

    rng('shuffle');
    order = randperm(size(entries,1));
    nToPlot = min(maxPlots, numel(order));

    nMade = 0;

    for iE = 1:nToPlot
        row = order(iE);

        subjID = entries{row,1};
        cond   = entries{row,2};
        leg    = entries{row,3};
        pairName = entries{row,4};

        R = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
        C = R.CycleBandCoherence;

        cyc = C.cycle_number(:);
        bandNames = cycle_band_names(C);

        mask_analysis        = logical(C.analysis_cycle_mask(:));
        mask_real_outer      = logical(C.mask_real_outer(:));
        mask_analysis_outer  = logical(C.mask_analysis_outer(:));
        mask_analysis_middle = logical(C.mask_analysis_middle(:));

        fig = figure('Visible','off','Color','w','Position',[100 100 1200 900]);

        for ib = 1:numel(bandNames)
            plot_one_band_cycle_panel(cyc, C.(bandNames{ib})(:), mask_analysis, mask_real_outer, mask_analysis_outer, mask_analysis_middle, ...
                bandNames{ib}, subjID, cond, leg, pairName, ib, numel(bandNames));
        end

        fname = sprintf('CYCLE_BAND_COH__%s__%s__%s__%s.png', subjID, cond, leg, pairName);
        fname = regexprep(fname, '[^\w\.-]', '_');

        saveas(fig, fullfile(outDir, fname));
        close(fig);

        nMade = nMade + 1;
    end

    fprintf('Saved %d cycle-band coherence QC plot(s) in:\n%s\n', nMade, outDir);
end

function plot_one_band_cycle_panel(cyc, vals, mask_analysis, mask_real_outer, mask_analysis_outer, mask_analysis_middle, ...
    bandLabel, subjID, cond, leg, pairName, panelIdx, nPanels)

    subplot(nPanels,1,panelIdx); hold on;

    % all cycles faint
    plot(cyc, vals, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1);
    plot(cyc, vals, 'o', 'Color', [0.8 0.8 0.8], ...
        'MarkerFaceColor', [0.8 0.8 0.8], 'MarkerSize', 4);

    % smoothed line over included cycles only
    vals_incl = vals;
    vals_incl(~mask_analysis) = NaN;
    vals_smooth = moving_average_ignore_nan(vals_incl, 3);
    plot(cyc, vals_smooth, '-', 'Color', [0 0 0], 'LineWidth', 2);

    % excluded cycles
    idx_excl = ~mask_analysis;
    if any(idx_excl)
        plot(cyc(idx_excl), vals(idx_excl), 'x', ...
            'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'MarkerSize', 8);
    end

    % original outer
    if any(mask_real_outer)
        plot(cyc(mask_real_outer), vals(mask_real_outer), 'o', ...
            'Color', [0 0.4470 0.7410], ...
            'MarkerFaceColor', [0 0.4470 0.7410], ...
            'MarkerSize', 8);
    end

    % retained outer
    if any(mask_analysis_outer)
        plot(cyc(mask_analysis_outer), vals(mask_analysis_outer), 's', ...
            'Color', [0.8500 0.3250 0.0980], ...
            'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'MarkerSize', 8);
    end

    % retained middle
    if any(mask_analysis_middle)
        plot(cyc(mask_analysis_middle), vals(mask_analysis_middle), 'o', ...
            'Color', [0.2 0.2 0.2], ...
            'MarkerFaceColor', [0.2 0.2 0.2], ...
            'MarkerSize', 5);
    end

    ylim([0 1]);
    xlim([min(cyc)-0.5, max(cyc)+0.5]);
    ylabel(sprintf('%s coherence', bandLabel));
    grid on;
    box on;

    if panelIdx == 1
        title(sprintf('%s | %s | %s | %s | cycle-wise band coherence', ...
            subjID, cond, leg, pairName), 'Interpreter', 'none');
        legend({'All cycles','All cycles','Smoothed included','Excluded','Original outer','Retained outer','Retained middle'}, ...
            'Location', 'best');
    end

    if panelIdx == 3
        xlabel('Cycle number');
    end
end

function y = moving_average_ignore_nan(x, win)

    x = x(:);
    y = nan(size(x));

    n = numel(x);
    halfw = floor(win/2);

    for i = 1:n
        i1 = max(1, i-halfw);
        i2 = min(n, i+halfw);
        seg = x(i1:i2);
        y(i) = mean(seg, 'omitnan');
    end
end

function bandNames = cycle_band_names(C)
% The per-band fields of R.CycleBandCoherence (one per configured band)
    bandNames = setdiff(fieldnames(C), {'cycle_number','FullRange','analysis_cycle_mask', ...
        'mask_real_outer','mask_analysis_outer','mask_analysis_middle'}, 'stable');
end
