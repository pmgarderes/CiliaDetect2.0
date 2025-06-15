function newParams = openParamEditor(currentParams)
    % Extract field names from the currentParams structure
    paramNames = fieldnames(currentParams);
    numParams = numel(paramNames);

    % Initialize prompts and default values
    prompts = cell(numParams, 1);
    defaultValues = cell(numParams, 1);

    for i = 1:numParams
        field = paramNames{i};
        value = currentParams.(field);
        prompts{i} = sprintf('%s:', field);

        % Convert the value to a string for display
        if isnumeric(value)
            defaultValues{i} = num2str(value);
        elseif ischar(value)
            defaultValues{i} = value;
        elseif islogical(value)
            defaultValues{i} = num2str(value);
        else
            defaultValues{i} = '';
        end
    end

    % Display the input dialog
    answer = inputdlg(prompts, 'Edit Parameters', [1 50], defaultValues);

    % If the user cancels, return empty
    if isempty(answer)
        newParams = [];
        return;
    end

    % Construct the newParams structure with updated values
    newParams = struct();
    for i = 1:numParams
        field = paramNames{i};
        originalValue = currentParams.(field);
        userInput = answer{i};

        % Convert the input string back to the original data type
        if isnumeric(originalValue)
            newParams.(field) = str2double(userInput);
        elseif ischar(originalValue)
            newParams.(field) = userInput;
        elseif islogical(originalValue)
            newParams.(field) = logical(str2double(userInput));
        else
            newParams.(field) = userInput;
        end
    end
end

% % function newParams = openParamEditor(currentParams)
% %     % Create a modal dialog
% %     d = dialog('Position', [300 300 250 200], 'Name', 'Edit Parameters');
% % 
% %     % Threshold
% %     uicontrol('Parent', d, ...
% %               'Style', 'text', ...
% %               'Position', [10 150 80 20], ...
% %               'String', 'Threshold:');
% %     thresholdField = uicontrol('Parent', d, ...
% %                                'Style', 'edit', ...
% %                                'Position', [100 150 100 20], ...
% %                                'String', num2str(currentParams.threshold));
% % 
% %     % Min Area
% %     uicontrol('Parent', d, ...
% %               'Style', 'text', ...
% %               'Position', [10 110 80 20], ...
% %               'String', 'Min Area:');
% %     minAreaField = uicontrol('Parent', d, ...
% %                              'Style', 'edit', ...
% %                              'Position', [100 110 100 20], ...
% %                              'String', num2str(currentParams.minArea));
% % 
% %     % Max Area
% %     uicontrol('Parent', d, ...
% %               'Style', 'text', ...
% %               'Position', [10 70 80 20], ...
% %               'String', 'Max Area:');
% %     maxAreaField = uicontrol('Parent', d, ...
% %                              'Style', 'edit', ...
% %                              'Position', [100 70 100 20], ...
% %                              'String', num2str(currentParams.maxArea));
% % 
% %     % Smoothing
% %     uicontrol('Parent', d, ...
% %               'Style', 'text', ...
% %               'Position', [10 30 80 20], ...
% %               'String', 'Smoothing:');
% %     smoothingField = uicontrol('Parent', d, ...
% %                                'Style', 'checkbox', ...
% %                                'Position', [100 30 100 20], ...
% %                                'Value', currentParams.smoothing);
% % 
% %     % OK and Cancel buttons
% %     uicontrol('Parent', d, ...
% %               'Position', [40 0 70 25], ...
% %               'String', 'OK', ...
% %               'Callback', @onOK);
% %     uicontrol('Parent', d, ...
% %               'Position', [140 0 70 25], ...
% %               'String', 'Cancel', ...
% %               'Callback', 'delete(gcf)');
% % 
% %     newParams = [];
% % 
% %     function onOK(~, ~)
% %         % Retrieve values from the fields
% %         threshold = str2double(get(thresholdField, 'String'));
% %         minArea = str2double(get(minAreaField, 'String'));
% %         maxArea = str2double(get(maxAreaField, 'String'));
% %         smoothing = get(smoothingField, 'Value');
% % 
% %         % Validate inputs (optional)
% %         if isnan(threshold) || isnan(minArea) || isnan(maxArea)
% %             errordlg('Please enter valid numeric values.', 'Invalid Input', 'modal');
% %             return;
% %         end
% % 
% %         % Update the parameters structure
% %         newParams = struct(...
% %             'threshold', threshold, ...
% %             'minArea', minArea, ...
% %             'maxArea', maxArea, ...
% %             'smoothing', logical(smoothing) ...
% %         );
% % 
% %         delete(d);  % Close the dialog
% %     end
% % 
% %     uiwait(d);  % Wait for the dialog to close
% % end
