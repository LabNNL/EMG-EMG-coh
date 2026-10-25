function [status, reasons, M] = flag_saturation_plateau(x, fs, Q)
% Detects rail/plateau-like contamination (often saturation/clipping or cable artifact)
% Works even if units are arbitrary by using robust, within-signal criteria.

reasons = strings(0,1);
status  = "PASS";
M = struct();

x0 = x(~isnan(x));
if numel(x0) < 10
    M.plateau_frac = NaN;
    M.rail_frac = NaN;
    return;
end

% If the signal is low-amplitude, this is a dropout/flatline case, not saturation.
p2p = max(x0) - min(x0);
rmsv = sqrt(mean(x0.^2));

if (p2p < Q.flatline_p2p_max) || (rmsv < Q.flatline_rms_max)
    M.plateau_frac = NaN;
    M.rail_frac = NaN;
    return; % do NOT label as saturation_plateau
end

% --- Plateau fraction: how often the signal barely changes sample-to-sample ---
dx = abs(diff(double(x0)));
eps_dx = max(1e-12, Q.plateau_eps_frac * median(dx(dx>0)));  % adaptive threshold
if isempty(eps_dx) || ~isfinite(eps_dx) || eps_dx==0
    eps_dx = 1e-12;
end
plateau_frac = mean(dx < eps_dx);
M.plateau_frac = plateau_frac;

% --- Rail fraction: fraction of samples near extreme values (proxy for clipping)
xmax = max(x0); xmin = min(x0);
range = xmax - xmin;
if range <= 0
    rail_frac = 1;
else
    rail_eps = Q.rail_eps_frac * range;  % e.g., 0.5% of range
    rail_frac = max(mean(abs(x0 - xmax) <= rail_eps), mean(abs(x0 - xmin) <= rail_eps));
end
M.rail_frac = rail_frac;

% Decision
if plateau_frac > Q.max_plateau_frac_fail || rail_frac > Q.max_rail_frac_fail
    status = "FAIL"; reasons = "saturation_plateau";
elseif plateau_frac > Q.max_plateau_frac_warn || rail_frac > Q.max_rail_frac_warn
    status = "WARN"; reasons = "saturation_plateau_warn";
end
end