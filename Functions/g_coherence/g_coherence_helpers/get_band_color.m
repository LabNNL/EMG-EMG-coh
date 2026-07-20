
function c = get_band_color(bandName)
% Bands = shades of yellow/orange (light -> dark)
% Alpha -> Beta -> Gamma

    switch char(string(bandName))
        case 'Alpha'
            c = [0.98 0.84 0.40];   % warm yellow
        case 'Beta'
            c = [0.95 0.63 0.22];   % orange
        case 'Gamma'
            c = [0.82 0.42 0.08];   % dark orange
        otherwise
            c = [0.4 0.4 0.4];
    end
end
