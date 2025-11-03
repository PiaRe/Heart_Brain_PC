function [EEG, cV, rejV] = ecg_ica_corr(EEG, ECG_template, R_marker, time_window, SDcrit)
    % ECG_ICA_CORR - Identifies ECG-related ICA components by correlation.
    %
    % Syntax:  [EEG, cV, rejV] = ecg_ica_corr(EEG, ECG_template, time_window, R_marker, SDcrit)
    %
    % Inputs:
    %    EEG - EEG structure containing ICA activations (already epoched).
    %    ECG_template - ECG template for correlation (required).
    %    R_marker - Heartbeat events to epoch ICA component
    %    time_window - Timewindow for epoched ICA analysis
    %    SDcrit - Standard deviation criterion for identifying ECG components.
    %
    % Outputs:
    %    EEG - EEG structure with identified ECG components.
    %    cV - Correlation values of ICA components with ECG template.
    %    rejV - Logical vector indicating rejected components.
    %
    % Description:
    %    This function identifies ECG-related Independent Component Analysis (ICA)
    %    components by correlating them with an ECG template. It performs the following steps:
    %    1) Uses the already epoched ICA activations.
    %    2) Calculates the correlation of each average ICA waveform to the ECG template.
    %    3) Identifies components above a certain standard deviation threshold as ECG artifacts.
    %    4) Checks for oscillatory peaks to preserve potential brain-like activity.
    %
    % Example:
    %    [EEG, cV, rejV] = ecg_ica_corr(EEG, ECG_template, [], [], 1.5);
    %
    % See also: pop_epoch, pop_rmbase, compute_RP

    % Create a temporary EEG structure for ICA data
    EEGtemp = EEG;

    %get back ICA activity
    EEG = eeg_checkset(EEG, 'ica');
    EEG.icaact = (EEG.icaweights * EEG.icasphere) * EEG.data(EEG.icachansind, :);

    EEGtemp.data = EEG.icaact;
    add_chans = size(EEG.data, 1) - size(EEGtemp.data, 1);

    if ndims(EEGtemp.data) <= 2
        %exchange EEG data with ICA data for easier epoching
        if size(EEGtemp.data, 1) ~= size(EEG.data, 1)
            EEGtemp.data = [EEGtemp.data; zeros(add_chans, length(EEGtemp.data))];
        end

        %Epoch ICA data
        EEGtemp = pop_epoch(EEGtemp, R_marker, time_window);

        if add_chans > 0
            EEGtemp.data(end - add_chans + 1:end, :, :) = [];
        end

    end

    % Calculate the average ICA component across epochs
    avgIC = mean(EEGtemp.data, 3);

    % Calculate correlation values with the ECG template
    cV = abs(corr(avgIC', ECG_template'));
    % Determine the correlation threshold
    corthreshV = mean(cV) + SDcrit * std(cV);
    % Identify components that exceed the threshold
    rejV = cV > corthreshV;
    % Find the indices of rejected components
    comps = find(rejV);

    % If no components are identified, display a message
    if sum(comps) == 0
        disp('No ECG components identified')
    else

        % Check for alpha relative power to preserve potential brain-like activity
        for k = 1:sum(rejV)

            comp = comps(k);
            alpha_rel_pow = compute_RP(EEGtemp.data(comp, :), 500, [1, 45], [7 15]);

            % if peak greater than 50% - keep the component
            if alpha_rel_pow > 0.5
                rejV(comps(k)) = 0;
            else
            end

        end

    end

end
