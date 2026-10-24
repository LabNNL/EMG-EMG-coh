function val = get_band_auc_norm(R, bandName)
    val = NaN;
    try
        auc_raw = R.AUC_CoherenceFull.(bandName);
        switch bandName
            case 'Alpha'
                bw = 12 - 8;
            case 'Beta'
                bw = 30 - 13;
            case 'Gamma'
                bw = 150 - 31;
            otherwise
                bw = NaN;
        end

        if ~isnan(bw) && bw > 0
            val = auc_raw / bw;
        end
    catch
        val = NaN;
    end
end