function S = ensure_final_fields(S, subjID, cond, leg)
    if ~isfield(S, subjID), S.(subjID) = struct(); end
    if ~isfield(S.(subjID), cond), S.(subjID).(cond) = struct(); end
    if ~isfield(S.(subjID).(cond), leg), S.(subjID).(cond).(leg) = struct(); end
end
