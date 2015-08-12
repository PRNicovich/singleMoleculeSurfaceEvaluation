folderPath = 'M:\images\zeisspalm\Manchen Zhao\15_05_27';

outputFolder = 'D:\MATLAB\CountSingleMolecules\29052015';

% Counting molecules with pkfnd
% Specify parameters to capture most molecules without excess noise peaks
bpassLowHigh = [0.8, 1.5]; % Range of PSF size for bandpass filtering
minPkfndIntensity = 40; % Determined by visual inspection of results
psfWidth = 1.1; %in pixels

%%%%%%%%%%%%%%%%%%%%%%%

fileList = dir(strcat(folderPath, '\*.czi'));

CountNumbers = cell(length(fileList), 2);

for fileNumber = 1:length(fileList)



    %%%%%%%%%%%%%
    % Load .czi file

    imgData = CZIImport(fullfile(folderPath, fileList(fileNumber).name));
    
    img = bpass(imgData, bpassLowHigh(1), bpassLowHigh(2));
    pksFound = pkfnd(img, minPkfndIntensity, psfWidth);
    

    plotFileName = strcat(fileList(fileNumber).name(1:end-4), '_LocalizedPeaks.tif');
    
    localizedFig = figure(2);
    imagesc(imgData);
    colormap('gray');
    hold on
    plot(pksFound(:,1), pksFound(:,2), 'ro')
    set(gca, 'XTick', [], 'YTick', []);
    axis image
    hold off
    xlabel('X Position (pixels)');ylabel('Y Position (pixels)');
    title(fileList(fileNumber).name, 'interpreter', 'none');

    print(2, '-dtiff', fullfile(outputFolder, plotFileName));
    
    CountNumbers{fileNumber, 1} = fileList(fileNumber).name(1:end-4);    
    CountNumbers{fileNumber, 2} = size(pksFound, 1);
    
end


%% Output results to .txt file

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

