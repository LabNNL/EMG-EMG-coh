function age_group = subject_to_group(subjID, C)
    age_group = "Unknown";
    if isfield(C, 'groups') && isa(C.groups, 'containers.Map')
        if isKey(C.groups, char(subjID))
            age_group = string(C.groups(char(subjID)));
        end
    end
end

