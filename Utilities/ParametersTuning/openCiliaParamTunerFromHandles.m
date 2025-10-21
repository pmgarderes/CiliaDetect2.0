function newParams = openCiliaParamTunerFromHandles(currentParams, handles)
% Returns updated struct on Apply, [] on Cancel/close.

    % ---------- Build sample set ----------
    dets = handles.ciliaDetections;
    if isempty(dets), warndlg('No past cilia detections found.','No Samples'); newParams = []; return; end
    if ~iscell(dets), dets = num2cell(dets); end

    K = numel(dets);
    sampleImgs  = cell(K,1);
    sampleSeeds = nan(K,2);
    sampleCh    = nan(K,1);

    for i = 1:K
        d = dets{i};
        seed = double(d.click(1:2));
        sampleSeeds(i,:) = seed;

        ch = getfield_ifexists(d, {'channel','ch','Channel','Chan'}, handles.currentChannel);
        ch = clampIndex(ch, numel(handles.stack), 1);
        I3 = getStack3D_preserve(handles.stack{ch});
        z  = getfield_ifexists(d, {'z','zIndex','Z','slice','idxZ'}, handles.currentZ);
        z  = clampIndex(z, size_or_len(I3,3), 1);

        sampleImgs{i} = I3(:,:,z);
        sampleCh(i)   = ch;
    end

    ok = ~cellfun(@isempty, sampleImgs) & all(isfinite(sampleSeeds),2);
    sampleImgs  = sampleImgs(ok); sampleSeeds = sampleSeeds(ok,:); sampleCh = sampleCh(ok);
    if isempty(sampleImgs), warndlg('Could not build sample set from existing detections.','No Valid Samples'); newParams = []; return; end

    % ---------- Allow-list ----------
    allowList = ["windowSize","maxArea","minArea","adaptiveSensitivity", ...
                 "minThinness","minElongation","minEccentricity","maxEccentricity", ...
                 "prefilterEnable","prefilterScalePx","lineBridgeEnable"];
    keep = intersect(allowList, string(fieldnames(currentParams)),'stable');
    params = struct(); for k = 1:numel(keep), nm = keep(k); params.(nm) = currentParams.(nm); end
    if ~isfield(params,'windowSize') || ~isscalar(params.windowSize) || ~isfinite(params.windowSize) || params.windowSize<=0
        params.windowSize = 64; % safety
    end

    % ---------- GUI ----------
    newParams = [];                % important: this will be filled before uiresume
    fig = figure('Name','Cilia Detection – Parameter Tuner','NumberTitle','off', ...
        'MenuBar','none','ToolBar','none','Units','normalized','Position',[0.12 0.12 0.76 0.76], ...
        'Color',[0.97 0.97 0.97],'KeyPressFcn',@onKey,'CloseRequestFcn',@onClose);

    pLeft  = uipanel(fig,'Title','Parameters','Units','normalized','Position',[0.0 0 0.30 1]);
    pTop   = uipanel(fig,'Title','Controls','Units','normalized','Position',[0.30 0.92 0.70 0.08]);
    pRight = uipanel(fig,'Title','Preview (cropped around seed)','Units','normalized','Position',[0.30 0.0 0.70 0.92]);

    Ndefault = min( max(1, min(4, numel(sampleImgs))), numel(sampleImgs) );
    uicontrol(pTop,'Style','text','String','N:', 'Units','normalized','Position',[0.01 0.15 0.05 0.7], 'HorizontalAlignment','left');
    hN = uicontrol(pTop,'Style','edit','String',num2str(Ndefault),'Units','normalized','Position',[0.06 0.2 0.06 0.6],'Callback',@onNChange);
    uicontrol(pTop,'Style','pushbutton','String','Resample','Units','normalized','Position',[0.14 0.15 0.10 0.7],'Callback',@onResample);
    uicontrol(pTop,'Style','pushbutton','String','Save…','Units','normalized','Position',[0.27 0.15 0.10 0.7],'Callback',@onSave);
    uicontrol(pTop,'Style','pushbutton','String','Reset','Units','normalized','Position',[0.73 0.15 0.08 0.7],'Callback',@onReset);
    uicontrol(pTop,'Style','pushbutton','String','Apply','Units','normalized','Position',[0.82 0.15 0.08 0.7],'Callback',@onApply,'FontWeight','bold');
    uicontrol(pTop,'Style','pushbutton','String','Cancel','Units','normalized','Position',[0.91 0.15 0.08 0.7],'Callback',@onCancel);

    % Param controls
    paramNames  = fieldnames(params); original = params; ctrlHandles = struct();
    ctrlGap = 0.012; rowH = 0.045; y = 0.96;
    for i = 1:numel(paramNames)
        nm  = paramNames{i}; val = params.(nm);
        y = y - rowH - ctrlGap;
        uicontrol(pLeft,'Style','text','String',[nm ':'],'Units','normalized','Position',[0.05 y 0.42 rowH],'HorizontalAlignment','left');
        if islogical(val)
            h = uicontrol(pLeft,'Style','checkbox','Value',val,'Units','normalized','Position',[0.48 y 0.47 rowH], 'Callback',@(src,~)onParamLogical(nm,src));
        elseif isnumeric(val) && isscalar(val)
            h = uicontrol(pLeft,'Style','edit','String',num2str(val),'Units','normalized','Position',[0.48 y 0.47 rowH], 'BackgroundColor',[1 1 1], 'Callback',@(src,~)onParamNumeric(nm,src));
        else
            h = uicontrol(pLeft,'Style','text','String','[unsupported type]','Units','normalized','Position',[0.48 y 0.47 rowH],'HorizontalAlignment','left','ForegroundColor',[0.6 0 0]);
        end
        ctrlHandles.(nm) = h;
    end

    % Preview grid
    state.allImgs  = sampleImgs; state.allSeeds = sampleSeeds; state.allCh = sampleCh;
    state.idx      = pickIndices(Ndefault, numel(state.allImgs));
    [ax, imgH, ovlH] = buildTiledAxes(pRight, numel(state.idx));
    redrawAll();

    % Block until user applies/cancels/closes:
    uiwait(fig);

    % If the figure is still open, close it (defense)
    if isvalid(fig), delete(fig); end
    % newParams was set in onApply/onCancel before uiresume

    % ======== Callbacks ========
    function onParamNumeric(name, src)
        v = str2double(get(src,'String'));
        if isnan(v), set(src,'String',num2str(params.(name))); return; end
        if strcmp(name,'adaptiveSensitivity'), v = min(max(v,0),1); set(src,'String',num2str(v)); end
        params.(name) = v; redrawAll();
    end
    function onParamLogical(name, src), params.(name) = logical(get(src,'Value')); redrawAll(); end
    function onNChange(src, ~)
        nTry = round(str2double(get(src,'String'))); if isnan(nTry) || nTry < 1, nTry = numel(state.idx); end
        nTry = min(nTry, numel(state.allImgs)); state.idx = pickIndices(nTry, numel(state.allImgs));
        [ax, imgH, ovlH] = buildTiledAxes(pRight, numel(state.idx)); redrawAll();
    end
    function onResample(~,~), state.idx = pickIndices(numel(state.idx), numel(state.allImgs)); redrawAll(); end
    function onReset(~,~)
        params = original;
        for j = 1:numel(paramNames)
            nm = paramNames{j}; val = original.(nm); h = ctrlHandles.(nm);
            if ~ishandle(h), continue; end
            if islogical(val), set(h,'Value',val); else, set(h,'String',num2str(val)); end
        end
        redrawAll();
    end
    function onSave(~,~)
        try
            if isfield(handles,'workingDir') && isfolder(handles.workingDir)
                startPath = fullfile(handles.workingDir, 'CiliaParams.mat');
            else
                startPath = 'CiliaParams.mat';
            end
            [f,p] = uiputfile('*.mat','Save parameters as...', startPath);
            if isequal(f,0), return; end
            S = params; %#ok<NASGU>
            save(fullfile(p,f), 'S');
        catch err
            warndlg(sprintf('Could not save parameters:\n%s', err.message), 'Save Error');
        end
    end
    function onApply(~,~)
        newParams = params;     % <-- set output
        if strcmp(get(fig,'WaitStatus'),'waiting'), uiresume(fig); else, delete(fig); end
    end
    function onCancel(~,~)
        newParams = [];         % <-- cancel output
        if strcmp(get(fig,'WaitStatus'),'waiting'), uiresume(fig); else, delete(fig); end
    end
    function onClose(~,~)       % user clicked window [X]
        onCancel();
    end
    function onKey(~, evt)
        switch lower(evt.Key)
            case 'escape', onCancel();
            case 'r',      onResample();
        end
    end

    % ======== Drawing / helpers ========
    function [axArr, imgArr, ovlCells] = buildTiledAxes(parent, n)
        delete(allchild(parent));
        tl = tiledlayout(parent, bestRows(n), bestCols(n), 'Padding','compact','TileSpacing','compact');
        axArr = gobjects(n,1); imgArr = gobjects(n,1); ovlCells = cell(n,1);
        for ii = 1:n
            axArr(ii) = nexttile(tl); axis(axArr(ii),'image'); axis(axArr(ii),'off'); colormap(axArr(ii), gray);
            imgArr(ii) = imagesc(axArr(ii), 0); hold(axArr(ii),'on'); ovlCells{ii} = gobjects(0);
            title(axArr(ii), sprintf('Sample %d', ii));
        end
    end
    function r = bestRows(n), r = floor(sqrt(n)); if r*(r+1) < n, r = r+1; end; if r<1, r=1; end, end
    function c = bestCols(n), r = bestRows(n); c = ceil(n/r); end
    function idx = pickIndices(n, k), if n>=k, idx=(1:k).'; else, idx=randperm(k,n).'; end, end

    function redrawAll()
        if ~isfield(params,'windowSize') || ~isscalar(params.windowSize) || params.windowSize<=0
            params.windowSize = 64; if isfield(ctrlHandles,'windowSize') && ishandle(ctrlHandles.windowSize)
                set(ctrlHandles.windowSize,'String',num2str(params.windowSize)); end
        end
        for i = 1:numel(state.idx)
            gi = state.idx(i); I = state.allImgs{gi}; ch = state.allCh(gi); seed = state.allSeeds(gi,:);
            [Iroi, seedLocal] = cropAroundSeed(I, seed, params.windowSize);
            set(imgH(i), 'CData', double(Iroi)); axis(ax(i), 'image'); axis(ax(i), 'off'); colormap(ax(i), gray);
            [L,W] = getLWForChannel(ch); applyWindowLevelToAxes(ax(i), L, W);

            ROI_for_det = im2single(Iroi); BW = [];
            try
                if isfield(params,'adaptiveSensitivity'), as = min(max(params.adaptiveSensitivity,0),1); else, as = []; end
                out = detect_cilium_from_seed2(ROI_for_det, seedLocal, params, as);
                if islogical(out), BW = out;
                elseif isstruct(out) && isfield(out,'BW'), BW = logical(out.BW); end
            catch err
                warning('detect_cilium_from_seed2 error on sample %d: %s', gi, err.message); BW = [];
            end

            % Clear old overlays
            if ~isempty(ovlH{i}), for hh = reshape(ovlH{i},1,[]), if isgraphics(hh), delete(hh); end, end, end
            ovlH{i} = gobjects(0);

            if ~isempty(BW) && isequal(size(BW), size(Iroi))
                boundaries = bwboundaries(BW);
                for kk = 1:numel(boundaries)       % <-- fix: correct loop indexing
                    B = boundaries{kk};
                    h = plot(ax(i), B(:,2), B(:,1), 'g-', 'LineWidth', 1.5);
                    ovlH{i}(end+1,1) = h; %#ok<AGROW>
                end
            end
            drawnow limitrate;
        end
    end

    function [ROI, seedLocal] = cropAroundSeed(I, seedXY, win)
        win = max(8, round(win)); half = round(win/2);
        x = round(seedXY(1)); y = round(seedXY(2)); [H,W] = size(I);
        x1 = max(1, x - half); x2 = min(W, x + half); y1 = max(1, y - half); y2 = min(H, y + half);
        ROI = I(y1:y2, x1:x2); seedLocal = [x - x1 + 1, y - y1 + 1];
    end
    function [L,W] = getLWForChannel(ch)
        if isfield(handles,'LW_by_channel') && size(handles.LW_by_channel,1) >= ch && all(isfinite(handles.LW_by_channel(ch,:)))
            L = handles.LW_by_channel(ch,1); W = handles.LW_by_channel(ch,2);
        else, L = handles.windowLevel; W = handles.windowWidth; end
    end
    function applyWindowLevelToAxes(axh, L, W), w = max(W, eps); caxis(axh, [L - w/2, L + w/2]); end
    function Z = getStack3D_preserve(x)
        if isnumeric(x), if ndims(x)==2, Z = reshape(x, size(x,1), size(x,2), 1); else, Z = x; end
        elseif iscell(x), n = numel(x); s0 = size(x{1}); Z = zeros([s0 n], class(x{1})); for ii=1:n, Z(:,:,ii)=x{ii}; end
        else, error('Unsupported stack format in handles.stack{ch}'); end
    end
    function v = getfield_ifexists(s, names, defaultV), v = defaultV; for ii = 1:numel(names), if isfield(s, names{ii}), v = s.(names{ii}); return; end, end, end
    function out = clampIndex(v, vmax, vdefault), if isempty(v) || ~isfinite(v) || v<1, out=vdefault; else, out=min(max(1, round(v)), vmax); end, end
    function L = size_or_len(A, dim), s = size(A); if numel(s) < dim, L = 1; else, L = s(dim); end, end
end
