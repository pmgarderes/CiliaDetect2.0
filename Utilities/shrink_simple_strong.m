function BWout = shrink_simple_strong(BW, F, strength)
% Aggressive edge-aware shrink (few lines).
% 1) local support with larger kernel  2) center bias (distance map)
% 3) multiply by fluorescence          4) adaptive threshold inside BW

BW = logical(BW); F = double(F);
if ~any(BW(:)), BWout = BW; return; end
strength = min(max(strength,0),1);

% --- width estimate (px) ---
D = bwdist(~BW);                         % radius inside mask
rad = D(BW); rad = rad(rad>0);
width = max(2, min(30, 2*median(rad))); % full width clamp

% --- 1) local mask support with bigger kernel as strength↑ ---
r0 = max(1, round(0.4*width));
% k  = 2*max(1, round((1+2*strength)*r0)) + 1;     % odd, grows with strength
k  = max(1, round((1+2*strength)*r0)) + 1;     % odd, grows with strength
S  = conv2(double(BW), ones(k)/(k*k), 'same');   % 0..1

% --- 2) center bias: favor interior over rim ---
C = 0;%min(1, D / max(1, (0.5*width)));            % 0 at edge -> 1 at core

% --- 3) fluorescence (normalized), stronger exponent as strength↑ ---
Fn = F - min(F(BW)); mx = max(1e-9, max(Fn(BW)));
Fn = zeros(size(Fn)); Fn(BW) = (F(BW)-min(F(BW)))/mx;   % normalize inside BW
gamma = 0.6 + 1.4*strength;                              % 0.6..2.0
score = S .* (C) .* (Fn.^gamma);

% --- 4) adaptive threshold inside BW (biased up as strength↑) ---
vals = score(BW);
t0 = (numel(vals)>16) * graythresh(vals) + (numel(vals)<=16)*0.5;
t  = min(0.98, max(0.05, t0 + 0.20*strength));           % stronger shrink
BWout = BW & (score >= t);
end

