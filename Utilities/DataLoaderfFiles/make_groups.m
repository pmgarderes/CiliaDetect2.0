function [bounds, sizes] = make_groups(n, DS, ~)
    G = max(1, round(n / DS));
    q = floor(n / G);
    r = n - q*G;
    sizes = [repmat(q+1, r, 1); repmat(q, G-r, 1)];
    bounds = zeros(G,2);
    s = 1;
    for g = 1:G
        e = s + sizes(g) - 1;
        bounds(g,:) = [s, e];
        s = e + 1;
    end
end
