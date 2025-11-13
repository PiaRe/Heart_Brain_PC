function label = format_beat_label(beat_type, group_select)
    % FORMAT_BEAT_LABEL - Format beat label for plotting
    %
    % Inputs:
    %   beat_type    - Beat type string (e.g., '0', '-3', 'iN')
    %   group_select - Group selection ('PAC', 'PVC', or 'PC')
    %
    % Outputs:
    %   label - Formatted label string for visualization
    %
    % Note: Beat types are converted as follows:
    %       'iN' -> 'N'
    %       '0'  -> group name ('PAC', 'PVC', 'PC')
    %       '-3', '-2', '-1', '+1', '+2' -> 'PAC-3', 'PAC+1', etc.
    %
    % Author: Pia Reinfeld
    % Date: 2025

    % Convert to char for comparison
    beat_type = char(beat_type);

    % Special case: 'iN' beats -> 'N'
    if strcmp(beat_type, 'iN')
        label = 'N';
        return;
    end

    % Special case: '0' beat -> group name (PAC, PVC, or PC)
    if strcmp(beat_type, '0') || strcmp(beat_type, group_select)
        label = group_select;
        return;
    end

    % Check if beat_type already contains the group prefix (e.g., 'PVC-3' or 'PVC+1')
    if strncmp(beat_type, group_select, length(group_select))
        label = beat_type;
        return;
    end

    % Otherwise, add group prefix to beat offset (e.g., '-3' -> 'PVC-3')
    % Handle numeric offset: -3, -2, -1, +1, +2
    offset = str2double(beat_type);

    if ~isnan(offset)
        % Valid numeric offset
        if offset > 0
            label = [group_select, '+', num2str(offset)];
        else
            label = [group_select, num2str(offset)];
        end

    else
        % If not a number, just concatenate
        label = sprintf('%s%s', group_select, beat_type);
    end

end
