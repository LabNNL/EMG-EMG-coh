function add_poi_patch(ax, startPct, endPct, faceAlpha)
% ADD_POI_PATCH  Shade a pair's phase of interest on a gait-cycle axis.
%
%   add_poi_patch(ax, startPct, endPct, faceAlpha)
%
% startPct and endPct are percentages of the gait cycle. A window whose start
% is after its end wraps around the end of the cycle (TAprox_TAdist is 60->20)
% and is drawn as two patches.
%
% Recovered from a commented-out block in h_coherence_stats.m, which was the
% only copy: make_cycle_triplet_figure called this function but nothing
% defined it, so cycle-triplet figures errored whenever
% C.h_stats.analysis.make_cycle_triplets was turned on.

if isnan(startPct) || isnan(endPct)
    return;
end

yl = ylim(ax);
grey = [0.5 0.5 0.5];

if startPct <= endPct
    shade(ax, [startPct endPct endPct startPct], yl, grey, faceAlpha);
else
    % wrap-around window, e.g. 60 -> 20
    shade(ax, [startPct 100 100 startPct], yl, grey, faceAlpha);
    shade(ax, [0 endPct endPct 0], yl, grey, faceAlpha);
end
end

function shade(ax, xs, yl, colour, faceAlpha)
patch(ax, xs, [yl(1) yl(1) yl(2) yl(2)], colour, ...
    'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
