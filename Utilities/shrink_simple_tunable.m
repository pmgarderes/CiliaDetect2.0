function BWout = shrink_simple_tunable(BW, F, strength)
% Minimal, fast shrink with two toggles; true no-op at strength==0.
%  Fluorescence-driven shrink, lightly informed by the mask.
% - Fluorescence has large importance
% - Mask only gates area + adds a mild prior
% strength: 0..1 (higher = stronger shrink)

BW = logical(BW); F = double(F);
if ~any(BW(:)), BWout = BW; return; end
strength = max(0,min(1,strength));

% 1) Normalize fluorescence robustly inside a small guard around BW
guard = imdilate(BW, strel('disk',1,0));
vals  = F(guard);
lo = prctile(vals,2); hi = prctile(vals,98); if hi<=lo, hi=lo+eps; end
Fn = (F - lo) / (hi - lo); Fn = min(max(Fn,0),1);

% 2) Mild denoise (small, fast)
Fn = imboxfilt(Fn,3);

% 3) Light mask prior: local support (3x3). Weight kept small.
S = conv2(double(BW), ones(3)/9, 'same');   % 0..1
wMask = 0.55 + 0.45*S;                      % 0.55..1.0  (mask is supportive, not dominant)

% 4) Score: fluorescence^gamma, nudged by mask prior
gamma =  1.6*strength;                 % 0.9..2.5 → stronger shrink as strength↑
score = (Fn.^gamma) .* wMask;

% 5) Adaptive threshold *within BW*, biased up with strength
vals = score(BW);
t0 = (numel(vals)>32)*graythresh(vals) + (numel(vals)<=32)*0.5;
t  = min(0.98, max(0.02, t0 + 0.18*strength));   % more shrink as strength↑
BWout = BW & (score >= t);
end

