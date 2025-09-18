function params = migrate_params(params)
% Remove deprecated fields and fill missing defaults.
    defaults = default_params();

    % 1) Remove deprecated/unused fields
    deprecated = {'fluorescenceMode','QuantificationDepth'};
    for k = 1:numel(deprecated)
        if isfield(params, deprecated{k})
            params = rmfield(params, deprecated{k});
        end
    end

    % 2) Add any missing new fields from defaults
    f = fieldnames(defaults);
    for k = 1:numel(f)
        if ~isfield(params, f{k})
            params.(f{k}) = defaults.(f{k});
        end
    end

    % 3) Optional: warn on unknown fields (typos)
    known = [fieldnames(defaults); "_meta"];
    extras = setdiff(fieldnames(params), known);
    if ~isempty(extras)
        warning('Unknown parameter fields found and kept: %s', strjoin(extras, ', '));
    end
end