function preprocessCallback(hObject, ~)
    handles = guidata(hObject);

    % Pick folder
    foldername = uigetdir(pwd, 'Select folder with ND2 files to downsample');
    if isequal(foldername,0)
        updateStatusText(handles.status, '', 'Pre-processing canceled.');
        return;
    end

    % Ask DS factor (default 25 or last used)
    def = '25';
    if isfield(handles,'DSfactor') && ~isempty(handles.DSfactor)
        def = num2str(handles.DSfactor);
    end
    answ = inputdlg({'Downsample factor (integer > 0):'}, 'Preprocess Options', 1, {def});
    if isempty(answ)
        updateStatusText(handles.status, '', 'Pre-processing canceled.');
        return;
    end
    DSfactor = str2double(answ{1});
    if isnan(DSfactor) || DSfactor <= 0
        errordlg('Invalid downsample factor. Must be a positive number.','Invalid input');
        return;
    end

    handles.DSfactor   = DSfactor;
    handles.workingDir = foldername;
    guidata(hObject, handles);

    % Kickoff message
%     updateStatusText(handles.status, '', sprintf('WAIT,  Pre-processing in: %s', foldername));
%     msg = sprintf('WAIT, Pre-processing in:\n%s', foldername);
    set(handles.WAITstatus, 'String', 'WAIT');
    msg = sprintf(' ... Pre-processing in:');
    updateStatusText(handles.status, msg, foldername);
    % Run batch (just pass the text handle)
    try
        N = batch_downsample_nd2_folder_liveReport(handles.workingDir, DSfactor, true, handles.status_Operation);
        updateStatusText(handles.status, 'Done.', '');
    catch ME
        updateStatusText(handles.status, 'Error during pre-processing:', ME.message);
        rethrow(ME);
        N = 0 ; 
    end
    
    updateStatusText(handles.status, '', sprintf('Done pre-processing '));
    updateStatusText(statusHandle, sprintf('%d files of type nd2 were pre-processed and saved ', N), msg2);
    set(handles.WAITstatus, 'String', '');
end


% % % function preprocessCallback(hObject, ~)
% % %     handles = guidata(hObject);
% % % 
% % %     % Pick folder
% % %     foldername = uigetdir(pwd, 'Select folder with ND2 files to downsample');
% % %     if isequal(foldername,0)
% % %         setStatus(handles, '', 'Pre-processing canceled.');
% % %         return;
% % %     end
% % % 
% % %     % Ask DS factor (default 25 or last used)
% % %     def = '25';
% % %     if isfield(handles,'DSfactor') && ~isempty(handles.DSfactor)
% % %         def = num2str(handles.DSfactor);
% % %     end
% % %     answ = inputdlg({'Downsample factor (integer > 0):'}, 'Preprocess Options', 1, {def});
% % %     if isempty(answ)
% % %         setStatus(handles, '', 'Pre-processing canceled.');
% % %         return;
% % %     end
% % %     DSfactor = str2double(answ{1});
% % %     if isnan(DSfactor) || DSfactor <= 0
% % %         errordlg('Invalid downsample factor. Must be a positive number.','Invalid input');
% % %         return;
% % %     end
% % % 
% % %     handles.DSfactor   = DSfactor;
% % %     handles.workingDir = foldername;
% % %     guidata(hObject, handles);
% % % 
% % %     % Status: starting
% % %     setStatus(handles, '', sprintf('Pre-processing in: %s', foldername));
% % % 
% % %     % Define a simple status function to pass to the batch function
% % %     function statusFcn(nFound, i, N, filename, phase)
% % %         % nFound: total files found (constant); i: current index (1..N)
% % %         % phase: 'found'|'processing'|'saved'|'done'|'failed'
% % %         switch phase
% % %             case 'found'
% % %                 line1 = sprintf('%d files were found of type nd2', nFound);
% % %                 line2 = '';
% % %             case 'processing'
% % %                 line1 = sprintf('%d files were found of type nd2', N);
% % %                 line2 = sprintf('processing: %s [%d/%d]', filename, i, N);
% % %             case 'saved'
% % %                 line1 = sprintf('%d files were found of type nd2', N);
% % %                 line2 = sprintf('saved: %s [%d/%d]', filename, i, N);
% % %             case 'failed'
% % %                 line1 = sprintf('%d files were found of type nd2', N);
% % %                 line2 = sprintf('FAILED: %s [%d/%d]', filename, i, N);
% % %             case 'done'
% % %                 line1 = sprintf('%d files were found of type nd2', N);
% % %                 line2 = 'done.';
% % %             otherwise
% % %                 line1 = ''; line2 = '';
% % %         end
% % %         setStatus(guidata(hObject), line1, line2);
% % %         drawnow limitrate;
% % %     end
% % % 
% % %     % Run batch (no progress bar)
% % %     try
% % %         batch_downsample_nd2_folder_liveReport(handles.workingDir, DSfactor, true, statusFcn);
% % %         statusFcn(0, 1, 1, '', 'done');
% % %     catch ME
% % %         setStatus(handles, '', sprintf('Error: %s', ME.message));
% % %         rethrow(ME);
% % %     end
% % % end


% % % function preprocessCallback(hObject, ~)
% % %     handles = guidata(hObject);
% % % 
% % %     % --- 1) Pick folder and DS factor ---
% % %     foldername = uigetdir(pwd, 'Select folder with ND2 files to downsample');
% % %     if isequal(foldername,0), appendLog('Pre-processing canceled.'); return; end
% % % 
% % %     def = '25';
% % %     if isfield(handles,'DSfactor') && ~isempty(handles.DSfactor), def = num2str(handles.DSfactor); end
% % %     answ = inputdlg({'Downsample factor (integer > 0):'}, 'Preprocess Options', 1, {def});
% % %     if isempty(answ), appendLog('Pre-processing canceled.'); return; end
% % %     DSfactor = str2double(answ{1});
% % %     if isnan(DSfactor) || DSfactor<=0, errordlg('Invalid downsample factor.','Invalid input'); return; end
% % % 
% % %     handles.DSfactor   = DSfactor;
% % %     handles.workingDir = foldername;
% % % 
% % %     % --- 2) Ensure UI elements (log + progress) exist ---
% % %     handles = ensureLogBox(handles);           % handles.logBox
% % %     handles = ensureProgressBar(handles);      % handles.progressOuter, progressInner, progressLabel
% % %     guidata(hObject, handles);
% % % 
% % %     % --- 3) Reset progress UI ---
% % %     set(handles.progressInner, 'Position', [handles.progressInnerPos(1:2), 0, handles.progressInnerPos(4)]);
% % %     set(handles.progressLabel, 'String', 'Ready...');
% % %     appendLog(sprintf('Pre-processing in: %s', foldername));
% % % 
% % %     % --- 4) Add a Cancel button (embedded) ---
% % %     if ~isfield(handles,'cancelBtn') || ~ishandle(handles.cancelBtn)
% % %         handles.cancelRequested = false;
% % %         handles.cancelBtn = uicontrol('Style','pushbutton','String','Cancel', ...
% % %             'Units','normalized','Position',[0.35 0.65 0.08 0.04], ...
% % %             'Callback', @(btn,~) setCancelFlag(btn));
% % %         guidata(hObject, handles);
% % %     else
% % %         handles.cancelRequested = false;
% % %         guidata(hObject, handles);
% % %     end
% % % 
% % %     % --- 5) Define progress + cancel functions (nested) ---
% % %     function setCancelFlag(btn)
% % %         H = guidata(btn);
% % %         H.cancelRequested = true;
% % %         guidata(btn, H);
% % %         appendLog('Cancellation requested...');
% % %         set(H.progressLabel,'String','Cancelling...');
% % %     end
% % % 
% % %     function tf = isCanceled()
% % %         H = guidata(hObject);
% % %         tf = isfield(H,'cancelRequested') && H.cancelRequested;
% % %     end
% % % 
% % %     function progressFcn(i, n, msg)
% % %         % i in [0..n], n >= 1
% % %         H = guidata(hObject);
% % %         frac = max(0, min(1, i/max(n,1)));
% % %         % grow inner bar width linearly with frac
% % %         outerPos = get(H.progressOuter, 'Position');
% % %         newW = frac * H.progressMaxWidth;
% % %         pos  = [H.progressInnerPos(1:2), newW, H.progressInnerPos(4)];
% % %         set(H.progressInner, 'Position', pos);
% % %         set(H.progressLabel, 'String', sprintf('[%d/%d] %s', i, n, msg));
% % %         appendLog(sprintf('[%d/%d] %s', i, n, msg));
% % %         drawnow limitrate;
% % %     end
% % % 
% % %     % --- 6) Run the batch (no waitbar) ---
% % %     try
% % %         batch_downsample_nd2_folder_liveReport(foldername, DSfactor, true, @progressFcn, @isCanceled);
% % %         progressFcn(1,1,'Done.');
% % %     catch ME
% % %         if strcmp(ME.identifier,'UserCanceled:Preprocess')
% % %             appendLog('Pre-processing canceled by user.');
% % %         else
% % %             errordlg(sprintf('Preprocessing failed:\n%s', ME.message), 'Error');
% % %             rethrow(ME);
% % %         end
% % %     end
% % % 
% % %     % --- 7) Cleanup Cancel button ---
% % %     handles = guidata(hObject);
% % %     if isfield(handles,'cancelBtn') && ishandle(handles.cancelBtn)
% % %         delete(handles.cancelBtn);
% % %         handles = rmfield(handles,'cancelBtn');
% % %     end
% % %     guidata(hObject, handles);
% % % 
% % %     % ------- helpers (nested) -------
% % %     function H = ensureLogBox(H)
% % %         if ~isfield(H,'logBox') || ~ishandle(H.logBox)
% % %             H.logBox = uicontrol('Style','listbox','Units','normalized', ...
% % %                 'Position',[0.35, 0.38, 0.30, 0.22], ...
% % %                 'BackgroundColor',[0.96 0.96 0.96], ...
% % %                 'FontName','Consolas', 'Max',1,'Min',0, ...
% % %                 'String', {});
% % %         end
% % %     end
% % % 
% % %     function appendLog(txt)
% % %         H = guidata(hObject);
% % %         H = ensureLogBox(H);
% % %         cur = get(H.logBox,'String');
% % %         if ischar(cur), cur = {cur}; end
% % %         cur{end+1} = txt;
% % %         set(H.logBox,'String',cur, 'Value', numel(cur));  % auto-scroll to last
% % %         drawnow limitrate;
% % %         guidata(hObject, H);
% % %     end
% % % 
% % % 
% % %     function H = ensureProgressBar(H)
% % %         % Outer (track)
% % %         if ~isfield(H,'progressOuter') || ~ishandle(H.progressOuter)
% % %             H.progressOuter = uicontrol('Style','text','Units','normalized', ...
% % %                 'Position',[0.35 0.58 0.30 0.015], 'BackgroundColor',[0.85 0.85 0.85], ...
% % %                 'TooltipString','Pre-processing progress');
% % %         end
% % %         outerPos = get(H.progressOuter,'Position');
% % %         % Inner (fill)
% % %         if ~isfield(H,'progressInner') || ~ishandle(H.progressInner)
% % %             H.progressInner = uicontrol('Style','text','Units','normalized', ...
% % %                 'Position',[outerPos(1) outerPos(2) 0 outerPos(4)], 'BackgroundColor',[0.20 0.65 0.20]);
% % %         end
% % %         % Label
% % %         if ~isfield(H,'progressLabel') || ~ishandle(H.progressLabel)
% % %             H.progressLabel = uicontrol('Style','text','Units','normalized', ...
% % %                 'Position',[0.35 0.65 0.30 0.02], 'BackgroundColor',get(H.fig,'Color'), ...
% % %                 'HorizontalAlignment','left','String','', 'FontWeight','bold');
% % %         end
% % %         % Cache sizes
% % %         H.progressInnerPos = get(H.progressInner,'Position');
% % %         H.progressMaxWidth = outerPos(3);
% % %     end
% % % end
