function BURST_QC = ensure_burst_qc_fields(BURST_QC, subjID, cond, leg)
if ~isfield(BURST_QC, subjID)
    BURST_QC.(subjID) = struct();
end
if ~isfield(BURST_QC.(subjID), cond)
    BURST_QC.(subjID).(cond) = struct();
end
if ~isfield(BURST_QC.(subjID).(cond), leg)
    BURST_QC.(subjID).(cond).(leg) = struct();
end
end