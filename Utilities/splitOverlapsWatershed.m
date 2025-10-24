function Lsep = splitOverlapsWatershed(BW, varargin)
% Lsep: label matrix (0=background). Objects are split when multiple cores exist.
% Optional name/value:
%   'MinCoreDistPx' (default 5) : suppress seeds closer than this (prevents over-splitting)
%   'Hmin'          (default []) : strength for imhmin on -dist; if empty, auto from size
%   'OnlyIfConcave' (default true): only split components that look concave or branched

    p = inputParser;
    p.addParameter('MinCoreDistPx', 5);
    p.addParameter('Hmin', []);
    p.addParameter('OnlyIfConcave', true);
    p.parse(varargin{:});
    MinCoreDistPx = p.Results.MinCoreDistPx;
    Hmin = p.Results.Hmin;
    onlyIfConcave = p.Results.OnlyIfConcave;

    % Label components
    CC = bwconncomp(BW);
    Lsep = zeros(size(BW), 'uint16');
    nextLabel = uint16(0);

    for i = 1:CC.NumObjects
        pix = CC.PixelIdxList{i};
        comp = false(size(BW)); comp(pix) = true;

        % Optional check: do we LOOK merged?
        doSplit = true;
        if onlyIfConcave
            % hull ratio or skeleton branching indicate possible merge
            areaComp = numel(pix);
            hull = bwconvhull(comp);
            concavity = (nnz(hull) - areaComp) / max(areaComp,1);
            skel = bwskel(comp);
            bp = bwmorph(skel,'branchpoints');
            doSplit = (concavity > 0.15) || any(bp(:));   % thresholds are conservative; tweak if needed
        end

        if ~doSplit
            nextLabel = nextLabel + 1;
            Lsep(comp) = nextLabel;
            continue;
        end

        % Distance-based seeds
        dist = bwdist(~comp);
        D = -dist; D(~comp) = Inf;

        % Auto h-min (depress shallow minima) based on size if not given
        if isempty(Hmin)
            % ~10% of max dist is a decent starting point for elongated shapes
            h = max(1, 0.1 * max(dist(comp)));
        else
            h = Hmin;
        end

        % Smooth + seed extraction
        Dm = imhmin(D, h);
        L = watershed(Dm);       % basins within the component
        seg = comp; seg(L==0) = false;   % cut along watershed lines

        % If seeds are still too close, merge tiny splits via morphology
        % (avoid fragments from ridges)
        % Remove slivers that are too small to be cilia-ish:
        seg = bwareaopen(seg,  max(5, round(0.05 * areaComp)));

        % Relabel local component and paste into global
        Llocal = bwlabel(seg);
        % (Optionally merge labels whose centroids are too close)
        if MinCoreDistPx > 1
            Llocal = mergeCloseLabels(Llocal, MinCoreDistPx);
        end

        % Write out with global labels
        if max(Llocal(:)) <= 1
            nextLabel = nextLabel + 1;
            Lsep(Llocal==1) = nextLabel;
        else
            nloc = max(Llocal(:));
            for k = 1:nloc
                nextLabel = nextLabel + 1;
                Lsep(Llocal==k) = nextLabel;
            end
        end
    end
end

function Lout = mergeCloseLabels(Lin, minDist)
    % Merge labels whose centroids are closer than minDist (helps over-splitting)
    Lout = Lin;
    stats = regionprops(Lout,'Centroid','PixelIdxList');
    n = numel(stats);
    if n < 2, return; end
    C = vertcat(stats.Centroid);
    D = squareform(pdist(C));
    merged = false(1,n);
    for i = 1:n
        if merged(i), continue; end
        near = find(D(i,:) > 0 & D(i,:) < minDist & ~merged);
        for j = near
            % merge j into i
            Lout(stats(j).PixelIdxList) = i;
            merged(j) = true;
        end
    end
    % relabel compactly
    Lout = bwlabel(Lout > 0);
end
