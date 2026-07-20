function age_group = subject_to_group(subjID, C)
    age_group = "Unknown";
    if isfield(C, 'groups') && isa(C.groups, 'containers.Map')
        if isKey(C.groups, subjID)
            age_group = string(C.groups(subjID));
        end
    end
end

