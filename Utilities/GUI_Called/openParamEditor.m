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


