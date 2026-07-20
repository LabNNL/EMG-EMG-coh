function plot_burst_qc_signal(subjID, cond, leg, mf, fs, x, x_env, bursts_idx, burst_keep, burst_reason, outDir, C)

fig = figure('Visible','off','Color','w','Position',[100 100 1400 750]);
t = (0:numel(x)-1)/fs;

%% ===================== TOP: signal + shaded bursts =====================
subplot(2,1,1);
plot(t, x, 'k', 'LineWidth', 0.8); hold on;
if ~isempty(x_env)
    plot(t, x_env, 'b', 'LineWidth', 1);
end
yl = ylim;

for iB = 1:size(bursts_idx,1)
    x1 = (bursts_idx(iB,1)-1)/fs;
    x2 = (bursts_idx(iB,2)-1)/fs;

    fc = get_reason_color_from_config(burst_keep(iB), burst_reason(iB), C);

    patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], fc, ...
        'EdgeColor','none', 'FaceAlpha', C.plotting.AlphaTransparency);

    if ~burst_keep(iB)
        xm = (x1 + x2)/2;
        txt = short_reason_label(burst_reason(iB));
        text(xm, yl(2) - 0.05*(yl(2)-yl(1)), txt, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','top', ...
            'FontSize',8, ...
            'Interpreter','none');
    end
end

uistack(findobj(gca,'Type','line'),'top');
title(sprintf('%s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

%% ===================== BOTTOM: decision bar =====================
subplot(2,1,2);
hold on;
ylim([-0.2 1.2]);
xlim([t(1) t(end)]);

for iB = 1:size(bursts_idx,1)
    x1 = (bursts_idx(iB,1)-1)/fs;
    x2 = (bursts_idx(iB,2)-1)/fs;
    yv = double(burst_keep(iB));

    c = get_reason_color_from_config(burst_keep(iB), burst_reason(iB), C);
    plot([x1 x2], [yv yv], 'LineWidth', 8, 'Color', c);

    if ~burst_keep(iB)
        xm = (x1 + x2)/2;
        txt = short_reason_label(burst_reason(iB));
        text(xm, yv + 0.08, txt, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'FontSize',8, ...
            'Interpreter','none');
    end
end

yticks([0 1]);
yticklabels({'reject','keep'});
xlabel('Time (s)');
ylabel('Decision');
title('Burst-level decision (color-coded by rejection reason)');
grid on;

nReject = sum(~burst_keep);
nKeep   = sum(burst_keep);

sgtitle(sprintf('%s | kept: %d | rejected: %d / %d', ...
    mf, nKeep, nReject, numel(burst_keep)), 'Interpreter','none');

fname = sprintf('BurstQC_%s_%s_%s_%s.png', subjID, cond, leg, mf);
saveas(fig, fullfile(outDir, fname));
close(fig);
end

function c = get_reason_color_from_config(isKeep, reason, C)

if isKeep
    c = C.plotting.colors.include;
    return;
end

r = string(reason);

if contains(r, "signal_fail")
    c = C.plotting.colors.reason.signal_fail;
elseif contains(r, "bad_bounds")
    c = C.plotting.colors.reason.bad_bounds;
elseif contains(r, "spike_global")
    c = C.plotting.colors.reason.spike;
elseif contains(r, "spike_1")
    c = C.plotting.colors.reason.spike;
elseif contains(r, "spike_2")
    c = C.plotting.colors.reason.spike;
elseif contains(r, "plateau")
    c = C.plotting.colors.reason.plateau;
elseif contains(r, "abs_amp")
    c = C.plotting.colors.reason.abs_amp;
elseif contains(r, "medfreq")
    c = C.plotting.colors.reason.medfreq;
elseif contains(r, "spec")
    c = C.plotting.colors.reason.spec;
elseif contains(r, "too_short")
    c = C.plotting.colors.reason.too_short;
elseif contains(r, "too_long")
    c = C.plotting.colors.reason.too_long;
elseif contains(r, "flatline")
    c = C.plotting.colors.reason.flatline;
else
    c = C.plotting.colors.reason.other;
end
end

%% ===================== HELPER: short label =====================
function txt = short_reason_label(reason)

r = string(reason);

if r == "ok"
    txt = "";
    return;
end

parts = split(r, "+");
parts = parts(strlength(parts) > 0);

shortParts = strings(size(parts));

for i = 1:numel(parts)
    p = parts(i);

    if p == "spike_1"
        shortParts(i) = "spike1";
    elseif p == "spike_2"
        shortParts(i) = "spike2";
    elseif p == "spike_global"
        shortParts(i) = "spikeG";
    elseif p == "plateau"
        shortParts(i) = "plat";
    elseif p == "spec"
        shortParts(i) = "spec";
    elseif p == "medfreq"
        shortParts(i) = "freq";
    elseif p == "abs_amp"
        shortParts(i) = "amp";
    elseif p == "too_short"
        shortParts(i) = "short";
    elseif p == "too_long"
        shortParts(i) = "long";
    elseif p == "bad_bounds"
        shortParts(i) = "bounds";
    elseif p == "signal_fail"
        shortParts(i) = "sig";
    else
        shortParts(i) = p;
    end
end

txt = strjoin(cellstr(shortParts), newline);
end