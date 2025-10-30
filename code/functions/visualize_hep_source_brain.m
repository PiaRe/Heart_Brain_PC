function visualize_hep_source_brain(surface_atlas, source_data, color_limits, colormap_brain, smooth_flag, varargin)
    % VISUALIZE_HEP_SOURCE_BRAIN - Visualize HEP source reconstruction results on brain surface
    %
    % This function creates multiple views of brain surface visualizations with
    % source-reconstructed HEP data overlaid on the cortical surface.
    %
    % Syntax:
    %   visualize_hep_source_brain(surface_atlas, source_data, color_limits, ...
    %                              colormap_brain, smooth_flag, varargin)
    %
    % Inputs:
    %   surface_atlas   - Structure containing cortical surface information (sa)
    %   source_data     - Source activity values to be plotted on the surface
    %   color_limits    - [min, max] color scale limits for visualization
    %   colormap_brain  - Colormap to use for plotting (e.g., cm17, cm9)
    %   smooth_flag     - Boolean (1/0): use smoothed or standard surface
    %
    % Optional Parameters (Name-Value pairs):
    %   'views'         - Vector of view indices to plot (default: [1,2,3,4,5,8])
    %                     1 = left lateral    2 = left medial
    %                     3 = right lateral   4 = right medial
    %                     5 = dorsal          6 = dorsal horizontal
    %                     7 = ventral         8 = ventral horizontal
    %   'save'          - Boolean (1/0): save figures to disk (default: 1)
    %   'savename'      - Base filename for saved figures (default: 'hep_source')
    %   'saveformat'    - File format for saving (default: 'pdf')
    %
    % Example:
    %   visualize_hep_source_brain(sa, source_activity, [0 100], cm17, 'xx', 1, ...
    %                              'views', [1,2,3,4,5,8], 'save', 1, ...
    %                              'savename', 'PVC_vs_PVC-3', 'saveformat', 'pdf')
    %
    % Notes:
    %   - Original function by Stefan Haufe
    %   - Modified by Mina Jamshidi for flexible parameter handling
    %   - Adapted for HEP_ES project by Pia Reinfeld (2025)
    %   - Renamed for project-specific clarity and documentation
    %
    % See also: save_multiverse_source_figure, showsurface_adapted
    %
    % Author: Pia Reinfeld
    % Date: 2025

    %% Initialize figure settings
    set(0, 'DefaultFigureColor', [1 1 1]);
    views_to_plot = [1, 2, 3, 4, 5, 8];

    %% Select surface vertices based on smoothing option
    if smooth_flag
        cortex_vertices = surface_atlas.cortex75K.vc_smooth;
    else
        cortex_vertices = surface_atlas.cortex75K.vc;
    end

    %% Configure surface plotting parameters
    surface_params = struct( ...
        'alpha_const', 1, ...
        'mycolormap', colormap_brain, ...
        'colorlimits', color_limits, ...
        'showdirections', 0, ...
        'colorbars', 0, ...
        'dipnames', [], ...
        'mymarkersize', 15, ...
        'directions', [0 0 1 1 1 1], ...
        'printcbar', 1, ...
        'userticks', []);

    %% Generate brain surface plots for each requested view

    % LEFT HEMISPHERE VIEWS
    surface_params.myviewdir = [-1 0 0];

    % View 1: Left lateral
    if ismember(1, views_to_plot)
        figure('Name', 'Left Lateral View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri_left, surface_params, source_data);

    end

    % View 2: Left medial
    if ismember(2, views_to_plot)
        figure('Name', 'Left Medial View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri_right, surface_params, source_data);

    end

    % RIGHT HEMISPHERE VIEWS
    surface_params.myviewdir = [1 0 0];

    % View 3: Right lateral
    if ismember(3, views_to_plot)
        figure('Name', 'Right Lateral View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri_right, surface_params, source_data);

    end

    % View 4: Right medial
    if ismember(4, views_to_plot)
        figure('Name', 'Right Medial View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri_left, surface_params, source_data);

    end

    % DORSAL VIEWS
    surface_params.myviewdir = [0 0 1];

    % View 5: Dorsal (top view)
    if ismember(5, views_to_plot)
        figure('Name', 'Dorsal View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri, surface_params, source_data);

    end

    % View 6: Dorsal horizontal
    if ismember(6, views_to_plot)
        surface_params.myviewdir = [-1e-10 0 1];
        surface_params.directions = [1 0 1 1 0 0];
        figure('Name', 'Dorsal Horizontal View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri, surface_params, source_data);

        % Reset directions for other views
        surface_params.directions = [0 0 1 1 1 1];
    end

    % VENTRAL VIEWS
    surface_params.myviewdir = [-1e-10 0 -1];

    % View 7: Ventral (bottom view)
    if ismember(7, views_to_plot)
        figure('Name', 'Ventral View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri, surface_params, source_data);

    end

    % View 8: Ventral horizontal
    if ismember(8, views_to_plot)
        surface_params.myviewdir = [0 1e-10 -1];
        figure('Name', 'Ventral Horizontal View', 'NumberTitle', 'off');
        showsurface_adapted(cortex_vertices, surface_atlas.cortex75K.tri, surface_params, source_data);

    end

    %% Save colorbar scale

    % Reset figure settings
    set(0, 'DefaultFigureColor', [1 1 1]);

end
