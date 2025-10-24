function Idet = prefilter_for_detection_fast2(Iraw, p)
% Fast large-scale edge-preserving prefilter using Fast Guided Filter.
% Uses only p.prefilterEnable, p.prefilterScalePx (≈ sigma), p.lineBridgeEnable (ignored here).

    if ~isfield(p,'prefilterEnable') || ~p.prefilterEnable
        Idet = Iraw; return;
    end

    scale = max(0.5, double(p.prefilterScalePx));   % desired smoothing scale (px)
    Imin = double(min(Iraw(:))); Imax = double(max(Iraw(:)));
    Ir   = (double(Iraw) - Imin) / max(1e-9, (Imax - Imin));  % normalize to [0,1]

    % Map your previous guided-filter params to fast-GF
    r   = ceil(scale);                 % radius in pixels (like win ≈ 2r+1)
    eps = (0.03 * scale)^2;            % regularization (same spirit as before)
    s   = max(1, round(scale/4));      % downsample factor (≈5 for scale=20)

    J = fast_guided_filter(Ir, Ir, r, eps, s);   % guide=Ir, input=Ir

    Idet = cast(J * (Imax - Imin) + Imin, class(Iraw));
end

% -------- Fast Guided Filter (gray) --------
function q = fast_guided_filter(I, p, r, eps, s)
% I: guide (0..1), p: input, r: radius (px), eps: regularization, s: subsample factor
% Complexity ~ O(N / s^2)

    if s > 1
        I_low = imresize(I, 1/s, 'bilinear');
        p_low = imresize(p, 1/s, 'bilinear');
        r_low = max(1, round(r / s));
    else
        I_low = I; p_low = p; r_low = r;
    end

    w = 2*r_low + 1;                       % box window at low-res

    mean_I  = imboxfilt(I_low, [w w], 'NormalizationFactor', 1/(w*w));
    mean_p  = imboxfilt(p_low, [w w], 'NormalizationFactor', 1/(w*w));
    mean_Ip = imboxfilt(I_low.*p_low, [w w], 'NormalizationFactor', 1/(w*w));
    cov_Ip  = mean_Ip - mean_I.*mean_p;

    mean_II = imboxfilt(I_low.*I_low, [w w], 'NormalizationFactor', 1/(w*w));
    var_I   = mean_II - mean_I.^2;

    a = cov_Ip ./ (var_I + eps);
    b = mean_p - a .* mean_I;

    mean_a = imboxfilt(a, [w w], 'NormalizationFactor', 1/(w*w));
    mean_b = imboxfilt(b, [w w], 'NormalizationFactor', 1/(w*w));

    if s > 1
        mean_a = imresize(mean_a, size(I), 'bilinear');
        mean_b = imresize(mean_b, size(I), 'bilinear');
    end

    q = mean_a .* I + mean_b;
end
