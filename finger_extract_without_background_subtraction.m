%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---- Written by: Yash Bhalgat                     %%%
%%%---- 3rd year, Electrical Engineering, IIT Bombay %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Code doesn't involve complicated background subtraction
%%% See the readme.txt file

%creating object for acquisition from the web-cam
vidDevice = imaq.VideoDevice('winvideo', 1, 'YUY2_640x480', ...
'ROI', [1 1 640 480], ...
'ReturnedColorSpace', 'rgb');

%create "original object" video player
hVideoIn = vision.VideoPlayer;
hVideoIn.Name = 'Original Video';
hVideoIn.Position = [30 100 640 480];

%create "fingers tracking" object video player 
hVideoOut = vision.VideoPlayer;
hVideoOut.Name = 'Fingers Tracking Video';
hVideoOut.Position = [700 100 640 480];

%construct blob analysis
hblob = vision.BlobAnalysis('AreaOutputPort', true, ... %to calculate the area   %%Set blob analysis handling%%
                                'CentroidOutputPort', true, ... % to calculate centre coordinates
                                'BoundingBoxOutputPort', true', ... % to calculate coordinate box
                                'MinimumBlobArea', 800, ... % min area pixel blob
                                'MaximumBlobArea', 3600, ... % max area pixel blob
                                'MaximumCount', 10);                             

% rectangular shape inserter                            
hshapeinsRedBox = vision.ShapeInserter('BorderColor', 'Custom', 'CustomBorderColor', [1 0 0], 'Fill', true, 'FillColor', 'Custom', 'CustomFillColor', [1 0 0]);         

%%%%%%%%%%%%%%%%%%%%%%%%% Processing starts %%%%%%%%%%%%%%%%%%%%%%%%%
nFrames = 0;
while (nFrames <= 1000) 
    finger_array = [0,0,0,0,0];
    rgbData = step(vidDevice); %acquires one frame
    rgbData = flipdim(rgbData,2); %reflected image

    data = rgbData;
    
    % Skin Segmentation
    diff_im = imsubtract(data(:,:,1), rgb2gray(data)); %reducing red channel with grayscale
    diff_im = medfilt2(diff_im, [3 3]); %filtering
    diff_im = imadjust(diff_im); %perform color - mapping on the results of the reduction
    level = graythresh(diff_im); %find the threshold
    bw = im2bw(diff_im,level); %convert to binary image
    bwfill = medfilt2(imfill(bw,'holes'), [3 3]); %filling the hole when there is
    
    % Fingers Extraction
    se1 = strel('disk',28);
    eroded = imerode(bwfill,se1); %morphological operation - erode
    
    se2 = strel('disk',40);
    dilated = imdilate(eroded,se2); %morphological operation - dilate
    
    result = imsubtract(bwfill,dilated);
    se3 = strel('disk',6);
    finger = imerode(result,se3);
    finger = im2bw(finger);
    
    % Representation
    [area, centroid, bbox] = step(hblob, finger); %% % taking the value of the centroid and the bounding box of blobs
    centroid = uint16(centroid); 
    data(1:40,1:250,:) = 0; % black label on the top corner of the video player fingers traker
    data(:,:,1) = finger;
    data(:,:,2) = finger;
    data(:,:,3) = finger;
    vidIn = step(hshapeinsRedBox, data, bbox); % red label if the finger is found
    for object = 1:1:length(bbox(:,1))
        centX = centroid(object,1); centY = centroid(object,2);

        if (area(object)>3000)
            finger_array(3) = 1;   % middle finger
        end
        if (area(object)<1500)
            if(centX < max_centX-100)
                finger_array(1) = 1;   % thumb
            else
                finger_array(5) = 1;
            end
        end    
        if(area(object)>1500 && area(object)<3000)
            if(centX < (max_centX+min_centX)/2) % index finger
                finger_array(2) = 1;
            else
                finger_array(4) = 1;    % ring finger
            end
        end
    end

    rgb_Out = vidIn;

    step(hVideoIn, rgbData); %send the original acquisition frame to the video player 1
    step(hVideoOut, rgb_Out); %send frames to results of manipulation video player 2
    nFrames = nFrames + 1;
    
    % displying the array of fingers
    noOfFingers = min(length(bbox(:,1)), 5);
    if(noOfFingers==5)
        finger_array = [1,1,1,1,1];
    end
    disp(strcat(['No of fingers: ' num2str(noOfFingers)]));
    disp('array of non-bent fingers:'), disp(finger_array);
end

%release all video object attached hardware
release(hVideoOut);
release(hVideoIn);
release(vidDevice);