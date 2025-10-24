function Idet = prefilter_for_detection_fast(Iraw, p)
% Fast prefilter: guided filter (if available) else 3× box filter ≈ Gaussian.
% Uses only p.prefilterEnable, p.prefilterScalePx, p.lineBridgeEnable (ignored for speed).

    if ~isfield(p,'prefilterEnable') || ~p.prefilterEnable
        Idet = Iraw; return;
    end
    scale = max(0.5, double(p.prefilterScalePx));
    Imin = double(min(Iraw(:))); Imax = double(max(Iraw(:)));
    Ir   = (double(Iraw)-Imin)/max(1e-9,(Imax-Imin));

    if exist('imguidedfilter','file') == 2
        win0 = 9;                      % small, fast window (odd)
        sigma0 = (win0-1)/2;           % ~per-pass “radius”
        % passes so that sigma_eff ~ sqrt(n)*sigma0 ≈ scale
        nPass = 2; %max(1, ceil((scale / sigma0)^2));
        DoS_total = (0.03*scale)^2;    % gentle, scale-aware smoothing
        DoS_pass  = DoS_total ; %/ nPass; % distribute across passes

        J = Ir;
        for k=1:nPass
            J = imguidedfilter(J, 'NeighborhoodSize',[win0 win0], ...
                                  'DegreeOfSmoothing', DoS_pass);
        end
% %                 win  = 2*ceil(scale) + 1;              % neighborhood size ~ 2σ+1
% %         DoS  = (0.03 * scale)^2;               % small, scale-aware smoothing
% %         J    = imguidedfilter(Ir, 'NeighborhoodSize', [win win], ...
% %                                   'DegreeOfSmoothing', DoS);
    end

    Idet = cast(J*(Imax-Imin)+Imin, class(Iraw));
end
