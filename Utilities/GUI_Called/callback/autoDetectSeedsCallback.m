function autoDetectSeedsCallback(hObject, ~)


    % Retrieve GUI state
    handles = guidata(hObject);
    params  = handles.params;

    % display messages : 
    set(handles.WAITstatus, 'String', 'WAIT');
    
    % ---- How many cilia to find?
    answer = inputdlg({'How many cilia do you intend to find in this image?'}, ...
                      'Auto-detect cilia', 1, {num2str( min(50, 5) )});
    if isempty(answer), return; end
    targetN = str2double(answer{1});
    if ~isfinite(targetN) || targetN < 1, return; end
    targetN = round(targetN);

    % ---- Channel & Z-plane for seeding / segmentation
    seedCh = 1;
    if isfield(handles,'currentChannel') && ~isempty(handles.currentChannel)
        seedCh = handles.currentChannel;
    elseif isfield(params,'seedChannel')
        seedCh = params.seedChannel;
    end
    seedCh = max(1, min(seedCh, numel(handles.stack)));

    z0 = 1;
    if isfield(handles,'currentZ') && ~isempty(handles.currentZ)
        z0 = handles.currentZ;
    end

    % Pull stack dims
    stack = handles.stack;   % cell {nCh}, each YxXxZ
    [H,W,Z] = size(stack{seedCh});
    z0 = max(1, min(Z, z0)); % clamp

    % ---- Build seeding image on the CURRENT Z-PLANE ONLY
    plane = double(stack{seedCh}(:,:,z0));

    % optional top-hat to pop cilia
    if isfield(params,'tophatRadius') && params.tophatRadius > 0
        se = strel('disk', params.tophatRadius);
        plane = imtophat(plane, se);
    end
    % light smoothing
    planeF = imgaussfilt(plane, 1.0);

    % ---- Seeding parameters
    if isfield(params,'seedExclusionRadius') && ~isempty(params.seedExclusionRadius)
        radius = round(params.seedExclusionRadius);
    else
        radius = max(6, round(params.windowSize/3));   % px
    end
    if isfield(params,'seedMinPeakPercentile') && ~isempty(params.seedMinPeakPercentile)
        pct = params.seedMinPeakPercentile;
    else
        pct = 70;                                      % only pick peaks above this percentile
    end

    % ---- Ensure bookkeeping fields exist (manual-compatible)
    if ~isfield(handles,'ciliaDetections') || isempty(handles.ciliaDetections)
        handles.ciliaDetections = {};
    end
    if ~isfield(handles,'roiHandles') || isempty(handles.roiHandles)
        handles.roiHandles = {};
    end
    if ~isfield(handles,'testedPoints') || isempty(handles.testedPoints)
        handles.testedPoints = table('Size',[0 8], ...
            'VariableTypes',{'double','double','double','double','double','double','logical','double'}, ...
            'VariableNames',{'x','y','z','intensity','area','elong','passed','channel'});
    end

    % ---- Build forbidden mask from existing manual-style detections + tested points
    forbidden = build_forbidden_mask(false(H,W), handles.ciliaDetections, ...
                                     handles.testedPoints, radius, seedCh, z0);

    % ---- Pick seeds
    [px, py] = pick_top_peaks_iterative(planeF, targetN, radius, pct, forbidden);
    if isempty(px)
        msgbox('No candidate peaks found on this plane (after exclusion/threshold).', 'No peaks','warn');
        return;
    end

    % ---- Suppress seeds too close to existing detections and to each other (2D)
    minSep = max(8, round(params.windowSize / 3)); % px

    existingCenters = [];
    if ~isempty(handles.ciliaDetections)
        try
            C = cellfun(@(d) get_detection_center(d.mask), handles.ciliaDetections, 'uni', false);
            existingCenters = vertcat(C{:});
        catch
            existingCenters = [];
        end
    end

    sel = false(numel(px),1);
    kept = 0;
    for k = 1:numel(px)
        p = [px(k), py(k)];
        if any(p <= 1) || p(1) > W || p(2) > H, continue; end
        if ~isempty(existingCenters)
            if min(sum((existingCenters - p).^2, 2)) < (minSep^2), continue; end
        end
        if any(sel)
            S = [px(sel), py(sel)];
            if min(sum((S - p).^2, 2)) < (minSep^2), continue; end
        end
        sel(k) = true;
        kept = kept + 1;
        if kept >= targetN, break; end
    end
    px = px(sel); py = py(sel);
    if isempty(px)
        msgbox('All candidate peaks were too close to existing/selected seeds.', 'No seeds','warn');
        return;
    end

    % ---- Test/segment each seed and SAVE LIKE MANUAL
    added = 0;
    for k = 1:numel(px)
        % (A) Segment using the same function as manual, or keep your scoring pipeline.
        % If you prefer EXACT parity with manual, use detect_cilium_from_seed2:
        currentFrame = stack{seedCh}(:,:,z0);
        mask = detect_cilium_from_seed2(currentFrame, [px(k), py(k)], params, params.adaptiveSensitivity);

        % If you want to keep your scoring, you can instead do:
        % [mask, area, elong, ecc, passed] = build_and_score_roi(stack{seedCh}, [px(k), py(k), z0], params);

        % Quick derived features for logging (optional, safe if mask empty)
        area = nnz(mask);
        elong = NaN;
        passed = area > 0; % treat non-empty mask as success; adapt if you have a criterion

        % Log tested point
        handles.testedPoints = [handles.testedPoints; { ...
            px(k), py(k), z0, planeF(py(k),px(k)), area, elong, logical(passed), seedCh}]; %#ok<AGROW>

        if ~passed, continue; end

        % (B) SAVE to the SAME FIELDS as manual ROI
        detectionStruct = struct( ...
            'channel', seedCh, ...
            'zplane',  z0, ...
            'click',   [px(k), py(k)], ...
            'mask',    mask);
        handles.ciliaDetections{end+1} = detectionStruct; %#ok<AGROW>

        % (C) Draw boundary + point, and store graphics in roiHandles (like manual)
        ax = handles.ax;  % same axis used by manual path
        hold(ax, 'on');
        boundaries = bwboundaries(mask);
        roiGroup = gobjects(0);
        for b = 1:numel(boundaries)
            B = boundaries{b};
            h = plot(ax, B(:,2), B(:,1), 'g-', 'LineWidth', 1.5);
            roiGroup(end+1) = h; %#ok<AGROW>
        end
        hPoint = plot(ax, px(k), py(k), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
        roiGroup(end+1) = hPoint;
        handles.roiHandles{end+1} = roiGroup; %#ok<AGROW>

        added = added + 1;
    end

    % ---- Update state & UI
    guidata(hObject, handles);
    if isfield(handles,'status')
        updateStatusText(handles.status, '', ...
            sprintf('Auto-detect (Z=%d): %d tested, %d added.', z0, targetN , added));
    end
    if isfield(handles,'redrawFcn') && isa(handles.redrawFcn,'function_handle')
        try handles.redrawFcn(); end %#ok<TRYNC>
    end

    % ---- (Optional) overlay all tested points for this z/ch
    ax = handles.ax;
    hold(ax,'on');
    tp = handles.testedPoints;
    if ~isempty(tp)
        selTP = tp.channel==seedCh & tp.z==z0;
        plot(ax, tp.x(selTP), tp.y(selTP), 'r.', 'MarkerSize', 5);
    end
    
    set(handles.WAITstatus, 'String', '');
end

