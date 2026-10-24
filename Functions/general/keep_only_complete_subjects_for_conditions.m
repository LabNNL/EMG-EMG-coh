function T_out = keep_only_complete_subjects_for_conditions(T_in, conditionOrder)
%KEEP_ONLY_COMPLETE_SUBJECTS_FOR_CONDITIONS
% Keep only subjects who have all requested conditions.
%
% Input table should contain:
%   subject
%   condition
%
% Works for categorical or string condition/subject variables.

    % Important for tables: empty output must keep variables
    T_out = T_in([], :);

    if isempty(T_in)
        return;
    end

    if ~ismember('subject', T_in.Properties.VariableNames) || ~ismember('condition', T_in.Properties.VariableNames)
        warning('keep_only_complete_subjects_for_conditions: missing subject or condition variable.');
        return;
    end

    reqConds = string(conditionOrder(:));
    reqConds(reqConds == "") = [];

    if isempty(reqConds)
        T_out = T_in;
        return;
    end

    subjVals = string(T_in.subject);
    condVals = string(T_in.condition);

    subjList = unique(subjVals);
    keepSubject = false(size(subjList));

    for iS = 1:numel(subjList)

        s = subjList(iS);
        condsHere = unique(condVals(subjVals == s));

        keepSubject(iS) = all(ismember(reqConds, condsHere));
    end

    keptSubjects = subjList(keepSubject);

    if isempty(keptSubjects)
        T_out = T_in([], :);
    else
        T_out = T_in(ismember(subjVals, keptSubjects), :);
    end
end
