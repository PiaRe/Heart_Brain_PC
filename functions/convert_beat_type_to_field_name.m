function field_name = convert_beat_type_to_field_name(beat_type)
    % CONVERT_BEAT_TYPE_TO_FIELD_NAME - Convert beat type string to valid MATLAB field name
    %
    % This function converts beat type strings (e.g., 'PAC+1', 'PVC-2') into valid
    % MATLAB field names by replacing special characters with text equivalents.
    %
    % Input:
    %   beat_type - String representing a beat type (e.g., 'PAC+1', 'PVC-2', 'iN')
    %
    % Output:
    %   field_name - Valid MATLAB field name string (e.g., 'PACplus1', 'PVCminus2', 'iN')
    %
    % Examples:
    %   convert_beat_type_to_field_name('PAC+1') returns 'PACplus1'
    %   convert_beat_type_to_field_name('PVC-2') returns 'PVCminus2'
    %   convert_beat_type_to_field_name('iN') returns 'iN'
    %
    % Author: Pia Reinfeld
    
    % Replace special characters with text equivalents
    field_name = strrep(strrep(beat_type, '+', 'plus'), '-', 'minus');
end
