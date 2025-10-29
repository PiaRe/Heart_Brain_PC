function create_dirs(dirs_to_create)
% CREATE_DIRS - Creates directories if they don't exist
%
% Input:
%   dirs_to_create - cell array of directory paths to create
%
% Author: Pia Reinfeld

for i = 1:length(dirs_to_create)
    if ~exist(dirs_to_create{i}, 'dir')
        mkdir(dirs_to_create{i});
        fprintf('Created directory: %s\n', dirs_to_create{i});
    else
        fprintf('Directory already exists: %s\n', dirs_to_create{i});
    end
end

end
