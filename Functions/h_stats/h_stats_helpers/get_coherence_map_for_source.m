function CohMap = get_coherence_map_for_source(R, coherenceSource)
%GET_COHERENCE_MAP_FOR_SOURCE Return coherence matrix for selected source.
%
% coherenceSource options:
%   "sig"           -> R.Coherence_sig
%   "raw"           -> R.Coherence
%   "sig_equalized" -> R.Coherence_sig_equalized
%   "sig_common_threshold" -> R.Coherence_sig_common_threshold
%  "zcoh_bokil"    -> R.ZCoh_Bokil
%  "surrogate_delta" -> R.Coherence_surrogate_delta
%  "cycle_bias_corrected" -> R.Coherence_cycle_bias_corrected
%
% Returns [] if the requested source is unavailable.

    CohMap = [];

    if nargin < 2 || isempty(coherenceSource)
        coherenceSource = "sig";
    end

    coherenceSource = lower(string(coherenceSource));

    if isempty(R) || ~isstruct(R)
        return;
    end

    switch coherenceSource

        case "sig"
            if isfield(R, 'Coherence_sig') && ~isempty(R.Coherence_sig)
                CohMap = R.Coherence_sig;
            end

        case "raw"
            if isfield(R, 'Coherence') && ~isempty(R.Coherence)
                CohMap = R.Coherence;
            end

        case "equalized"
            if isfield(R, 'Coherence_equalized') && ~isempty(R.Coherence_equalized)
                CohMap = R.Coherence_equalized;
            end

        case "sig_equalized"
            if isfield(R, 'Coherence_sig_equalized') && ~isempty(R.Coherence_sig_equalized)
                CohMap = R.Coherence_sig_equalized;
            end
        case "sig_common_threshold"
            if isfield(R, 'Coherence_sig_common_threshold') && ~isempty(R.Coherence_sig_common_threshold)
                CohMap = R.Coherence_sig_common_threshold;
            end
        case "zcoh_bokil"
            if isfield(R, 'Coherence_zcoh_bokil') && ~isempty(R.Coherence_zcoh_bokil)
                CohMap = R.Coherence_zcoh_bokil;
            end
        case "surrogate_delta"
            if isfield(R, 'Coherence_surrogate_delta') && ~isempty(R.Coherence_surrogate_delta)
                CohMap = R.Coherence_surrogate_delta;
            end
        case "cycle_bias_corrected"
            if isfield(R, 'Coherence_cycle_bias_corrected') && ~isempty(R.Coherence_cycle_bias_corrected)
                CohMap = R.Coherence_cycle_bias_corrected;
            end

        otherwise
            warning('Unknown coherenceSource: %s. Returning empty coherence map.', coherenceSource);
            CohMap = [];
    end
end