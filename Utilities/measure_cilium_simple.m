function R = measure_cilium_simple(mask, Metadata, roi_id)
% Simple, robust morphology for a single 2D cilium ROI.
% Returns a struct with Length_um, Width_um_mean, Curviness, LW_Ratio, Area_um2.

    if ~islogical(mask), mask = mask ~= 0; end
    mask = imfill(mask, 'holes');
    mask = bwareafilt(mask, 1);     % keep largest blob (optional but safer)

    px = Metadata.pixelSizeX_um;
    py = Metadata.pixelSizeY_um;

    % ---- Area (µm^2)
    area_px = nnz(mask);
    Area_um2 = area_px * px * py;

    % ---- Skeleton & endpoints
    if exist('bwskel','file')
        skel = bwskel(mask);
    else
        skel = bwmorph(mask,'skel',inf);
    end
    % prune small spurs
    for k = 1:3, skel = bwmorph(skel,'spur',1); end

    % endpoints
    endp = bwmorph(skel,'endpoints');
    [er, ec] = find(endp);
    if numel(er) < 2
        % fallback: length from regionprops major axis (rough)
        rp = regionprops(mask,'MajorAxisLength');
        Length_um = (isempty(rp) || isempty(rp.MajorAxisLength)) ? 0 : rp.MajorAxisLength * (px+py)/2;
        Curviness = 1;  % no reliable chord
    else
        % pick the longest geodesic path between endpoints
        [Length_um, chord_um] = longest_skeleton_path_um(skel, [er ec], px, py);
        Curviness = (chord_um>0) * (Length_um / chord_um);
        if chord_um==0, Curviness = 1; end
    end

    % ---- Mean width (µm): tube approx = Area / Length
    if Length_um > 0
        Width_um_mean = Area_um2 / Length_um;
    else
        Width_um_mean = 0;
    end

    % ---- Length/Width ratio
    LW_Ratio = (Width_um_mean>0) * (Length_um / Width_um_mean);

    % ---- Output
    if nargin < 3, roi_id = []; end
    R = struct('ROI',roi_id, ...
               'Length_um',Length_um, ...
               'Width_um_mean',Width_um_mean, ...
               'Curviness',Curviness, ...
               'LW_Ratio',LW_Ratio, ...
               'Area_um2',Area_um2);
end

function [len_um, chord_um] = longest_skeleton_path_um(skel, endpoints_rc, px, py)
% Compute centerline (geodesic) length along skeleton between the furthest endpoints.
    % map skeleton pixels to linear indices
    [r,c] = find(skel);
    lin = sub2ind(size(skel), r, c);
    % 8-neighbors graph
    sz = size(skel);
    nbr = [-1 0; 1 0; 0 -1; 0 1; -1 -1; -1 1; 1 -1; 1 1];
    E = [];     % edges
    W = [];     % weights (µm)
    idxMap = zeros(sz); idxMap(lin) = 1:numel(lin);
    for k = 1:numel(lin)
        rr = r(k); cc = c(k);
        for m = 1:8
            rr2 = rr + nbr(m,1); cc2 = cc + nbr(m,2);
            if rr2>=1 && rr2<=sz(1) && cc2>=1 && cc2<=sz(2) && skel(rr2,cc2)
                i = idxMap(rr,cc); j = idxMap(rr2,cc2);
                if i<j
                    % step length in µm (anisotropy-aware)
                    dx = (cc2-cc) * px;
                    dy = (rr2-rr) * py;
                    w = hypot(dx, dy);
                    E(end+1,:) = [i j]; %#ok<AGROW>
                    W(end+1,1) = w;     %#ok<AGROW>
                end
            end
        end
    end
    if isempty(E)
        len_um = 0; chord_um = 0; return;
    end
    G = graph(E(:,1), E(:,2), W);
    % endpoints nodes:
    e_lin = sub2ind(sz, endpoints_rc(:,1), endpoints_rc(:,2));
    e_nodes = idxMap(e_lin);
    e_nodes = e_nodes(e_nodes>0);
    if numel(e_nodes) < 2
        len_um = sum(W); chord_um = 0; return;
    end
    % find pair of endpoints with max shortest-path distance
    bestLen = 0; pair = [e_nodes(1) e_nodes(2)];
    for a = 1:numel(e_nodes)
        [dist, ~, pred] = shortestpathtree_all(G, e_nodes(a)); %#ok<NASGU>
        for b = a+1:numel(e_nodes)
            d = distances(G, e_nodes(a), e_nodes(b));
            if isfinite(d) && d > bestLen
                bestLen = d;
                pair = [e_nodes(a) e_nodes(b)];
            end
        end
    end
    len_um = bestLen;

    % chord in µm between those endpoints (straight line)
    [rrA, ccA] = ind2sub(sz, lin(pair(1)));
    [rrB, ccB] = ind2sub(sz, lin(pair(2)));
    chord_um = hypot((ccB-ccA)*px, (rrB-rrA)*py);
end

function [dist, pred] = shortestpathtree_all(G, s)
% helper to warm up distances; returns dist from s (not strictly needed but kept)
    dist = distances(G, s, 1:numnodes(G));
    pred = [];
end
