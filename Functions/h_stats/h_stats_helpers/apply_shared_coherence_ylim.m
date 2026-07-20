function apply_shared_coherence_ylim(ax, HC)

    if nargin < 1 || isempty(ax)
        ax = gca;
    end

    if isfield(HC.plot, 'use_fixed_coherence_ylim') && HC.plot.use_fixed_coherence_ylim && isfield(HC.plot, 'coherence_ylim') && numel(HC.plot.coherence_ylim) == 2

        ylim(ax, HC.plot.coherence_ylim);
    end
end
