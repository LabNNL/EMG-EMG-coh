function FINAL_PAIRED_SIGNALS = load_final_paired_signals_file(inFile)

    L = load(inFile);
    varNames = fieldnames(L);

    if isfield(L, 'FINAL_PAIRED_SIGNALS')
        FINAL_PAIRED_SIGNALS = L.FINAL_PAIRED_SIGNALS;
        return;
    end

    idx = find(startsWith(varNames, 'FINAL_PAIRED_SIGNALS'), 1, 'first');

    if isempty(idx)
        error(['No variable starting with FINAL_PAIRED_SIGNALS found in %s.\n' ...
               'Variables found: %s'], ...
               inFile, strjoin(varNames, ', '));
    end

    chosenVar = varNames{idx};
    FINAL_PAIRED_SIGNALS = L.(chosenVar);

    fprintf('Loaded variable "%s" from %s\n', chosenVar, inFile);
end