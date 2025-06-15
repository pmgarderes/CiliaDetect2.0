function updateDisplay(hObject)
    handles = guidata(hObject);  % Retrieve the handles structure

    % Update the image data
    currentImage = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
    set(handles.imgHandle, 'CData', currentImage);

    % Update the title with current channel and Z-plane information
    title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
        handles.currentChannel, handles.currentZ, handles.numSlices), ...
        'Color', 'w', 'FontSize', 18);

    % Save the updated handles structure
    guidata(hObject, handles);

     % Bring focus back to the figure to ensure KeyPressFcn works
%     figure(handles.fig);
%     myfig = get(gcf);

    figure(handles.fig);
    % Refresh the display
    drawnow;
end
