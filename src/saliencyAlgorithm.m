%% Implement the Itti saliency algorithm with your improvements
function saliencyMap = saliencyAlgorithm(image)
% INPUT: 
%   image: original input single image
% OUTPUT: 
%   saliencyMap = saliency map generated from input image. size is the 1/16
%   of the original input image.
%

    addpath('utils');
    
    image = double(image);
    [height, width, ~] = size(image);
    
    % saliencyMap = zeros(height, width);
    Map.original_image = image;
    Map.original_height = height;
    Map.original_width = width;
    Map.bandwidth = 2;  % tunable, little effect
    Map.garbor_orientations = [0,45,90,135];
    Map.features = {'intensity', 'color', 'orientation'};
    % your code here
    %% 1. linear filtering (color, intensity, orientation)
    
    % I.seperate color channel
    red_channel = scale_normalize(image(:,:,1),[0,1]);
    green_channel = scale_normalize(image(:,:,2), [0,1]);
    blue_channel = scale_normalize(image(:,:,3), [0,1]);
    
    % II.obtain intensity image and broadly-tuned color channels
    I0 = red_channel/3 + green_channel/3 + blue_channel/3;   % intensity
    R0 = red_channel - 0.5 * (green_channel + blue_channel);
    G0 = green_channel - 0.5 * (red_channel + blue_channel);
    B0 = blue_channel - 0.5 * (red_channel + green_channel);
    Y0 = 0.5 * (red_channel + green_channel) - 0.5 * abs(red_channel - green_channel) - blue_channel;
    % negative values are set to zero
    R0 = max(R0, 0);
    G0 = max(G0, 0);
    B0 = max(B0, 0);
    Y0 = max(Y0, 0);
    
    % III.obtain gabor filters for four directions
    for orient = Map.garbor_orientations
        Map.garbor_filters = gabor_filter(Map.bandwidth, orient);
    end;
    
    % IV.create feature pyramid space
    Map.intensity = cell(9,1); % Create a list of downsampled intensity feature map
    Map.color = cell(9, 4);    % Create a list of downsampled color feature map
                               % Columns are R,G,B,Y channels respecitvely
    Map.orientation = cell(9,4); % Create a list of downsampled orientation feature map
                                 % Columns are orentation from 0~135 degrees
                                 % respectively
    % V.create pyramids
    for i = 1:9
        % append
        Map.intensity{i} = I0;
        Map.color{i,1} = R0;
        Map.color{i,2} = G0;
        Map.color{i,3} = B0;
        Map.color{i,4} = Y0;
        Map.orientation{i,1} = imfilter(I0, Map.garbor_filters(1));
        Map.orientation{i,2} = imfilter(I0, Map.garbor_filters(2));
        Map.orientation{i,3} = imfilter(I0, Map.garbor_filters(3));
        Map.orientation{i,4} = imfilter(I0, Map.garbor_filters(4));
        % update to next level
        I0 = impyramid(I0, 'reduce');
        R0 = impyramid(R0, 'reduce');
        G0 = impyramid(G0, 'reduce');
        B0 = impyramid(B0, 'reduce');
        Y0 = impyramid(Y0, 'reduce');
    end
    
    %% 2. center-surround difference and normalization
    % I. Prepare intensity, color, orientation feature maps   
    I_maps = cell(6,1);
    RG_maps = cell(6,1);
    BY_maps = cell(6,1);
    orientation_maps = cell(4,6);

    % II. center surround 
    % Regularize all feature maps to level 5 (sigma = 4)
    i = 0;
    sz = [Map.original_height/16, Map.original_width/16];
    for c = [3,4,5]
        for delta = [3,4]
            i = i + 1;
            s = c + delta;
            % Intensity
            I_maps{i} = abs(imresize(Map.intensity{c}, sz, 'nearest') - imresize(Map.intensity{s}, sz, 'nearest'));
            % Color : R-1 G-2 B-3 Y-4
            c_map = imresize(Map.color{c,1} - Map.color{c,2}, sz, 'nearest');
            s_map = imresize(Map.color{s,2} - Map.color{s,1}, sz, 'nearest');
            RG_maps{i} = abs(c_map - s_map);
            c_map = imresize(Map.color{c,3} - Map.color{c,4}, sz, 'nearest');
            s_map = imresize(Map.color{s,4} - Map.color{s,3}, sz, 'nearest');
            BY_maps{i} = abs(c_map - s_map);
            % Orientation Maps
            orientation_maps{1, i} = abs(imresize(Map.orientation{c, 1},sz,'nearest') - imresize(Map.orientation{s, 1}, sz, 'nearest'));
            orientation_maps{2, i} = abs(imresize(Map.orientation{c, 2},sz,'nearest') - imresize(Map.orientation{s, 2}, sz, 'nearest'));
            orientation_maps{3, i} = abs(imresize(Map.orientation{c, 3},sz,'nearest') - imresize(Map.orientation{s, 3}, sz, 'nearest'));
            orientation_maps{4, i} = abs(imresize(Map.orientation{c, 4},sz,'nearest') - imresize(Map.orientation{s, 4}, sz, 'nearest'));
        end
    end
    
    
    %% 3. across-scale combinations and normalization
    % create conspicuity maps
    conspicuity_intensity = zeros(sz);
    conspicuity_color = zeros(sz);
    conspicuity_orient0 = zeros(sz);
    conspicuity_orient45 = zeros(sz);
    conspicuity_orient90 = zeros(sz);
    conspicuity_orient135 = zeros(sz);
    % combine across-scale normalized feature maps 
    for level = 1: length(I_maps)
        conspicuity_intensity = conspicuity_intensity + local_maxima(I_maps{i}, [0,10]);
        conspicuity_color = conspicuity_color + local_maxima(RG_maps{i}, [0,10]) + local_maxima(BY_maps{i}, [0,10]); 
        conspicuity_orient0 = conspicuity_orient0 + local_maxima(orientation_maps{1,level}, [0,10]);
        conspicuity_orient45 = conspicuity_orient45 + local_maxima(orientation_maps{2,level}, [0,10]);
        conspicuity_orient90 = conspicuity_orient90 + local_maxima(orientation_maps{3,level}, [0,10]);
        conspicuity_orient135 = conspicuity_orient135 + local_maxima(orientation_maps{4,level}, [0,10]);
    end
    % combine orientation of four directions
    conspicuity_orientation = local_maxima(conspicuity_orient0, [0,10]) + ...
                              local_maxima(conspicuity_orient45, [0,10]) + ...
                              local_maxima(conspicuity_orient90, [0,10]) + ...
                              local_maxima(conspicuity_orient135, [0,10]);
   
                          
    %% 4. linear combination
    saliency_map = local_maxima(conspicuity_intensity, [0,10])/3 + ...
                   local_maxima(conspicuity_color,[0,10])/3 + ... 
                   local_maxima(conspicuity_orientation, [0,10])/3;
    saliencyMap = saliency_map;
end
