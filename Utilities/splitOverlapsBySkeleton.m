function [Lsep, info] = splitOverlapsBySkeleton(BW, seedXY, varargin)
% Simplified splitter using a seed-anchored main path and conservative pruning.
% Lsep: uint16 label image (0=bg). Never over-prunes: in doubt, keeps.
%
% Required:
%   BW        : logical binary image
%   seedXY    : [x y] click/seed in pixel coordinates (1-based, image space)
%
% Name/Value:
%   'PruneLenPx'   (default 6)  : prune side spurs whose geodesic length <= this
%   'SafetyHalo'   (default 2)  : protect main path pixels by dilating this many px
%   'MinBranchPix' (default 3)  : ignore microscopic branches (< this, noise)
%
% Outputs:
%   Lsep : labels after pruning short non-main branches
%   info : struct with debugging outputs:
%          .sk, .mainPathMask, .mainPathXY, .sideKeepMask, .sidePrunedMask

% ---------- Params ----------
p = inputParser;
p.addParameter('PruneLenPx',   6);
p.addParameter('SafetyHalo',   2);
p.addParameter('MinBranchPix', 3);
p.parse(varargin{:});
P = p.Results;

% ---------- Prep ----------
BW = logical(BW);
[H,W] = size(BW);
Lsep  = zeros([H W], 'uint16');

% If nothing there, done
if ~any(BW(:)), info = struct(); return; end

% Connected components
CC = bwconncomp(BW);
nextLabel = uint16(0);

% Find which component the seed belongs to (or nearest)
seedXY = round(seedXY(:)).';                   % [x y]
seedXY = max([1 1], min([W H], seedXY));
seedIdx = sub2ind([H W], seedXY(2), seedXY(1));

% If seed not in foreground, snap to nearest foreground pixel
if ~BW(seedIdx)
    DtoFG = bwdist(~BW);
    if DtoFG(seedIdx)==0
        % no FG anywhere
        info = struct(); return;
    end
    [~,nearIdx] = max(DtoFG(:));  % farthest from background == near to FG
    seedIdx = nearIdx;
    [sy,sx] = ind2sub([H W], seedIdx);
    seedXY = [sx sy];
end

% Build a map: seed component id
seedCompId = 0;
for ci = 1:CC.NumObjects
    if any(CC.PixelIdxList{ci}==seedIdx)
        seedCompId = ci;
        break;
    end
end

% ---------- Process each component ----------
for ci = 1:CC.NumObjects
    compMask = false(H,W); compMask(CC.PixelIdxList{ci}) = true;

    % Components not holding the seed: keep intact (no pruning)
    if ci ~= seedCompId
        nextLabel = nextLabel + 1;
        Lsep(compMask) = nextLabel; %#ok<AGROW>
        continue;
    end

    % ----- Skeleton (robust) -----
    % Use bwskel when available, fallback to bwmorph
    try
        sk = bwskel(compMask);
    catch
        sk = bwmorph(compMask,'skel',Inf);
    end
    % Clean tiny jitter
    sk = bwareaopen(sk, P.MinBranchPix);

    if ~any(sk(:))
        % fallback: keep component as-is
        nextLabel = nextLabel + 1; Lsep(compMask) = nextLabel; %#ok<AGROW>
        info = struct('sk',sk,'mainPathMask',false(H,W), ...
            'mainPathXY',zeros(0,2),'sideKeepMask',false(H,W), ...
            'sidePrunedMask',false(H,W));
        continue;
    end

    % ----- Graph from skeleton -----
    [nodes, nodeMap, deg] = skelNodes(sk); % nodes: [x y], nodeMap: pixel->nodeId (0 if non-node)
    if isempty(nodes) || (sum(deg==1)== 2)
        % trivial: put comp back
        nextLabel = nextLabel + 1; Lsep(compMask) = nextLabel; %#ok<AGROW>
        info = struct('sk',sk,'mainPathMask',false(H,W), ...
            'mainPathXY',zeros(0,2),'sideKeepMask',false(H,W), ...
            'sidePrunedMask',false(H,W));
        continue;
    end
    endpoints = find(deg==1);
    % map seed to nearest skeleton pixel
    [sy,sx] = ind2sub([H W], find(sk));
    [~,iMin] = min( (sx - seedXY(1)).^2 + (sy - seedXY(2)).^2 );
    seedSkXY = [sx(iMin) sy(iMin)];

    % Snap the seed to closest node (endpoint or junction). If none, add pseudo-node
    seedNode = nearestNode(nodes, seedSkXY);

    % %         % ----- Choose MAIN PATH: seed -> farthest endpoint -----
    % %         if isempty(endpoints)
    % %             mainPathNodeIds = seedNode; % degenerate
    % %         else
    % %             [adj, edgeLen, edgePix] = skelAdjacency(sk, nodes); % graph
    % %             % Dijkstra from seed to every endpoint
    % %             [dist2all, prev] = dijkstra(adj, edgeLen, seedNode);
    % %             % choose endpoint with max finite distance
    % %             d = dist2all(endpoints);
    % %             d(~isfinite(d)) = -Inf;
    % %             [~,k] = max(d);
    % %             target = endpoints(k);
    % %             % backtrack node ids
    % %             mainPathNodeIds = backtrack_nodes(prev, seedNode, target);
    % %             if isempty(mainPathNodeIds)
    % %                 mainPathNodeIds = seedNode;
    % %             end
    % %         end
    % %
    % %         % Rasterize node-path into pixel mask
    % %         mainPathMask = false(H,W);
    % %         if numel(mainPathNodeIds) >= 1
    % %             % Stitch edge pixel chains along the path
    % %             [~, ~, edgePix] = skelAdjacency(sk, nodes); % ensure edgePix in scope
    % %             for kk = 1:numel(mainPathNodeIds)-1
    % %                 a = mainPathNodeIds(kk);
    % %                 b = mainPathNodeIds(kk+1);
    % %                 key = edgeKey(a,b);
    % %                 if edgePix.isKey(key)
    % %                     idx = edgePix(key);
    % %                     mainPathMask(idx) = true;
    % %                 else
    % %                     % if missing, set node pixels at least
    % %                     xy = round(nodes([a b],:));
    % %                     mainPathMask(sub2ind([H W], xy(:,2), xy(:,1))) = true;
    % %                 end
    % %             end
    % %             % include nodes themselves
    % %             xy = round(nodes(mainPathNodeIds,:));
    % %             mainPathMask(sub2ind([H W], xy(:,2), xy(:,1))) = true;
    % %         end
    %% Replacement block that only keep the main segment
    % ----- 1) Seed-adjacent segment on skeleton -----
    segMask = traceSegmentFromSeed(sk, seedXY);
    if ~any(segMask(:))
        nextLabel = nextLabel + 1; Lsep(compMask) = nextLabel;
        continue;
    end

    % ----- 2) Estimate average full-width of that segment (in px) -----
    distComp = bwdist(~compMask);                % radius map inside original ROI
    r = distComp(segMask);                       % radii along the segment
    r = r(isfinite(r) & r>0);
    if isempty(r)
        widthPx = 4;                             % fallback
    else
        widthPx = 2*median(r);                   % full width = 2 * median radius
        widthPx = max(2, min(widthPx, 20));      % clamp to sane range
    end

    % ----- 3) Delete branches longer than widthPx, keep shorter ones -----
    sideSk = sk & ~segMask;
    CCs = bwconncomp(sideSk, 8);

    keepBranchMask = false(size(sk));
    for s = 1:CCs.NumObjects
        seg = false(size(sk)); seg(CCs.PixelIdxList{s}) = true;

        % geodesic "diameter" of this branch (longest shortest path)
        L = branchGeodesicLength(seg);
        if L <= widthPx
            keepBranchMask(CCs.PixelIdxList{s}) = true;   % keep short branches
        end
    end

    keptSk = segMask | keepBranchMask;           % main segment + short branches
    delSk  = sk & ~keptSk;                       % branches to remove entirely

    % ----- 4) Pull back ORIGINAL ROI to nearest skeleton PIXEL (kept only) -----
    % Pixels whose nearest skeleton pixel lies on a deleted branch are removed.
    [~, IDXall] = bwdist(sk);
    lin = find(compMask);
    nearestIdx = IDXall(lin);
    nearestIsKept = false(size(compMask));
    nearestIsKept(lin) = keptSk(nearestIdx);

    keepMask = compMask & nearestIsKept;

    % If we were too aggressive and nuked everything, fall back to main segment tube
    if ~any(keepMask(:))
        keepMask = compMask & (bwdist(segMask) <= max(1, round(widthPx/2)));
    end

    % ----- 5) Emit a single label for this (seed) component -----
    if any(keepMask(:))
        nextLabel = nextLabel + 1;
        Lsep(keepMask) = nextLabel;
    else
        nextLabel = nextLabel + 1;
        Lsep(compMask) = nextLabel;
    end

    %% end of Replacement block that only keep the main segment

    % %         % Safety halo to avoid accidental chopping right next to the path
    % %         if P.SafetyHalo > 0
    % %             halo = imdilate(mainPathMask, strel('disk', P.SafetyHalo, 0));
    % %         else
    % %             halo = mainPathMask;
    % %         end
    % %
    % %         % ----- Identify side branches (not touching main path) -----
    % %         sideSk = sk & ~halo;
    % %         if any(sideSk(:))
    % %             % Split sideSk into connected pieces, prune only short ones
    % %             CCs = bwconncomp(sideSk);
    % %             sideKeep = false(H,W);
    % %             sidePruned = false(H,W);
    % %             for s = 1:CCs.NumObjects
    % %                 seg = false(H,W); seg(CCs.PixelIdxList{s}) = true;
    % %                 % Geodesic length along skeleton for the segment
    % %                 len = approxGeodesicLen(seg);
    % %                 if len <= P.PruneLenPx
    % %                     sidePruned(CCs.PixelIdxList{s}) = true;
    % %                 else
    % %                     % ambiguous or long: KEEP
    % %                     sideKeep(CCs.PixelIdxList{s}) = true;
    % %                 end
    % %             end
    % %         else
    % %             sideKeep   = false(H,W);
    % %             sidePruned = false(H,W);
    % %         end
    % %
    % %         % ----- Compose final mask (main path + kept sides) -----
    % %         skKept = (sk & halo) | sideKeep;
    % %
    % %     % ----- Replace "thicken" with a Voronoi pullback to the kept skeleton -----
    % %     Lsk = bwlabel(skKept, 8);                 % label skeleton components to keep
    % %     if max(Lsk(:)) == 0
    % %         % No kept skeleton => keep original component intact
    % %         nextLabel = nextLabel + 1;
    % %         Lsep(compMask) = nextLabel;
    % %     else
    % %         % For each pixel, find nearest kept-skeleton pixel and inherit its label
    % %         % (This partitions compMask by closest skKept component in image space.)
    % %         [~, IDX] = bwdist(Lsk > 0);           % index of nearest skKept pixel
    % %         % Map each pixel's nearest index to the skeleton component id
    % %         nearestSkLabel = zeros(size(compMask),'uint16');
    % %         lin = find(compMask);
    % %         nearestSkLabel(lin) = uint16(Lsk(IDX(lin)));
    % %
    % %         % Optional: drop tiny slivers (safety)
    % %         MinRegionPix = 5;
    % %
    % %         % Emit labels per skeleton component (stable, conservative)
    % %         u = setdiff(unique(nearestSkLabel(lin)), uint16(0));
    % %         for j = 1:numel(u)
    % %             reg = compMask & (nearestSkLabel == u(j));
    % %             if nnz(reg) < MinRegionPix
    % %                 continue; % ambiguous dust -> keep merged by skipping
    % %             end
    % %             nextLabel = nextLabel + 1;
    % %             Lsep(reg) = nextLabel; %#ok<AGROW>
    % %         end
    % %
    % %         % Fallback: if nothing emitted (e.g., all tiny), keep original
    % %         if ~any(Lsep(compMask))
    % %             nextLabel = nextLabel + 1;
    % %             Lsep(compMask) = nextLabel;
    % %         end
    % %     end


    % ----- Debug info -----
    info = struct();
    info.sk            = sk;
    % %         info.mainPathMask  = mainPathMask;
    % %         info.mainPathXY    = nodes(mainPathNodeIds,:);
    % %         info.sideKeepMask  = sideKeep;
    % %         info.sidePrunedMask= sidePruned;
end
end

% ================= Helpers =================

function [nodes, nodeMap, deg] = skelNodes(sk)
% Nodes at pixels with degree ~= 2 (endpoints deg=1 and junctions deg>=3)
[H,W] = size(sk);
nodeMap = zeros(H,W,'uint32');
[yy,xx] = find(sk);
deg = zeros(numel(xx),1);
for i = 1:numel(xx)
    x = xx(i); y = yy(i);
    nb = neighbors8([x y],[H W]);
    c  = 0;
    for k = 1:size(nb,1)
        if sk(nb(k,2), nb(k,1)), c = c + 1; end
    end
    deg(i) = c;
end
isNode = (deg ~= 2);
nodes  = [xx(isNode) yy(isNode)];
% map only node pixels (others -> 0)
linAll = sub2ind([H W], yy(isNode), xx(isNode));
nodeMap(linAll) = uint32(1:numel(linAll));
% For convenience, return degree only for nodes
deg = deg(isNode);
end

function [adj, edgeLen, edgePix] = skelAdjacency(sk, nodes)
% Build adjacency between nodes by tracing degree-2 chains
[H,W] = size(sk);
nodeMap = zeros(H,W,'uint32');
idxNode = sub2ind([H W], nodes(:,2), nodes(:,1));
nodeMap(idxNode) = uint32(1:size(nodes,1));

visited = false(H,W);
edgePix = containers.Map('KeyType','char','ValueType','any');
adj     = cell(size(nodes,1),1);
edgeLen = cell(size(nodes,1),1);

% walk out of every node along each neighbor chain
for n = 1:size(nodes,1)
    x0 = nodes(n,1); y0 = nodes(n,2);
    nb = neighbors8([x0 y0], [H W]);
    for k = 1:size(nb,1)
        x = nb(k,1); y = nb(k,2);
        if ~sk(y,x), continue; end
        if nodeMap(y,x) ~= 0
            % direct neighbor node -> tiny edge
            m = double(nodeMap(y,x));
            kkey = edgeKey(n,m);
            if ~isKey(edgePix, kkey)
                edgePix(kkey) = sub2ind([H W],[y;y0],[x;x0]);
            end
            adj{n}(end+1) = m; %#ok<AGROW>
            edgeLen{n}(end+1) = 1; %#ok<AGROW>
            continue;
        end

        % Follow degree-2 chain until next node
        chain = [x0 y0; x y];
        px = x; py = y; pxPrev = x0; pyPrev = y0;
        while true
            visited(py,px) = true;
            nb2 = neighbors8([px py],[H W]);
            % among neighbors that are skeleton, choose the one not equal to prev
            nxt = [];
            for t = 1:size(nb2,1)
                qx = nb2(t,1); qy = nb2(t,2);
                if ~sk(qy,qx), continue; end
                if qx==pxPrev && qy==pyPrev, continue; end
                nxt(end+1,:) = [qx qy]; %#ok<AGROW>
            end
            if isempty(nxt)
                break; % dead end (shouldn’t happen if we started from a node)
            end
            if size(nxt,1) > 1
                % branched before encountering a node -> stop; let other walks pick it up
                break;
            end
            qx = nxt(1,1); qy = nxt(1,2);
            chain(end+1,:) = [qx qy]; %#ok<AGROW>

            if nodeMap(qy,qx) ~= 0
                % reached a node
                m = double(nodeMap(qy,qx));
                kkey = edgeKey(n,m);
                if ~isKey(edgePix, kkey)
                    lin = sub2ind([H W], chain(:,2), chain(:,1));
                    edgePix(kkey) = lin;
                end
                adj{n}(end+1) = m; %#ok<AGROW>
                edgeLen{n}(end+1) = geodesicLen(chain); %#ok<AGROW>
                break;
            end
            % advance
            pxPrev = px; pyPrev = py; px = qx; py = qy;
        end
    end
end
end

function key = edgeKey(a,b)
if a>b, tmp=a; a=b; b=tmp; end
key = sprintf('%d-%d',a,b);
end

function L = geodesicLen(xy)
if size(xy,1)<2, L=0; return; end
d = hypot(diff(xy(:,1)), diff(xy(:,2)));
L = sum(d);
end

function L = approxGeodesicLen(segMask)
% approximate by skeleton perimeter along the chain
[y,x] = find(segMask);
if isempty(x), L = 0; return; end
% crude but safe: bounding-chain length via bwdistgeodesic from one endpoint
ep = bwmorph(segMask,'endpoints');
[ey,ex] = find(ep);
if numel(ex) < 1
    L = numel(x); return;
end
D = bwdistgeodesic(segMask, ex(1), ey(1), 'quasi-euclidean');
L = max(D(segMask),[],'omitnan');
if ~isfinite(L), L = numel(x); end
end

function nId = nearestNode(nodes, xy)
dx = nodes(:,1) - xy(1);
dy = nodes(:,2) - xy(2);
[~,i] = min(dx.^2 + dy.^2);
nId = i;
end

function [dist, prev] = dijkstra(adj, edgeLen, src)
% DIJKSTRA  Single-source shortest paths on an adjacency list graph.
% adj, edgeLen : 1xN cell arrays; adj{u} -> vector of neighbor node ids,
%                edgeLen{u}(k) -> weight of edge u->adj{u}(k)
% src          : 1-based source node id
% dist         : Nx1 double of shortest distances (Inf if unreachable)
% prev         : Nx1 uint32 of predecessor nodes (0 if none)

N = numel(adj);
dist = inf(N,1);
prev = zeros(N,1,'uint32');
visited = false(N,1);

% basic sanity
if src < 1 || src > N || ~isscalar(src) || ~isfinite(src)
    error('dijkstra: invalid source node.');
end
dist(src) = 0;

for iter = 1:N
    % pick the unvisited node with smallest tentative distance
    distMasked = dist;
    distMasked(visited) = inf;
    [du, u] = min(distMasked);

    % nothing reachable remains
    if ~isfinite(du)
        break;
    end

    visited(u) = true;

    nbrs = adj{u};
    if isempty(nbrs)
        continue;
    end

    w = edgeLen{u};
    if numel(w) ~= numel(nbrs)
        error('dijkstra: edgeLen{%d} length mismatch (got %d vs %d).', ...
            u, numel(w), numel(nbrs));
    end

    % relax edges u -> v
    alt = du + w(:);
    v   = nbrs(:);
    better = alt < dist(v);
    if any(better)
        dist(v(better)) = alt(better);
        prev(v(better)) = uint32(u);
    end
end
end


function path = backtrack_nodes(prev, s, t)
if s==t, path = s; return; end
P = uint32(t);
while P(1) ~= 0 && P(1) ~= s
    P = [prev(P(1)); P]; %#ok<AGROW>
    if P(1)==0, path = []; return; end
end
if isempty(P) || P(1)==0, path = []; else, path = double([s; P]); end
end

function pts = neighbors8(p, szHW)
H = szHW(1); W = szHW(2);
x = p(1); y = p(2);
X = max(1,x-1):min(W,x+1);
Y = max(1,y-1):min(H,y+1);
[XX,YY] = meshgrid(X,Y);
pts = [XX(:), YY(:)];
pts(XX(:)==x & YY(:)==y,:) = [];
end

function segMask = traceSegmentFromSeed(sk, seedXY)
% Return a logical mask of the skeleton segment (degree-2 chain) adjacent to seed.
% The segment is maximal in both directions until first node (deg ~= 2) or endpoint.

[H,W] = size(sk);
segMask = false(H,W);
if ~any(sk(:)), return; end

% Closest skeleton pixel to the click
[sy, sx] = find(sk);
[~, iMin] = min( (sx - seedXY(1)).^2 + (sy - seedXY(2)).^2 );
p = [sx(iMin), sy(iMin)];

% Degree at a pixel
    function d = deg_at(q)
        nb = neighbors8(q, [H W]);
        d = 0;
        for kk = 1:size(nb,1)
            if sk(nb(kk,2), nb(kk,1)), d = d + 1; end
        end
    end

% One-direction walk until first node (deg ~= 2) or endpoint
    function chain = walk_from(start, coming_from)
        chain = start;
        prev = coming_from;
        curr = start;
        while true
            nb = neighbors8(curr, [H W]);
            nxt = [];
            for t = 1:size(nb,1)
                q = nb(t,:);
                if ~sk(q(2), q(1)), continue; end
                if ~isempty(prev) && all(q==prev), continue; end
                nxt(end+1,:) = q; %#ok<AGROW>
            end
            d = deg_at(curr);
            if d ~= 2 || isempty(nxt)
                % stop at endpoints or junctions (do not step past nodes)
                break;
            end
            % continue straight (only one valid next if deg==2)
            q = nxt(1,:);
            chain(end+1,:) = q; %#ok<AGROW>
            prev = curr;
            curr = q;
        end
    end

d0 = deg_at(p);

if d0 == 2
    % Inside a degree-2 chain: walk both directions
    % pick its two neighbors
    nb = neighbors8(p, [H W]);
    neigh = [];
    for t = 1:size(nb,1)
        q = nb(t,:);
        if sk(q(2), q(1)), neigh(end+1,:) = q; end %#ok<AGROW>
    end
    if size(neigh,1) < 2
        % deg==2 but numerically fragile; treat as endpoint
        left = walk_from(p, []);
        right = p;
    else
        left  = flipud(walk_from(p, neigh(2,:))); % go against neighbor 2
        right = walk_from(p, neigh(1,:));         % go toward neighbor 1
    end
    chain = unique([left; right], 'rows', 'stable');

elseif d0 == 1
    % Endpoint: walk forward once
    nb = neighbors8(p, [H W]);
    nbh = [];
    for t = 1:size(nb,1)
        q = nb(t,:);
        if sk(q(2), q(1)), nbh(end+1,:) = q; end %#ok<AGROW>
    end
    if isempty(nbh)
        chain = p;
    else
        chain = [p; walk_from(nbh(1,:), p)];
    end

else
    % Junction (deg>=3): pick the adjacent chain with the longest length
    nb = neighbors8(p, [H W]);
    nbh = [];
    for t = 1:size(nb,1)
        q = nb(t,:);
        if sk(q(2), q(1)), nbh(end+1,:) = q; end %#ok<AGROW>
    end
    bestChain = p; bestLen = 0;
    for t = 1:size(nbh,1)
        c = [p; walk_from(nbh(t,:), p)];
        L = sum(hypot(diff(c(:,1)), diff(c(:,2))));
        if L > bestLen
            bestLen = L; bestChain = c;
        end
    end
    chain = bestChain;
end

% Rasterize chain
idx = sub2ind([H W], chain(:,2), chain(:,1));
segMask(idx) = true;
end


function L = branchGeodesicLength(segSk)
% Longest shortest-path length within a skeleton branch (in px, quasi-Euclidean)
% If no endpoints (tiny loop), use number of pixels as a conservative length.

if ~any(segSk(:)), L = 0; return; end
ep = bwmorph(segSk, 'endpoints');
[ey, ex] = find(ep);

if numel(ex) >= 1
    % 1st pass: from an arbitrary endpoint to farthest endpoint
    D1 = bwdistgeodesic(segSk, ex(1), ey(1), 'quasi-euclidean');
    D1(~isfinite(D1)) = -inf;
    [~, imax] = max(D1(:));
    [y2,x2] = ind2sub(size(segSk), imax);

    % 2nd pass: from the farthest endpoint to its farthest point
    D2 = bwdistgeodesic(segSk, x2, y2, 'quasi-euclidean');
    D2(~isfinite(D2)) = -inf;
    L = max(D2(:));
    if ~isfinite(L) || isempty(L), L = 0; end
else
    % No endpoints (tiny blob/loop) -> treat as very short
    L = nnz(segSk);
end
end
