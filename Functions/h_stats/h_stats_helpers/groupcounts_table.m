function Tgc = groupcounts_table(T, vars)
    Tgc = groupcounts(T, vars);
    Tgc.Properties.VariableNames{'GroupCount'} = 'n';
end
