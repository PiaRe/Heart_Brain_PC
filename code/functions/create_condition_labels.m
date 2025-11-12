function [comparison_label, reference_label] = create_condition_labels(beat_comparison, beat_reference, group_select, is_control_analysis, is_pac_pvc_comparison, is_correlation_analysis)
    % CREATE_CONDITION_LABELS - Generate automatic labels for plotting
    %
    % Inputs:
    %   beat_comparison        - Comparison beat type (e.g., '-3', '-2', '-1', '0', '1', '2', 'iN')
    %   beat_reference         - Reference beat type (e.g., 'iN', '0', '-3', etc.)
    %   group_select           - Group selection ('PC', 'PAC', 'PVC')
    %   is_control_analysis    - (Optional) Boolean for control group comparison (default: false)
    %   is_pac_pvc_comparison  - (Optional) Boolean for PAC vs PVC comparison (default: false)
    %   is_correlation_analysis - (Optional) Boolean for correlation analysis (default: false)
    %
    % Outputs:
    %   comparison_label - Formatted label for comparison condition
    %   reference_label  - Formatted label for reference condition
    %
    % Note: Beat types are converted as follows:
    %       'iN' -> 'N'
    %       '0'  -> group name ('PAC', 'PVC', 'PC')
    %       '-3', '-2', '-1', '1', '2' -> 'PAC-3', 'PAC+1', etc.

    % Handle optional parameters with defaults
    if nargin < 4 || isempty(is_control_analysis)
        is_control_analysis = false;
    end

    if nargin < 5 || isempty(is_pac_pvc_comparison)
        is_pac_pvc_comparison = false;
    end

    if nargin < 6 || isempty(is_correlation_analysis)
        is_correlation_analysis = false;
    end

    % Function to format beat label based on beat type and group
    function label = format_beat_label(beat_str, group) %this you have as a standalone function which could be removed
        % Convert string to allow comparison
        beat_str = char(beat_str);

        if strcmp(beat_str, 'iN')
            % iN beats -> 'N'
            label = 'N';
        elseif strcmp(beat_str, '0')
            % 0 beat -> group name (PAC, PVC, or PC)
            label = group;
        else
            % Numeric offset: -3, -2, -1, 1, 2
            % Convert to proper format with sign
            offset = str2double(beat_str);

            if offset > 0
                label = [group, '+', num2str(offset)];
            else
                label = [group, num2str(offset)];
            end

        end

    end

    % Generate labels based on comparison type
    if is_correlation_analysis
        % CFA Correlation analysis: special labels with Delta symbol
        comparison_label = 'Empirical Correlation between \Delta EEG and \Delta ECG';
        reference_label = 'Chance Level Correlation between \Delta EEG and \Delta ECG';

    elseif is_pac_pvc_comparison
        % PAC vs PVC comparison: same beat type, different groups
        comp_base = format_beat_label(beat_comparison, 'PAC');
        ref_base = format_beat_label(beat_reference, 'PVC');

        % Only add group suffix if it's 'N' (otherwise redundant: PAC+1 is clear)
        if strcmp(comp_base, 'N')
            comparison_label = [comp_base, '_{PAC-group}'];
        else
            comparison_label = comp_base;
        end

        if strcmp(ref_base, 'N')
            reference_label = [ref_base, '_{PVC-group}'];
        else
            reference_label = ref_base;
        end

    elseif is_control_analysis
        % PC/PAC/PVC vs Control comparison
        comp_base = format_beat_label(beat_comparison, group_select);
        ref_base = format_beat_label(beat_reference, group_select);

        if strcmp(group_select, 'PC')
            group_suffix = '_{PC-group}';
        elseif strcmp(group_select, 'PAC')
            group_suffix = '_{PAC-group}';
        elseif strcmp(group_select, 'PVC')
            group_suffix = '_{PVC-group}';
        else
            group_suffix = ['_{', group_select, '-group}'];
        end

        comparison_label = [comp_base, group_suffix];
        reference_label = [ref_base, '_{Control-group}'];

    else
        % Within-subject comparison
        comp_base = format_beat_label(beat_comparison, group_select);
        ref_base = format_beat_label(beat_reference, group_select);

        comparison_label = comp_base;
        reference_label = ref_base;
    end

end
