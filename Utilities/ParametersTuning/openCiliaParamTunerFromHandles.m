function newParams = openCiliaParamTunerFromHandles(currentParams, handles)
% Returns updated struct on Apply, [] on Cancel/close.

% ---------- Build sample set ----------
dets = getfield_def(handles,'ciliaDetections',[]);
if ~iscell(dets), dets = num2cell(dets); end

K = numel(dets);
sampleImgs  = cell(K,1);
sampleSeeds = nan(K,2);
sampleCh    = nan(K,1);

for i = 1:K
    d = dets{i};
    if ~isstruct(d) || ~isfield(d,'click') || numel(d.click) < 2
        continue
    end
    seed = double(d.click(1:2));
    sampleSeeds(i,:) = seed;

    ch = getfield_ifexists(d, {'channel','ch','Channel','Chan'}, getfield_def(handles,'currentChannel',1));
    ch = clampIndex(ch, numel(handles.stack), 1);
    I3 = getStack3D_preserve(handles.stack{ch});
    z  = getfield_ifexists(d, {'z','zIndex','Z','slice','idxZ'}, getfield_def(handles,'currentZ',1));
    z  = clampIndex(z, size_or_len(I3,3), 1);

    sampleImgs{i} = I3(:,:,z);
    sampleCh(i)   = ch;
end

ok = ~cellfun(@isempty, sampleImgs) & all(isfinite(sampleSeeds),2);
sampleImgs  = sampleImgs(ok);
sampleSeeds = sampleSeeds(ok,:);
sampleCh    = sampleCh(ok);
% NOTE: Do NOT early-return if empty; GUI still opens for Load/Save/Apply.

% ---------- Allow-list ----------
allowList = ["windowSize","maxArea","minArea","adaptiveSensitivity", ...
    "minThinness","minElongation","minEccentricity","maxEccentricity", ...
    "prefilterEnable","prefilterScalePx","lineBridgeEnable","useGOtsu", ...
    "splitOverlapsEnable","splitMinCoreDistPx", ...
    "strengthBridge","strengthShrink"];

keep = intersect(allowList, string(fieldnames(currentParams)),'stable');
params = struct();
for k = 1:numel(keep), nm = keep(k); params.(nm) = currentParams.(nm); end

% Ensure required/default params
if ~isfield(params,'useGOtsu'),             params.useGOtsu = false; end
if ~isfield(params,'splitOverlapsEnable'),  params.splitOverlapsEnable = false; end
if ~isfield(params,'strengthBridge'),       params.strengthBridge = 0.6; end
if ~isfield(params,'strengthShrink'),       params.strengthShrink = 0.2; end
if ~isfield(params,'prefilterEnable'),      params.prefilterEnable = false; end
if ~isfield(params,'prefilterScalePx'),     params.prefilterScalePx = 2; end
if ~isfield(params,'lineBridgeEnable'),     params.lineBridgeEnable = true; end

if ~isfield(params,'windowSize') || ~isscalar(params.windowSize) || ~isfinite(params.windowSize) || params.windowSize<=0
    params.windowSize = 64;
end

% ---------- Help/tooltip text ----------
helpText = struct();
helpText.windowSize          = 'Crop size (px) around the seed for preview and detection.';
helpText.maxArea             = 'Reject detections with area above this (px^2).';
helpText.minArea             = 'Reject detections with area below this (px^2).';
helpText.adaptiveSensitivity = '0–1: higher = more sensitive thresholding (keeps more pixels).';
helpText.minThinness         = 'Lower bound on thinness (4πA/P^2). Filters stubby/round shapes.';
helpText.minElongation       = 'Lower bound on elongation (major/minor). Enforce cilium-like shapes.';
helpText.minEccentricity     = 'Lower bound on region eccentricity (0..1).';
helpText.maxEccentricity     = 'Upper bound on region eccentricity (0..1).';
helpText.prefilterEnable     = 'If on, a mild pre-filter (e.g., blur/DoG) improves SNR before detection.';
helpText.prefilterScalePx    = 'Prefilter scale (px). Typical 1–3 px.';
helpText.lineBridgeEnable    = 'If on, connect faint gaps along a line between ciliary segments.';
helpText.useGOtsu            = 'Use global Otsu instead of adaptive local thresholding.';
helpText.splitOverlapsEnable = 'If on, attempt to split overlapping/merged cilia.';
helpText.splitMinCoreDistPx  = 'Min core-to-core distance (px) to allow splitting.';
helpText.strengthBridge      = '0–1: how aggressively bridging fills gaps (higher = more bridging).';
helpText.strengthShrink      = '0–1: how much to erode after bridging to trim overgrowth (higher = more shrink).';

% ---------- GUI ----------
newParams = []; % will be set before uiresume
fig = figure('Name','Cilia Detection – Parameter Tuner','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Units','normalized','Position',[0.12 0.12 0.76 0.76], ...
    'Color',[0.97 0.97 0.97],'KeyPressFcn',@onKey,'CloseRequestFcn',@onClose);

% Left column split into 3 grouped panels
pLeft  = uipanel(fig,'Title','','Units','normalized','Position',[0.0 0 0.30 1],'BorderType','none');

gDetect  = uipanel(pLeft,'Title','1. Detection & Thresholding','Units','normalized', ...
    'Position',[0.05 0.67 0.90 0.30]);
gCrit    = uipanel(pLeft,'Title','2. Inclusion / Exclusion Criteria','Units','normalized', ...
    'Position',[0.05 0.33 0.90 0.32]);
gFilter  = uipanel(pLeft,'Title','3. Filtering & Bridging','Units','normalized', ...
    'Position',[0.05 0.02 0.90 0.29]);

pTop   = uipanel(fig,'Title','Controls','Units','normalized','Position',[0.30 0.92 0.70 0.08]);
pRight = uipanel(fig,'Title','Preview (cropped around seed)','Units','normalized','Position',[0.30 0.0 0.70 0.92]);

% Controls panel (N, load/save/apply)
Ndefault = min( max(0, min(4, numel(sampleImgs))), numel(sampleImgs) ); % allow 0 when no samples

uicontrol(pTop,'Style','text','String','N:', 'Units','normalized','Position',[0.01 0.15 0.05 0.7], 'HorizontalAlignment','left');
hN = uicontrol(pTop,'Style','edit','String',num2str(Ndefault),'Units','normalized','Position',[0.06 0.2 0.06 0.6],'Callback',@onNChange);

uicontrol(pTop,'Style','pushbutton','String','Resample','Units','normalized','Position',[0.14 0.15 0.10 0.7],'Callback',@onResample);
uicontrol(pTop,'Style','pushbutton','String','Load…','Units','normalized','Position',[0.27 0.15 0.10 0.7],'Callback',@onLoad);
uicontrol(pTop,'Style','pushbutton','String','Save…','Units','normalized','Position',[0.39 0.15 0.10 0.7],'Callback',@onSave);
uicontrol(pTop,'Style','pushbutton','String','Reset','Units','normalized','Position',[0.73 0.15 0.08 0.7],'Callback',@onReset);
uicontrol(pTop,'Style','pushbutton','String','Apply','Units','normalized','Position',[0.82 0.15 0.08 0.7],'Callback',@onApply,'FontWeight','bold');
uicontrol(pTop,'Style','pushbutton','String','Cancel','Units','normalized','Position',[0.91 0.15 0.08 0.7],'Callback',@onCancel);

% ---------- Param controls (grouped, compact 2-col layout) ----------
ctrlHandles = struct(); original = params;

% UI scale
rowH = 0.065;         % compact rows
gap  = 0.015;         % small vertical gap
fs   = 9;             % smaller font size

% Position helpers for 2 columns (label+edit each)
col = struct();
col.lbl1 = [0.04  0    0.20 rowH];
col.ed1  = [0.25  0    0.18 rowH];
col.lbl2 = [0.52  0    0.20 rowH];
col.ed2  = [0.73  0    0.18 rowH];

% --- 1) Detection & Thresholding group ---------------------------------
y = 0.88;

% windowSize (row 1, col1)
p1 = col.lbl1; p1(2)=y; p2 = col.ed1; p2(2)=y;
[ctrlHandles.windowSize, ~] = addNumeric(gDetect,'windowSize',params.windowSize,p1,p2,helpText.windowSize);

% Threshold mode popup (row 1, col2)
p3 = col.lbl2; p3(2)=y; p4 = col.ed2; p4(2)=y;
uicontrol(gDetect,'Style','text','String','thresholdMode:','Units','normalized', ...
    'Position',p3,'HorizontalAlignment','left','TooltipString','Select thresholding mode','FontSize',fs);
ctrlHandles.threshMode = uicontrol(gDetect,'Style','popupmenu','Units','normalized', ...
    'String',{'Adaptive (local)','Global Otsu'},'Value', 1 + double(params.useGOtsu), ...
    'Position',p4,'TooltipString',helpText.useGOtsu,'FontSize',fs, ...
    'Callback',@(src,~)onThreshPopup(src));

% adaptiveSensitivity (row 2, col1)
y = y - rowH - gap;
p1 = col.lbl1; p1(2)=y; p2 = col.ed1; p2(2)=y;
[ctrlHandles.adaptiveSensitivity, ~] = addNumeric(gDetect,'adaptiveSensitivity', ...
    bound01(getfield_def(params,'adaptiveSensitivity',0.5)), p1,p2,helpText.adaptiveSensitivity);
set(ctrlHandles.adaptiveSensitivity,'FontSize',fs);

% --- 2) Inclusion / Exclusion Criteria ---------------------------------
y2 = 0.88;

% minArea (r1c1)  /  maxArea (r1c2)
p1 = col.lbl1; p1(2)=y2; p2 = col.ed1; p2(2)=y2;
[ctrlHandles.minArea, ~] = addNumeric(gCrit,'minArea',getfield_def(params,'minArea',20), p1,p2,helpText.minArea);
p3 = col.lbl2; p3(2)=y2; p4 = col.ed2; p4(2)=y2;
[ctrlHandles.maxArea, ~] = addNumeric(gCrit,'maxArea',getfield_def(params,'maxArea',5000), p3,p4,helpText.maxArea);

% minThinness (r2c1) / minElongation (r2c2)
y2 = y2 - rowH - gap;
p1 = col.lbl1; p1(2)=y2; p2 = col.ed1; p2(2)=y2;
[ctrlHandles.minThinness, ~]   = addNumeric(gCrit,'minThinness',getfield_def(params,'minThinness',0.05), p1,p2,helpText.minThinness);
p3 = col.lbl2; p3(2)=y2; p4 = col.ed2; p4(2)=y2;
[ctrlHandles.minElongation, ~] = addNumeric(gCrit,'minElongation',getfield_def(params,'minElongation',1.8), p3,p4,helpText.minElongation);

% minEcc (r3c1) / maxEcc (r3c2)
y2 = y2 - rowH - gap;
p1 = col.lbl1; p1(2)=y2; p2 = col.ed1; p2(2)=y2;
[ctrlHandles.minEccentricity, ~] = addNumeric(gCrit,'minEccentricity',getfield_def(params,'minEccentricity',0.6), p1,p2,helpText.minEccentricity);
p3 = col.lbl2; p3(2)=y2; p4 = col.ed2; p4(2)=y2;
[ctrlHandles.maxEccentricity, ~] = addNumeric(gCrit,'maxEccentricity',getfield_def(params,'maxEccentricity',0.999), p3,p4,helpText.maxEccentricity);

% --- 3) Filtering & Bridging -------------------------------------------
y3 = 0.88;

% PrefilterEnable (r1c1 checkbox) + prefilterScalePx (r1c2)
pChk = [0.04 y3 0.40 rowH];
[ctrlHandles.prefilterEnable, ~] = addCheckbox(gFilter,'prefilterEnable',logical(params.prefilterEnable), pChk, helpText.prefilterEnable, @onParamLogical);
set(ctrlHandles.prefilterEnable,'FontSize',fs);
p3 = col.lbl2; p3(2)=y3; p4 = col.ed2; p4(2)=y3;
[ctrlHandles.prefilterScalePx, ~] = addNumeric(gFilter,'prefilterScalePx',params.prefilterScalePx, p3,p4,helpText.prefilterScalePx);

% splitOverlapsEnable (r2c1) + splitMinCoreDistPx (r2c2)
y3 = y3 - rowH - gap;
pChk = [0.04 y3 0.40 rowH];
[ctrlHandles.splitOverlapsEnable, ~] = addCheckbox(gFilter,'splitOverlapsEnable',logical(params.splitOverlapsEnable), pChk, helpText.splitOverlapsEnable, @onParamLogical);
set(ctrlHandles.splitOverlapsEnable,'FontSize',fs);
p3 = col.lbl2; p3(2)=y3; p4 = col.ed2; p4(2)=y3;
[ctrlHandles.splitMinCoreDistPx, ~]  = addNumeric(gFilter,'splitMinCoreDistPx',getfield_def(params,'splitMinCoreDistPx',3), p3,p4,helpText.splitMinCoreDistPx);

% lineBridgeEnable (r3c1) + strengthBridge (r3c2)
y3 = y3 - rowH - gap;
pChk = [0.04 y3 0.40 rowH];
[ctrlHandles.lineBridgeEnable, ~] = addCheckbox(gFilter,'lineBridgeEnable',logical(params.lineBridgeEnable), pChk, helpText.lineBridgeEnable, @onParamLogical);
set(ctrlHandles.lineBridgeEnable,'FontSize',fs);
p3 = col.lbl2; p3(2)=y3; p4 = col.ed2; p4(2)=y3;
[ctrlHandles.strengthBridge, ~] = addNumeric(gFilter,'strengthBridge',bound01(params.strengthBridge), p3,p4,helpText.strengthBridge);

% strengthShrink (r4c2 only)
y3 = y3 - rowH - gap;
p3 = col.lbl2; p3(2)=y3; p4 = col.ed2; p4(2)=y3;
[ctrlHandles.strengthShrink, ~] = addNumeric(gFilter,'strengthShrink',bound01(params.strengthShrink), p3,p4,helpText.strengthShrink);

% --- Apply compact font size to all numeric edits/labels in the three panels
set(findall(gDetect,'-property','FontSize'),'FontSize',fs);
set(findall(gCrit,  '-property','FontSize'),'FontSize',fs);
set(findall(gFilter,'-property','FontSize'),'FontSize',fs);

% Replace radio-group logic with popup callback
    function onThreshPopup(src)
        val = get(src,'Value'); % 1=Adaptive, 2=GOtsu
        params.useGOtsu = (val==2);
        refreshEnableStates();
        redrawAll();
    end


% ---------- Preview grid ----------
state.allImgs  = sampleImgs; state.allSeeds = sampleSeeds; state.allCh = sampleCh;
if isempty(state.allImgs)
    state.idx = zeros(0,1);
    [ax, imgH, ovlH] = deal(gobjects(0), gobjects(0), cell(0,1));
    buildEmptyPreviewPanel(pRight);
else
    state.idx = pickIndices(Ndefault, numel(state.allImgs));
    [ax, imgH, ovlH] = buildTiledAxes(pRight, numel(state.idx));
    redrawAll();
end


% Initial enable/disable based on current params
refreshEnableStates();

% Block until user applies/cancels/closes:
uiwait(fig);
if isvalid(fig), delete(fig); end

% ======== Callbacks ========
    function onParamNumeric(name, src)
        v = str2double(get(src,'String'));
        if isnan(v), set(src,'String',num2str(params.(name))); return; end
        if any(strcmp(name,{'adaptiveSensitivity','strengthBridge','strengthShrink'}))
            v = bound01(v);
            set(src,'String',num2str(v));
        end
        params.(name) = v;
        redrawAll();
    end

    function onParamLogical(name, src)
        params.(name) = logical(get(src,'Value'));
        refreshEnableStates();
        redrawAll();
    end


    function onNChange(src, ~)
        nTry = round(str2double(get(src,'String'))); 
        if isnan(nTry) || nTry < 0, nTry = numel(state.idx); end
        nTry = min(nTry, numel(state.allImgs)); 
        state.idx = pickIndices(nTry, numel(state.allImgs));
        if isempty(state.idx)
            buildEmptyPreviewPanel(pRight);
            [ax, imgH, ovlH] = deal(gobjects(0), gobjects(0), cell(0,1));
        else
            [ax, imgH, ovlH] = buildTiledAxes(pRight, numel(state.idx)); 
            redrawAll();
        end
    end

    function buildEmptyPreviewPanel(parent)
        delete(allchild(parent));
        uicontrol(parent,'Style','text','Units','normalized', ...
            'Position',[0.05 0.40 0.90 0.20], 'String', ...
            'No preview samples available. You can still Load/Save and Apply parameters.', ...
            'FontAngle','italic','HorizontalAlignment','center');
    end

    function onResample(~,~)
        state.idx = pickIndices(numel(state.idx), numel(state.allImgs));
        if isempty(state.idx)
            buildEmptyPreviewPanel(pRight);
            [ax, imgH, ovlH] = deal(gobjects(0), gobjects(0), cell(0,1));
        else
            redrawAll();
        end
    end

    function onReset(~,~)
        params = original;

% % %         % Push values back into controls (numeric & logical)
% % %         setIf(ctrlHandles,'windowSize', params.windowSize);
% % %         setIf(ctrlHandles,'adaptiveSensitivity', bound01(getfield_def(params,'adaptiveSensitivity',0.5)));
% % %         setIf(ctrlHandles,'minArea', getfield_def(params,'minArea',20));
% % %         setIf(ctrlHandles,'maxArea', getfield_def(params,'maxArea',5000));
% % %         setIf(ctrlHandles,'minThinness', getfield_def(params,'minThinness',0.05));
% % %         setIf(ctrlHandles,'minElongation', getfield_def(params,'minElongation',1.8));
% % %         setIf(ctrlHandles,'minEccentricity', getfield_def(params,'minEccentricity',0.6));
% % %         setIf(ctrlHandles,'maxEccentricity', getfield_def(params,'maxEccentricity',0.999));
% % %         setIf(ctrlHandles,'prefilterEnable', logical(getfield_def(params,'prefilterEnable',false)));
% % %         setIf(ctrlHandles,'prefilterScalePx', getfield_def(params,'prefilterScalePx',2));
% % %         setIf(ctrlHandles,'splitOverlapsEnable', logical(getfield_def(params,'splitOverlapsEnable',false)));
% % %         setIf(ctrlHandles,'splitMinCoreDistPx', getfield_def(params,'splitMinCoreDistPx',3));
% % %         setIf(ctrlHandles,'lineBridgeEnable', logical(getfield_def(params,'lineBridgeEnable',true)));
% % %         setIf(ctrlHandles,'strengthBridge', bound01(getfield_def(params,'strengthBridge',0.6)));
% % %         setIf(ctrlHandles,'strengthShrink', bound01(getfield_def(params,'strengthShrink',0.2)));
% % %         % Set threshold popup from params.useGOtsu (1=Adaptive, 2=GOtsu)
% % %         if isfield(ctrlHandles,'threshMode') && ishghandle(ctrlHandles.threshMode)
% % %             set(ctrlHandles.threshMode,'Value', 1 + double(params.useGOtsu));
% % %         end

        try
            pd = default_params();   % <- your function
        catch
            pd = struct();           % be defensive if not on path
        end
    
        % Overwrite current params with allowed fields from pd
        for nm = allowList
            cn = char(nm);
            if isfield(pd, cn)
                params.(cn) = pd.(cn);
            end
        end
        refreshEnableStates();
        if isempty(state.allImgs)
            buildEmptyPreviewPanel(pRight);
        else
            redrawAll();
        end
    end


    function onLoad(~,~)
        try
            startPath = './config/CiliaParams.mat';
            [f,p] = uigetfile('*.mat','Load parameters from...', startPath);
            if isequal(f,0), return; end
            L = load(fullfile(p,f));
            if isfield(L,'S') && isstruct(L.S)
                Lp = L.S;
            else
                fn = fieldnames(L); Lp = [];
                for ii=1:numel(fn), if isstruct(L.(fn{ii})), Lp = L.(fn{ii}); break; end, end
                if isempty(Lp), warndlg('No struct found in MAT file.','Load Error'); return; end
            end
            for nm = allowList
                nm = char(nm);
                if isfield(Lp, nm), params.(nm) = Lp.(nm); end
            end
            % Clamp/normalize
            if isfield(params,'adaptiveSensitivity'), params.adaptiveSensitivity = bound01(params.adaptiveSensitivity); end
            if isfield(params,'strengthBridge'),      params.strengthBridge      = bound01(params.strengthBridge); end
            if isfield(params,'strengthShrink'),      params.strengthShrink      = bound01(params.strengthShrink); end

            % Push to UI
            setIf(ctrlHandles,'windowSize', params.windowSize);

            % Set threshold popup from params.useGOtsu (1=Adaptive, 2=GOtsu)
            if isfield(ctrlHandles,'threshMode') && ishghandle(ctrlHandles.threshMode)
                set(ctrlHandles.threshMode,'Value', 1 + double(params.useGOtsu));
            end

            setIf(ctrlHandles,'adaptiveSensitivity', getfield_def(params,'adaptiveSensitivity',0.5));
            setIf(ctrlHandles,'minArea', getfield_def(params,'minArea',20));
            setIf(ctrlHandles,'maxArea', getfield_def(params,'maxArea',5000));
            setIf(ctrlHandles,'minThinness', getfield_def(params,'minThinness',0.05));
            setIf(ctrlHandles,'minElongation', getfield_def(params,'minElongation',1.8));
            setIf(ctrlHandles,'minEccentricity', getfield_def(params,'minEccentricity',0.6));
            setIf(ctrlHandles,'maxEccentricity', getfield_def(params,'maxEccentricity',0.999));
            setIf(ctrlHandles,'prefilterEnable', logical(getfield_def(params,'prefilterEnable',false)));
            setIf(ctrlHandles,'prefilterScalePx', getfield_def(params,'prefilterScalePx',2));
            setIf(ctrlHandles,'splitOverlapsEnable', logical(getfield_def(params,'splitOverlapsEnable',false)));
            setIf(ctrlHandles,'splitMinCoreDistPx', getfield_def(params,'splitMinCoreDistPx',3));
            setIf(ctrlHandles,'lineBridgeEnable', logical(getfield_def(params,'lineBridgeEnable',true)));
            setIf(ctrlHandles,'strengthBridge', getfield_def(params,'strengthBridge',0.6));
            setIf(ctrlHandles,'strengthShrink', getfield_def(params,'strengthShrink',0.2));

            refreshEnableStates();
            redrawAll();

            refreshEnableStates();
            redrawAll();
        catch err
            warndlg(sprintf('Could not load parameters:\n%s', err.message), 'Load Error');
        end
    end

    function onSave(~,~)
        try
            startPath = './config/CiliaParams.mat';
            [cfgDir,~,~] = fileparts(startPath);
            if ~isempty(cfgDir) && ~isfolder(cfgDir), mkdir(cfgDir); end
            [f,p] = uiputfile('*.mat','Save parameters as...', startPath);
            if isequal(f,0), return; end
            S = params; %#ok<NASGU>
            save(fullfile(p,f), 'S');
        catch err
            warndlg(sprintf('Could not save parameters:\n%s', err.message), 'Save Error');
        end
    end

% %     function onApply(~,~)
% %         newParams = params;
% %         if strcmp(get(fig,'WaitStatus'),'waiting'), uiresume(fig); else, delete(fig); end
% %     end
    function onApply(~,~)
        newParams = params; 
        % Save as the new defaults so next time the GUI can preload them
            cfgDir = './config';
            if ~isfolder(cfgDir), mkdir(cfgDir); end
            msg = 'Parameters applied.\nThese will be used as defaults next time you open the GUI.';
            msgbox(sprintf(msg),'Defaults Updated','help');    
        if strcmp(get(fig,'WaitStatus'),'waiting'), uiresume(fig); else, delete(fig); end
    end


    function onCancel(~,~)
        newParams = [];
        if strcmp(get(fig,'WaitStatus'),'waiting'), uiresume(fig); else, delete(fig); end
    end

    function onClose(~,~), onCancel(); end

    function onKey(~, evt)
        switch lower(evt.Key)
            case 'escape', onCancel();
            case 'r',      onResample();
        end
    end

% ======== Drawing / helpers ========
    function refreshEnableStates()
        % Thresholding mode
        isAdaptive = ~params.useGOtsu;
        setEnabled(ctrlHandles.adaptiveSensitivity, isAdaptive);

        % Prefilter dependency
        setEnabled(ctrlHandles.prefilterScalePx, logical(params.prefilterEnable));

        % Split overlaps dependency
        setEnabled(ctrlHandles.splitMinCoreDistPx, logical(params.splitOverlapsEnable));

        % Bridging dependency
        setEnabled(ctrlHandles.strengthBridge, logical(params.lineBridgeEnable));
        setEnabled(ctrlHandles.strengthShrink, logical(params.lineBridgeEnable));
    end

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
        if isempty(state.idx), return; end
        if ~isfield(params,'windowSize') || ~isscalar(params.windowSize) || params.windowSize<=0
            params.windowSize = 64;
            setIf(ctrlHandles,'windowSize', params.windowSize);
        end
        for i = 1:numel(state.idx)
            gi = state.idx(i); I = state.allImgs{gi}; ch = state.allCh(gi); seed = state.allSeeds(gi,:);
            [Iroi, seedLocal] = cropAroundSeed(I, seed, params.windowSize);
            set(imgH(i), 'CData', double(Iroi)); axis(ax(i), 'image'); axis(ax(i), 'off'); colormap(ax(i), gray);
            [L,W] = getLWForChannel(ch); applyWindowLevelToAxes(ax(i), L, W);

            ROI_for_det = im2single(Iroi); BW = [];
            try
                as = bound01(getfield_def(params,'adaptiveSensitivity',0.5));
                out = detect_cilium_from_seed2(ROI_for_det, seedLocal, params, as);
                if islogical(out), BW = out;
                elseif isstruct(out) && isfield(out,'BW'), BW = logical(out.BW); end
            catch err
                warning('detect_cilium_from_seed2 error on sample %d: %s', gi, err.message); BW = [];
            end

            % Clear old overlays
            if ~isempty(ovlH{i}), for hh = reshape(ovlH{i},1,[]), if isgraphics(hh), delete(hh); end, end, end
            ovlH{i} = gobjects(0);

            % Seed cross (small red "x")
            hSeed = plot(ax(i), seedLocal(1), seedLocal(2), 'rx', 'MarkerSize', 7, 'LineWidth', 1.3);
            ovlH{i}(end+1,1) = hSeed; %#ok<AGROW>

            % Mask outlines
            if ~isempty(BW) && isequal(size(BW), size(Iroi))
                boundaries = bwboundaries(BW);
                for kk = 1:numel(boundaries)
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

% ---------- tiny utils ----------
    function v = getfield_def(S, name, def), if isfield(S,name), v=S.(name); else, v=def; end, end
    function setIf(H, name, val)
        if isfield(H,name) && ishghandle(H.(name))
            h = H.(name);
            switch get(h,'Style')
                case 'checkbox', set(h,'Value',logical(val));
                otherwise,        set(h,'String',num2str(val));
            end
        end
    end
    function tf = setEnabled(h, tf), if ishghandle(h), set(h,'Enable', iff(tf,'on','off')); end, end
    function out = iff(cond,a,b), if cond, out=a; else, out=b; end, end
    function x = bound01(x), x = min(max(x,0),1); end

    function [hEdit, hLbl] = addNumeric(parent, name, val, posLbl, posEdit, tip)
        hLbl  = uicontrol(parent,'Style','text','String',[name ':'],'Units','normalized', ...
            'Position',posLbl,'HorizontalAlignment','left','TooltipString',tip);
        hEdit = uicontrol(parent,'Style','edit','String',num2str(val),'Units','normalized', ...
            'Position',posEdit,'BackgroundColor',[1 1 1],'TooltipString',tip, ...
            'Callback',@(src,~)onParamNumeric(name,src));
    end
    function [hChk, hLbl] = addCheckbox(parent, name, val, posChk, tip, cb)
        hChk = uicontrol(parent,'Style','checkbox','String',name,'Units','normalized', ...
            'Position',posChk,'Value',logical(val),'TooltipString',tip, ...
            'Callback',@(src,~)cb(name,src));
        hLbl = []; %#ok<NASGU>
    end

    function L = size_or_len(A, dim), s = size(A); if numel(s) < dim, L = 1; else, L = s(dim); end, end

    function v = getfield_ifexists(S, names, defaultV)
        % Return the first existing, non-empty field among `names` from struct S; else defaultV.
        % names can be a char, string, or cellstr of candidate field names.
        v = defaultV;
        if ~isstruct(S), return; end
        if ischar(names) || isstring(names)
            names = cellstr(names);
        end
        for ii = 1:numel(names)
            nm = names{ii};
            if isfield(S, nm)
                val = S.(nm);
                if ~isempty(val)
                    v = val;
                    return;
                end
            end
        end
    end
    function out = clampIndex(v, vmax, vdefault)
        % Clamp index v to [1..vmax]; if v is empty/non-finite/<1, return vdefault.
        if isempty(v) || ~isfinite(v) || v < 1
            out = vdefault;
        else
            out = min(max(1, round(v)), vmax);
        end
    end

end
