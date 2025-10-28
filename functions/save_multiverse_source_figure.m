function save_multiverse_source_figure(title_text, save_path, filename_base)
    % SAVE_MULTIVERSE_SOURCE_FIGURE Save brain source visualization with multiverse analysis results
    %
    % This function combines multiple brain views into a single figure showing
    % the percentage of significant multiverse analysis pipelines per brain region.
    % It is specifically designed for HEP source reconstruction multiverse analyses.
    %
    % Inputs:
    %   title_text     - Title for the figure (supports LaTeX formatting)
    %   save_path      - Directory path where the figure will be saved
    %   filename_base  - Base name for the output file (without extension)
    %
    % Output:
    %   Saves a PDF figure with 6 brain views (lateral, medial, dorsal, ventral,
    %   anterior, posterior) showing multiverse analysis results with colorbar
    %
    % Example:
    %   save_multiverse_source_figure('HEP Comparison', '/output/path', 'hep_analysis')
    %
    % Note: This function expects 6 individual brain view figures (1-6) to be
    % already created by allplots_cortex_mina or plot_brain_surface_visualization
    %
    % Author: Pia Reinfeld
    % Date: 2025
    % Project: Heart-Brain Coupling in Premature Contractions

    % Validate inputs
    if nargin < 3
        error('save_multiverse_source_figure requires 3 inputs: title_text, save_path, filename_base');
    end

    % Create save directory if it doesn't exist
    if ~exist(save_path, 'dir')
        mkdir(save_path);
        fprintf('Created output directory: %s\n', save_path);
    end

    % Configuration
    num_views = 6; % Number of brain views to combine
    num_rows = 1; % Single row layout

    % Create main figure (hidden until complete)
    main_figure = figure('visible', 'off');
    set(main_figure, 'Color', 'white');

    % Initialize subplot array
    subplot_handles = gobjects(num_views, 1);

    % Collect and arrange all brain view plots
    for view_idx = 1:num_views
        % Get the source figure
        source_fig = figure(view_idx);
        source_ax = gca;
        source_children = get(source_ax, 'children');

        % Switch to main figure and create subplot
        figure(main_figure);
        subplot_handles(view_idx) = subplot(num_rows, num_views, view_idx);

        % Copy graphics objects from source to subplot
        copyobj(source_children, subplot_handles(view_idx));
        axis off;

        % Copy view properties from original plot
        set(subplot_handles(view_idx), ...
            'CLim', get(source_ax, 'CLim'), ...
            'View', get(source_ax, 'View'), ...
            'XLim', get(source_ax, 'XLim'), ...
            'YLim', get(source_ax, 'YLim'), ...
            'ZLim', get(source_ax, 'ZLim'));

        % Set subplot dimensions based on view type
        if ismember(view_idx, [1, 2, 3, 4])
            % Lateral and dorsal/ventral views
            height = 0.4;
            width = 0.12;
        elseif ismember(view_idx, [5, 6])
            % Anterior and posterior views
            height = 0.5;
            width = 0.10;
        else
            warning('Unexpected view index: %d', view_idx);
            height = 0.4;
            width = 0.12;
        end

        % Position subplot in horizontal layout
        x_position = 0.05 + (view_idx - 1) * 0.13;
        y_position = 0.5 - height / 2;
        set(subplot_handles(view_idx), 'Position', [x_position, y_position, width, height]);
    end

    % Add main title
    sgtitle(title_text, 'Interpreter', 'latex', 'FontSize', 15);

    % Configure colormap (use BrewerMap if available for better visualization)
    if exist('brewermap', 'file')

        try
            color_steps = 100;
            % ft_hastoolbox('brewermap', 1);
            colormap(brewermap(color_steps, 'BuGn')); % Blue-Green sequential colormap
        catch
            colormap('parula'); % Fallback to default
        end

    else
        colormap('parula');
    end

    % Add colorbar with descriptive label
    colorbar_handle = colorbar('Position', [0.86, 0.15, 0.03, 0.7]);
    colorbar_handle.FontSize = 10;
    colorbar_handle.Label.FontSize = 10;
    colorbar_handle.Label.String = {'Significantly different', 'multiverse pipelines in %'};

    % Set figure size (optimized for publication)
    set(main_figure, 'Units', 'centimeters', 'Position', [0, 0, 20, 5]);
    figure_position = get(main_figure, 'Position');
    set(main_figure, 'PaperPositionMode', 'Auto', ...
        'PaperUnits', 'centimeters', ...
        'PaperSize', [figure_position(3), figure_position(4)]);

    fprintf('Patience, saving the multiverse source figure in pdf format takes up to a few minutes');
    % Save as pdf
    output_filepath = fullfile(save_path, [filename_base, '.pdf']);
    exportgraphics(main_figure, output_filepath, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Resolution', 300);

    fprintf('Multiverse source figure saved: %s\n', output_filepath);

    % Close all figures to free memory
    close all;

end
