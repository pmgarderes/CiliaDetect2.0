function batch_downsample_nd2_folder(folderPath, DSfactor, saveMetadata)
% Reads all ND2 files in a folder, downsamples them, and saves them
% as [filename]_reduced.mat into a "reduced_stack" subfolder.
%
% Inputs:
%   - folderPath: string, full path to folder containing ND2 files
%   - DSfactor: scalar, e.g., 25
%   - saveMetadata: optional boolean (default: true)

if nargin < 3
    saveMetadata = true;
end

% Make save folder
saveFolder = fullfile(folderPath, 'reduced_stack');
if ~isfolder(saveFolder)
    mkdir(saveFolder);
end

% Find all ND2 files
nd2Files = dir(fullfile(folderPath, '*.nd2'));
fprintf('Found %d ND2 files in folder.\n', numel(nd2Files));

for i = 1:numel(nd2Files)
    nd2name = nd2Files(i).name;
    fullpath = fullfile(folderPath, nd2name);
    [~, basename, ~] = fileparts(nd2name);
    saveName = fullfile(saveFolder, [basename '_reduced.mat']);

    fprintf('[%d/%d] Processing: %s\n', i, numel(nd2Files), nd2name);

    try
        param.DSfactor = DSfactor;
        [imgStack, metadata] = load_nd2_image_downsampled(fullpath, param);

        if saveMetadata
            save(saveName, 'imgStack', 'metadata', '-v7.3');
        else
            save(saveName, 'imgStack', '-v7.3');
        end

        fprintf('Saved: %s\n', saveName);
    catch ME
        warning('Failed to process %s: %s', nd2name, ME.message);
    end
end

fprintf('Done.\n');
end
