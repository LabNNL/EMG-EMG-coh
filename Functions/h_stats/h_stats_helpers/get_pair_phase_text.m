function txt = get_pair_phase_text(pairName, C)

    txt = 'POI: unknown';

    try
        if ~isfield(C, 'physio') || ~isfield(C.physio, 'phase_windows_pct')
            return;
        end

        if ~isfield(C.physio.phase_windows_pct, char(string(pairName)))
            return;
        end

        W = C.physio.phase_windows_pct.(char(string(pairName)));
        s = W.start_pct;
        e = W.end_pct;

        if s <= e
            txt = sprintf('POI: %d–%d%% gait cycle', s, e);
        else
            txt = sprintf('POI: %d–100%% + 0–%d%% gait cycle', s, e);
        end
    catch
        txt = 'POI: unknown';
    end
end