
% folderPath and outputFolder must be different paths!
folderPath = 'M:\images\zeisspalm\Manchen Zhao\15_05_27';

outputFolder = 'D:\MATLAB\CountSingleMolecules\29052015';

% Counting molecules with pkfnd
% Specify parameters to capture most molecules without excess noise peaks
bpassLowHigh = [0.8, 1.5]; % Range of PSF size for bandpass filtering
minPkfndIntensity = 45; % Determined by visual inspection of results
psfWidth = 1.1; %in pixels

% Centroid parameters with cntrd
WindowDiameter = 9; % Window size for determining the centroid position

BrightnessHistogramBins = 100; % Number of bins to use in the brightness histogram
MaxHistogramBrightness = 10000; % Value for largest bin in histogram.  Set to 'Inf' to be auto-detecting.

%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(folderPath, outputFolder)
    error('folderPath and outputFolder must be different paths.');
end

fileList = dir(strcat(folderPath, '\*.czi'));
fileList = [fileList; dir(strcat(folderPath, '\*.tif'))];
fileList = [fileList; dir(strcat(folderPath, '\*.tiff'))];

CountNumbers = cell(length(fileList), 5);

for fileNumber = 1:length(fileList)


    % Check if file is one of permitted formats
    switch lower(fileList(fileNumber).name((end-2):end));
    
        case 'czi';
    
            %%%%%%%%%%%%%
            % Load .czi file   

            imgData = CZIImport(fullfile(folderPath, fileList(fileNumber).name));
    
        case 'tif'
            
            %%%%%%%%%%%%%
            % Load .tif file 
            
            imgData = imread(fullfile(folderPath, fileList(fileNumber).name));
            
        case 'tiff'
            
            %%%%%%%%%%%%%
            % Load .tif file 
            
            imgData = imread(fullfile(folderPath, fileList(fileNumber).name));
            
        otherwise 
            fprintf(1, 'File %s is in unsupported format.\n', fileList(fileNumber).name);
            
    end
    img = bpass(imgData, bpassLowHigh(1), bpassLowHigh(2));
    pksFound = pkfnd(img, minPkfndIntensity, psfWidth);
    centroidsFound = cntrd(img, pksFound, WindowDiameter, 0);

    [bHistDataY, bHistDataX] = hist(centroidsFound(:,3), BrightnessHistogramBins);
    
    plotFileName = strcat(fileList(fileNumber).name(1:end-4), '_LocalizedPeaks.tif');
    histFileName = strcat(fileList(fileNumber).name(1:end-4), '_BrightnessHistogram.tif');
    
    localizedFig = figure(2);
    imagesc(imgData);
    colormap('gray');
    hold on
    plot(centroidsFound(:,1), centroidsFound(:,2), 'ro')
    set(gca, 'XTick', [], 'YTick', []);
    axis image
    hold off
    xlabel('X Position (pixels)');ylabel('Y Position (pixels)');
    title(fileList(fileNumber).name, 'interpreter', 'none');

    print(2, '-dtiff', fullfile(outputFolder, plotFileName));
    
    
    BrightnessFig = figure(3);
    plot(bHistDataX, bHistDataY, 'r-')
    xlabel('Brightness (Counts)');ylabel('Frequency');
    title(fileList(fileNumber).name, 'interpreter', 'none');
    
    print(3, '-dtiff', fullfile(outputFolder, histFileName));
    
    CountNumbers{fileNumber, 1} = fileList(fileNumber).name(1:end-4);    
    CountNumbers{fileNumber, 2} = size(pksFound, 1);
    CountNumbers{fileNumber, 3} = centroidsFound(:,3);
    CountNumbers{fileNumber, 4} = [bHistDataX bHistDataY];
    CountNumbers{fileNumber, 5} = centroidsFound;
    
end


%% Output results to .txt file

% Peak numbers
txtFileName = 'MoleculeCountingResults.txt';
fID = fopen(fullfile(outputFolder, txtFileName), 'w');
fprintf(fID, '# Data : %s\r\n', folderPath);
fprintf(fID, '# Processed by : %s\r\n', mfilename('fullpath'));
fprintf(fID, '# Bandpass Filter : [%.2f, %.2f]\r\n', bpassLowHigh(1), bpassLowHigh(2));
fprintf(fID, '# Minum peak Intensity : %.2f\r\n', minPkfndIntensity);
fprintf(fID, '# PSF Width : %.2f\r\n', psfWidth);
fprintf(fID, '#############################\r\n');
for k = 1:size(CountNumbers, 1)
    fprintf(fID, '"%s"\t%.0f\r\n', CountNumbers{k,1}, CountNumbers{k,2});
end
fclose(fID);

% Brightness numbers
txtFileName = 'BrightnessOfPeaksResults.txt';
fID = fopen(fullfile(outputFolder, txtFileName), 'w');
fprintf(fID, '# Data : %s\r\n', folderPath);
fprintf(fID, '# Processed by : %s\r\n', mfilename('fullpath'));
fprintf(fID, '# Bandpass Filter : [%.2f, %.2f]\r\n', bpassLowHigh(1), bpassLowHigh(2));
fprintf(fID, '# Minum peak Intensity : %.2f\r\n', minPkfndIntensity);
fprintf(fID, '# PSF Width : %.2f\r\n', psfWidth);
fprintf(fID, '# Window Diameter : %.1f\r\n', WindowDiameter);
fprintf(fID, '# Histogram Bins : %.f\r\n', BrightnessHistogramBins);
fprintf(fID, '#############################\r\n');

% Make brightness data matrix
if MaxHistogramBrightness < Inf
    histVector = linspace(0, ...
        MaxHistogramBrightness, BrightnessHistogramBins);
else 
    histVector = linspace(0, ...
        max(cell2mat(cellfun(@max, CountNumbers(:,3), 'UniformOutput', false))), BrightnessHistogramBins);
end

histMatrix = zeros(numel(histVector), length(fileList)+1);
histMatrix(:,1) = histVector;
for k = 1:length(fileList)
    histMatrix(:, k+1) = histc(CountNumbers{k,3}, histVector');
end

fprintf(fID, '%s\t%s\r\n', 'Brightness', strjoin(CountNumbers(:,1)', '\t'));

formatString = repmat('%.3f\t', 1, length(fileList));
formatString = strcat(formatString, '%.3f\r\n');

for k = 1:size(histMatrix, 1)
    fprintf(fID, formatString, histMatrix(k,:));
end
fclose(fID);


