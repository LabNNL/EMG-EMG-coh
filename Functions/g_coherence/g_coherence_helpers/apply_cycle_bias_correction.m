function Ccorr = apply_cycle_bias_correction(Craw, Ncycle, corrCfg)

    Ccorr = nan(size(Craw));

    if isempty(Craw) || isempty(Ncycle) || isnan(Ncycle) || Ncycle <= 0
        return;
    end

    a = corrCfg.a;
    Nref = corrCfg.Nref;

    correction = a * (1/Ncycle - 1/Nref);

    Ccorr = Craw - correction;

    if isfield(corrCfg, 'clip_to_01') && corrCfg.clip_to_01
        Ccorr(Ccorr < 0) = 0;
        Ccorr(Ccorr > 1) = 1;
    end

    Ccorr(~isfinite(Ccorr)) = NaN;
end