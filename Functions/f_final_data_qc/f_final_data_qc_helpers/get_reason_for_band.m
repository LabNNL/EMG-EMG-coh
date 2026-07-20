function reasonStr = get_reason_for_band(cyc, cycleNum, band)

    reasonStr = "";

    if strcmpi(string(band), "overall")
        if isfield(cyc, 'cycle_reason') && numel(cyc.cycle_reason) >= cycleNum
            reasonStr = string(cyc.cycle_reason(cycleNum));
        end
        return;
    end

    if isfield(cyc, 'band_reason') && isfield(cyc.band_reason, char(string(band)))
        v = cyc.band_reason.(char(string(band)));
        if numel(v) >= cycleNum
            reasonStr = string(v(cycleNum));
        end
    end
end