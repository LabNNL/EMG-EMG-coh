function BURSTS_DET = ensure_fields(BURSTS_DET, subjID, cond, leg)
    if ~isfield(BURSTS_DET, subjID)
        BURSTS_DET.(subjID) = struct();
    end
    if ~isfield(BURSTS_DET.(subjID), cond)
        BURSTS_DET.(subjID).(cond) = struct();
    end
    if ~isfield(BURSTS_DET.(subjID).(cond), leg)
        BURSTS_DET.(subjID).(cond).(leg) = struct();
    end
end
