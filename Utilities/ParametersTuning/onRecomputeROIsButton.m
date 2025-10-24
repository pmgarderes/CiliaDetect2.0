function onRecomputeROIsButton(~, ~)
    % Recompute all cilia ROIs with (possibly) new parameters selected via the tuner.

    % Grab handles (assuming this callback is nested inside FullGUI)
    fig = handles.figure1;            % or your figure handle name
    oldPointer = get(fig,'Pointer');

    try
        set(fig,'Pointer','watch');
        drawnow;

        % 1) Ask user for updated params via the tuner (keeps old if Cancel)
        currParams = getfield_def(handles, 'params', struct());
        newParams  = openCiliaParamTunerFromHandles(currParams, handles);
        if isempty(newParams)
            % User cancelled – just bail out gracefully
            set(fig,'Pointer',oldPointer); drawnow;
            return;
        end
        % Keep boolean consistency and bounds
        if ~isfield(newParams,'useGOtsu'), newParams.useGOtsu = false; end
        if isfield(newParams,'adaptiveSensitivity')
            newParams.adaptiveSensitivity = min(max(newParams.adaptiveSensitivity,0),1);
        end
        if isfield(newParams,'strengthBridge')
            newParams.strengthBridge = min(max(newParams.strengthBridge,0),1);
        end
        if isfield(newParams,'strengthShrink')
            newParams.strengthShrink = min(max(newParams.strengthShrink,0),1);
        end
        if ~isfield(newParams,'windowSize') || ~isscalar(newParams.windowSize) || newParams.windowSize<=0
            newParams.windowSize = 64;
        end

        % 2) Get detections to recompute
        dets = getfield_def(handles, 'ciliaDetections', []);
        if isempty(dets)
            warndlg('No past cilia detections found.', 'Nothing to recompute');
            set(fig,'Pointer',oldPointer); drawnow;
            return;
        end
        if ~iscell(dets), dets = num2cell(dets); end

        % 3) Loop with a waitbar
        Hwb = waitbar(0,'Recomputing cilia masks...','Name','Cilia ROI Recompute');
        cleanup = onCleanup(@()tryCloseWaitbar(Hwb));

        for i = 1:numel(dets)
            waitbar((i-1)/numel(dets), Hwb, sprintf('Recomputing %d/%d...', i, numel(dets)));

            d = dets{i};
            if ~isstruct(d) || ~isfield(d,'click') || numel(d.click) < 2
                continue
            end
            seed = double(d.click(1:2));

            % Channel & Z
            ch = getfield_ifexists(d, {'channel','ch','Channel','Chan'}, getfield_def(handles,'currentChannel',1));
            ch = clampIndex(ch, numel(handles.stack), 1);
            I3 = getStack3D_preserve(handles.stack{ch});
            z  = getfield_ifexists(d, {'z','zIndex','Z','slice','idxZ'}, getfield_def(handles,'currentZ',1));
            z  = clampIndex(z, size_or_len(I3,3), 1);

            I = I3(:,:,z);

            % Crop around seed
            [Iroi, seedLocal, rect] = cropAroundSeedWithRect(I, seed, newParams.windowSize);
            ROI_for_det = im2single(Iroi);

            % Run detector
            try
                as = getfield_def(newParams,'adaptiveSensitivity',0.5);
                as = min(max(as,0),1);
                out = detect_cilium_from_seed2(ROI_for_det, seedLocal, newParams, as);
                if islogical(out)
                    BWroi = out;
                elseif isstruct(out) && isfield(out,'BW')
                    BWroi = logical(out.BW);
                else
                    BWroi = false(size(Iroi));
                end
            catch err
                warning('detect_cilium_from_seed2 failed on det %d: %s', i, err.message);
                BWroi = false(size(Iroi));
            end

            % Lift ROI mask back to full image size
            BWfull = false(size(I));
            x1 = rect(1); y1 = rect(2); x2 = rect(3); y2 = rect(4);
            if isequal(size(BWroi), [y2-y1+1, x2-x1+1])
                BWfull(y1:y2, x1:x2) = BWroi;
            else
                % Size mismatch fallback: skip write but keep going
                warning('ROI size mismatch on det %d. Skipping write-back.', i);
            end

            % Update detection entry
            d.BW                = BWfull;
            d.ch                = ch;
            d.z                 = z;
            d.paramsSnapshot    = newParams;     % keep a copy for provenance
            d.lastComputedTime  = datestr(now);  % human readable
            dets{i}             = d;
        end

        % 4) Save back & refresh GUI overlays
        handles.ciliaDetections = dets;
        handles.params          = newParams;      % persist tuned params
        guidata(fig, handles);

        % If you have your own refresh routine, call it here:
        if exist('refreshCiliaOverlay','file') == 2
            refreshCiliaOverlay(handles);
        else
            % no-op; or trigger whatever redraw your GUI uses
            if isfield(handles,'axesMain') && ishghandle(handles.axesMain)
                drawnow;
            end
        end

    catch ME
        set(fig,'Pointer',oldPointer);
        rethrow(ME);
    end

    set(fig,'Pointer',oldPointer);
    drawnow;

    % ------- helpers (nested) -------
    function [ROI, seedLocal, rect] = cropAroundSeedWithRect(I, seedXY, win)
        win = max(8, round(win)); half = round(win/2);
        x = round(seedXY(1)); y = round(seedXY(2));
        [H,W] = size(I);
        x1 = max(1, x - half); x2 = min(W, x + half);
        y1 = max(1, y - half); y2 = min(H, y + half);
        ROI = I(y1:y2, x1:x2);
        seedLocal = [x - x1 + 1, y - y1 + 1];
        rect = [x1 y1 x2 y2];
    end

    function tryCloseWaitbar(h)
        if ishghandle(h), close(h); end
    end
end
