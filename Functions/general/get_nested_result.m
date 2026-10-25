function R = get_nested_result(S, subjID, cond, leg, pairName)

    R = [];

    try
        if ~isstruct(S), return; end
        if ~isfield(S, subjID), return; end
        if ~isfield(S.(subjID), cond), return; end
        if ~isfield(S.(subjID).(cond), leg), return; end
        if ~isfield(S.(subjID).(cond).(leg), pairName), return; end

        R = S.(subjID).(cond).(leg).(pairName);
    catch
        R = [];
    end
end
