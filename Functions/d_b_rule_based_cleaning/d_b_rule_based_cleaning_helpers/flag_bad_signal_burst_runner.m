function [status, reasons, M] = flag_bad_signal_burst_runner(x, fs, Q)

reasons = strings(0,1);
status  = "PASS";
M = struct();

[st, r, m] = flag_nan_and_empty(x, Q);
status = max_status_local(status, st); reasons = [reasons; r]; M = merge_metrics_local(M,m);

[st, r, m] = flag_duration(x, fs, Q);
status = max_status_local(status, st); reasons = [reasons; r]; M = merge_metrics_local(M,m);

[st, r, m] = flag_flatline(x, fs, Q);
status = max_status_local(status, st); reasons = [reasons; r]; M = merge_metrics_local(M,m);

if Q.check_line_noise
    [st, r, m] = flag_line_noise(x, fs, Q);
    status = max_status_local(status, st); reasons = [reasons; r]; M = merge_metrics_local(M,m);
end

if Q.check_spectrum
    [st, r, m] = flag_spectrum_shape(x, fs, Q);
    status = max_status_local(status, st); reasons = [reasons; r]; M = merge_metrics_local(M,m);
end

if isempty(reasons)
    reasons = "ok";
end
end

function s = max_status_local(a,b)
order = containers.Map({'PASS','WARN','FAIL'}, [1 2 3]);
if order(char(b)) > order(char(a)), s = b; else, s = a; end
end

function M = merge_metrics_local(M, m)
fn = fieldnames(m);
for i = 1:numel(fn)
    M.(fn{i}) = m.(fn{i});
end
end