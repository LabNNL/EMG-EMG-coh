function label = get_spm_method_label_switch(P)

    if isfield(P, 'use_nonparametric') && P.use_nonparametric
        label = "SnPM";
    else
        label = "SPM";
    end
end