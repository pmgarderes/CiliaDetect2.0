function [imgStack, metadata] = load_nd2_image_downsampled(filename, param)
    % INPUTS:
    %   filename: full path to .nd2 file
    %   para: struct with at least field para.DSfactor (e.g., 10)
    %
    % OUTPUTS:
    %   imgStack: 4D cell array, one per channel (each is Y x X x Downsampled Z/T)
    %   metadata: Bio-Formats metadata store for reference

    assert(isfield(param, 'DSfactor'), 'Please define para.DSfactor');
    
    if ~isfield(param, 'fluorescenceMode')
        param.fluorescenceMode = 'mean'; % Options: 'mean' or 'sum'
    end
    
    % Add Bio-Formats to path if not already
    assert(exist('bfGetReader', 'file') == 2, 'Bio-Formats not found. Add bfmatlab to your path.');
    
    % Initialize reader
    reader = bfGetReader(filename);
    OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
    metadataStore = reader.getMetadataStore();

    reader.setSeries(0); % Only load the first series
    sizeX = reader.getSizeX();
    sizeY = reader.getSizeY();
    sizeZ = reader.getSizeZ();
    sizeC = reader.getSizeC();
    sizeT = reader.getSizeT();
    numPlanes = reader.getImageCount(); % typically Z * C * T

    fprintf('Loaded ND2: [%d x %d], Z=%d, C=%d, T=%d, Planes=%d\n', ...
        sizeX, sizeY, sizeZ, sizeC, sizeT, numPlanes);

    % Preallocate image stack for each channel
    imgStack = cell(sizeC, 1);
    for c = 1:sizeC
        imgStack{c} = [];
    end

    % Infer layout: assume data ordered as ZCT or T-C-Z depending on acquisition
    stackBy = sizeZ * sizeT;

    % Get all planes per channel
    planesPerChannel = numPlanes / sizeC;
    planesPerGroup = param.DSfactor;

    if mod(planesPerChannel, param.DSfactor) ~= 0
        warning('Number of planes per channel (%d) is not divisible by DSfactor (%d). Truncating extra frames.', ...
            planesPerChannel, param.DSfactor);
    end

    numGroups = floor(planesPerChannel / param.DSfactor);
    for c = 1:sizeC
        % Allocate average stack
        avgStack = zeros(sizeY, sizeX, numGroups, 'double'); % use double for averaging

        for g = 1:numGroups
            sumStack = zeros(sizeY, sizeX, 'double');
            for i = 1:param.DSfactor
                planeIdx = (c-1) + sizeC * ( (g-1)*param.DSfactor + (i-1) ) + 1;
                plane = double(bfGetPlane(reader, planeIdx));
                sumStack = sumStack + plane;
            end
            if strcmp(param.fluorescenceMode, 'sum')
                avgStack(:,:,g) = sumStack; % / para.DSfactor;
            else
                avgStack(:,:,g) = sumStack/ param.DSfactor;
            end
        end
        imgStack{c} = uint16(avgStack); % Convert back to integer
    end

    metadata = metadataStore;
    reader.close();
end
