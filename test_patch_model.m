clear;clc;

% test phase
% test data: unline test images, images in test data will have pose
% variations, varying shadow conditions, blurring as well as alignment
% errors to show quality variations from the ideal state.
% Viola-Jones haar-based face detector is used to detect face, then resized
% to 64x64 to match with training image dimension. Image log transformed to
% normalize intensity. Now, the image is segmented into patches in the same
% way as training phase. Each patch is normalized to zero mean and unit
% variance. DCT coeffecients are extracted. Now to determine the similarity
% of each patch of the face image to the corrresponding patch of the
% generic face model a posterior probbility for each patch is determining
% by vector into a Gaussian probability density function based on the
% generic face model.

% The aim is not to recognize an individual face but to determine ow lose
% the patch of the face from the test set is to an average patch at the
% same location represented by the generic facce model. The formua assigns
% a low probability to patches with DCT coefficients far fromt he mean of
% the probabilistic model and a high probability to patches with DCT
% coefficients close tot he mean of the probabilitic model.

% The quality of the image is determined by combining all the posterior
% probabilities of the patches.

minsz = [75 75];
imSize = [64 64];
patchSize = [8 8];

patchRows = imSize(1) - patchSize(1) + 1; % 64-8+1 = 57
patchCols = imSize(2) - patchSize(2) + 1; % 64-8+1 = 57

load('patch_model');

% user_id = 'aaron eckhart';
% user_id = 'abhishek bachchan';
% user_id = 'abigail breslin';
user_id = 'abraham lincoln';
% user_id = 'adam ant';
% user_id = 'adam brody';

files = dir(['test_data\' user_id '_*.jpg']);

max_quality = 0;

for k = 1:length(files)
    I = imread(['test_data\' files(k).name]);

    if max(size(I))>1200 % avoid too large image
        I = imresize(I, 1200/max(size(I)), 'bilinear');
    end
    I = im2double(I);
    try
        Igr = rgb2gray(I);
    catch exception
    end
    fDect = vision.CascadeObjectDetector(); 
    fDect.ScaleFactor = 1.02; fDect.MergeThreshold = 2; fDect.MinSize = minsz; 
    bbox = step(fDect, Igr);

    subplot(1,length(files),k);
    imshow(I); hold on;
    %% crop and resize face
    m0 = 150; std0 = 50;
    for b = 1:size(bbox,1)
        crgr = imcrop(Igr, bbox(b,:));
        crgr = crgr*255;
        crgr = (crgr-mean(crgr(:)))*std0/std(crgr(:))+m0;
        crgr(crgr<0)=0; crgr(crgr>255)=255;        
        crgr = imresize(crgr/255.0, [64 64], 'bilinear');                    
        crgr = log2(crgr+1);

        quality = 0;
        for i = 1:patchRows
            for j = 1:patchCols
                patch = crgr(i:i+patchSize(1)-1, j:j+patchSize(2)-1);
                patch = (patch - mean(patch(:))) / var(patch(:));
                J = dct2(patch);
                feature = [J(1,2); J(2,1); J(3,1)];
                patchMean = featureMean{i,j}; 
                patchCov = featureCovariance{i,j};
                prob = exp(-0.5*(feature-patchMean)' * inv(patchCov) * (feature - patchMean) ) / (2*pi)^(length(feature)/2) * det(patchCov)^0.5;
                quality = quality + log2(prob);                
%                 fprintf('prob=%f, log2(prob)=%f\n', prob, log2(prob));
            end
        end
        
        if quality > max_quality
            max_quality = quality;
            max_quality_imgid = files(k).name;
        end
        % display result
        box = bbox(b,:);
        fsize = max(round((box(3)/60)^(0.5)*10),8);

        quality = quality/(patchRows*patchCols);
        quality = min(max(quality,0), 100);
        
        text(box(1)+box(3)*0.02, box(2)+box(3)*0.99, num2str(round(quality)), 'Color', [0 0 0], 'VerticalAlignment', 'top', ...
            'BackgroundColor', [1 0 1], 'HorizontalAlignment', 'left', 'FontSize', fsize, 'FontWeight', 'bold');
        rectangle('Position', box, 'EdgeColor', 'm', 'LineWidth', 2.5);

    end
    drawnow;    
end
msgbox(sprintf('Max Quality = %d, Image File = %s', round(max_quality/(patchRows*patchCols)), max_quality_imgid));
