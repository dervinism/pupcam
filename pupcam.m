function varargout = pupcam(varargin)
% PUPCAM MATLAB code for pupcam.fig
%      PUPCAM, by itself, creates a new PUPCAM or raises the existing
%      singleton*.
%
%      H = PUPCAM returns the handle to a new PUPCAM or the handle to
%      the existing singleton*.
%
%      PUPCAM('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PUPCAM.M with the given input arguments.
%
%      PUPCAM('Property','Value',...) creates a new PUPCAM or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before pupcam_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to pupcam_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help pupcam

% Last Modified by GUIDE v2.5 02-Nov-2018 15:13:25

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pupcam_OpeningFcn, ...
                   'gui_OutputFcn',  @pupcam_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before pupcam is made visible.
function pupcam_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to pupcam (see VARARGIN)

%% --- 1 Hardware of the computer
objects = imaqfind; % clean out of memory any previous vieo input objects ('clear all' does not suffice)
delete(objects)
clear objects

%imaqhwinfo % See if there are any Image Acquisition adaptors are available (At least, should have 'winvideo'.
% If none, try Image Acquisition Toolbox Support Package for OS Generic Video Interface).

x = imaqhwinfo('winvideo');

global daqSession % it will be used by a callback function, so is made global
daqSession = daq.createSession('ni');
daqSession.Rate = 1000;

daqSession.addAnalogOutputChannel('Dev1', 0,'Voltage'); % AO0 only
%daqSession.addDigitalChannel('Dev1', 'Port0/Line7', 'OutputOnly');
% We don't have to use analog output, since all we want is a trigger (binary) signal
% to record when each frame was acquired. Thus a digital output suffices

%% --- 2 Create video input object
format = 'MJPG_640x480'; % Has to be one of x.DeviceInfo.SupportedFormats
% MJPG_640x480 produces 120 Hz frame rate
% MJPG_800x600 produces 60 Hz frame rate
% MJPG_1920x1080 produces 30 Hz frame rate

eyeVid = videoinput('winvideo', x.DeviceIDs{1}, format);

%A simpler alternative to the above:
%eyeVid = eval(x.DeviceInfo(2).VideoInputConstructor);

src = getselectedsource(eyeVid);


%% --- 3 configuration
eyeVid.FrameGrabInterval = 5; % 1 by default, k value means every k-th frame in the video stream is acquired
eyeVid.FramesPerTrigger = 1;

%src.ExposureMode = 'manual'; % This seems to reduce the sampling rate from 120 Hz to 60 Hz...

%src.Exposure = eyePP.Exposure;
%   try %% AS added as there is no Gain mode on my camera object
%     src.GainMode = 'manual';
%   catch
%     display('There was a problem setting the gain mode of the camera');
%   end
%src.Gain = eyePP.Gain;

eyeVid.ReturnedColorspace = 'grayscale'; % 'rgb', 'YCbCr'
eyePP.FrameRate = set(getselectedsource(eyeVid), 'FrameRate');
eyePP.FrameRate = str2double(eyePP.FrameRate{1})/eyeVid.FrameGrabInterval;
fprintf('Your camera supports the following frame rates: %g\n', eyePP.FrameRate);
%fprintf('All these are strings, e.g. set ''30.0000'' for 30 fps\n');

eyeVid.LoggingMode = 'disk'; %'disk&memory' is another option, but this will cause [after some time] RAM overflow
eyePP.VideoProfile = 'Archival';
% switch eyePP.VideoProfile
%   case 'Archival'
%     diskLogger = VideoWriter(['c:\tmp\video_' num2str(round(rem(now, 1)*1e5)) '.mj2'], 'Archival');
%     diskLogger.MJ2BitDepth = 8;
%   case 'Motion JPEG AVI'
%     diskLogger = VideoWriter(fullfile(folders{iName}, [fileStems{iName}, '.avi']), 'Motion JPEG AVI');
%     diskLogger.Quality = eyePP.VideoQuality;
%   case 'Motion JPEG 2000'
%     diskLogger = VideoWriter(fullfile(folders{iName}, [fileStems{iName}, '.mj2']), 'Motion JPEG 2000');
%     diskLogger.MJ2BitDepth = 8;
%     diskLogger.LosslessCompression = false;
%     diskLogger.CompressionRatio = eyePP.CompressionRatio;
% end

% diskLogger.FrameRate = eyePP.FrameRate;

%% Display video
axes(handles.axes1)
set(gca, 'Units','pixels');
position = get(gca,'OuterPosition');
%position = get(gca,'Position');
hImage = image(zeros(round(position(4))+25,round(position(3))-25), 'Parent',handles.axes1);
preview(eyeVid,hImage);
handles.text2.String = 'Ready to record';
handles.text3.String = ['Video frame refresh rate: ' num2str(eyePP.FrameRate) ' Hz'];
if ~isfield(handles,'recFolder') || (isfield(handles,'recFolder') && isempty(handles.recFolder))
    handles.text4.String = 'Recording folder: c:\tmp';
else
    handles.text4.String = ['Recording folder: ' handles.recFolder];
end

%% Folder for saving videos
handles.recFolder = 'c:\tmp';

%% Set the frame count update timer
handles.timer = timer(...
    'ExecutionMode', 'fixedRate', ...           % Run timer repeatedly.
    'Period', 1, ...                            % Initial period is 1 sec.
    'TimerFcn', {@update_framecount,hObject});  % Specify callback function.

%% Process object handles
handles.x = x;
handles.format = format;
handles.eyeVid = eyeVid;
handles.eyePP = eyePP;
handles.src = src;
handles.videoState = 'preview';

% Choose default command line output for pupcam
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes pupcam wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = pupcam_OutputFcn(~, ~, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, ~, handles) %#ok<*DEFNU>
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

global daqSession

if isrunning(handles.eyeVid) && ~islogging(handles.eyeVid)
  trigger(handles.eyeVid);
  handles.videoState = 'recording';
  handles.text2.String = 'Recording resumed';
elseif ~isrunning(handles.eyeVid)
  if ~isfield(handles,'recFolder') || (isfield(handles,'recFolder') && isempty(handles.recFolder))
    handles.recFolder = 'c:\tmp';
  end
  diskLogger = VideoWriter([handles.recFolder filesep 'video_' num2str(round(rem(now, 1)*1e5)) '.mj2'], 'Archival');
  %diskLogger = VideoWriter(['C:\Users\3XS Admin\Desktop\pupcam\pupcamData' filesep num2str(round(rem(now, 1)*1e5)) '.mj2'], 'Archival');
  diskLogger.MJ2BitDepth = 8;
  diskLogger.FrameRate = handles.eyePP.FrameRate;

  handles.eyeVid.DiskLogger = diskLogger;
  handles.eyeVid.TriggerRepeat = Inf;
  handles.eyeVid.FramesAcquiredFcn = @videoFrameAcquiredFcn; % Parameters can be passed, but in this case we have none
  handles.eyeVid.FramesAcquiredFcnCount = 1; % the function will be called after every frame's acquisition
  daqSession.outputSingleScan(0);
  preview(handles.eyeVid);
  start(handles.eyeVid);
  handles.videoState = 'recording';
  handles.text2.String = 'Recording started';
  handles.text3.String = ['Frame count: ' num2str(getfield(handles.eyeVid.DiskLogger,'FrameCount'))]; %#ok<*GFLD>
  handles.text4.String = ['Recording file: ' getfield(handles.eyeVid.DiskLogger,'Path') filesep...
      getfield(handles.eyeVid.DiskLogger,'Filename')];
  start(handles.timer); % start the frame count update timer
else
  handles.text2.String = 'Already recording. Stop recording before starting again';
end

% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, ~, handles)
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

if exist('handles','var') && isfield(handles,'eyeVid') && isrunning(handles.eyeVid)
  stop(handles.eyeVid)
  handles.videoState = 'stopped';
  handles.text2.String = 'Recording stopped';
  handles.text3.String = ['Frame count: ' num2str(getfield(handles.eyeVid.DiskLogger,'FrameCount'))];
  handles.text4.String = ['Recorded file: ' getfield(handles.eyeVid.DiskLogger,'Path') filesep...
      getfield(handles.eyeVid.DiskLogger,'Filename')];
  stop(handles.timer); % stop the frame count update timer
else
  handles.text2.String = 'Not recording';
end

% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, ~, handles)
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

if ~isrunning(handles.eyeVid)
  handles.eyeVid.ROIPosition = [0 0 handles.eyeVid.VideoResolution];
  hPreview = preview(handles.eyeVid);
  handles.text2.String = 'Please select ROI (double click on a rectangle to accept)';
  h = imrect(get(hPreview, 'Parent'));
  pos = wait(h);
  stoppreview(handles.eyeVid)
  handles.eyeVid.ROIPosition = pos;
  set(h,'visible','off');
  clear pos h hPreview
  preview(handles.eyeVid);
  handles.text2.String = 'ROI was set';
else
  handles.text2.String = 'Still recording. Stop recording before setting ROI';
end

% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, ~, handles)
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

if ~isrunning(handles.eyeVid)
  preview(handles.eyeVid);
  handles.eyeVid.ROIPosition = [0 0 handles.eyeVid.VideoResolution];
  handles.text2.String = 'ROI was removed';
else
  handles.text2.String = 'Still recording. Stop recording before removing ROI';
end

% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, ~, handles)
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)

if ~isrunning(handles.eyeVid)
  handles.recFolder = uigetdir;
  handles.text2.String = 'Folder for saving videos was selected';
  handles.text3.String = ['Video frame refresh rate: ' num2str(handles.eyePP.FrameRate) ' Hz'];
  handles.text4.String = ['Recording folder: ' handles.recFolder];
else
  handles.text2.String = 'Still recording. Stop recording before changing folder';
end

% Update handles structure
guidata(hObject, handles);


% --- Updates frame count.
function update_framecount(~, ~, figure1)

handles = guidata(figure1);
handles.text3.String = ['Frame count: ' num2str(getfield(handles.eyeVid.DiskLogger,'FrameCount'))];


% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, ~, handles)
% hObject    handle to pushbutton7 (see GCBO)
% handles    structure with handles and user data (see GUIDATA)

if ~isrunning(handles.eyeVid)
  handles.text2.String = 'Ready to record';
  while true
    prompt = {'Enter a frame rate (in Hz)'};
    title = 'Frame Rate';
    definput = {'24'};
    opts.Interpreter = 'tex';
    answer = inputdlg(prompt,title,[1 40],definput,opts);
    answer = str2num(answer{1}); %#ok<*ST2NM>
    if answer > 0 && answer <= 120
      handles.eyeVid.FrameGrabInterval = round(str2num(handles.src.FrameRate)/answer);
      handles.eyePP.FrameRate = str2num(handles.src.FrameRate)/handles.eyeVid.FrameGrabInterval;
      handles.text3.String = ['Video frame refresh rate: ' num2str(handles.eyePP.FrameRate) ' Hz'];
      break
    else
      uiwait(msgbox('The video frame refresh rate has to be in the range of (0,120] Hz', 'CreateMode','modal'));
    end
  end
  handles.text4.String = ['Recording folder: ' handles.recFolder];
else
  handles.text2.String = 'Still recording. Stop recording before changing the frame refresh rate';
end

% Update handles structure
guidata(hObject, handles);