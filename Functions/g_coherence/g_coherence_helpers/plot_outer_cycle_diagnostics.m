function plot_outer_cycle_diagnostics(R, outDir, freq_range)

    Freq = R.Freq;

    fig = figure('Visible','off','Color','w','Position',[100 100 1200 500]);

    % ----- Spectra comparison -----
    subplot(1,2,1); hold on;
    plot(Freq, R.mean_real_outer_spectrum, 'LineWidth', 1.8, 'DisplayName', ...
        sprintf('Original outer cycles (n=%d)', R.n_cycles_real_outer));
    plot(Freq, R.mean_analysis_outer_spectrum, 'LineWidth', 1.8, 'DisplayName', ...
        sprintf('Retained outer cycles (n=%d)', R.n_cycles_analysis_outer));
    plot(Freq, R.mean_analysis_middle_spectrum, 'LineWidth', 1.8, 'DisplayName', ...
        sprintf('Retained middle cycles (n=%d)', R.n_cycles_analysis_middle));

    xlim(freq_range);
    ylim([0 1]);
    xlabel('Frequency (Hz)');
    ylabel('Coherence');
    title('Mean spectra comparison');
    box on; grid on;
    legend('Location','best');

    % ----- Scalar summary -----
    subplot(1,2,2);
    vals = [R.diag_full_mean_real_outer, ...
            R.diag_full_mean_analysis_outer, ...
            R.diag_full_mean_analysis_middle];
    bar(vals);
    set(gca, 'XTick', 1:3, 'XTickLabel', {'Orig outer','Retained outer','Retained middle'});
    ylabel('Mean coherence');
    title('Full-range mean coherence');
    box on; grid on;

    sgtitle(sprintf('%s | %s | %s | %s | outer-cycle diagnostics', ...
        R.subject, R.condition, R.leg, R.pair_name), 'Interpreter','none');

    fname = sprintf('outer_cycle_diag__%s__%s__%s__%s.png', ...
        R.subject, R.condition, R.leg, R.pair_name);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end