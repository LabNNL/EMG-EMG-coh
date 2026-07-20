function ordered = keep_present_in_order(desiredOrder, presentCats)
    ordered = {};
    for i = 1:numel(desiredOrder)
        if any(strcmp(cellstr(presentCats), desiredOrder{i}))
            ordered{end+1} = desiredOrder{i}; %#ok<AGROW>
        end
    end
end