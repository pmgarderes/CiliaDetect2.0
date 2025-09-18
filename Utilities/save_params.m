function save_params(params)
% Save params to JSON (human-readable) in the code folder.
    cfgPath = config_path();
    [cfgDir,~,~] = fileparts(cfgPath);
    if ~isfolder(cfgDir), mkdir(cfgDir); end
    params.meta.version = 1;
    params.meta.last_modified = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    jsonStr = jsonencode(params);
    jsonStr = pretty_json(jsonStr);  % nice formatting
    fid = fopen(cfgPath,'w');
    assert(fid>0, 'Cannot write %s', cfgPath);
    fwrite(fid, jsonStr, 'char');
    fclose(fid);
end