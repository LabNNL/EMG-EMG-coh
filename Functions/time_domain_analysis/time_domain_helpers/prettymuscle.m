function prettymuscleName = prettymuscle(muscleName)
    % Convert internal muscle names to more readable format
    % Take out EMG and Concat first
    prettymuscleName = regexprep(muscleName, 'EMG_|_Concat', '');
    % Replace underscores with spaces
    prettymuscleName = strrep(prettymuscleName, '_', ' ');
    %if contains TA replace by 'Tibialis Anterior'
    if contains(prettymuscleName, 'TAdist')
        prettymuscleName = strrep(prettymuscleName, 'TAdist', 'Tibialis Anterior dist');
    elseif contains(prettymuscleName, 'TAprox')
        prettymuscleName = strrep(prettymuscleName, 'TAprox', 'Tibialis Anterior prox');
    elseif contains(prettymuscleName, 'SOL')
        prettymuscleName = strrep(prettymuscleName, 'SOL', 'Soleus');
    elseif contains(prettymuscleName, 'GMED')
        prettymuscleName = strrep(prettymuscleName, 'GMED', 'Gluteus Medius');
    elseif contains(prettymuscleName, 'GM')
        prettymuscleName = strrep(prettymuscleName, 'GM', 'Gastrocnemius Medialis');
    elseif contains(prettymuscleName, 'VL')
        prettymuscleName = strrep(prettymuscleName, 'VL', 'Vastus Lateralis');
    elseif contains(prettymuscleName, 'RF')
        prettymuscleName = strrep(prettymuscleName, 'RF', 'Rectus Femoris');
    elseif contains(prettymuscleName, 'ST')
        prettymuscleName = strrep(prettymuscleName, 'ST', 'Semitendinosus');
    end
end
