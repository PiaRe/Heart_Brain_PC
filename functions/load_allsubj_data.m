function [allsubj_PC, allsubj_control] = load_allsubj_data(input_filename, varargin)
    % LOAD_ALLSUBJ_DATA - Smart loading of allsubj data with caching
    %
    % This function loads allsubj_PC and optionally allsubj_control data
    % but checks if the data is already in the base workspace to avoid
    % redundant loading of large variables.
    %
    % Syntax:
    %   [allsubj_PC, allsubj_control] = load_allsubj_data(input_filename)
    %   [allsubj_PC, allsubj_control] = load_allsubj_data(input_filename, 'ControlFile', control_filename)
    %
    % Inputs:
    %   input_filename - Full path to PC data file
    %
    % Optional Name-Value Pairs:
    %   'ControlFile' - Full path to control data file (if needed)
    %   'Force' - Force reload even if data exists (default: false)
    %
    % Outputs:
    %   allsubj_PC - PC group data structure
    %   allsubj_control - Control group data structure (empty if not requested)
    %
    % Example:
    %   [allsubj_PC, ~] = load_allsubj_data(pc_file);
    %   [allsubj_PC, allsubj_control] = load_allsubj_data(pc_file, 'ControlFile', ctrl_file);
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'input_filename', @ischar);
    addParameter(p, 'ControlFile', '', @ischar);
    addParameter(p, 'Force', false, @islogical);
    parse(p, input_filename, varargin{:});

    control_filename = p.Results.ControlFile;
    force_reload = p.Results.Force;

    %% Initialize outputs
    allsubj_PC = [];
    allsubj_control = [];

    %% Check if PC data already exists in base workspace
    load_pc = true;

    if ~force_reload
        % Check if variable exists in base workspace
        if evalin('base', 'exist(''allsubj_PC'', ''var'')')
            % Check if it's from the same file
            if evalin('base', 'exist(''allsubj_PC_source_file'', ''var'')')
                cached_file = evalin('base', 'allsubj_PC_source_file');

                if strcmp(cached_file, input_filename)
                    % Data is already loaded from the correct file
                    fprintf('Using cached PC data (already loaded from: %s)\n', input_filename);
                    allsubj_PC = evalin('base', 'allsubj_PC');
                    load_pc = false;
                end

            end

        end

    end

    %% Load PC data if needed
    if load_pc

        if ~exist(input_filename, 'file')
            error('Data file not found: %s', input_filename);
        end

        fprintf('Loading PC group data from: %s\n', input_filename);
        tic;
        load(input_filename, 'allsubj_PC');
        elapsed = toc;
        fprintf('  -> Loaded in %.2f seconds\n', elapsed);

        % Store in base workspace for future use
        assignin('base', 'allsubj_PC', allsubj_PC);
        assignin('base', 'allsubj_PC_source_file', input_filename);
    end

    %% Check if control data is requested
    if ~isempty(control_filename)
        load_control = true;

        if ~force_reload
            % Check if variable exists in base workspace
            if evalin('base', 'exist(''allsubj_control'', ''var'')')
                % Check if it's from the same file
                if evalin('base', 'exist(''allsubj_control_source_file'', ''var'')')
                    cached_file = evalin('base', 'allsubj_control_source_file');

                    if strcmp(cached_file, control_filename)
                        % Data is already loaded from the correct file
                        fprintf('Using cached control data (already loaded from: %s)\n', control_filename);
                        allsubj_control = evalin('base', 'allsubj_control');
                        load_control = false;
                    end

                end

            end

        end

        %% Load control data if needed
        if load_control

            if ~exist(control_filename, 'file')
                error('Control group data file not found: %s', control_filename);
            end

            fprintf('Loading control group data from: %s\n', control_filename);
            tic;
            load(control_filename, 'allsubj_control');
            elapsed = toc;
            fprintf('  -> Loaded in %.2f seconds\n', elapsed);

            % Store in base workspace for future use
            assignin('base', 'allsubj_control', allsubj_control);
            assignin('base', 'allsubj_control_source_file', control_filename);
        end

    end

end
