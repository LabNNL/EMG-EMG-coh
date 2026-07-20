function poiMeta = get_pair_poi_metadata(pairName, C, nTime)

    poiMeta = struct();
    poiMeta.has_poi = false;
    poiMeta.start_pct = NaN;
    poiMeta.end_pct = NaN;
    poiMeta.indices = [];

    if ~isfield(C, 'physio') || ~isfield(C.physio, 'phase_windows_pct')
        return;
    end

    pairChar = char(string(pairName));

    if ~isfield(C.physio.phase_windows_pct, pairChar)
        return;
    end

    Wpoi = C.physio.phase_windows_pct.(pairChar);

    if ~isfield(Wpoi, 'start_pct') || ~isfield(Wpoi, 'end_pct')
        return;
    end

    start_pct = Wpoi.start_pct;
    end_pct   = Wpoi.end_pct;

    time_percent = linspace(0, 100, nTime);

    if start_pct <= end_pct
        poi_idx = find(time_percent >= start_pct & time_percent <= end_pct);
    else
        poi_idx = find(time_percent >= start_pct | time_percent <= end_pct);
    end

    if isempty(poi_idx)
        return;
    end

    poiMeta.has_poi = true;
    poiMeta.start_pct = start_pct;
    poiMeta.end_pct = end_pct;
    poiMeta.indices = poi_idx;
end
