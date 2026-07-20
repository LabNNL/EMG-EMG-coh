function plot_group_mean_spectra(Gpair, groupVals, groupField, pairName, outDir, freq_range, curveField, C)

    fig = figure('Visible','off','Color','w','Position',[100 100 900 500]);
    hold on;

    for ig = 1:numel(groupVals)
        gv = groupVals(ig);

        idx = false(numel(Gpair),1);
        for k = 1:numel(Gpair)
            idx(k) = (string(Gpair(k).(groupField)) == gv);
        end
        Gsel = Gpair(idx);

        if isempty(Gsel), continue; end

        F = Gsel(1).Freq;
        curves = [];
        for k = 1:numel(Gsel)
            if isfield(Gsel(k), curveField)
                curves = cat(2, curves, Gsel(k).(curveField));
            end
        end

        if isempty(curves)
            continue;
        end
        meanCurve = mean(curves, 2, 'omitnan');

        if strcmp(groupField, 'age_group')
            thisColor = get_age_color(gv, C);
        elseif strcmp(groupField, 'condition')
            thisColor = get_condition_color(gv, C);
        else
            thisColor = [0.3 0.3 0.3];
        end

        plot(F, meanCurve, 'LineWidth', 1.8, 'Color', thisColor, 'DisplayName', sprintf('%s (n=%d)', get_pretty_group_label(gv, groupField), numel(Gsel)));
    end

    xlim(freq_range);
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    ylim([0 1]);
    xlabel('Frequency (Hz)');
    ylabel('Mean coherence');
    if strcmp(curveField, 'MeanFreqCurve_Sig')
        spectrumLabel = 'Significant mean coherence spectrum';
    else
        spectrumLabel = 'Mean coherence spectrum';
    end
    title(sprintf('%s | %s | grouped by %s', spectrumLabel, pairName, strrep(groupField,'_',' ')), ...
        'Interpreter','none');
    legend('Location','best');
    grid on;

    fname = sprintf('GROUP_SPECTRUM__%s__BY_%s.png', pairName, upper(groupField));
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end
