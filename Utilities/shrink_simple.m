function BWout = shrink_simple(BW, F, strength,adaptiveSensitivity)
% SHRINK_SIMPLE  minimal edge-aware shrink.
% 1. Likelihood = local mask support (neighbors in BW)
% 2. Multiply by fluorescence
% 3. Adaptive threshold within original mask
%
% strength : 0..1  (higher = stronger shrink)

BW = logical(BW);
F  = double(F);

% 1. local mask likelihood (fraction of 3×3 neighborhood in ROI)
kernel = ones(3);
likelihood = conv2(double(BW), kernel, 'same') / 9;

% 2. multiply by normalized fluorescence (inside mask)
F = F - min(F(:));
if max(F(:))>0, F = F ./ max(F(:)); end
score = likelihood .* F;

% 3. adaptive threshold inside mask
T = adaptthresh(score, 0.5 + 0.3*strength, 'ForegroundPolarity','bright');
BWout = BW & imbinarize(score, T);

% % BW = logical(BW);
% % F  = double(F);
% % 
% % % 1. local mask likelihood (fraction of 3×3 neighborhood in ROI)
% % kernel = ones(5);
% % likelihood = conv2(double(BW), kernel, 'same') / 9;
% % 
% % % 2. multiply by normalized fluorescence (inside mask)
% % F = F - min(F(:));
% % if max(F(:))>0, F = F ./ max(F(:)); end
% % score = likelihood./(1-strength)+ (F/(strength));
% % % score = likelihood .* F;
% % 
% % % 3. adaptive threshold inside mask
% % % T = adaptthresh(score, adaptiveSensitivity); %  + 0.3*strength, 'ForegroundPolarity','bright');
% % T = adaptthresh(score, 0.5 + 0.3*strength, 'ForegroundPolarity','bright');
% % BWout = BW & imbinarize(score, T);

end
