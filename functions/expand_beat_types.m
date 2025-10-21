function expanded_types = expand_beat_types(beat_type)
    % EXPAND_BEAT_TYPES - Expand generic beat types to specific PAC/PVC types
    %
    % This helper function takes a generic beat type (e.g., 'PC-3') and expands
    % it to include both PAC and PVC variants (e.g., {'PAC-3', 'PVC-3'}).
    % Special cases like 'iN' and 'N' are returned as-is.
    %
    % Inputs:
    %   beat_type - String or cell array of beat type(s) to expand
    %
    % Outputs:
    %   expanded_types - Cell array of expanded beat type(s)
    %
    % Examples:
    %   expand_beat_types('PC-3') returns {'PAC-3', 'PVC-3'}
    %   expand_beat_types('iPC') returns {'iPAC', 'iPVC'}
    %   expand_beat_types('iN') returns {'iN'}
    %   expand_beat_types({'PC-3', 'iN'}) returns {'PAC-3', 'PVC-3', 'iN'}
    %
    % Author: Pia Reinfeld

    % Handle cell array input
    if iscell(beat_type)
        expanded_types = {};

        for i = 1:length(beat_type)
            expanded_types = [expanded_types, expand_beat_types(beat_type{i})];
        end

        return;
    end

    % Handle string input
    if ischar(beat_type) || isstring(beat_type)
        beat_type = char(beat_type);

        % Special cases that don't need expansion
        if strcmp(beat_type, 'iN') || strcmp(beat_type, 'N') || strcmp(beat_type, 'badECG')
            expanded_types = {beat_type};
            return;
        end

        % Check if it's a generic PC type that needs expansion
        if startsWith(beat_type, 'PC')
            % Replace 'PC' with both 'PAC' and 'PVC'
            pac_type = strrep(beat_type, 'PC', 'PAC');
            pvc_type = strrep(beat_type, 'PC', 'PVC');
            expanded_types = {pac_type, pvc_type};
        elseif startsWith(beat_type, 'iPC')
            % Handle isolated PC case
            expanded_types = {'iPAC', 'iPVC'};
        else
            % Already specific type (PAC-3, PVC-3, etc.) or unknown type
            expanded_types = {beat_type};
        end

    else
        error('beat_type must be a string or cell array of strings');
    end

end
