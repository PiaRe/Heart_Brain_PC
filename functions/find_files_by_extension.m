function files = find_files_by_extension(directory_path, file_extension, ignore_missing)
    % FIND_FILES_BY_EXTENSION - Find files with specified extension in directory
    %
    % This utility function searches for files with a specific extension in a
    % given directory and returns a structure array with file information.
    %
    % Inputs:
    %   directory_path  - Path to directory to search (string)
    %   file_extension  - File extension to search for (string, e.g., '*.set', '*.vhdr')
    %   ignore_missing  - Optional: if true, don't error if directory doesn't exist (logical, default: false)
    %
    % Outputs:
    %   files - Structure array with file information (same format as dir() output)
    %
    % Examples:
    %   find_files_by_extension('/path/to/data', '*.set')
    %   find_files_by_extension('/path/to/data', '*.vhdr')
    %   find_files_by_extension('/path/to/data', '*.set', true) % Don't error if dir missing
    %
    % Author: Pia Reinfeld

    % Input validation
    if ~ischar(directory_path) && ~isstring(directory_path)
        error('directory_path must be a string or character array');
    end
    
    if ~ischar(file_extension) && ~isstring(file_extension)
        error('file_extension must be a string or character array');
    end
    
    if nargin < 3
        ignore_missing = false;
    end
    
    directory_path = char(directory_path);
    file_extension = char(file_extension);
    
    % Ensure extension starts with * if not provided
    if ~startsWith(file_extension, '*')
        if startsWith(file_extension, '.')
            file_extension = ['*' file_extension];
        else
            file_extension = ['*.' file_extension];
        end
    end
    
    % Check if directory exists
    if ~exist(directory_path, 'dir')
        if ignore_missing
            files = dir.empty; % Return empty dir structure
            return;
        else
            error('Directory does not exist: %s', directory_path);
        end
    end
    
    % Search for files
    search_pattern = fullfile(directory_path, file_extension);
    files = dir(search_pattern);
    
    % Optionally display found files count
    if isempty(files)
        fprintf('No %s files found in %s\n', file_extension, directory_path);
    else
        fprintf('Found %d %s files in %s\n', length(files), file_extension, directory_path);
    end
    
end
