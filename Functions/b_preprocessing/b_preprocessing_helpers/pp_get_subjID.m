function subjID = pp_get_subjID(L)
subjIDs = fieldnames(L.CYCLES_SIGNAL_RAW);
if isempty(subjIDs)
    error("Empty CYCLES_SIGNAL_RAW (no subj fields).");
end
subjID = subjIDs{1};
end