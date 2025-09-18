function params = load_or_init_params()
% Load params.json from the code folder; if missing, create from defaults.
% Applies a small migration to drop deprecated fields and fills any new ones.

    cfgPath = config_path();              % .../yourCodeFolder/config/params.json
    if ~isfile(cfgPath)
        params = default_params();
        save_params(params);
        return;
    end

    % Load JSON
    txt = fileread(cfgPath);
    params = jsondecode(txt);

    % Migrate: remove deprecated or add missing fields
    params = migrate_params(params);

    % Save back if migration changed anything
    save_params(params);
end









