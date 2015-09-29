%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---- Written by: Yash Bhalgat                     %%%
%%%---- 3rd year, Electrical Engineering, IIT Bombay %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Code involves good background subtraction
%%% So, please see the readme.txt file for proper usage to get best results

% creating object for acquisition from the web-cam
vidDevice = imaq.VideoDevice('winvideo', 1, 'YUY2_640x480', 'ROI', [1 1 640 480], 'ReturnedColorSpace', 'rgb');

vidDevice.DeviceProperties.FrameRate = '15';

% finger_array to be displayed on terminal as given in problem statement
finger_array = [0,0,0,0,0];

% create "original object" video player
hVideoIn = vision.VideoPlayer;
hVideoIn.Name = 'Original Video';
hVideoIn.Position = [30 100 640 480];

% create "fingers tracking" object video player 
hVideoOut = vision.VideoPlayer;
hVideoOut.Name = 'Fingers Tracking Video';
hVideoOut.Position = [700 100 640 480];

%code for blob analysis
hblob = vision.BlobAnalysis('AreaOutputPort', true, ... %to calculate the area   %%Set blob analysis handling%%
                                'CentroidOutputPort', true, ... % to calculate centre coordinates
                                'BoundingBoxOutputPort', true', ... % to calculate coordinate box
                                'MinimumBlobArea', 900, ... % min area pixel blob
                                'MaximumBlobArea', 5000, ... % max area pixel blob
                                'MaximumCount', 10); % maks blob yang dapat dihitung
% rectangular shape inserter                            
hshapeinsRedBox = vision.ShapeInserter('BorderColor', 'Custom', 'CustomBorderColor', [1 0 0], 'Fill', true, 'FillColor', 'Custom', 'CustomFillColor', [1 0 0]);         

htextins = vision.TextInserter('Text', 'Analyzing Background', ... % Set text for number of blobs
                                    'Location',  [12 200], ...
                                    'Color', [0 0 1], ... // red color
                                    'FontSize', 20);

nFrames = 0;

%================================ Processing starts ======================================%
% includes "backround subtraction", which enables detection in "any" background

avgBackData = zeros([480 640 3]);
while (nFrames <= 10)       % backgroud averaging for 10 frames
    backData = step(vidDevice); %acquires one frame
    backData = flipdim(backData,2); %reflected image
    avgBackData = (avgBackData*(nFrames)+backData)/(nFrames+1);
    
    nFrames = nFrames + 1;
end
    
nFrames = 0;
while (nFrames <= 500)
    finger_array = [0,0,0,0,0];
    rgbData = step(vidDevice); 
    rgbData = flipdim(rgbData,2); % flip the frame
    
    % background subtraction
    rgbData = rgbData.*(abs(rgbData-avgBackData)>0.05);
    data = rgbData;
    
    % Skin Segmentation
    diff_im = rgb2gray(data);
%     diff_im = imsubtract(data(:,:,1), rgb2gray(data)); %removing grayscale from red channel
    diff_im = medfilt2(diff_im, [3 3]); %filtering
    diff_im = imadjust(diff_im); % color maping to appropriate range
    level = graythresh(diff_im); % using thresholding method
    bw = im2bw(diff_im,level); 
    bwfill = medfilt2(imfill(bw,'holes'), [3 3]); 
    
    %%%% ---------------Fingers Extraction---------------- %%%%
    se1 = strel('disk',28);
    eroded = imerode(bwfill,se1);
    
    se2 = strel('disk',40);
    dilated = imdilate(eroded,se2);    
    
    result = imsubtract(bwfill,dilated);
    se3 = strel('disk',6);
    finger = imerode(result,se3);
    finger = im2bw(finger);
    
    % Representation of the final image to see
    [area, centroid, bbox] = step(hblob, finger); % taking the value of the area, centroid and the bounding box of blobs
    centroid = uint16(centroid); % converting centroid type
    data(:,:,1) = finger;
    data(:,:,2) = finger;
    data(:,:,3) = finger;
    data(1:40,1:250,:) = 0; 
    vidIn = step(hshapeinsRedBox, data, bbox); % red label if the finger is found
    max_centX = max(centroid(:,1));
    min_centX = min(centroid(:,1));
    
    % logic for forming the finger_array based on area
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
    step(hVideoOut, rgb_Out); %send the original acquisition frame to the video player 2
    nFrames = nFrames + 1;
    
    % displying the array of fingers
    noOfFingers = min(length(bbox(:,1)), 5);
    if(noOfFingers==5)
        finger_array = [1,1,1,1,1];
    end
    disp(strcat(['No of fingers: ' num2str(noOfFingers)]));
    disp('array of non-bent fingers:'), disp(finger_array);

end

% release all video object attached hardware
release(hVideoOut);
release(hVideoIn);
release(vidDevice);