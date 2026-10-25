function m = longest_true_run(v)
v = v(:);
if isempty(v)
    m = 0; return;
end
dv = diff([false; v; false]);
run_starts = find(dv==1);
run_ends   = find(dv==-1) - 1;
if isempty(run_starts)
    m = 0;
else
    m = max(run_ends - run_starts + 1);
end
end