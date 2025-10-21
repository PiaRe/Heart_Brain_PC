function data_with_bsl = apply_baseline(bsl, data)
    % APPLY_BASELINE - Apply baseline correction using precomputed baseline values
    %
    % This function applies baseline correction to fieldtrip data using
    % precomputed baseline values from a reference condition.
    %
    % Inputs:
    %   bsl  - Cell array of baseline values (one per trial)
    %   data - Fieldtrip data structure
    %
    % Outputs:
    %   data_with_bsl - Fieldtrip data structure with baseline correction applied
    %
    % Author: Pia Reinfeld

    data_with_bsl = data;

    for itrial = 1:size(data.trial, 2)
        data_with_bsl.trial{itrial} = data.trial{itrial} - bsl{itrial};
    end

end
