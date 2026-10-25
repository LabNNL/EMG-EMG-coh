function y = resample_to_length(x, nSamples)

    x = x(:);

    oldGrid = linspace(0, 1, numel(x));
    newGrid = linspace(0, 1, nSamples);

    y = interp1(oldGrid, x, newGrid, 'linear', 'extrap')';
end
