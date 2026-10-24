function other = opposite_leg(leg)
    if strcmpi(leg, 'left')
        other = 'right';
    else
        other = 'left';
    end
end
