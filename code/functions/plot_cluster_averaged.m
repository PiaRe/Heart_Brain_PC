function plot_cluster_averaged(stat, comparison_data_ga, reference_data_ga, comparison_label, reference_label, time_roi, save_path, filename, cluster_polarity, cluster_num, n_subjects)
    % PLOT_CLUSTER_AVERAGED - Plot averaged signal over significant cluster channels
    %
    % This function creates plots of averaged event-related signals (EEG/ECG)
    % over channels belonging to a significant cluster from cluster-based
    % permutation testing. Works for both EEG (HEP) and ECG data.
    %
    % Inputs:
    %   stat                - Statistical results from ft_timelockstatistics
    %   comparison_data_ga  - Grand average of comparison condition
    %   reference_data_ga   - Grand average of reference condition
    %   comparison_label    - Label for comparison condition (e.g., 'PAC+1')
    %   reference_label     - Label for reference condition (e.g., 'N')
    %   time_roi            - Time range of interest [tmin tmax]
    %   save_path           - Path to save figure
    %   filename            - Base filename for saving
    %   cluster_polarity    - 'pos', 'neg', or 'comb'
    %   cluster_num         - Cluster number to plot
    %   n_subjects          - Number of subjects for SEM calculation

    if ~exist(save_path, 'dir')
        mkdir(save_path);
    end

    % Check if cluster exists
    if strcmp(cluster_polarity, 'pos')

        if ~isfield(stat, 'posclusters') || isempty(stat.posclusters)
            fprintf('No significant positive cluster found.\n');
            return;
        end

        cluster_chan = stat.posclusterslabelmat == cluster_num;
        [ch_idx, ~] = find(cluster_chan);
        ch_idx = unique(ch_idx);
    elseif strcmp(cluster_polarity, 'neg')

        if ~isfield(stat, 'negclusters') || isempty(stat.negclusters)
            fprintf('No significant negative cluster found.\n');
            return;
        end

        cluster_chan = stat.negclusterslabelmat == cluster_num;
        [ch_idx, ~] = find(cluster_chan);
        ch_idx = unique(ch_idx);
    elseif strcmp(cluster_polarity, 'comb')
        % For combined, use all channels
        ch_idx = 1:size(stat.mask, 1);
    else
        error('cluster_polarity must be ''pos'', ''neg'', or ''comb''');
    end

    if isempty(ch_idx)
        fprintf('No channels found in cluster.\n');
        return;
    end

    % Check if this is ECG data (single channel named 'ECG')
    is_ecg = false;

    if length(comparison_data_ga.label) == 1 && strcmp(comparison_data_ga.label{1}, 'ECG')
        is_ecg = true;
        fprintf('Detected ECG data - will invert Y-axis (negative up, positive down)\n');
    end

    % Average across cluster channels
    avg_comparison = mean(comparison_data_ga.avg(ch_idx, :), 1);
    avg_reference = mean(reference_data_ga.avg(ch_idx, :), 1);

    % Calculate SEM
    sem_comparison = mean(sqrt(comparison_data_ga.var(ch_idx, :)), 1) / sqrt(n_subjects);
    sem_reference = mean(sqrt(reference_data_ga.var(ch_idx, :)), 1) / sqrt(n_subjects);

    % Time ROI indices
    time_roi_idx = comparison_data_ga.time >= time_roi(1) & comparison_data_ga.time <= time_roi(2);
    plot_time = comparison_data_ga.time(time_roi_idx);

    % Create figure
    figure;
    hold on;

    % Plot with bounded lines
    h1 = boundedline(plot_time, avg_comparison(time_roi_idx), sem_comparison(time_roi_idx), ...
        'cmap', [0.8500, 0.3250, 0.0980], 'alpha', 'LineWidth', 4);
    h2 = boundedline(plot_time, avg_reference(time_roi_idx), sem_reference(time_roi_idx), ...
        'cmap', [0, 0.4470, 0.7410], 'alpha', 'LineWidth', 4);

    % Labels and formatting
    ylabel('Amplitude in µV', 'FontSize', 14);
    xlabel('Time in s', 'FontSize', 14);
    ax = gca;
    ax.FontName = 'Roboto';
    ax.FontSize = 12;

    % Add significance shading
    if strcmp(cluster_polarity, 'pos')
        pos_clust = find([stat.posclusters.prob] < 0.025);
        pos = ismember(stat.posclusterslabelmat, pos_clust);
        highlight = mean(pos(ch_idx, time_roi_idx), 1) > 0;
    elseif strcmp(cluster_polarity, 'neg')
        neg_clust = find([stat.negclusters.prob] < 0.025);
        neg = ismember(stat.negclusterslabelmat, neg_clust);
        highlight = mean(neg(ch_idx, time_roi_idx), 1) > 0;
    else
        highlight = mean(stat.mask(ch_idx, time_roi_idx), 1) > 0;
    end

    % Find significant segments
    begsample = find(diff([0 highlight 0]) == 1);
    endsample = find(diff([0 highlight 0]) == -1) - 1;

    ylim_orig = ylim;

    % Shade significant regions
    for i = 1:length(begsample)
        begx = plot_time(begsample(i));
        endx = plot_time(endsample(i));
        ft_plot_box([begx endx ylim], 'facealpha', 0.25, 'facecolor', [0 0 0], 'edgecolor', 'none');
        set(gca, 'YLim', ylim_orig);
    end

    % Send patches to back
    set(gca, 'children', flipud(get(gca, 'children')));
    set(gca, 'Layer', 'top');

    % Invert Y-axis for ECG plots (negative up, positive down)
    if is_ecg
        set(gca, 'YDir', 'reverse');
        fprintf('Y-axis inverted for ECG plot\n');
    end

    axis tight;
    leg = legend([h1, h2], {['HEP_{', comparison_label, '}'], ['HEP_{', reference_label, '}']}, ...
        'Location', 'Best', 'FontSize', 14);
    legend('boxoff');
    leg.ItemTokenSize = [20, 20];
    leg.LineWidth = 3;
    grid on;

    % Save figure
    set(gcf, 'units', 'centimeters', 'pos', [0 0 15 10]);
    pos = get(gcf, 'Position');
    set(gcf, 'PaperPositionMode', 'Auto', 'PaperUnits', 'centimeters', 'PaperSize', [pos(3), pos(4)]);

    exportgraphics(gcf, fullfile(save_path, [filename, '_', cluster_polarity, '_cluster_avg.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'none');

    close(gcf);
end
