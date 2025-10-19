function p = default_params()
% Central place for defaults (update here only).
    p = struct();

    % ---- ROI detection GUI ----
    p.windowSize          = 100;
    p.minArea             = 10;
    p.maxArea             = 1500;
    p.minElongation       = 2.0;
    p.minThinness         = 2.0;       % try 1.5–3
    p.adaptiveSensitivity = 0.45;      % 0.3–0.6 typical
    p.maxroiOverlap       = 0.8;       % keep only one ROI if overlap > 80%

    % ---- Background masks ----
    p.backgroundSpread    = 12;        % dilation radius (px)
    p.backgroundPadding   = 2;         % exclusion padding (px)

    % ---- Automated detection ----
    p.tophatRadius        = 5;
    p.maxEccentricity     = 1.0;
    p.minEccentricity     = 0.8;

    % ---- Detection-only prefilter (COMPACT UI) ----
    % User controls: enable + spatialScalePx only
    p.prefilterEnable     = false;   % checkbox
    p.prefilterScalePx    = 2.0;     % one number = spatial scale (px)

    % ---- Line-bridge (COMPACT UI) ----
    p.lineBridgeEnable    = false;   % checkbox
end


% % function p = default_params()
% % % Central place for defaults (update here only).
% %     p = struct();
% % 
% %     % ---- ROI detection GUI ----
% %     p.windowSize         = 100;
% %     p.minArea            = 10;
% %     p.maxArea            = 1500;
% %     p.minElongation      = 2.0;
% %     p.minThinness        = 2.0;      % try 1.5–3
% %     p.adaptiveSensitivity= 0.45;      % 0.3–0.6 typical
% %     p.maxroiOverlap      = 0.8;      % keep only one ROI if overlap > 80%
% % 
% %     % ---- Background masks ----
% %     p.backgroundSpread   = 12;       % dilation radius (px)
% %     p.backgroundPadding  = 2;        % exclusion padding (px)
% % 
% %     % ---- Automated detection ----
% %     p.tophatRadius       = 5;
% %     p.maxEccentricity    = 1.0;
% %     p.minEccentricity    = 0.8;
% % 
% % end