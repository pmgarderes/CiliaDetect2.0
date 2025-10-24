function [BWshrink, score, widthPx] = shrink_mask_likelihood(BW, F, strength, fluorWeight)
% SHRINK_MASK_LIKELIHOOD  Edge-aware ROI shrink using mask support × fluorescence.
%
%   [BWshrink, score, widthPx] = shrink_mask_likelihood(BW, F, strength, fluorWeight)
%
% Inputs
%   BW           : logical ROI mask
%   F            : fluorescence image (any numeric type)
%   strength     : 0..1   how strongly to shrink (higher = smaller mask)
%   fluorWeight  : 0..1   influence of fluorescence (0 = ignore F)
%
% Outputs
%   BWshrink     : cleaned, shrunken ROI mask
%   score        : continuous likelihood map used for thresholding
%   widthPx      : estimated cilium width in pixels
%
% Notes
%   •  Width is estimated from MinorAxisLength, fallback = 2×median radius.
%   •  Works with single ROIs (keeps the one overlapping BW most).
%   •  Fluorescence acts only near ROI edges; holes are filled automatically.

% -------------------------------------------------------------------------
% Sanitize & parameters
% -------------------------------------------------------------------------
BW = logical(BW);
F  = double(F);
if ~any(BW(:))
    BWshrink = BW; score = zeros(size(BW)); widthPx = 0; return;
end
strength     = min(max(double(strength),0),1);
fluorWeight  = min(max(double(fluorWeight),0),1);

% -------------------------------------------------------------------------
% 1) Choose main ROI and estimate width
% -------------------------------------------------------------------------
CC = bwconncomp(BW,8);
if CC.NumObjects > 1
    [~,iMax] = max(cellfun(@numel,CC.PixelIdxList));
    BWroi = false(size(BW)); BWroi(CC.PixelIdxList{iMax}) = true;
else
    BWroi = BW;
end

Sprops = regionprops(BWroi,'MinorAxisLength');
if ~isempty(Sprops) && Sprops(1).MinorAxisLength>0
    widthPx = double(Sprops(1).MinorAxisLength);
else
    D = bwdist(~BWroi);
    r = D(BWroi); r = r(r>0);
    widthPx = 2*median(r);
end
widthPx = max(2, min(widthPx,30));    % clamp sane range

% -------------------------------------------------------------------------
% 2) Local mask support S  (fraction of ROI inside a disk)
% -------------------------------------------------------------------------
rDisk = max(1, round((0.35 + 0.45*strength) * (widthPx/2)));
se    = strel('disk', rDisk, 0);
K     = double(se.Neighborhood); K = K/sum(K(:));
S     = conv2(double(BWroi), K, 'same');
S     = min(max(S,0),1);

% -------------------------------------------------------------------------
% 3) Edge-aware fluorescence normalization
% -------------------------------------------------------------------------
win = max(3, 2*round((1.0 - 0.5*strength)*widthPx) + 1);
eps = 1e-3 * var(F(BWroi));
if ~isfinite(eps) || eps<=0, eps = 1e-3; end
G = guidedFilterGray(F, F, win, eps);

guard = imdilate(BWroi, strel('disk', max(1, round(widthPx/2)), 0));
vals  = G(guard);
lo = prctile(vals,5); hi = prctile(vals,95);
if hi<=lo, hi=lo+eps; end
Gn = (G - lo) / (hi - lo);
Gn = min(max(Gn,0),1);

% -------------------------------------------------------------------------
% 4) Combine likelihoods
% -------------------------------------------------------------------------
eta = 0.35 * fluorWeight;               % fluorescence influence cap
a   = 1.1 + 1.2*strength;               % mask exponent (dominant)
b   = 0.25 + 0.75*strength;             % fluorescence exponent
Gm  = (1-eta)*S + eta*Gn;               % convex blend
score = (S.^a) .* (Gm.^b);

% -------------------------------------------------------------------------
% 5) Threshold (bias by strength), fill holes, keep main component
% -------------------------------------------------------------------------
svals = score(guard);
if numel(svals)<50
    t0 = 0.5;
else
    t0 = graythresh(svals);
    if ~isfinite(t0) || t0<=0, t0 = 0.5; end
end
t = min(0.95, max(0.05, t0 + 0.10*strength));  % gentle bias

BWcand = (score>=t) & guard;
BWcand = bwareaopen(BWcand, max(3, round(0.05*sum(BWroi(:)))));
BWcand = imfill(BWcand,'holes');

L = bwlabel(BWcand,8);
if max(L(:))==0
    BWshrink = BWroi; return;
end
labs = unique(L(BWroi)); labs(labs==0)=[];
if isempty(labs)
    stats = regionprops(L,'Area');
    [~,mx]=max([stats.Area]);
    BWshrink = (L==mx);
else
    ov = arrayfun(@(lab) nnz(BWroi & (L==lab)), labs);
    [~,k]=max(ov);
    BWshrink = (L==labs(k));
end
end
