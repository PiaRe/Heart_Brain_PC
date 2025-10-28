function plot_brain_surface_visualization(cortex_surface, source_data, color_limits, colormap_data, varargin)
    % PLOT_BRAIN_SURFACE_VISUALIZATION Visualize brain source data on cortical surface
    %
    % This function creates multiple views of brain surface plots showing source
    % reconstruction results. It is a project-specific wrapper around the
    % allplots_cortex_mina function for HEP source analysis visualization.
    %
    % Inputs:
    %   cortex_surface - Structure containing cortical surface mesh data
    %                    (from source_atlas_eloreta.mat)
    %   source_data    - Vector of source amplitudes/values to plot on surface
    %                    Must match the number of cortical vertices
    %   color_limits   - [min, max] color scale limits (e.g., [0 100] for percentages)
    %   colormap_data  - Colormap matrix (n_colors x 3 RGB values)
    %   varargin       - Additional optional parameters as name-value pairs:
    %                    'views'  : Array of view indices (default: [1,2,3,4,5,8])
    %                               1=left lateral, 2=right lateral, 3=dorsal,
    %                               4=ventral, 5=anterior, 8=posterior
    %                    'save'   : Whether to save individual view figures (0 or 1)
    %                    'marker' : Marker string (default: 'xx')
    %                    'alpha'  : Transparency value (default: 1)
    %
    % Output:
    %   Creates 6 figure windows with different brain views
    %
    % Example:
    %   plot_brain_surface_visualization(sa, source_values, [0 100], colormap_brain, ...
    %       'views', [1,2,3,4,5,8], 'save', 0);
    %
    % Dependencies:
    %   Requires allplots_cortex_mina to be in MATLAB path
    %
    % Author: Pia Reinfeld
    % Date: 2025
    % Project: Heart-Brain Coupling in Premature Contractions

    % Validate inputs
    if nargin < 4
        error('plot_brain_surface_visualization requires at least 4 inputs');
    end

    % Set default parameter values
    default_marker = 'xx';
    default_alpha = 1;
    default_views = [1, 2, 3, 4, 5, 8]; % Standard 6 views
    default_save = 0;

    % Parse optional parameters
    p = inputParser;
    addParameter(p, 'marker', default_marker, @ischar);
    addParameter(p, 'alpha', default_alpha, @isnumeric);
    addParameter(p, 'views', default_views, @isnumeric);
    addParameter(p, 'save', default_save, @isnumeric);

    % Allow additional parameters to be passed through
    p.KeepUnmatched = true;
    parse(p, varargin{:});

    marker = p.Results.marker;
    alpha_value = p.Results.alpha;
    views = p.Results.views;
    save_flag = p.Results.save;

    % Validate source data dimensions
    if ~isvector(source_data)
        error('source_data must be a vector');
    end

    % Validate color limits
    if numel(color_limits) ~= 2 || color_limits(1) >= color_limits(2)
        error('color_limits must be [min, max] with min < max');
    end

    % Call the external visualization function
    try
        allplots_cortex_mina(cortex_surface, source_data, color_limits, ...
            colormap_data, marker, alpha_value, ...
            'views', views, 'save', save_flag);

        fprintf('Brain surface visualization created with %d views\n', length(views));

    catch ME
        % Provide helpful error message if external function is not available
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
            error(['The external function ''allplots_cortex_mina'' is not found in the MATLAB path.\n' ...
                       'Please ensure it is available or add its directory to the path.\n' ...
                   'Original error: %s'], ME.message);
        else
            rethrow(ME);
        end

    end

end
