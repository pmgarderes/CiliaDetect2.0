function [px, py] = pick_top_peaks_iterative(img, N, radius, minPct, forbidden)
% Iteratively selects the brightest pixel in 'img' (double),
% then excludes a disk of 'radius' around it, until N seeds or no peaks left.
% 'minPct' is the percentile threshold (0-100) below which we stop.
% 'forbidden' is an optional logical mask of pixels to ignore initially.

    if nargin < 5 || isempty(forbidden), forbidden = false(size(img)); end
    img = double(img);
    img(~isfinite(img)) = -Inf;

    % percentile threshold
    flat = img(~isinf(img));
    if isempty(flat)
        px=[]; py=[]; return;
    end
    thr = prctile(flat, min(max(minPct,0),100));

    % precompute a disk kernel
    r = max(0, round(radius));
    dSz = 2*r + 1;
    [xx, yy] = meshgrid(-r:r, -r:r);
    disk = (xx.^2 + yy.^2) <= r^2;

    H = size(img,1); W = size(img,2);
    px = zeros(0,1); py = zeros(0,1);

    % working copy
    A = img;
    % apply initial forbidden mask
    A(forbidden) = -Inf;

    for k = 1:N
        [val, idx] = max(A(:));
        if ~isfinite(val) || val < thr
            break; % no more strong peaks
        end
        [y, x] = ind2sub([H,W], idx);
        px(end+1,1) = x; %#ok<AGROW>
        py(end+1,1) = y; %#ok<AGROW>

        % zero-out (exclude) a disk neighborhood
        x1 = max(1, x - r); x2 = min(W, x + r);
        y1 = max(1, y - r); y2 = min(H, y + r);

        subDisk = disk( (y1-y+ r +1):(y2-y+ r +1), (x1-x+ r +1):(x2-x+ r +1) );
        block = A(y1:y2, x1:x2);
        block(subDisk) = -Inf;
        A(y1:y2, x1:x2) = block;
    end
end

function forbidden = forbid_existing_centers(forbidden, detections, radius)
% Mark a forbidden disk around each existing detection centroid.
    if isempty(detections), return; end
    [H,W] = size(forbidden);
    r = max(0, round(radius));
    [xx, yy] = meshgrid(-r:r, -r:r);
    disk = (xx.^2 + yy.^2) <= r^2;

    for i = 1:numel(detections)
        m = logical(detections{i}.mask);
        s = regionprops(m, 'Centroid');
        if isempty(s), continue; end
        c = round(s(1).Centroid);  % [x y]
        x = c(1); y = c(2);
        if any(~isfinite([x y])) || x<1 || x>W || y<1 || y>H, continue; end

        x1 = max(1, x - r); x2 = min(W, x + r);
        y1 = max(1, y - r); y2 = min(H, y + r);

        subDisk = disk( (y1-y+ r +1):(y2-y+ r +1), (x1-x+ r +1):(x2-x+ r +1) );
        forbidden(y1:y2, x1:x2) = forbidden(y1:y2, x1:x2) | subDisk;
    end
end

function c = get_detection_center(mask)
    s = regionprops(mask, 'Centroid');
    if isempty(s), c = [NaN,NaN]; else, c = s(1).Centroid; end
end
