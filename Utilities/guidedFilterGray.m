function q = guidedFilterGray(I, p, win, eps)
% Simple gray guided filter (He et al., 2010)
I = double(I); p = double(p);
h = fspecial('average', win);

mean_I  = imfilter(I,h,'replicate');
mean_p  = imfilter(p,h,'replicate');
mean_Ip = imfilter(I.*p,h,'replicate');
cov_Ip  = mean_Ip - mean_I.*mean_p;

mean_II = imfilter(I.*I,h,'replicate');
var_I   = mean_II - mean_I.^2;

a = cov_Ip ./ (var_I + eps);
b = mean_p - a .* mean_I;

mean_a = imfilter(a,h,'replicate');
mean_b = imfilter(b,h,'replicate');

q = mean_a .* I + mean_b;
end
