function c = get_phase_color(phaseName)
% Phases = shades of blue (light -> dark)
% Full -> Stance -> Swing

    switch char(string(phaseName))
        case 'Full'
            c = [0.63 0.82 0.95];   % light blue
        case 'Stance'
            c = [0.32 0.62 0.88];   % medium blue
        case 'Swing'
            c = [0.10 0.32 0.62];   % dark blue
        otherwise
            c = [0.4 0.4 0.4];
    end
end
