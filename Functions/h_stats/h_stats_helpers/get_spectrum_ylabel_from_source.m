function ytxt = get_spectrum_ylabel_from_source(HS)

    if isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "sig")
        ytxt = 'Significant coherence';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "equalized")
        ytxt = 'Coherence (equalized number of cycles)';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "sig_equalized")
        ytxt = 'Equalized significant coherence';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "sig_common_threshold")
        ytxt = 'Significant coherence (common threshold)';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "zcoh_bokil")
        ytxt = 'Bokil z-coherence';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "surrogate_delta")
        ytxt = 'Surrogate delta coherence';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "cycle_bias_corrected")
        ytxt = 'Cycle-bias-corrected coherence';
    elseif isfield(HS, 'spectrum_source') && strcmpi(string(HS.spectrum_source), "raw")
        ytxt = 'Raw coherence';
    else
        ytxt = 'Coherence';
    end
end