function label = format_beat_label(beat_type, group_select)
    % FORMAT_BEAT_LABEL - Format beat label for plotting
    %
    % Inputs:
    %   beat_type    - Beat type string (e.g., '0', '-3', 'PVC')
    %   group_select - Group selection ('PAC', 'PVC', or 'PC')
    %
    % Outputs:
    %   label - Formatted label string for visualization
    %
    % Author: Pia Reinfeld
    % Date: 2025

    % Map beat type to label
    if strcmp(beat_type, '0') || strcmp(beat_type, group_select)
        label = group_select;
    elseif strncmp(beat_type, group_select, length(group_select))
        % e.g., 'PVC-3' or 'PVC+1'
        label = beat_type;
    else
        % e.g., '-3', '+1'
        label = sprintf('%s%s', group_select, beat_type);
    end

end
