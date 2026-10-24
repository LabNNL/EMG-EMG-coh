function runs = logical_to_runs_local(mask)
    % Convert logical vector into [start end] runs of true values

    mask = logical(mask(:));

    if isempty(mask) || ~any(mask)
        runs = zeros(0,2);
        return;
    end

    d = diff([false; mask; false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    runs = [starts, ends];
end