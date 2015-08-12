function DataOut = CZIImport(varargin)
% Reads in a Zeiss *.czi format file.
% Call as Data = CZIImport(filename, [Z Planes], [Time points], [Channels], DimsStructure)
% where :
% filename  = String pointing to *.czi file to open
% [Z Planes] is a vector of integers designating which Z planes to output
% [Time points] and [Channels] are as [Z Planes], but for Time points and
% channels, respectively.  
% Output is in same format as *.czi file (uint8 or uint16, typically).
%
% Dimensions obtained with CZIDimensions (required for this function)
%
% Tested with data off of Zeiss 780 confocal microscope.
% Tested data with z-stacks, tiles, multiple channels.
% Not tested : time points, rotation, scene,
% illumination, block, mosaic, phase, or view dimensions; compression;
% metaData (aside from dimensions).
% Much faster and with lower memory overhead than imreadBF.
% 
% Often will return images with bottom part (~88 lines) transposed to top.
% Very slow with large data sets from PALM, for example.  

fname = varargin{1};

if nargin == 5;
    
    Dims = varargin{5};
    
else
    % Get Dimensions
    Dims = CZIDimensions(fname);

end


if nargin == 1;
    
    Zeds = 1:Dims.Z;
    Times = 1:Dims.T;
    Chans = 1:Dims.C;
    
elseif nargin == 2;
    
    Zeds = varargin{2};
    Times = 1:Dims.T;
    Chans = 1:Dims.C;
    
elseif nargin == 3;
    
    Zeds = varargin{2};
    Times = varargin{3};
    Chans = 1:Dims.C;
    
elseif nargin == 4;
    
    Zeds = varargin{2};
    Times = varargin{3};
    Chans = varargin{4};
    
elseif nargin == 5;
    
	Zeds = varargin{2};
    Times = varargin{3};
    Chans = varargin{4};
    
else
    
    error('Incorrect number of arguments');
    
end

% Dimension error checking

if Dims.Z < max(Zeds(:))
    
    Zeds = Zeds(le(Zeds, Dims.Z));
    
elseif Dims.T < max(Times(:))
    
    Times = Times(le(Times, Dims.T));
    
elseif Dims.C < max(Chans(:))
    
    Chans = Chans(le(Chans, Dims.C));
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%
% Start file reading

fobj = fopen(fname);

%%%%% Read in primary file header

Header.FileSegmentID = fread(fobj, 16, 'uint8=>char')';
Header.AllocatedSize = fread(fobj, 1, 'int64')';
Header.UsedSize = fread(fobj, 1, 'int64')';

Header.MajorVersion = fread(fobj, 1, 'int');
Header.MinorVersion = fread(fobj, 1, 'int');
Header.Reserved1 = fread(fobj, 1, 'int');
Header.Reserved2 = fread(fobj, 1, 'int');
Header.PrimaryFileGuid = dec2hex(fread(fobj, 16, 'uint8')');
Header.FileGuid = dec2hex(fread(fobj, 16, 'uint8')');
Header.FilePart = fread(fobj, 1, 'int32');
Header.DirectoryPosition = fread(fobj, 1, 'int64');
Header.MetadataPosition = fread(fobj, 1, 'int64');
Header.UpdatePending = dec2bin(fread(fobj, 1, 'int32'));
Header.AttachmentDirectoryPosition = fread(fobj, 1, 'int64');


%%%%%%%%%%%%%%
% Find and read Directory Segment
fseek(fobj, Header.DirectoryPosition, 'bof');
Header.Directory.SegmentID = fread(fobj, 16, 'uint8=>char')';
Header.Directory.AllocatedSize = fread(fobj, 1, 'int64');
Header.Directory.UsedSize = fread(fobj, 1, 'int64');
Header.Directory.NumEntries = fread(fobj, 1, 'int');
fseek(fobj, 124, 'cof');
% Gotta loop over these, probably

for m = 1:Header.Directory.NumEntries
    
    Header.Directory.Entry(m).Entry = fread(fobj, 2, 'uint8=>char')';
    Header.Directory.Entry(m).PixelType = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).FilePosition = fread(fobj, 1, 'int64');
    Header.Directory.Entry(m).FilePart = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).Compression = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).PyramidType = fread(fobj, 1, 'uint8');
    ThrowawayBytes = fread(fobj, 5, 'uint8');
    Header.Directory.Entry(m).DimensionCount = fread(fobj, 1, 'int32');

    % Another loop here
    for k = 1:Header.Directory.Entry(m).DimensionCount
        
        Header.Directory.Entry(m).DimensionEntries(k).Dimension = fread(fobj, 4, 'uint8=>char')';
        Header.Directory.Entry(m).DimensionEntries(k).Start = fread(fobj, 1, 'int32');
        Header.Directory.Entry(m).DimensionEntries(k).Size = fread(fobj, 1, 'int32');
        Header.Directory.Entry(m).DimensionEntries(k).StartCoordinate = fread(fobj, 1, 'float32');
        Header.Directory.Entry(m).DimensionEntries(k).StoredSize = fread(fobj, 1, 'int32');
        
    end
    
end

% Pull out dimensions in X x Y x Z x T x C

% Z, T, and C are different entries.  Each Entry a single X x Y plane.
for k = 1:length(Header.Directory.Entry)
    
    % Dimensions here in bytes
    
    Dim.X(k) = Header.Directory.Entry(k).DimensionEntries(1).Size;
    Dim.Y(k) = Header.Directory.Entry(k).DimensionEntries(2).Size;
    Dim.Z(k) = Header.Directory.Entry(k).DimensionEntries(3).Start+1;
    Dim.T(k) = Header.Directory.Entry(k).DimensionEntries(4).Start+1;
    Dim.C(k) = Header.Directory.Entry(k).DimensionEntries(5).Start+1;
    
    Dim.FilePosition(k) = Header.Directory.Entry(k).FilePosition;
    


end

% Pixel type with 1 index, rather than 0 index in pdf
PixelType{1} = 'uint8'; % 8 bit grayscale
PixelType{2} = 'uint16'; % 16 bit grayscale
PixelType{3} = 'float32'; % 32 bit grayscale
PixelType{4} = 'uint8'; % BGR Triples
PixelType{5} = 'uint16'; % 16-bit BGR Triples
PixelType{9} = 'float32'; % Single-precision BGR Triples
PixelType{10} = 'uint8'; % 8 bit BGR+alpha
PixelType{11} = 'ubit64'; % Complex 64-bit grayscale
PixelType{12} = 'ubit64'; % Complex 64-bit BGR


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Data read-in

% Assuming datatype across entire file is constant
% DHold = zeros([Dim.X(1), Dim.Y(1), numel(Zeds), numel(Times), numel(Chans)], ...
%     PixelType{Header.Directory.Entry(1).PixelType+1});

% DHold = zeros([Dim.X(1)*Dim.Y(1), numel(Zeds), numel(Times), numel(Chans)], ...
%     PixelType{Header.Directory.Entry(1).PixelType+1});

DHold = zeros(Dim.X(1)*Dim.Y(1)*numel(Zeds)*numel(Times)*numel(Chans), 1, ...
    PixelType{Header.Directory.Entry(1).PixelType+1});

LocNow = 1;

for z = 1:numel(Zeds)
    for t = 1:numel(Times)
        for c = 1:numel(Chans)
            
            zhere = Zeds(z);
            there = Times(t);
            chere = Chans(c);

            whichLoc = find((Dim.Z == zhere) & (Dim.T == there) & (Dim.C == chere));
            
            


    %%%%%
    % Read in a plane
    m = whichLoc;

    fseek(fobj, Dim.FilePosition(m), 'bof');
    Data.SegmentID = fread(fobj, 16, 'uint8=>char')';
    Data.AllocatedSize = fread(fobj, 1, 'int64');
    Data.UsedSize = fread(fobj, 1, 'int64');
    Data.MetadataSize = fread(fobj, 1, 'int32');
    Data.AttachmentSize = fread(fobj, 1, 'int32');
    Data.DataSize = fread(fobj, 1, 'int64');

    Data.DirectoryEntry.SchemaType = fread(fobj, 2, 'uint8=>char')';
    Data.DirectoryEntry.PixelType = fread(fobj, 1, 'int32');
    Data.DirectoryEntry.FilePosition = fread(fobj, 1, 'int64');
    Data.DirectoryEntry.FilePart = fread(fobj, 1, 'int32');
    Data.DirectoryEntry.Compression = fread(fobj, 1, 'int32');
    Data.DirectoryEntry.PyramidType = fread(fobj, 1, 'uint8');
    ThrowawayBytes = fread(fobj, 5, 'uint8');
    Data.DirectoryEntry.DimensionCount = fread(fobj, 1, 'int32');

    for k = 1:Data.DirectoryEntry.DimensionCount
        Data.DirectoryEntry.DimensionEntries(k).Dimension  = fread(fobj, 4, 'uint8=>char')';
        Data.DirectoryEntry.DimensionEntries(k).Start = fread(fobj, 1, 'int32');
        Data.DirectoryEntry.DimensionEntries(k).Size = fread(fobj, 1, 'int32');
        Data.DirectoryEntry.DimensionEntries(k).StartCoordinate = fread(fobj, 1, 'float32');
        Data.DirectoryEntry.DimensionEntries(k).StoredSize = fread(fobj, 1, 'int32');
    end
    
	% Known this shift needs to happen, but not that it needs to be this
    % value.  '48' at end found by trial-and-error on a few files.
    FillAmount = 256 - ((Data.DirectoryEntry.DimensionCount*20) + 48);
    if FillAmount > 0
        fseek(fobj, FillAmount, 0);
    end

    Data.Metadata = fread(fobj, Data.MetadataSize, 'uint8=>char')';
    
    DataHere = fread(fobj, Data.DataSize/(Data.DirectoryEntry.PixelType+1), ...
        sprintf('*%s', PixelType{Data.DirectoryEntry.PixelType+1}));
    
    
    
    
%     DHold(:,:,z,t,c) = DataHere;
    DHold(LocNow:(LocNow+numel(DataHere)-1)) = DataHere;
    Data.Attachment = fread(fobj, Data.AttachmentSize, 'uint8');

        LocNow = LocNow+numel(DataHere);
    

        end
    end
end

% assignin('base', 'DataHere', DHold);

% This changed to correct error for when both z and c dimensions used.
% Untested with t dimension included.  
DHold = reshape(DHold, [Dim.X(1) Dim.Y(1), numel(Chans), numel(Times), numel(Zeds)]);
DHold = permute(DHold, [1 2 5 4 3]);

DataOut = DHold;

fclose(fobj);

end



