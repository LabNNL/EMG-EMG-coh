function [status, reasons, M] = flag_duration(x, fs, Q)
reasons = strings(0,1); status="PASS"; M=struct();
dur_sec = numel(x)/fs;
M.duration_s = dur_sec;
if dur_sec < Q.min_seconds_per_signal
    status="FAIL"; reasons="too_short";
end
end