function plot_topomap_comparison(stat, comparison_data_ga, reference_data_ga, difference_data_ga, comparison_label, reference_label, time_array, save_path, filename, cluster_polarity, cluster_num, layout)
    % PLOT_TOPOMAP_COMPARISON - Plot topographies for three conditions
    %
    % Inputs:
    %   stat                 - Statistical results from ft_timelockstatistics
    %   comparison_data_ga   - Grand average of comparison condition
    %   reference_data_ga    - Grand average of reference condition
    %   difference_data_ga   - Grand average of difference (comparison - reference)
    %   comparison_label     - Label for comparison condition (e.g., 'PAC+1')
    %   reference_label      - Label for reference condition (e.g., 'N')
    %   time_array           - Time vector
    %   save_path            - Path to save figure
    %   filename             - Base filename for saving
    %   cluster_polarity     - 'pos' or 'neg'
    %   cluster_num          - Cluster number to plot
    %   layout               - FieldTrip layout structure

    if ~exist(save_path, 'dir')
        mkdir(save_path);
    end

    % Check if cluster exists and get channels
    if strcmp(cluster_polarity, 'pos')

        if ~isfield(stat, 'posclusters') || isempty(stat.posclusters)
            fprintf('No significant positive cluster found.\n');
            return;
        end

        pos_cluster_pvals = [stat.posclusters(:).prob];
        pos_clust = find(pos_cluster_pvals < 0.025);
        pos = stat.posclusterslabelmat == cluster_num;

        [pos_a, pos_b] = find(pos);
        cluster_chan = unique(pos_a);

        if size(pos, 2) == 1
            time_window = stat.cfg.latency;
        else
            time_window = [time_array(min(pos_b)) time_array(max(pos_b))];
        end

        cluster_title = 'Positive Cluster';

    elseif strcmp(cluster_polarity, 'neg')

        if ~isfield(stat, 'negclusters') || isempty(stat.negclusters)
            fprintf('No significant negative cluster found.\n');
            return;
        end

        neg_cluster_pvals = [stat.negclusters(:).prob];
        neg_clust = find(neg_cluster_pvals < 0.025);
        neg = stat.negclusterslabelmat == cluster_num;

        [neg_a, neg_b] = find(neg);
        cluster_chan = unique(neg_a);

        if size(neg, 2) == 1
            time_window = stat.cfg.latency;
        else
            time_window = [time_array(min(neg_b)) time_array(max(neg_b))];
        end

        cluster_title = 'Negative Cluster';

    else
        error('cluster_polarity must be ''pos'' or ''neg''');
    end

    if isempty(cluster_chan)
        fprintf('No channels found in cluster.\n');
        return;
    end

    % Configure plotting
    cfg = [];
    cfg.comment = 'no';
    cfg.layout = layout;
    cfg.xlim = time_window;

    % Create topoplots without highlighting first
    ft_topoplotER(cfg, comparison_data_ga);
    ax1 = gca;

    ft_topoplotER(cfg, reference_data_ga);
    ax2 = gca;

    % Add highlighting for difference plot
    cfg.highlight = 'on';
    cfg.highlightcolor = 'w';
    cfg.highlightsymbol = '.';
    cfg.highlightsize = 14;
    cfg.highlightchannel = cluster_chan;

    ft_topoplotER(cfg, difference_data_ga);
    ax3 = gca;

    % Create new figure with subplots
    figure;

    % Create subplots
    s1 = subplot(1, 3, 1);
    fig1 = get(ax1, 'children');
    copyobj(fig1, s1);
    axis off;

    s2 = subplot(1, 3, 2);
    fig2 = get(ax2, 'children');
    copyobj(fig2, s2);
    axis off;

    s3 = subplot(1, 3, 3);
    fig3 = get(ax3, 'children');
    copyobj(fig3, s3);
    axis off;

    % Add titles
    title(s1, ['HEP_{', comparison_label, '}'], 'FontSize', 10);
    title(s2, ['HEP_{', reference_label, '}'], 'FontSize', 10);
    title(s3, ['HEP_{', comparison_label, '} - HEP_{', reference_label, '}'], 'FontSize', 10);

    % Position subplots
    set(s1, 'Position', [0.05, 0.15, 0.2, 0.6]);
    set(s2, 'Position', [0.325, 0.15, 0.2, 0.6]);
    set(s3, 'Position', [0.6, 0.15, 0.2, 0.6]);

    % Set color limits
    clim(s1, [-1, 1]);
    clim(s2, [-1, 1]);
    clim(s3, [-1, 1]);

    % Add colorbar
    ft_hastoolbox('brewermap', 1);
    colormap(flipud(brewermap(1024, 'RdBu')));
    c = colorbar('Position', [0.87 0.1 0.02 0.8]);
    c.FontSize = 10;
    c.Label.FontSize = 12;
    c.Label.String = 'Ampl. in µV';

    % Add title
    sgtitle(cluster_title, 'FontSize', 13);

    % Add time window annotation
    annotation('textbox', [0, 0.1, 1, 0.05], 'FontSize', 11, ...
        'String', ['time window: ', num2str(time_window(1)), ' s - ', num2str(time_window(2)), ' s'], ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center');

    % Save figure
    set(gcf, 'units', 'centimeters', 'pos', [0 0 15 5]);
    pos = get(gcf, 'Position');
    set(gcf, 'PaperPositionMode', 'Auto', 'PaperUnits', 'centimeters', 'PaperSize', [pos(3), pos(4)]);

    exportgraphics(gcf, fullfile(save_path, [filename, '_', cluster_polarity, '_3topo.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    close(gcf);
end
