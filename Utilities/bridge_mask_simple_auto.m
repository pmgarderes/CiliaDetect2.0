function [BWb, widthPx] = bridge_mask_simple_auto(BW, strength)
% Bridge small gaps in a thin ROI mask using only:
%   strength : 0..1 (how aggressively to bridge)
%
% Width is estimated from the ROI itself (MinorAxisLength; fallback to 2*median radius).
% Returns the bridged mask BWb and the estimated widthPx (pixels).

    % ---- sanitize ----
    BW = logical(BW);
    if ~any(BW(:))
        BWb = BW; widthPx = 0; return;
    end
    strength = min(max(double(strength),0),1);

    % ---- pick the ROI (largest connected component) ----
    CC = bwconncomp(BW, 8);
    if CC.NumObjects > 1
        [~,iMax] = max(cellfun(@numel, CC.PixelIdxList));
        BWroi = false(size(BW)); BWroi(CC.PixelIdxList{iMax}) = true;
    else
        BWroi = BW;
    end

    % ---- estimate width (pixels) ----
    S = regionprops(BWroi, 'MinorAxisLength');
    if ~isempty(S) && isfield(S,'MinorAxisLength') && ~isempty(S(1).MinorAxisLength) ...
            && isfinite(S(1).MinorAxisLength) && S(1).MinorAxisLength > 0
        widthPx = double(S(1).MinorAxisLength);
    else
        % fallback from distance map (2 * median radius)
        D = bwdist(~BWroi);
        rad = D(BWroi); rad = rad(rad>0);
        widthPx = 2*median(rad);
    end
    % clamp to a sane range
    widthPx = max(2, min(widthPx, 30));

    % ---- scale from width & strength (no extra params) ----
    Lmin = max(2, round(0.35 * widthPx));               % short bridges
    Lmax = max(Lmin, round(1.5  * widthPx));            % cap ~1.5× width
    Lend = round(Lmin + strength * (Lmax - Lmin));      % target length

    % progressive passes: 1..3 depending on strength
    nPass = max(1, 1 + round(2 * strength));
    if nPass == 1
        Lseq = Lend;
    else
        Lseq = unique(max(2, round(linspace(Lmin, Lend, nPass))));
    end

    % orientations (fixed set keeps API minimal)
    angs = 0:15:165;

    % guard region: keep edits near the ROI only (derived from width)
    guard = imdilate(BWroi, strel('disk', max(1, round(widthPx/2)), 0));

    % ---- multi-angle line closing, constrained to guard ----
    J = BWroi;
    for L = Lseq
        K = false(size(J));
        seLine = arrayfun(@(th) strel('line', L, th), angs, 'uni', 0);
        for k = 1:numel(seLine)
            K = K | imclose(J, seLine{k});
        end
        J = (K & guard) | BWroi;     % never remove original ROI pixels
    end

    % Keep the result only where the original mask existed (optional; comment if undesired)
    BWb = J | (BW & ~BWroi);         % if BW had other blobs, pass them through unchanged
end
