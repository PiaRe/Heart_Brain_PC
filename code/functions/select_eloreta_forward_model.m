function [forward_model, regularization_label] = select_eloreta_forward_model(alpha_value, ...
        forward_model_smooth, forward_model_standard, forward_model_focal)
    % SELECT_ELORETA_FORWARD_MODEL - Select appropriate eLORETA forward model
    %
    % Inputs:
    %   alpha_value              - Regularization parameter (0.5, 0.05, or 0.001)
    %   forward_model_smooth     - Smooth regularization forward model (alpha=0.5)
    %   forward_model_standard   - Standard regularization forward model (alpha=0.05)
    %   forward_model_focal      - Focal regularization forward model (alpha=0.001)
    %
    % Outputs:
    %   forward_model          - Selected forward model matrix
    %   regularization_label   - String label for the alpha value
    %
    % Author: Pia Reinfeld
    % Date: 2025

    switch alpha_value
        case 0.5
            forward_model = forward_model_smooth;
            regularization_label = 'smooth';
        case 0.05
            forward_model = forward_model_standard;
            regularization_label = 'standard';
        case 0.001
            forward_model = forward_model_focal;
            regularization_label = 'focal';
        otherwise
            error('Unsupported alpha value: %.3f. Use 0.5, 0.05, or 0.001', alpha_value);
    end

end
