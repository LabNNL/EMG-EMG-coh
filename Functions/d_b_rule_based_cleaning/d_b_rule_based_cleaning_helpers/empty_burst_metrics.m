function M = empty_burst_metrics(nB)
M = struct();
M.duration_ms   = NaN(nB,1);
M.spike_zmax    = NaN(nB,1);
M.deriv_zmax    = NaN(nB,1);
M.plateau_frac  = NaN(nB,1);
M.rail_frac     = NaN(nB,1);
M.low_over_mid  = NaN(nB,1);
M.high_over_mid = NaN(nB,1);
M.p2p_mV        = NaN(nB,1);
M.rms_mV        = NaN(nB,1);
M.MedFreq       = NaN(nB,1);
M.spike_global_z = NaN(nB,1);
end