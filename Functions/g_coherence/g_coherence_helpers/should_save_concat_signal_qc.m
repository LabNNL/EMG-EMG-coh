function tf = should_save_concat_signal_qc(QCP, subjID, cond, leg, pairName, nSaved)

    if ~QCP.enable || nSaved >= QCP.max_examples
        tf = false;
        return;
    end

    tf = true;

    if ~isempty(QCP.subjects)
        tf = tf && any(strcmp(string(subjID), string(QCP.subjects)));
    end
    if ~isempty(QCP.conditions)
        tf = tf && any(strcmp(string(cond), string(QCP.conditions)));
    end
    if ~isempty(QCP.legs)
        tf = tf && any(strcmp(string(leg), string(QCP.legs)));
    end
    if ~isempty(QCP.pairs)
        tf = tf && any(strcmp(string(pairName), string(QCP.pairs)));
    end
end