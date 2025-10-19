function N = load_bioformats_image_downsampled2(folderPath, DSfactor, saveMetadata, statusHandle)
% Same interface as before, but now supports .nd2, .czi, .dv, .tif, .tiff

N = 0;
if nargin < 3 || isempty(saveMetadata), saveMetadata = true; end
if nargin < 4, statusHandle = []; end

% Ensure output folder
saveFolder = fullfile(folderPath, 'reduced_stack');
if ~isfolder(saveFolder), mkdir(saveFolder); end

% Gather files across extensions (add more as needed)
exts = {'.nd2','.czi','.dv','.tif','.tiff'};
files = [];
for e = 1:numel(exts)
    files = [files; dir(fullfile(folderPath, ['*' exts{e}]))]; %#ok<AGROW>
end
N = numel(files);
updateStatusText(statusHandle, sprintf('%d files were found (.nd2/.czi/.dv/.tif/.tiff)', N), '');

% Process each file
for i = 1:N
    fname    = files(i).name;
    fullpath = fullfile(folderPath, fname);
    [~, base, ext] = fileparts(fname);
    saveName = fullfile(saveFolder, [base '_reduced.mat']);

    updateStatusText(statusHandle, ...
        sprintf('%d files were found (.nd2/.czi/.dv/.tif/.tiff)', N), ...
        sprintf('... Pre-processing %s [%d/%d]', fname, i, N));

    try
        param = struct('DSfactor', DSfactor);

        % Prefer the unified Bio-Formats loader
        try
            [imgStack, metadata] = load_bioformats_stack_downsampled(fullpath, param);
        catch
            % Optional native fallback for TIFF only
            if any(strcmpi(ext,{'.tif','.tiff'}))
                [imgStack, metadata] = load_tiff_stack_downsampled_native(fullpath, param);
            else
                rethrow(lasterror); %#ok<LERR>
            end
        end

        if saveMetadata
            save(saveName, 'imgStack', 'metadata', '-v7.3');
        else
            save(saveName, 'imgStack', '-v7.3');
        end

        updateStatusText(statusHandle, ...
            sprintf('%d files were found (.nd2/.czi/.dv/.tif/.tiff)', N), ...
            sprintf('saved: %s [%d/%d]', fname, i, N));

    catch ME
        warning('Failed to process %s: %s', fname, ME.message);
        updateStatusText(statusHandle, ...
            sprintf('%d files were found (.nd2/.czi/.dv/.tif/.tiff)', N), ...
            sprintf('FAILED: %s [%d/%d]', fname, i, N));
    end
end

% Final message
msg2 = ternary(saveMetadata, ' Metadata also saved ', ' Metadata not saved. ');
updateStatusText(statusHandle, sprintf('%d files were pre-processed and saved ', N), msg2);
updateStatusText(statusHandle,' ', ' ');
end

function out = ternary(cond, a, b), if cond, out=a; else, out=b; end, end
