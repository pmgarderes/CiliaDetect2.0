function N = batch_downsample_nd2_folder_liveReport(folderPath, DSfactor, saveMetadata, statusHandle)
% Inputs:
%   folderPath  : string path
%   DSfactor    : scalar downsample factor
%   saveMetadata: boolean
%   statusHandle: handle to your text uicontrol (shortcutPanel)
N = 0 ; 
if nargin < 3 || isempty(saveMetadata), saveMetadata = true; end

% Ensure output folder
saveFolder = fullfile(folderPath, 'reduced_stack');
if ~isfolder(saveFolder), mkdir(saveFolder); end

% List ND2 files
nd2Files = dir(fullfile(folderPath, '*.nd2'));
N = numel(nd2Files);
updateStatusText(statusHandle, sprintf('%d files were found of type nd2', N), '');

% Process each file
for i = 1:N
    nd2name  = nd2Files(i).name;
    fullpath = fullfile(folderPath, nd2name);
    [~, base, ~] = fileparts(nd2name);
    saveName = fullfile(saveFolder, [base '_reduced.mat']);

    updateStatusText(statusHandle, ...
        sprintf('%d files were found of type nd2', N), ...
        sprintf('... Pre-processing %s [%d/%d]', 'file', i, N));
    %         sprintf('processing: %s [%d/%d]', nd2name, i, N));
    try
        param.DSfactor = DSfactor;
        [imgStack, metadata] = load_nd2_image_downsampled(fullpath, param);

        if saveMetadata
            save(saveName, 'imgStack', 'metadata', '-v7.3');
        else
            save(saveName, 'imgStack', '-v7.3');
        end

        updateStatusText(statusHandle, ...
            sprintf('%d files were found of type nd2', N), ...
            sprintf('saved: %s [%d/%d]',  'file', i, N));

    catch ME
        warning('Failed to process %s: %s', nd2name, ME.message);
        updateStatusText(statusHandle, ...
            sprintf('%d files were found of type nd2', N), ...
            sprintf('FAILED: %s [%d/%d]',  'file', i, N));
    end
end

% Final message
if saveMetadata
    msg2  = ' Metadata also saved ';
else
   msg2  = ' Metadata not saved. ';
end
updateStatusText(statusHandle, sprintf('%d files of type nd2 were pre-processed and saved ', N), msg2);

updateStatusText(statusHandle,' ', ' ');
end


% % function batch_downsample_nd2_folder_liveReport(folderPath, DSfactor, saveMetadata, statusFcn)
% % if nargin < 3 || isempty(saveMetadata), saveMetadata = true; end
% % if nargin < 4, statusFcn = []; end
% % hasStatus = ~isempty(statusFcn) && isa(statusFcn,'function_handle');
% % 
% % saveFolder = fullfile(folderPath, 'reduced_stack');
% % if ~isfolder(saveFolder), mkdir(saveFolder); end
% % 
% % nd2Files = dir(fullfile(folderPath, '*.nd2'));
% % N = numel(nd2Files);
% % if hasStatus, statusFcn(N, 0, N, '', 'found'); end
% % 
% % for i = 1:N
% %     nd2name  = nd2Files(i).name;
% %     fullpath = fullfile(folderPath, nd2name);
% %     [~, base, ~] = fileparts(nd2name);
% %     saveName = fullfile(saveFolder, [base '_reduced.mat']);
% % 
% %     if hasStatus, statusFcn(N, i, N, nd2name, 'processing'); end
% %     try
% %         param.DSfactor = DSfactor;
% %         [imgStack, metadata] = load_nd2_image_downsampled(fullpath, param);
% % 
% %         if saveMetadata
% %             save(saveName, 'imgStack', 'metadata', '-v7.3');
% %         else
% %             save(saveName, 'imgStack', '-v7.3');
% %         end
% % 
% %         if hasStatus, statusFcn(N, i, N, nd2name, 'saved'); end
% %     catch ME
% %         warning('Failed to process %s: %s', nd2name, ME.message);
% %         if hasStatus, statusFcn(N, i, N, nd2name, 'failed'); end
% %     end
% % end
% % 
% % if hasStatus, statusFcn(N, N, N, '', 'done'); end
% % end


% % function batch_downsample_nd2_folder_liveReport(folderPath, DSfactor, saveMetadata, progressFcn, cancelFcn)
% % 
% % % Reads all ND2 files in a folder, downsamples them, and saves them
% % % as [filename]_reduced.mat into a "reduced_stack" subfolder.
% % %
% % % Inputs:
% % %   - folderPath: string, full path to folder containing ND2 files
% % %   - DSfactor: scalar, e.g., 25
% % %   - saveMetadata: optional boolean (default: true)
% % %   - progressFcn: optional @(i, n, msg) for live updates
% % %   - cancelFcn:   optional @() -> true if user requested cancel
% % 
% % if nargin < 3 || isempty(saveMetadata), saveMetadata = true; end
% % if nargin < 4 || isempty(progressFcn), progressFcn = []; end
% % if nargin < 5 || isempty(cancelFcn),   cancelFcn   = @() false; end
% % hasProg = ~isempty(progressFcn) && isa(progressFcn,'function_handle');
% % 
% % % Make save folder
% % saveFolder = fullfile(folderPath, 'reduced_stack');
% % if ~isfolder(saveFolder), mkdir(saveFolder); end
% % 
% % % Find all ND2 files
% % nd2Files = dir(fullfile(folderPath, '*.nd2'));
% % N = numel(nd2Files);
% % if hasProg, progressFcn(0, max(N,1), sprintf('Found %d ND2 files', N)); end
% % 
% % for i = 1:N
% %     if cancelFcn(), error('UserCanceled:Preprocess','User canceled preprocessing.'); end
% % 
% %     nd2name  = nd2Files(i).name;
% %     fullpath = fullfile(folderPath, nd2name);
% %     [~, basename, ~] = fileparts(nd2name);
% %     saveName = fullfile(saveFolder, [basename '_reduced.mat']);
% % 
% %     if hasProg, progressFcn(i-1, N, sprintf('Processing: %s', nd2name)); end
% %     drawnow
% %     try
% %         param.DSfactor = DSfactor;
% %         [imgStack, metadata] = load_nd2_image_downsampled(fullpath, param);
% %          if cancelFcn(), error('UserCanceled:Preprocess','User canceled preprocessing.'); end
% % 
% %         if saveMetadata
% %             save(saveName, 'imgStack', 'metadata', '-v7.3');
% %         else
% %             save(saveName, 'imgStack', '-v7.3');
% %         end
% % 
% %         if hasProg, progressFcn(i, N, sprintf('Saved: %s', saveName)); end
% %     catch ME
% %         if strcmp(ME.identifier,'UserCanceled:Preprocess'), rethrow(ME); end
% %         if hasProg, progressFcn(i, N, sprintf('Failed: %s (%s)', nd2name, ME.message)); end
% %         warning('Failed to process %s: %s', nd2name, ME.message);
% %     end
% % end
% % 
% % if hasProg, progressFcn(N, max(N,1), 'Done.'); end
% % end
