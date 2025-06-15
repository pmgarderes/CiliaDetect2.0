function autoDetectSeedsCallback(hObject, ~)
    % Retrieve the handles structure
    handles = guidata(hObject);

    % Access the current image from the stack
    currentImage = handles.stack{handles.currentChannel}(:,:,handles.currentZ);

    % Retrieve detection parameters
    params = handles.params;

    % Perform seed detection
    seedPoints = detectCiliaSeeds(currentImage, params);

    % Store the detected seed points
    handles.seedPoints = seedPoints;

    % Visualize the detected seeds on the axes
    axes(handles.ax);  % Ensure the correct axes is active
    hold on;
    plot(seedPoints(:,1), seedPoints(:,2), 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
    hold off;

    % Update the handles structure
    guidata(hObject, handles);

    % Display the number of detected seeds
    fprintf('Detected %d seed points.\n', size(seedPoints, 1));
end
