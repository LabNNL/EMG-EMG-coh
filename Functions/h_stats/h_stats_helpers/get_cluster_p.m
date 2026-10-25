function p = get_cluster_p(clusters, ic)
%GET_CLUSTER_P  p-value of one supra-threshold cluster, or NaN.
%
%   p = get_cluster_p(clusters, ic)
%
% spm1d stores SPMi.clusters as a CELL array of spm1d.geom.Cluster objects
% (see SnPM1Di.m, which reads self.clusters{i}.P). Indexing it with ()
% therefore yields a 1x1 cell, isprop returns false and the p-value silently
% comes back NaN. This accessor handles the cell case, falls back to object
% arrays, and checks both P (parametric, random field theory) and p.

p = NaN;

if isempty(clusters) || ic < 1 || ic > numel(clusters)
    return
end

if iscell(clusters)
    c = clusters{ic};
else
    c = clusters(ic);
end

if isobject(c) || isstruct(c)
    if isprop_or_field(c, 'P')
        p = c.P;
    elseif isprop_or_field(c, 'p')
        p = c.p;
    end
end

if ~isscalar(p) || ~isnumeric(p)
    p = NaN;
end
end

function tf = isprop_or_field(c, name)
tf = (isobject(c) && isprop(c, name)) || (isstruct(c) && isfield(c, name));
end
