function x = remove_short_runs_local(x, minLen)
    % Set runs of ones shorter than minLen to zero
    x = logical(x(:));
    runs = logical_to_runs_local(x);
    if isempty(runs), return; end

    lens = runs(:,2) - runs(:,1) + 1;
    shortIdx = find(lens < minLen);

    for i = 1:numel(shortIdx)
        r = runs(shortIdx(i),:);
        x(r(1):r(2)) = false;
    end
end