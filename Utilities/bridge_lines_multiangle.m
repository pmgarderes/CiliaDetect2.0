function BWb = bridge_lines_multiangle(BW, varargin)
% Scale-aware multi-angle line closing applied directly to a ROI mask.
% Bridges small puncta/gaps along thin structures without drifting far.
%
% BWb = bridge_lines_multiangle(BW, 'Strength', 0.5, 'AngleStep', 15, ...
%                               'MaxLenFactor', 1.5, 'GuardDilate', 1)
%
% Params:
%   Strength      : 0..1, how aggressive the bridging is (length & passes)
%   AngleStep     : degrees between orientations (smaller = more angles)
%   MaxLenFactor  : max line length as (MaxLenFactor * typical_width_px)
%   GuardDilate   : constrain changes to imdilate(BW, strel('disk', GuardDilate))
%   Passes        : how many progressive passes (default auto from Strength)
%
% Notes:
% - Typical width is estimated as 2*median distance-to-boundary inside BW.
% - Progressive passes use shorter -> longer lines.

    p = inputParser;
    p.addParameter('Strength',    0.5);   % 0..1
    p.addParameter('AngleStep',     15);  % deg
    p.addParameter('MaxLenFactor', 1.5);  % × (typical width)
    p.addParameter('GuardDilate',    1);  % px
    p.addParameter('Passes',        []);  % auto
    p.parse(varargin{:});
    P = p.Results;

    BW = logical(BW);
    if ~any(BW(:))
        BWb = BW; return;
    end

    % --- 1) Estimate typical full width of the ROI (px) ---
    D = bwdist(~BW);                 % distance-to-boundary inside the ROI
    rad = D(BW); rad = rad(rad>0);
    if isempty(rad)
        typWidth = 4;                 % fallback
    else
        typWidth = 2 * median(rad);   % full width ~ 2×median radius
        typWidth = max(2, min(typWidth, 30)); % clamp to sane range
    end

    % --- 2) Map Strength -> line lengths & passes ---
    % Min length ~ 0.4×width; Max length ~ MaxLenFactor×width
    Lmin = max(2, round(0.4 * typWidth));
    Lmax = max(Lmin, round(P.MaxLenFactor * typWidth));

    if isempty(P.Passes)
        nPass = max(1, 1 + round(2 * P.Strength));   % 1..3 passes
    else
        nPass = max(1, P.Passes);
    end

    % Sequence of line lengths from short -> long
    if nPass == 1
        Lseq = round(Lmin + P.Strength * (Lmax - Lmin));
    else
        Lseq = round(linspace(Lmin, Lmax, nPass));
    end
    Lseq = double(unique(max(2, Lseq)));  % ensure >=2 and unique

    % Orientation set
    step = max(5, min(45, P.AngleStep));
    angs = 0:step:(180-step);     % [0, step, ..., <180]

    % --- 3) Guard region so we don’t “paint” outside ROI neighborhood ---
    guard = imdilate(BW, strel('disk', max(0, round(P.GuardDilate)), 0));

    % --- 4) Progressive multi-angle closing ---
    J = BW;
    for L = Lseq
        K = false(size(J));
        for th = angs
            se = strel('line', L, th);
            K = K | imclose(J, se);
        end
        % Constrain to guard region and also keep original foreground
        J = (K & guard) | BW;
    end

    BWb = J;
end
