function updateCiliaCount(hObject)
    handles = guidata(hObject);  % Retrieve the updated handles structure
    count = numel(handles.ciliaDetections);
    set(handles.countLabel, 'String', sprintf('Cilia Count: %d', count));
    guidata(hObject, handles);  % Save any changes to handles
    if count==50
%         msgbox('Hurrah! 50 cilia!', 'Success', 'help');
                % Load your image
        img = imread(fullfile('./images/hurrah50.jpg')); % Replace with your image path

        % Create a new figure window
        fig = figure('Name', 'Hurrah!', 'NumberTitle', 'off', 'Position', [300 100 800 600]);

        % Display the image
            imshow(img);
    end

end
