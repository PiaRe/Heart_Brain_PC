function EEG = apply_crop_markers(EEG, crop_file_path, error_path, subjid)
    % APPLY_CROP_MARKERS - Apply crop markers to EEG data
    %
    % Inputs:
    %   EEG            - EEGLAB EEG structure
    %   crop_file_path - Full path to the crop marker file
    %   error_path     - Path to directory for error logs
    %   subjid         - Subject ID string
    %
    % Outputs:
    %   EEG            - Modified EEG structure with cropped data
    %
    % Author: Pia Reinfeld

    try
        % Load crop marker file
        start_table = readtable(crop_file_path);

        if height(start_table) >= 1 && width(start_table) >= 3
            start_marker = table2array(start_table(1, 3));

            if isa(start_marker, 'double') && ~isnan(start_marker)
                % Calculate start position (marker - 2 seconds)
                start_position = start_marker - 2 * EEG.srate;

                % Use last event as end marker
                if ~isempty(EEG.event)
                    endmark = EEG.event(end).latency;
                else
                    endmark = size(EEG.data, 2);
                end

                % Ensure valid range
                start_position = max(1, start_position);
                endmark = min(size(EEG.data, 2), endmark);

                if start_position < endmark
                    % Cut EEG data according to markers
                    EEG = pop_select(EEG, 'point', [start_position endmark]);
                    fprintf('Applied crop markers for subject %s\n', subjid);
                end

            else
                % Log missing start marker
                fileID = fopen(fullfile(error_path, 'no_start_marker.txt'), 'a+');
                fprintf(fileID, '\n%s %s\n', datestr(datetime), subjid);
                fclose(fileID);
            end

        end

    catch ME
        % Log crop marker error
        fileID = fopen(fullfile(error_path, 'crop_marker_error.txt'), 'a+');
        fprintf(fileID, '\n%s %s %s\n', datestr(datetime), subjid, ME.message);
        fclose(fileID);
    end

end
