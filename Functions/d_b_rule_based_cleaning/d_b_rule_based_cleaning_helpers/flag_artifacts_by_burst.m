function [burst_keep, burst_reason, M] = flag_artifacts_by_burst(x, fs, bursts_idx, Q)
%FLAG_ARTIFACTS_BY_BURST Binary burst-level artifact rejection
%
% For each detected burst:
%   keep = true  -> likely real muscular burst
%   keep = false -> artifact / fake burst
%
% Uses burst segment only (not cycle fractions).

x = x(:);
n = numel(x);

if isempty(bursts_idx)
    burst_keep = false(0,1);
    burst_reason = strings(0,1);
    M = empty_burst_metrics(0);
    return;
end

nB = size(bursts_idx,1);

burst_keep   = true(nB,1);
burst_reason = repmat("ok", nB, 1);

M = empty_burst_metrics(nB);

order = containers.Map({'PASS','FAIL'}, [1 2]);

    function s = maxS(a,b)
        if order(char(b)) > order(char(a)), s = b; else, s = a; end
    end

    function r = addReason(r, token)
        if strlength(r)==0 || r=="ok"
            r = token;
        else
            r = r + "+" + token;
        end
    end

    function [lom, hom] = spectral_ratios(seg)
        lom = NaN; hom = NaN;
        seg = seg(:);
        seg = seg(~isnan(seg));
        if numel(seg) < max(64, round(0.03*fs))
            return;
        end

        seg = double(seg);
        seg = seg - mean(seg);

        Nfft = 2^nextpow2(numel(seg));
        w = 0.5 - 0.5*cos(2*pi*(0:numel(seg)-1)'/(numel(seg)-1));
        X = fft(seg .* w, Nfft);
        P = (abs(X).^2) / Nfft;
        faxis = (0:Nfft-1)'*(fs/Nfft);

        half = 1:floor(Nfft/2);
        fpos = faxis(half);
        Ppos = P(half);

        bandpow = @(f1,f2) sum(Ppos(fpos>=f1 & fpos<=f2));

        f_low1 = Q.burst.spec_low(1);   f_low2 = Q.burst.spec_low(2);
        f_mid1 = Q.burst.spec_mid(1);   f_mid2 = min(Q.burst.spec_mid(2), fs/2 - 1);
        f_hi1  = Q.burst.spec_high(1);  f_hi2  = min(Q.burst.spec_high(2), fs/2 - 1);

        Plow  = bandpow(f_low1, f_low2);
        Pmid  = bandpow(f_mid1, f_mid2);
        Phigh = bandpow(f_hi1,  f_hi2);

        if Pmid > 0
            lom = Plow / Pmid;
            hom = Phigh / Pmid;
        end
    end

% ----- global burst-amplitude outlier reference within this signal -----
global_peak_abs = NaN(nB,1);

for bb = 1:nB
    ii1 = max(1, min(n, bursts_idx(bb,1)));
    ii2 = max(1, min(n, bursts_idx(bb,2)));

    if ii2 <= ii1
        continue;
    end

    seg_tmp = x(ii1:ii2);
    seg_tmp = seg_tmp(~isnan(seg_tmp));

    if isempty(seg_tmp)
        continue;
    end

    global_peak_abs(bb) = max(abs(seg_tmp), [], 'omitnan');
end

global_peak_abs_z = robust_z_from_vector(global_peak_abs);

for b = 1:nB
    i1 = max(1, min(n, bursts_idx(b,1)));
    i2 = max(1, min(n, bursts_idx(b,2)));

    sev = "PASS";
    reas = "ok";

    if i2 <= i1
        sev = "FAIL";
        reas = "bad_bounds";
        burst_keep(b) = false;
        burst_reason(b) = reas;
        continue;
    end

    seg = x(i1:i2);
    seg = seg(~isnan(seg));

    if numel(seg) < 5
        sev = "FAIL";
        reas = addReason(reas, "too_few_samples");
    end

    % ----- duration -----
    dur_samples = i2 - i1 + 1;
    dur_ms = 1000 * dur_samples / fs;
    M.duration_ms(b) = dur_ms;

    if isfield(Q,'burst') && isfield(Q.burst,'min_duration_ms') && dur_ms < Q.burst.min_duration_ms && Q.burst.duration.too_short_enable
        sev = maxS(sev, "FAIL");
        reas = addReason(reas, "too_short");
    end
    if isfield(Q,'burst') && isfield(Q.burst,'max_duration_ms') && dur_ms > Q.burst.max_duration_ms && Q.burst.duration.too_long_enable
        sev = maxS(sev, "FAIL");
        reas = addReason(reas, "too_long");
    end

    if numel(seg) < 5
        burst_keep(b) = false;
        burst_reason(b) = reas;
        continue;
    end

    segd = double(seg);
    segd = segd - median(segd);

    % ----- spike / pop -----
    if isfield(Q,'burst') && isfield(Q.burst,'spike') && Q.burst.spike.enable
        mad_amp = median(abs(segd - median(segd)));
        sigma_amp = 1.4826 * mad_amp + eps;
        z_amp = abs(segd) / sigma_amp;
        z_amp_max = max(z_amp);
        M.spike_zmax(b) = z_amp_max;
        M.spike_global_z(b) = global_peak_abs_z(b);

        dx = diff(segd);
        mad_dx = median(abs(dx - median(dx)));
        sigma_dx = 1.4826 * mad_dx + eps;
        z_deriv = abs(dx - median(dx)) / sigma_dx;
        z_deriv_max = max(z_deriv);
        M.deriv_zmax(b) = z_deriv_max;

        % Rule 1: very large and brief spike
        if (z_amp_max > Q.burst.spike.amp_z_fail)
            sev = maxS(sev, "FAIL");
            reas = addReason(reas, "spike_1");

        % Rule 2: moderately large + sharp + brief
        elseif (z_amp_max > Q.burst.spike.amp_z_warn) && ...
            (isnan(z_deriv_max) || z_deriv_max > Q.burst.spike.deriv_z_warn)
            sev = maxS(sev, "FAIL");
            reas = addReason(reas, "spike_2");
        end
    end

    % Rule 3: globally extreme burst amplitude compared with other bursts in this signal
    if isfield(Q.burst.spike, 'global_enable') && Q.burst.spike.global_enable
        if nnz(isfinite(global_peak_abs)) >= Q.burst.spike.global_min_bursts
            if isfinite(global_peak_abs_z(b)) && global_peak_abs_z(b) > Q.burst.spike.global_amp_z_fail
                sev = maxS(sev, "FAIL");
                reas = addReason(reas, "spike_global");
            end
        end
    end
    
    % ----- plateau / rail -----
    if isfield(Q,'burst') && isfield(Q.burst,'plateau') && Q.burst.plateau.enable
        dx = abs(diff(segd));
        dxnz = dx(dx>0);

        if isempty(dxnz)
            plateau_frac = 1;
        else
            eps_dx = Q.burst.plateau_eps_frac * median(dxnz);
            plateau_frac = mean(dx < max(eps_dx, 1e-12));
        end
        M.plateau_frac(b) = plateau_frac;

        xmax = max(segd); xmin = min(segd);
        rngv = xmax - xmin;
        if rngv <= 0
            rail_frac = 1;
        else
            rail_eps = Q.burst.rail_eps_frac * rngv;
            rail_frac = max(mean(abs(segd - xmax) <= rail_eps), ...
                            mean(abs(segd - xmin) <= rail_eps));
        end
        M.rail_frac(b) = rail_frac;

        if plateau_frac > Q.burst.plateau_frac_fail || rail_frac > Q.burst.rail_frac_fail
            sev = maxS(sev, "FAIL");
            reas = addReason(reas, "plateau");
        end
    end

    % ----- spectrum -----
    if isfield(Q,'burst') && isfield(Q.burst,'spec') && Q.burst.spec.enable
        [lom, hom] = spectral_ratios(seg);
        M.low_over_mid(b) = lom;
        M.high_over_mid(b) = hom;

        if isfinite(lom) && isfinite(hom)
            if lom > Q.burst.spec_low_over_mid_fail || hom > Q.burst.spec_high_over_mid_fail
                sev = maxS(sev, "FAIL");
                reas = addReason(reas, "spec");
            end
        end
    end

    % ----- median frequency -----
    if isfield(Q,'burst') && isfield(Q.burst,'medfreq') && Q.burst.medfreq.enable
        MedFreq = median_frequency(seg, fs);
        M.MedFreq(b) = MedFreq;

        if isfinite(MedFreq)
            if MedFreq < Q.burst.medfreq.min_hz_fail
                sev = maxS(sev, "FAIL");
                reas = addReason(reas, "medfreq");
            end
        end
    end

    % ----- absolute amplitude -----
    if isfield(Q,'burst') && isfield(Q.burst,'abs') && Q.burst.abs.enable
        p2p = max(seg) - min(seg);
        rmsv = sqrt(mean(seg.^2));

        if Q.burst.abs.units == "V"
            p2p_mV = 1000 * p2p;
            rms_mV = 1000 * rmsv;
        else
            p2p_mV = p2p;
            rms_mV = rmsv;
        end

        M.p2p_mV(b) = p2p_mV;
        M.rms_mV(b) = rms_mV;

        if (p2p_mV > Q.burst.abs.max_p2p_mV_fail) || (rms_mV > Q.burst.abs.max_rms_mV_fail)
            sev = maxS(sev, "FAIL");
            reas = addReason(reas, "abs_amp");
        end
    end

    if reas == "ok"
        burst_keep(b) = true;
    else
        burst_keep(b) = sev == "PASS";
    end
    burst_reason(b) = reas;
end
end

function z = robust_z_from_vector(v)
    z = NaN(size(v));
    v = double(v(:));
    good = isfinite(v);
    if nnz(good) < 3
        return;
    end
    medv = median(v(good), 'omitnan');
    madv = median(abs(v(good) - medv), 'omitnan');
    sigv = 1.4826 * madv + eps;
    z(good) = (v(good) - medv) / sigv;
end