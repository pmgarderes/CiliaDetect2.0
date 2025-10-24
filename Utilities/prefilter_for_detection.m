function Idet = prefilter_for_detection(Iraw, p)
% Use only p.prefilterEnable, p.prefilterScalePx, p.lineBridgeEnable.
% All other internal parameters are hardcoded for stability.

    if ~isfield(p,'prefilterEnable') || ~p.prefilterEnable
        Idet = Iraw;
        return;
    end

    scale = max(0.5, double(p.prefilterScalePx)); % clamp to sane minimum
    Imin = double(min(Iraw(:))); Imax = double(max(Iraw(:)));
    Ir = (double(Iraw) - Imin) / max(1e-9, (Imax - Imin));

    % Hardcoded bilateral/gaussian choice with derived strength
    useBilateral = exist('imbilatfilt','file') == 2;
    if useBilateral
        % Derive degreeOfSmoothing (variance-like) from scale for normalized images.
        % Works well across a range without exposing extra knobs.
        % Rule of thumb: base 0.02, grow mildly with scale.
        DoS = 0.02 + 0.005*(scale-1);      % ~0.015–0.05 typical
        DoS = max(0.01, min(0.06, DoS));   % clamp
        J = imbilatfilt(Ir, DoS, scale);
    else
        % Fallback: gentle Gaussian
        J = imgaussfilt(Ir, scale);
    end

    % Return in original class/range
    Idet = cast(J * (Imax - Imin) + Imin, class(Iraw));
end


% %     % Optional: short multi-angle line closing to bridge puncta along the shaft
% %     if isfield(p,'lineBridgeEnable') && p.lineBridgeEnable
% %         L = max(3, min(7, round(1.5*scale)));   % 3–7 px
% %         angs = 0:30:150;
% %         K = zeros(size(J),'like',J);
% %         for th = angs
% %             se = strel('line', L, th);
% %             K = max(K, imclose(J, se));
% %         end
% %         J = K;
% %     end