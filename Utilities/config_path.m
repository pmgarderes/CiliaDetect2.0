function pathOut = config_path()
% Build a config path anchored to the folder containing THIS file.
% Result: <thisFolder>/config/params.json
    here = mfilename('fullpath');
    hereDir = fileparts(here);
    pathOut = fullfile(hereDir, 'config', 'params.json');
end