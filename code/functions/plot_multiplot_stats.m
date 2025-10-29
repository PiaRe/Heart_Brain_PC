function plot_multiplot_stats(stat, comparison_data_ga, reference_data_ga, comparison_label, reference_label, layout, time_roi, save_path, filename)
    % PLOT_MULTIPLOT_STATS - Create multiplot with statistical results
    %
    % Inputs:
    %   stat                - Statistical results from ft_timelockstatistics
    %   comparison_data_ga  - Grand average of comparison condition
    %   reference_data_ga   - Grand average of reference condition
    %   comparison_label    - Label for comparison condition (e.g., 'PAC+1')
    %   reference_label     - Label for reference condition (e.g., 'N')
    %   layout              - FieldTrip layout structure
    %   time_roi            - Time range of interest [tmin tmax]
    %   save_path           - Path to save figure
    %   filename            - Base filename for saving

    if ~exist(save_path, 'dir')
        mkdir(save_path);
    end

    % Add mask to data
    comparison_data_ga.mask = stat.mask;
    reference_data_ga.mask = stat.mask;

    % Create multiplot
    figure;
    cfg = [];
    cfg.layout = layout;
    cfg.channel = {'all', '-ECG'};
    cfg.graphcolor = [[0, 0.4470, 0.7410]; [0.8500, 0.3250, 0.0980]];
    cfg.linewidth = 2;
    cfg.maskparameter = 'mask';
    cfg.maskstyle = 'box';
    cfg.maskfacealpha = 0.5;
    cfg.showlabels = 'yes';
    cfg.showcomment = 'no';
    cfg.xlim = time_roi;

    ft_multiplotER(cfg, reference_data_ga, comparison_data_ga);

    hold on;

    % Add legend
    h1 = plot(nan, nan, 'Color', [0, 0.4470, 0.7410], 'LineWidth', 2);
    h2 = plot(nan, nan, 'Color', [0.8500, 0.3250, 0.0980], 'LineWidth', 2);

    legend([h1, h2], {['HEP_{', reference_label, '}'], ['HEP_{', comparison_label, '}']});

    set(gcf, 'units', 'centimeters', 'pos', [0 0 25 20]);
    pos = get(gcf, 'Position');
    set(gcf, 'PaperPositionMode', 'Auto', 'PaperUnits', 'centimeters', 'PaperSize', [pos(3), pos(4)]);

    % Save figure
    exportgraphics(gcf, fullfile(save_path, [filename, '_multiplot.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    close(gcf);
end
