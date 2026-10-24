function [status, reasons, M] = flag_cycles(n_cycles, Q)
reasons = strings(0,1); status="PASS"; M=struct();
M.n_cycles = n_cycles;
if ~isnan(n_cycles) && n_cycles < Q.min_cycles
    status="WARN"; reasons="few_cycles";
end
end