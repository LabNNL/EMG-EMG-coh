function bandNames = cycle_band_names(C)
% The per-band fields of R.CycleBandCoherence (one per configured band)
    bandNames = setdiff(fieldnames(C), {'cycle_number','FullRange','analysis_cycle_mask', ...
        'mask_real_outer','mask_analysis_outer','mask_analysis_middle'}, 'stable');
end
