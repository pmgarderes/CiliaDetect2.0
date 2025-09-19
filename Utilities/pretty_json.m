function pretty = pretty_json(ugly)
% Make jsonencode output human-friendly.
    try
        % MATLAB R2021b+: jsonencode('PrettyPrint',true) exists — if so, use it instead.
        pretty = ugly;
        pretty = strrep(pretty, ',"', sprintf(',\n  "'));
        pretty = strrep(pretty, '{"', sprintf('{\n  "'));
        pretty = strrep(pretty, '}', sprintf('\n}'));
    catch
        pretty = ugly;
    end
end
