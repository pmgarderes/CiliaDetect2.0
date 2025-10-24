function path = selectMainPath(skel, mode, lambda)
% Select main skeleton path among all endpoint pairs.
% mode: 'longest' | 'smoothest' | 'hybrid'  (default: 'hybrid')
% lambda: smoothness weight for 'hybrid' (default 8)
%
% Returns path as [x y] integer coords, empty if none.

    if nargin < 2 || isempty(mode),   mode = 'hybrid'; end
    if nargin < 3 || isempty(lambda), lambda = 8;      end

    skel = logical(skel);
    ep = bwmorph(skel,'endpoints');
    [ey, ex] = find(ep);
    if numel(ex) < 2
        % Degenerate: return any skeleton pixels as a trivial path
        [yy, xx] = find(skel);
        path = [xx, yy];
        return;
    end

    best = struct('score', -Inf, 'len', 0, 'rough', Inf, 'path', []);
    bestSmooth = best; % for mode='smoothest'
    bestLong   = best; % for mode='longest'

    for i = 1:numel(ex)
        D = bwdistgeodesic(skel, ex(i), ey(i), 'quasi-euclidean');
        for j = i+1:numel(ex)
            if ~isfinite(D(ey(j),ex(j))), continue; end
            p = backtrackPath(D, [ex(j) ey(j)]);
            if size(p,1) < 2, continue; end

            % Metrics
            len   = polylineLength(p);
            rough = turnRoughness(p);          % sum(angle^2) / len (radians^2 per px)
            switch lower(mode)
                case 'longest'
                    score = len;
                case 'smoothest'
                    score = -rough;             % smaller rough is better
                otherwise % 'hybrid'
                    score = len - lambda * rough;
            end

            cand = struct('score',score,'len',len,'rough',rough,'path',p);
            if score > best.score, best = cand; end
            if len   > bestLong.len, bestLong = cand; end
            if rough < bestSmooth.rough, bestSmooth = cand; end
        end
    end

    % If no path found (rare), return empty
    if isempty(best.path)
        path = [];
        return;
    end

    % Tie-breakers:
    switch lower(mode)
        case 'longest'
            path = bestLong.path;
        case 'smoothest'
            % avoid silly short paths: if extremely short, fall back to hybrid
            if bestSmooth.len < 0.25 * bestLong.len
                path = best.path;
            else
                path = bestSmooth.path;
            end
        otherwise % 'hybrid'
            % if two candidates have close scores, prefer the longer one
            if abs(best.score - bestLong.score) < 0.05 * max(1,abs(bestLong.score))
                path = bestLong.path;
            else
                path = best.path;
            end
    end
end

% ---- helpers ----

function L = polylineLength(P)
    if size(P,1) < 2, L = 0; return; end
    d = hypot(diff(P(:,1)), diff(P(:,2)));
    L = sum(d);
end

function R = turnRoughness(P)
    % Sum of squared turning angles per unit length (robust, scale-aware).
    % P: [x y] pixel coords along path (not necessarily unit-spaced)
    if size(P,1) < 3, R = 0; return; end
    v1 = diff(P,1,1);                   % segment vectors
    n1 = sqrt(sum(v1.^2,2)) + eps;
    u1 = v1 ./ n1;                      % unit segments
    % angle between consecutive unit vectors
    c = sum(u1(1:end-1,:).*u1(2:end,:), 2);
    c = max(min(c,1),-1);               % clamp for safety
    ang = acos(c);                      % radians
    A = sum(ang.^2);                    % total squared angle
    L = polylineLength(P);
    R = A / max(L, eps);                % normalize by length
end

function path = backtrackPath(D, dst)
    path = zeros(0,2);
    curr = dst;
    while true
        path(end+1,:) = curr; %#ok<AGROW>
        d0 = D(curr(2), curr(1));
        if d0==0, break; end
        nbr = neighbors8(curr, size(D));
        vals = arrayfun(@(i) D(nbr(i,2), nbr(i,1)), 1:size(nbr,1));
        [m, k] = min(vals);
        if ~isfinite(m) || m >= d0, break; end
        curr = nbr(k,:);
    end
    path = flipud(path);
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
