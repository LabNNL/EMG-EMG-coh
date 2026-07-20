function Tflat = spectrum_table_to_flat_table(T)
% light export helper for CSV: keeps first/last few summary columns only

    n = height(T);
    meanSpec = nan(n,1);

    for i = 1:n
        try
            if iscell(T.Spectrum)
                meanSpec(i) = mean(T.Spectrum{i}, 'omitnan');
            else
                meanSpec(i) = mean(T.Spectrum(i,:), 'omitnan');
            end
        catch
            meanSpec(i) = NaN;
        end
    end

    keepVars = intersect({'subject','age_group','condition','leg','pair_name','n_cycles_used','n_legs_collapsed'}, T.Properties.VariableNames, 'stable');

    Tflat = T(:, keepVars);
    Tflat.mean_spectrum_value = meanSpec;
end