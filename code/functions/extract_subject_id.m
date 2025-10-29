function subjid = extract_subject_id(filename, file_extension)
    % EXTRACT_SUBJECT_ID - Extract subject ID from filename by removing extension
    %
    % This utility function extracts the subject ID from a filename by removing
    % the file extension. It handles common EEG file extensions.
    %
    % Inputs:
    %   filename       - The filename including extension (string)
    %   file_extension - Optional: specify extension length or type (string/numeric)
    %                   If not provided, auto-detects common extensions
    %
    % Outputs:
    %   subjid - Subject ID with extension removed (string)
    %
    % Examples:
    %   extract_subject_id('subject001.set') returns 'subject001'
    %   extract_subject_id('subject001.vhdr') returns 'subject001'
    %   extract_subject_id('subject001.set', '.set') returns 'subject001'
    %   extract_subject_id('subject001.set', 4) returns 'subject001'
    %
    % Author: Pia Reinfeld

    % Input validation
    if ~ischar(filename) && ~isstring(filename)
        error('filename must be a string or character array');
    end
    
    filename = char(filename); % Ensure char for compatibility
    
    % If no extension specified, auto-detect common EEG extensions
    if nargin < 2
        % Common EEG file extensions and their lengths
        extensions = {'.set', '.vhdr', '.vmrk', '.eeg'};
        extension_lengths = [4, 5, 5, 4];
        
        % Check which extension matches
        for i = 1:length(extensions)
            if endsWith(filename, extensions{i})
                chars_to_remove = extension_lengths(i);
                subjid = filename(1:end - chars_to_remove);
                return;
            end
        end
        
        % If no known extension found, assume 4 characters (.set default)
        chars_to_remove = 4;
        
    elseif isnumeric(file_extension)
        % Extension length specified as number
        chars_to_remove = file_extension;
        
    elseif ischar(file_extension) || isstring(file_extension)
        % Extension specified as string (e.g., '.set')
        file_extension = char(file_extension);
        if startsWith(file_extension, '.')
            chars_to_remove = length(file_extension);
        else
            error('Extension string must start with "." (e.g., ".set")');
        end
        
    else
        error('file_extension must be numeric (length) or string (extension)');
    end
    
    % Extract subject ID
    if length(filename) > chars_to_remove
        subjid = filename(1:end - chars_to_remove);
    else
        error('Filename "%s" is too short for specified extension length %d', filename, chars_to_remove);
    end
    
end
