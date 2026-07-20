function x = remove_long_runs_local(x, maxLen)
    % Set runs of ones longer than maxLen to zero
    x = logical(x(:));
    runs = logical_to_runs_local(x);
    if isempty(runs), return; end

    lens = runs(:,2) - runs(:,1) + 1;
    longIdx = find(lens > maxLen);

    for i = 1:numel(longIdx)
        r = runs(longIdx(i),:);
        x(r(1):r(2)) = false;
    end
end