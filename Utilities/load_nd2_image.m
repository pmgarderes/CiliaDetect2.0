function [imgStack, metadata] = load_nd2_image(filename)
    % Make sure Bio-Formats is in your path
    assert(exist('bfGetReader', 'file') == 2, ...
        'Bio-Formats not found. Add bfmatlab to your path.');

    % Create Bio-Formats reader
    reader = bfGetReader(filename);
    
    % Initialize
    numSeries = reader.getSeriesCount();
    imgStack = cell(numSeries, 1);
    metadata = cell(numSeries, 1);
    
    for s = 1:numSeries
        reader.setSeries(s-1); % 0-indexed
        stackSize = reader.getImageCount();
        width = reader.getSizeX();
        height = reader.getSizeY();
        numZ = reader.getSizeZ();
        numC = reader.getSizeC();
        numT = reader.getSizeT();

        fprintf('Series %d: size=[%d x %d], Z=%d, C=%d, T=%d\n', ...
            s, width, height, numZ, numC, numT);

        % Preallocate 4D array (Z, Y, X, C or T depending)
        imgSeries = zeros(height, width, stackSize, 'uint16'); % Adjust if needed

        for i = 1:stackSize
            plane = bfGetPlane(reader, i);
            imgSeries(:,:,i) = plane;
        end

        imgStack{s} = imgSeries;
        metadata{s} = reader.getMetadataStore();
    end
    
    reader.close();
end
