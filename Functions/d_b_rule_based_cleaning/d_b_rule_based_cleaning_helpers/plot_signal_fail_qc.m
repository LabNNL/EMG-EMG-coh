function plot_signal_fail_qc(subjID, cond, leg, mf, fs, x, x_env, sig_reason, Msig, outDir, C)

fig = figure('Visible','off','Color','w','Position',[100 100 1400 700]);
t = (0:numel(x)-1)/fs;

subplot(2,1,1);
plot(t, x, 'k', 'LineWidth', 0.8); hold on;
if ~isempty(x_env)
    plot(t, x_env, 'b', 'LineWidth', 1);
end
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('%s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');
grid on;

subplot(2,1,2);
axis off;

txt = {
    sprintf('Signal status: FAIL')
    sprintf('Reason: %s', sig_reason)
};

% Add useful metrics if present
if isfield(Msig,'flatline_frac') && ~isempty(Msig.flatline_frac)
    txt{end+1} = sprintf('flatline_frac: %.4f', Msig.flatline_frac);
end
if isfield(Msig,'line_ratio') && ~isempty(Msig.line_ratio)
    txt{end+1} = sprintf('line_ratio: %.4f', Msig.line_ratio);
end
if isfield(Msig,'low_over_mid') && ~isempty(Msig.low_over_mid)
    txt{end+1} = sprintf('low_over_mid: %.4f', Msig.low_over_mid);
end
if isfield(Msig,'high_over_mid') && ~isempty(Msig.high_over_mid)
    txt{end+1} = sprintf('high_over_mid: %.4f', Msig.high_over_mid);
end
if isfield(Msig,'p2p') && ~isempty(Msig.p2p)
    txt{end+1} = sprintf('p2p: %.6g', Msig.p2p);
end
if isfield(Msig,'rms') && ~isempty(Msig.rms)
    txt{end+1} = sprintf('rms: %.6g', Msig.rms);
end

text(0.02, 0.95, txt, 'Units','normalized', ...
    'VerticalAlignment','top', 'Interpreter','none', 'FontSize',10);

sgtitle(sprintf('Signal FAIL QC | %s', mf), 'Interpreter','none');

fname = sprintf('SignalFAIL_%s_%s_%s_%s.png', subjID, cond, leg, mf);
saveas(fig, fullfile(outDir, fname));
close(fig);
end