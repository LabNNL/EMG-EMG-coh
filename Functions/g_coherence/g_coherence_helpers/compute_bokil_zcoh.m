function Zcoh = compute_bokil_zcoh(Coherence, nCycles, zCfg)

    Zcoh = nan(size(Coherence));

    if isempty(Coherence) || isempty(nCycles) || isnan(nCycles) || nCycles <= 2
        return;
    end

    % ---------- Degrees of freedom ----------
    dfMode = "n_cycles";
    if isfield(zCfg, 'df_mode') && ~isempty(zCfg.df_mode)
        dfMode = lower(string(zCfg.df_mode));
    end

    switch dfMode
        case "n_cycles"
            df = nCycles;

        case "2n_cycles"
            df = 2 * nCycles;

        otherwise
            error('Unknown zcoh_bokil.df_mode: %s', dfMode);
    end

    if df <= 2
        return;
    end

    % ---------- Input transform ----------
    inputTransform = "coherence";
    if isfield(zCfg, 'input_transform') && ~isempty(zCfg.input_transform)
        inputTransform = lower(string(zCfg.input_transform));
    end

    C = Coherence;
    C(C < 0) = 0;
    C(C > 1) = 1;

    switch inputTransform
        case "coherence"
            X = C;

        case "sqrt_coherence"
            X = sqrt(C);

        otherwise
            error('Unknown zcoh_bokil.input_transform: %s', inputTransform);
    end

    % Avoid atanh(1) = Inf
    X(X >= 1) = 1 - eps;

    % ---------- Bokil-style bias correction and normalization ----------
    biasTerm = 1 / (df - 2);
    scaleTerm = sqrt(1 / (df - 2));

    Zcoh = (atanh(X) - biasTerm) ./ scaleTerm;
    Zcoh(~isfinite(Zcoh)) = NaN;
end