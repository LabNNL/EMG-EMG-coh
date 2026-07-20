function plot_one_cycle_subplot(ax, xPct, sig, cyc, cycleNum, musName, phaseIntervals_pct, fs, cycle_duration_sec, C, band)

    hold(ax,'on');

    yL = [min(sig,[],'omitnan'), max(sig,[],'omitnan')];
    if any(~isfinite(yL)) || yL(1) == yL(2)
        yL = [-1 1];
    end

    yPad = 0.05 * (yL(2) - yL(1));
    if yPad == 0
        yPad = 1;
    end
    yL = [yL(1)-yPad, yL(2)+yPad];

    %% ---------- Phase of interest ----------
    for i = 1:size(phaseIntervals_pct,1)
        p1 = phaseIntervals_pct(i,1);
        p2 = phaseIntervals_pct(i,2);

        patch(ax, ...
            [p1 p2 p2 p1], ...
            [yL(1) yL(1) yL(2) yL(2)], ...
            [0.75 0.85 0.95], ...
            'FaceAlpha', 0.20, ...
            'EdgeColor', 'none');

        xline(ax, p1, ':', 'Color', [0.25 0.45 0.85], 'LineWidth', 1.0);
        xline(ax, p2, ':', 'Color', [0.25 0.45 0.85], 'LineWidth', 1.0);
    end

    %% ---------- Get raw and padded bad segments ----------
    rawSegSec = zeros(0,2);
    paddedSegSec = zeros(0,2);
    rawHit = false;
    paddedHit = false;

    if numel(cyc.bad_burst_segments_sec) >= cycleNum && ~isempty(cyc.bad_burst_segments_sec{cycleNum})
        rawSegSec = cyc.bad_burst_segments_sec{cycleNum};
    end

    if strcmpi(string(band), "overall")
        if numel(cyc.bad_burst_segments_padded_sec) >= cycleNum && ~isempty(cyc.bad_burst_segments_padded_sec{cycleNum})
            paddedSegSec = cyc.bad_burst_segments_padded_sec{cycleNum};
        end
        if isfield(cyc, 'has_bad_burst_in_phase_of_interest') && numel(cyc.has_bad_burst_in_phase_of_interest) >= cycleNum
            rawHit = cyc.has_bad_burst_in_phase_of_interest(cycleNum);
        end
        if isfield(cyc, 'has_bad_burst_in_phase_of_interest_padded') && numel(cyc.has_bad_burst_in_phase_of_interest_padded) >= cycleNum
            paddedHit = cyc.has_bad_burst_in_phase_of_interest_padded(cycleNum);
        end
    else
        b = char(string(band));
        if isfield(cyc, 'band_bad_segments_padded_sec') && isfield(cyc.band_bad_segments_padded_sec, b)
            tmp = cyc.band_bad_segments_padded_sec.(b);
            if numel(tmp) >= cycleNum && ~isempty(tmp{cycleNum})
                paddedSegSec = tmp{cycleNum};
            end
        end
        if isfield(cyc, 'has_bad_burst_in_phase_of_interest') && numel(cyc.has_bad_burst_in_phase_of_interest) >= cycleNum
            rawHit = cyc.has_bad_burst_in_phase_of_interest(cycleNum);
        end
        if isfield(cyc, 'band_contaminated') && isfield(cyc.band_contaminated, b)
            tmp = cyc.band_contaminated.(b);
            if numel(tmp) >= cycleNum
                paddedHit = tmp(cycleNum);
            end
        end
    end

    %% ---------- Padded bad burst region ----------
    if ~isempty(paddedSegSec)
        segsPadPct = 100 * paddedSegSec / cycle_duration_sec;

        for i = 1:size(segsPadPct,1)
            p1 = segsPadPct(i,1);
            p2 = segsPadPct(i,2);

            patch(ax, ...
                [p1 p2 p2 p1], ...
                [yL(1) yL(1) yL(2) yL(2)], ...
                [1.0 0.6 0.6], ...
                'FaceAlpha', 0.12, ...
                'EdgeColor', 'none');

            xline(ax, p1, '--', 'Color', [1 0 0], 'LineWidth', 1.2);
            xline(ax, p2, '--', 'Color', [1 0 0], 'LineWidth', 1.2);
        end
    end

    %% ---------- Raw bad burst ----------
    if ~isempty(rawSegSec)
        segsPct = 100 * rawSegSec / cycle_duration_sec;

        for i = 1:size(segsPct,1)
            b1 = segsPct(i,1);
            b2 = segsPct(i,2);

            patch(ax, ...
                [b1 b2 b2 b1], ...
                [yL(1) yL(1) yL(2) yL(2)], ...
                [1 0 0], ...
                'FaceAlpha', 0.28, ...
                'EdgeColor', [0.85 0 0], ...
                'LineWidth', 1.2);
        end
    end

    %% ---------- Signal ----------
    plot(ax, xPct, sig, 'k', 'LineWidth', 1.1);

    %% ---------- Annotation ----------
    if strcmpi(string(band), "overall")
        modeLabel = "Overall";
    else
        modeLabel = char(string(band));
    end

    txt = sprintf('%s | Raw ROI overlap: %d   |   Padded ROI overlap: %d', ...
        modeLabel, rawHit, paddedHit);

    text(ax, 0.01, 0.97, txt, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'w', ...
        'Margin', 2);

    %% ---------- Styling ----------
    xlim(ax, [0 100]);
    ylim(ax, yL);
    xlabel(ax, 'Gait cycle (%)');
    ylabel(ax, 'Amplitude');
    title(ax, char(string(musName)), 'Interpreter','none');
    grid(ax,'on');
    box(ax,'on');

    %% ---------- Legend ----------
    hPhase = patch(nan, nan, [0.75 0.85 0.95], ...
        'FaceAlpha', 0.20, 'EdgeColor', 'none');
    hSignal = plot(nan, nan, 'k', 'LineWidth', 1.1);
    hBad = patch(nan, nan, [1 0 0], ...
        'FaceAlpha', 0.28, 'EdgeColor', [0.85 0 0], 'LineWidth', 1.2);
    hPad = plot(nan, nan, '--', 'Color', [1 0 0], 'LineWidth', 1.2);

    legend(ax, [hPhase hSignal hBad hPad], ...
        {'Phase of interest', 'Signal', 'Bad burst', 'Wavelet-padded exclusion boundary'}, ...
        'Location', 'best');
end