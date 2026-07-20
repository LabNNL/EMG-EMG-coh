function lbl = get_pretty_group_label(gv, groupField)
    gv = string(gv);

    switch char(groupField)
        case 'age_group'
            switch gv
                case "Enfants"
                    lbl = "Enfants";
                case "JeunesEnfants"
                    lbl = "Jeunes enfants";
                case "Adolescents"
                    lbl = "Adolescents";
                case "Adultes"
                    lbl = "Adultes";
                otherwise
                    lbl = gv;
            end

        case 'condition'
            switch gv
                case "Plat"
                    lbl = "Flat";
                case "Medium"
                    lbl = "Medium";
                case "High"
                    lbl = "High";
                otherwise
                    lbl = gv;
            end

        otherwise
            lbl = gv;
    end
end