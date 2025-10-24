function save_cluster_specifications(stat, savepath, savefile)
    % SAVE_CLUSTER_SPECIFICATIONS - Export cluster specifications to CSV file
    %
    % This function extracts information about significant clusters from
    % FieldTrip statistical results and saves them to a CSV file.
    %
    % Inputs:
    %   stat      - FieldTrip statistics structure from ft_timelockstatistics
    %   savepath  - Directory path where CSV file should be saved
    %   savefile  - Base filename for the CSV file (without extension)
    %
    % Output:
    %   Creates a CSV file: [savepath]/[savefile].csv
    %   Contains: ClusterType, ClusterNumber, Channels, TimeStart, TimeEnd,
    %             Probability, ClusterStat, StdDev, CIRange
    %
    % Author: Pia Reinfeld
    % Date: October 2025

    % Ensure save path exists
    if ~exist(savepath, 'dir')
        mkdir(savepath);
    end

    % Open CSV file for writing
    csv_file = fullfile(savepath, [savefile, '.csv']);
    fid = fopen(csv_file, 'w');

    if fid == -1
        error('Could not create CSV file: %s', csv_file);
    end

    % Write header
    fprintf(fid, 'ClusterType,ClusterNumber,Channels,TimeStart,TimeEnd,Probability,ClusterStat,StdDev,CIRange\n');

    % Process positive clusters
    if isfield(stat, 'posclusters') && ~isempty(stat.posclusters)

        pos_cluster_pvals = [stat.posclusters(:).prob];
        pos_clust = find(pos_cluster_pvals < 0.025);

        % If no significant clusters, still export the first one for reference
        if isempty(pos_clust)
            pos_clust = 1;
        end

        for clust_num = pos_clust
            % Find channels and time points in this cluster
            pos = stat.posclusterslabelmat == clust_num;
            [pos_a, pos_b] = find(pos);

            % Get channel labels
            if isfield(stat, 'label')
                pos_chan = stat.label(unique(pos_a));
            elseif isfield(stat, 'elec') && isfield(stat.elec, 'label')
                pos_chan = stat.elec.label(unique(pos_a));
            else
                pos_chan = arrayfun(@(x) sprintf('Ch%d', x), unique(pos_a), 'UniformOutput', false);
            end

            % Get time window
            pos_time = [stat.time(min(pos_b)) stat.time(max(pos_b))];

            % Get cluster statistics
            pos_stat_prob = stat.posclusters(1, clust_num).prob;
            pos_stat_clusterstat = stat.posclusters(1, clust_num).clusterstat;

            % Optional fields (may not always be present)
            if isfield(stat.posclusters, 'stddev')
                pos_stat_stddev = stat.posclusters(1, clust_num).stddev;
            else
                pos_stat_stddev = NaN;
            end

            if isfield(stat.posclusters, 'cirange')
                pos_stat_cirange = stat.posclusters(1, clust_num).cirange;
            else
                pos_stat_cirange = NaN;
            end

            % Write to CSV
            fprintf(fid, 'Positive,%d,%s,%.4f,%.4f,%.6f,%.4f,%.4f,%.4f\n', ...
                clust_num, strjoin(pos_chan, '|'), pos_time(1), pos_time(2), ...
                pos_stat_prob, pos_stat_clusterstat, pos_stat_stddev, pos_stat_cirange);
        end

    end

    % Process negative clusters
    if isfield(stat, 'negclusters') && ~isempty(stat.negclusters)

        neg_cluster_pvals = [stat.negclusters(:).prob];
        neg_clust = find(neg_cluster_pvals < 0.025);

        % If no significant clusters, still export the first one for reference
        if isempty(neg_clust)
            neg_clust = 1;
        end

        for clust_num = neg_clust
            % Find channels and time points in this cluster
            neg = stat.negclusterslabelmat == clust_num;
            [neg_a, neg_b] = find(neg);

            % Get channel labels
            if isfield(stat, 'label')
                neg_chan = stat.label(unique(neg_a));
            elseif isfield(stat, 'elec') && isfield(stat.elec, 'label')
                neg_chan = stat.elec.label(unique(neg_a));
            else
                neg_chan = arrayfun(@(x) sprintf('Ch%d', x), unique(neg_a), 'UniformOutput', false);
            end

            % Get time window
            neg_time = [stat.time(min(neg_b)) stat.time(max(neg_b))];

            % Get cluster statistics
            neg_stat_prob = stat.negclusters(1, clust_num).prob;
            neg_stat_clusterstat = stat.negclusters(1, clust_num).clusterstat;

            % Optional fields (may not always be present)
            if isfield(stat.negclusters, 'stddev')
                neg_stat_stddev = stat.negclusters(1, clust_num).stddev;
            else
                neg_stat_stddev = NaN;
            end

            if isfield(stat.negclusters, 'cirange')
                neg_stat_cirange = stat.negclusters(1, clust_num).cirange;
            else
                neg_stat_cirange = NaN;
            end

            % Write to CSV
            fprintf(fid, 'Negative,%d,%s,%.4f,%.4f,%.6f,%.4f,%.4f,%.4f\n', ...
                clust_num, strjoin(neg_chan, '|'), neg_time(1), neg_time(2), ...
                neg_stat_prob, neg_stat_clusterstat, neg_stat_stddev, neg_stat_cirange);
        end

    end

    % Close file
    fclose(fid);

    fprintf('Cluster specifications saved to: %s\n', csv_file);
end
