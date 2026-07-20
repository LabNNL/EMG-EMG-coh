function print_cycles_raw_structure(CYCLES_SIGNAL_RAW)
%PRINT_CYCLES_RAW_STRUCTURE Print a compact tree-like structure check.
%
% Prints the first available subject / condition / leg / muscle field and
% lists the subfields contained in that muscle structure.

    fprintf('\n=== STRUCTURE CHECK (random saved subject) ===\n');

    top_subj = fieldnames(CYCLES_SIGNAL_RAW);
    if isempty(top_subj)
        fprintf('CYCLES_SIGNAL_RAW is empty.\n');
        return;
    end

    subjID_rand = top_subj{1};

    fprintf('CYCLES_SIGNAL_RAW\n');
    fprintf('└── %s\n', subjID_rand);

    conds = fieldnames(CYCLES_SIGNAL_RAW.(subjID_rand));
    if isempty(conds)
        fprintf('    (no conditions found)\n');
        return;
    end
    cond = conds{1};
    fprintf('    └── %s\n', cond);

    legs = fieldnames(CYCLES_SIGNAL_RAW.(subjID_rand).(cond));
    if isempty(legs)
        fprintf('        (no legs found)\n');
        return;
    end
    leg = legs{1};
    fprintf('        └── %s\n', leg);

    mus_fields = fieldnames(CYCLES_SIGNAL_RAW.(subjID_rand).(cond).(leg));
    if isempty(mus_fields)
        fprintf('            (no muscle fields found)\n');
        return;
    end
    mus_field = mus_fields{1};
    fprintf('            └── %s\n', mus_field);

    subfields_mus = fieldnames(CYCLES_SIGNAL_RAW.(subjID_rand).(cond).(leg).(mus_field));
    for isf = 1:numel(subfields_mus)
        fprintf('                ├── %s\n', subfields_mus{isf});
    end

    required_fields = {'signal','n_cycles','cycle_lengths','cycle_starts','cycle_ends'};
    missing_fields = setdiff(required_fields, subfields_mus);

    if isempty(missing_fields)
        fprintf('                -> Structure OK\n');
    else
        fprintf('                -> Missing fields: %s\n', strjoin(missing_fields, ', '));
    end
end