function [doUse, tracker] = should_make_limited_subject_plot(subjID, tracker, maxN)

    doUse = false;

    if ~isfield(tracker, 'count') || isempty(tracker.count)
        tracker.count = 0;
    end
    if ~isfield(tracker, 'subjects') || isempty(tracker.subjects)
        tracker.subjects = strings(0,1);
    end

    if tracker.count >= maxN
        return;
    end

    subjID = string(subjID);

    % Only keep one entry per subject for this family
    if any(tracker.subjects == subjID)
        return;
    end

    tracker.count = tracker.count + 1;
    tracker.subjects(end+1,1) = subjID;
    doUse = true;
end