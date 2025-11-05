function field_name = beattype_to_fieldname(beat_type)
    % BEATTYPE_TO_FIELDNAME - Convert beat type string to generic field name
    %
    % This function converts beat type strings (e.g., 'PAC+1', 'PVC-2') into generic
    % MATLAB field names by removing group prefix and replacing special characters.
    % Special case: iPAC and iPVC are mapped to 'zero'.
    %
    % Input:
    %   beat_type - String representing a beat type (e.g., 'PAC+1', 'PVC-2', 'iN', '0')
    %
    % Output:
    %   field_name - Generic MATLAB field name string (e.g., 'plus1', 'minus2', 'zero', 'iN')
    %
    % Examples:
    %   beattype_to_fieldname('PAC+1') returns 'plus1'
    %   beattype_to_fieldname('PVC-2') returns 'minus2'
    %   beattype_to_fieldname('iN') returns 'iN'
    %   beattype_to_fieldname('iPAC') returns 'zero'
    %   beattype_to_fieldname('iPVC') returns 'zero'
    %
    % Author: Pia Reinfeld

    % Remove PAC/PVC prefix if present
    field_name = regexprep(beat_type, '^(PAC|PVC)', '');
    % Replace special characters with text equivalents
    field_name = strrep(strrep(field_name, '+', 'plus'), '-', 'minus');
    % Remove any leading/trailing whitespace
    field_name = strtrim(field_name);
    % Special cases that become zero
    if strcmp(field_name, 'iPAC') || strcmp(field_name, 'iPVC') || strcmp(field_name, '0')
        field_name = 'zero';
    end

end
