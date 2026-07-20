function pp_save_preproc_concat_plot(PNG_DIR_PREPROC, subjID, cond, leg, mf, y)
mus = erase(mf, '_Concat');

fig = figure('Visible','off','Color','w');
plot(y, 'LineWidth', 0.5);
title(sprintf('EMG Prétraité Concaténé | %s | %s | %s | %s', subjID, cond, leg, mus), 'Interpreter','none');
xlabel('Samples'); ylabel('Amplitude');
saveas(fig, fullfile(PNG_DIR_PREPROC, sprintf('%s_%s_%s_%s.png', subjID, cond, leg, mus)));
close(fig);
end