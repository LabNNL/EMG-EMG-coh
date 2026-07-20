function tf = get_wavelet_overlap_flag_for_band(cyc, cycleNum, band)

    tf = false;

    if strcmpi(string(band), "overall")
        if isfield(cyc, 'has_bad_burst_in_phase_of_interest_padded') && ...
                numel(cyc.has_bad_burst_in_phase_of_interest_padded) >= cycleNum
            tf = cyc.has_bad_burst_in_phase_of_interest_padded(cycleNum);
        end
        return;
    end

    if isfield(cyc, 'band_contaminated') && isfield(cyc.band_contaminated, char(string(band)))
        v = cyc.band_contaminated.(char(string(band)));
        if numel(v) >= cycleNum
            tf = v(cycleNum);
        end
    end
end