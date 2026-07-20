function val = get_band_auc_norm_from_scope(R, bandName, scopeName)

    val = NaN;

    try
        switch lower(string(scopeName))
            case "full"
                auc_raw = R.AUC_CoherenceFull.(bandName);
            case "stance"
                auc_raw = R.AUC_CoherenceStance.(bandName);
            case "swing"
                auc_raw = R.AUC_CoherenceSwing.(bandName);
            otherwise
                return;
        end

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