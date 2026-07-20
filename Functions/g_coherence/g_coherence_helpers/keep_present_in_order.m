
function ordered = keep_present_in_order(desiredOrder, presentCats)
% Return desiredOrder filtered to only categories that are present

    ordered = {};
    for i = 1:numel(desiredOrder)
        if any(strcmp(presentCats, desiredOrder{i}))
            ordered{end+1} = desiredOrder{i}; %#ok<AGROW>
        end
    end
end