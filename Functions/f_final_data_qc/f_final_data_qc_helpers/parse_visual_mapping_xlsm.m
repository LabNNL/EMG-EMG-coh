
function visualT = parse_visual_mapping_xlsm(xlsFile, sheetName)
% Parse visual QC sheet "Mapping-ALL".
%
% Real observed structure per participant block:
% - start column c contains:
%       row 1  : participant ID (e.g. CTL_01)
%       row 3  : "MUSCLE"
%       rows 4:11  : muscle labels
% - columns c+1:c+6 contain headers:
%       row 2: PLAT / MEDIUM / HIGH
%       row 3: GAUCHE / DROITE
% - rows 13:20 contain the numeric visual scores for the 8 muscles
% - column c+7 is a spacer / notes column (often 80), ignored here

raw = readcell(xlsFile, 'Sheet', sheetName);
[nr, nc] = size(raw);

%% ---------- Find participant block start columns ----------
subjectCols = [];
subjectIDs  = strings(0,1);

for c = 1:nc
    v = raw{1,c};
    if ischar(v) || isstring(v)
        s = string(strtrim(v));
        if ~ismissing(s) && ~isempty(regexp(char(s), '^CTL_\d+$', 'once'))
            subjectCols(end+1) = c; %#ok<AGROW>
            subjectIDs(end+1,1) = s; %#ok<AGROW>
        end
    end
end

if isempty(subjectCols)
    error('No participant blocks found in sheet "%s".', sheetName);
end

%% ---------- Fixed row/column structure ----------
labelRows = 4:11;    % TAprox ... GMED
scoreRows = 13:20;   % corresponding numeric scores
scoreColOffsets = 1:6;

condSeq = ["Plat","Plat","Medium","Medium","High","High"];
legSeq  = ["left","right","left","right","left","right"];

rows = {};
ri = 0;

%% ---------- Parse each participant block ----------
for isub = 1:numel(subjectCols)
    c0 = subjectCols(isub);
    subjID = subjectIDs(isub);

    % Basic bounds check
    if c0 + 6 > nc
        warning('Skipping %s: score columns exceed sheet width.', subjID);
        continue;
    end
    if max(labelRows) > nr || max(scoreRows) > nr
        warning('Skipping %s: expected rows exceed sheet height.', subjID);
        continue;
    end

    for k = 1:numel(labelRows)
        rLabel = labelRows(k);
        rScore = scoreRows(k);

        musLabel = raw{rLabel, c0};
        muscleName = normalize_visual_muscle_label(musLabel);

        if muscleName == ""
            warning('Participant %s: unrecognized muscle label at row %d, col %d.', subjID, rLabel, c0);
            continue;
        end

        for j = 1:numel(scoreColOffsets)
            cc = c0 + scoreColOffsets(j);
            score = to_numeric_or_nan(raw{rScore, cc});

            ri = ri + 1;
            rows(ri,:) = { ...
                subjID, condSeq(j), legSeq(j), muscleName, score ...
                };
        end
    end
end

%% ---------- Build output table ----------
visualT = cell2table(rows, 'VariableNames', ...
    {'subjID','condition','leg','muscleName','visual_score'});

visualT.subjID = string(visualT.subjID);
visualT.condition = string(visualT.condition);
visualT.leg = string(visualT.leg);
visualT.muscleName = string(visualT.muscleName);
end

function mus = normalize_visual_muscle_label(x)
% Accept labels like:
%   "TAprox"
%   "TAprox = Tibialis ..."
%   "TAdist = ..."
% and map them to config-style muscle names:
%   EMG_TAprox, EMG_TAdist, ...

if ~(ischar(x) || isstring(x))
    mus = "";
    return;
end

s = string(strtrim(x));
if s == ""
    mus = "";
    return;
end

sLower = lower(s);

if startsWith(sLower, "taprox")
    mus = "EMG_TAprox";
elseif startsWith(sLower, "tadist")
    mus = "EMG_TAdist";
elseif startsWith(sLower, "sol")
    mus = "EMG_SOL";
elseif startsWith(sLower, "gm ")
    mus = "EMG_GM";
elseif sLower == "gm"
    mus = "EMG_GM";
elseif startsWith(sLower, "vl")
    mus = "EMG_VL";
elseif startsWith(sLower, "rf")
    mus = "EMG_RF";
elseif startsWith(sLower, "st")
    mus = "EMG_ST";
elseif startsWith(sLower, "gmed")
    mus = "EMG_GMED";
else
    mus = "";
end
end

function y = to_numeric_or_nan(x)
if isnumeric(x)
    if isempty(x)
        y = NaN;
    else
        y = double(x);
    end
elseif ischar(x) || isstring(x)
    y = str2double(string(x));
    if isnan(y)
        y = NaN;
    end
else
    y = NaN;
end
end
