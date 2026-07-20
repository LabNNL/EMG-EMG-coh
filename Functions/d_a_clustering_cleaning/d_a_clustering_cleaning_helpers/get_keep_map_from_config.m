function KEEP = get_keep_map_from_config(groupVar, keepCfg)

    if groupVar == "ALL"
        KEEP = struct();
        KEEP.ALL = keepCfg.ALL;

    elseif groupVar == "muscle"
        KEEP = keepCfg.muscle;

    elseif groupVar == "age_group"
        KEEP = keepCfg.age_group;

    elseif groupVar == "condition"
        KEEP = keepCfg.condition;

    else
        error('Unsupported groupVar for manual keep mapping: %s', groupVar);
    end
end