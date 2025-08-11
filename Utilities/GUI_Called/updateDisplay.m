function [clim] = updateDisplay(hObject)
    handles = guidata(hObject);  % Retrieve the handles structure

    % Update the image data
    currentImage = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
    set(handles.imgHandle, 'CData', currentImage);
    

    % Re-apply the current window/level (if you keep them in handles)
    I = double(handles.stack{handles.currentChannel}(:,:,handles.currentZ));
    lo = prctile(I(:),1);  hi = prctile(I(:),99);         % robust stretch
    caxis(handles.ax,[lo hi]); set(handles.ax,'CLimMode','manual');
    handles.windowLevel = mean([lo hi]);
    handles.windowWidth = hi - lo;
    applyWindowLevel(handles);   % sets clim(handles.ax,[L - W/2, L + W/2])

    clim = [lo hi];
    % Update the title with current channel and Z-plane information
    title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
        handles.currentChannel, handles.currentZ, handles.numSlices), ...
        'Color', 'w', 'FontSize', 18);

    % Save the updated handles structure
    guidata(hObject, handles);

%     guidata(hObject, handles.fig);
    

    figure(handles.fig);
    % Refresh the display
    drawnow;
end
