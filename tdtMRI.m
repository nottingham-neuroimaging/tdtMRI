% function tdtMRI()
%
%   author: Julien Besle, based on Cris Lanting's MRITonotopy
%     date: 12/02/2013
%  purpose: Sound presentation for fMRI using a TDT RP2 real-time processor 
%           Each stimulus must be less than one TR and is synchronised to
%           a trigger received from the scanner through the TRIG input of the
%           RP2. TR must be at least 4s long, presumably because of the time it takes
%           to communicate with the processor (writing data, getting counter values, etc..).
%           Stimuli are synthesized in matlab as one or several simultaneous 
%           (not tested) streams of bandpass noises, presented over a continuous
%           broadband (equal energy) noise background. Parameters of the bandpass noises
%           (frequency, bandwidth, duration, level) are controlled through
%           a user-specific 'parameter' function that reads numerical parameters 
%           and outputs a sequence of complex stimuli.
%           The application's GUI allows the user to change general parameters
%           (number of epochs per run, TR) and parameters specific to the parameter
%           function. It also features button to start/stop the TDT
%           circuit, and start/stop stimulation runs, as well as a
%           graphical representation of stimuli.
%           
%           Overview of the TDT circuit (tdtMRI.rcx) and how it is controlled by matlab:
%           - The circuit implements two serial sources: one for the stimulus
%           presentation (signal) and one for the background noise. 
%           - When starting the circuit, the noise source buffer is filled 
%           with broadband noise. 
%           - When starting a run, a soft trigger switches on the
%           noise source, fills the signal buffer with the first half of the 
%           first stimulus and allows the scanner trigger to be received.
%           - Each time a trigger is received, a trial counter is increased
%           by one and the signal starts reading from the start of the
%           buffer. While it is reading, matlab fills the second half of
%           the signal buffer
%           - The signal buffer counter is monitored by matlab and when the
%           middle of the buffer is reached, matlab fills the first half of
%           the next stimulus and waits for the next trigger. If no trigger
%           is received when the stimulus finishes, the circuit stops the
%           signal buffer
%           - When the run finishes or the user stops the run, the noise is
%           switched off, the signal buffer stopped and its counter reset
%           and the trial counter reset.
%           The circuit also implements a virtual MRI trigger through 
%           its digital output, which must be physically connected to the TRIG input
%
%           Format of parameter functions
%           - parameter functions should be stored in a folder called
%           'parameters' located in the tdtMRI function folder
%           - they should accept as inputs (1) a parameter structure containing
%           numerical values, (2) an integer for the number of epochs per run 
%           and (3) an integer for the TR in milliseconds
%           - they should output (1) the parameter structure and (2) an array of
%           stimulus structures, each describing a stimulus whose duration is less
%           than 1 TR, in the order in which they should be presented
%           - when called with an empty parameter structure, they should
%           output a parameter structure with default values
%           - each stimulus is described by 6 fields, 2 of which are
%           single-valued and 4 of which are 2D arrays of numerical where
%           each rows describe a stream of stimuli
%           Single valued fields
%               - name: the name of the stimulus
%               - number: a number uniquely identifying each type of stimulus
%           2D array fields
%               - frequency: frequency of each bandpass noise in kHz
%               - level: level of each bandpass noise in dB (over noise ?)
%               - bandwidth: bandwidthof each bandpass noise
%               - duration: duration of each bandpass noise in milliseconds

function tdtMRI

  % ~~~~~~~~~~~~~~~~~ Initialize variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~
  % initialize variables that will be used by nested functions 
  %(shared-scope variables) 

  lGray = 0.775*ones(1,3);
  mGray = 0.65*ones(1,3);
  dGray = 0.5*ones(1,3);
  ScreenPos = get(0,'ScreenSize');
  FontSize = 13;
  messageNLines = 9; %number of lines in the message window

  rand('twister',sum(100*clock));     
%     randn('state',sum(100*clock))
  participant = 'test';
  nAddParam = 6;          %max number of parameters of the parameter function that are editable in the GUI
  usedAddParams = 0;      %number of parameters that are actually editable (could be less than nAddParam)
  pathString = fileparts(which(mfilename));   %path to the function
  if isempty(pathString)
    fprintf('Function %s must be on your path or in the current folder\n',mfilename);
    return;
  end

  TDT = true;    %set fo False to debug without switching the TDT on
  displaySounds = false;
  headphonesOptions={'NNL Inserts', 'NNL Headphones', 'Sennheiser HD 212Pro', 'Sensimetrics S14', 'None'};
  headphones = 'Sensimetrics S14';
  maxVoltage = 10; %saturation voltage of TDT
  if TDT
    getTagValDelay = .5; % the approximate time it takes to get values from the RP2 (in sec)
  else
    getTagValDelay = 0; %if running without the TDT, then things happen when they're supposed to
  end

  sampleDuration = 1/24.4140625;  %the duration of a TDT sample in milliseconds
  TR = 8000;          % the expected delay between image acquisitions (scanner pulses) in milliseconds
  stimTR = 2000;      % The total duration of a stimulus. Should be a divisor of the TR (i.e. an integer number of stimuli should fit in the TR)
  minTDTcycle = 7000;  % This is the shortest cycle that can be dealt with by the program considering the time delays of communicating with the TDT
                      % It will be used to decide when to start waiting for a trigger (minTR) and therefore how many scanner (or simulated) triggers should be skipped
                      % before receiving the next one
  TDTcycle = ceil(minTDTcycle/TR)*TR;  %the approximate time of a full cycle of the main program loop
  minTR = TDTcycle-TR/2;  % the minimum delay between consecutive received scanner pulses (useful to skip scanner pulses in continuous sequences)
  nStimTRs = TDTcycle/stimTR; %number of stimTR that fit in a TR
  nTRs = round(TDTcycle/stimTR);    %number of stimTRs that fit in a TDT cycle
  gateDuration = 10;  % the stimulus ramp time. this is applied to each bandpass noise 
                      % in the stimulus, as well as at the start and end
                      % of each stimulus

  simulatedTriggerToggle=0; %state of the simulated trigger switch
  syncTR = 8000;            % delay between simulated scanner pulses
  nRepeatsPerRun = 4;       %number of times the set of unique stimuli is repeated in a run
  currentRun=0;    
  completedRuns=0;          %to keep track of completed runs

  HB7Gain = -18;            % attenuation setting of the TDT HB7 Headphone Driver (in dB)
  NNLGain = [-40 -27.4 -18.6 -12.21 -6.2 0]; %attenuation corresponding to the 6 NNL amplifier 'Acoustic Level' settings
  NNLsetting = 6;              % amplification setting of NNL amplifier at the 7T scanner (in dB)
  HB7CalibGain = -27;       % attenuation setting of the TDT HB7 Headphone Driver at which calibration was done
  NNLCalibSetting = 6;         % amplification setting of NNL amplifier at the 7T scanner at which calibration was done
  transferFunction=struct();
  calibrationGainLeft = [];
  calibrationGainRight = [];
  noiseBufferSize = [];
  
  AMfrequency = 0; % default amplitude modulation frequency(0 = no modulation)
  NLevel = 35;%35;              % intended background noise level expressed in "masking" level (if Nlevel=Slevel, the signal would be just detectable)
  SNR1dB = 10*log10(10^(1/10)-1); % SNR1dB is the SNR of a just detectable signal embedded in noise:
                                  % a signal is just detectable if S+N is more intense than N alone by about 1 dB (Zwicker) 
                                  % solve 10*log10((IS+IN)/IN) = 1 dB for IS/IN and then apply 10*log10; IS/IN = signal/noise intensity; 
                                  % (i.e. a signal is just detectable in a noise level that's about 5.9 dB louder)
                                  % this will be subtracted to the desired noise level (instead of adding it to the signal)
  %For the background noise, there is a twist because the intended sound level concerns the portion of the spectrum
  %that stimulates one auditory (cochlear) filter and not the sound level of the total noise (at all frequencies)
  %To account for this, we compute the ratio of the energy within one critical band around 1kHz and the total energy for an
  %equally exciting noise (a noise that stimulates an auditory filter with the same energy)
  LEE = lcfLEE(2^18,1,sampleDuration); 

  params = [];              %structure that will contain the numerical parameters to the parameter function
  paramNames = [];          %names of these parameters
  lastButtonPressed = 'none';   %state of the start/stop run buttons
  parameterFunction = '';       %fid of the parameter function
  logFile=1;                    %fid of the log file
  RP2=[];          % activeX object for circuit control
  HActX = [];      % handle to the activeX figure (invisible)
  circuitRunning=false;   
  signalBufferMaxSize = [];     %maximum size of the signal buffer in samples
  signalExtraZeroes = round(100/sampleDuration); % 100 milliseconds of zeroes added at the end of signal to avoid having 
                                      % the MRI trigger sent at the same time as the counter reset 
                                      % (which creates a loop in the circuit)

  
  % ~~~~~~~~~~~~~~~~~~~~ GUI ~~~~~~~~~~~~~~~~~~~~
  mainBottomGap=40;
  mainRightGap=4;
  mainMaxWidth=1000;
  mainMaxHeight=700;
  hMainFigure = figure('Color',lGray,...
      'Menubar','none',...
      'Name','fMRI adaptation & tonotopy ',...
      'NumberTitle','off',...
      'Position',[ScreenPos(3)-min(ScreenPos(3),mainMaxWidth)-mainRightGap  ...
                 mainBottomGap ...
                 min(ScreenPos(3)-mainRightGap,mainMaxWidth) ...
                 min(ScreenPos(4)-mainBottomGap,mainMaxHeight)],...
      'DefaultUicontrolHorizontalAlignment','left',...
      'DefaultUicontrolFontSize',FontSize,...
      'DefaultUicontrolFontName','Arial',...
      'DefaultUicontrolUnits','normalized',...
      'closeRequestFcn',{@mainCallback,'QuitExp'});

  Width = 0.2;
  editHeight = 0.035;
  XGap = 0.025;
  YGap = 0.0075;
  XPos = 0.525; 
  YPos = 0.95;
  buttonHeight = 0.05;
  checkBoxHeight = 0.03;

  %%%%%%%%%%%%%%%% text/edit controls to change parameters
  uicontrol('Parent',hMainFigure,...                      %Participants's initials
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','Participants''s initials:');
  hParticipant = uicontrol('Parent',hMainFigure,...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'Participant'},...
      'Position',[XPos+Width+XGap YPos Width editHeight],...
      'String',participant,...
      'Style','edit');

  YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                       % Number of epochs/run
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','Number of epochs/run:');
  hEpochsPerRun = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'nEpochsPerRun'},...
      'Position',[XPos+Width+XGap YPos Width editHeight],...
      'String',num2str(nRepeatsPerRun),...
      'Style','edit');

  YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                       % TR (expected time between received scanner pulses
      'BackgroundColor',mGray,...                          % this is also the duration of the synthesized sound sequence)
      'Position',[XPos YPos Width/2 editHeight],...
      'Style','text',...
      'String','TR (sec):');
  hTR = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'TR'},...
      'Position',[XPos+(Width+XGap)/2 YPos (Width-XGap)/2 editHeight],...
      'String',num2str(TR/1000),...
      'Style','edit');

  uicontrol('Parent',hMainFigure,...                       % min TR (minimum waiting time after receiving a scanner pulse
      'BackgroundColor',mGray,...                          % before the next pulse can be received)
      'Position',[XPos+Width+XGap YPos Width*2/3 editHeight],...
      'Style','text',...
      'String','Stim TR (sec):');
  hStimTR = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'stimTR'},...
      'Position',[XPos+Width*5/3+XGap*3/2 YPos Width/3-XGap/2 editHeight],...
      'String',num2str(stimTR/1000),...
      'Style','edit');

  YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                       % Background Noise Level
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','Noise Level (dB):');
  hNLevel = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'noiseLevel'},...
      'Position',[XPos+Width+XGap YPos Width editHeight],...
      'String',num2str(NLevel),...
      'Style','edit');

YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                       %AM frequency of background noise level
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','AM Frequency (Hz):');
  hAMfrequency = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'AMfrequency'},...
      'Position',[XPos+Width+XGap YPos Width editHeight],...
      'String',num2str(AMfrequency),...
      'Style','edit');

  YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                      %Condition parameter file
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','Parameter Function:');
  
  %get a list of available parameter functions
  %all parameterFunctions should be saved as M files in a 'parameters' folder
  %located in same folder as tdtMRI.m
  parameterFunctions =  dir([pathString '/parameters/' '*.m']); %get the list of m files in that folder
  if ~isempty(parameterFunctions)
    parameterFunctionsList = cell(1,length(parameterFunctions));
    for iFile=1:length(parameterFunctions)
       parameterFunctionsList{iFile} = strtok(parameterFunctions(iFile).name,'.'); %remove extension 
       %(assumes there is no dot in the file name itself)
    end
    hParamsFunction = uicontrol('Parent',hMainFigure, ... %create a popup menu to select the parameter function
        'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'paramFunction'},...
        'Position',[XPos+Width+XGap YPos Width editHeight],...
        'String',parameterFunctionsList,...
        'Style','popup');
  else %in case no parameter function is found (unlikely), replace the popup menu by an edit box and a browser
    hParamsFunction = uicontrol('Parent',hMainFigure, ...
        'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'paramFunction'},...
        'Position',[XPos+Width+XGap YPos 0.1 editHeight],...
        'Style','edit');
    uicontrol('Parent',hMainFigure, ...
        'BackgroundColor',mGray,...
      'Callback',{@mainCallback,'Browse'},...
        'String','Browse',...
        'Position',[0.8 YPos 0.15 editHeight],...
        'Style','pushbutton');
  end

  %put a number of edit boxes for parameters specific to the selected
  %parameter function
  for iParam = 1:nAddParam
    YPos = YPos-(editHeight+YGap);
    hParamNames(iParam) = uicontrol('Parent',hMainFigure,...    %Additional parameters
        'BackgroundColor',mGray,...
        'Position',[XPos YPos Width editHeight],...
        'Enable','off',...
        'Style','text',...
        'String','Unused');
    hParams(iParam) = uicontrol('Parent',hMainFigure, ...
        'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'Parameter',iParam},...
        'Position',[XPos+Width+XGap YPos Width editHeight],...
        'Enable','off',...
        'Style','edit');
  end

  %%%%%%%%%%%%%%%% text controls to display run/trial information
  YPos = YPos-(editHeight+YGap);
  hNScans = uicontrol('Parent',hMainFigure,...              %Number of dynamic scans
      'BackgroundColor',mGray,...
      'Position',[XPos YPos 2*Width+XGap editHeight],...
      'Style','text',...
      'String','Number of dynamic scans:');

  YPos = YPos-(editHeight+2*YGap);
  hCurrentRun = uicontrol('Parent',hMainFigure,...          %Current run
      'BackgroundColor',mGray,...
      'Position',[XPos YPos 2*Width+XGap editHeight],...
      'Style','text',...
      'String','Current run:');

  YPos = YPos-(editHeight+YGap);
  hcurrentTrigger = uicontrol('Parent',hMainFigure,...        %Current trial
      'BackgroundColor',mGray,...
      'Position',[XPos YPos 2*Width+XGap editHeight],...
      'Style','text',...
      'String','Current scan:');

  YPos = YPos-(editHeight+YGap);
  hCurrentCondition = uicontrol('Parent',hMainFigure,...    %Current condition
      'BackgroundColor',mGray,...
      'Position',[XPos YPos 2*Width+XGap editHeight],...
      'Style','text',...
      'String','Current condition:');

  YPos = YPos-(editHeight+YGap);
  hRemainingTime = uicontrol('Parent',hMainFigure,...       %Time remaining
      'BackgroundColor',mGray,...
      'Position',[XPos YPos 2*Width+XGap editHeight],...
      'Style','text',...
      'String','Time remaining till end of run:');

%   YPos = YPos-(4.7*editHeight+2*YGap);
  hMessage = uicontrol('Parent',hMainFigure,...             %Message window
      'BackgroundColor',mGray,...
      'ForegroundColor','r',...
      'FontName','Arial',...
      'FontSize',FontSize,...
      'HorizontalAlignment','left',...
      'Units','normalized',...
      'Position',[XPos 2*YGap 2*Width+XGap YPos-3*YGap],...
      'Style','text');

%%%%%%%%%%%%%%%%% Sound display Windows
  windowWidth = 0.4;
  windowHeight = 0.4;
  YGap = 0.05;
  XPos = 0.075;
  YPos = 0.275;
  hSpectrogram = axes('Parent',gcf,...
     'Units','normalized',...
     'Position',[XPos YPos windowWidth windowHeight],...
     'FontName','Arial',...
     'FontSize',10,...
     'Box','on');
  hTimeseries = axes('Parent',gcf,...
     'Units','normalized',...
     'Position',[XPos YPos+windowHeight+YGap windowWidth 1-windowHeight-2*YGap-YPos],...
     'FontName','Arial',...
     'FontSize',10,...
     'Box','on');


  XGap = 0.025;
  YGap = 0.0075;
  XPos = 0.05;
  
  YPos = 0.21;
  uicontrol('Parent',hMainFigure,...    %sound display checkbox
    'Callback',{@mainCallback,'displaySounds'},...
    'BackgroundColor',lGray,...
    'Position',[XPos YPos Width checkBoxHeight], ...
    'Style','checkbox',...
    'String','Display sounds', ...
    'value',displaySounds);
 
  YPos = 0.14;
  hInserts = uicontrol('Parent',hMainFigure,...    %headphones checkbox
    'Callback',{@mainCallback,'headphones'},...
    'Position',[XPos YPos Width buttonHeight], ...
    'Style','popupmenu',...
    'String',headphonesOptions, ...
    'value',find(ismember(headphonesOptions,headphones)));

%%%%%%%%%%%%%%%% pushbuttons to control circuit/runs
  YPos = 0.15;
  hSimulatedTrigger = uicontrol('Parent',hMainFigure,...    %Simulated trigger
      'BackgroundColor',dGray,...
      'BusyAction','queue',...
    'Callback',{@mainCallback,'SynTrig'},...
      'Enable','off',...
      'HorizontalAlignment','center',...
    'Position',[XPos+Width+XGap YPos Width*2/3 buttonHeight], ...
      'Style','pushbutton',...
    'String',sprintf('Simulated Trigger (%.2f s)',syncTR/1000), ...
    'Tag','SynTrig');
  hSyncTR = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'SyncTR'},...
      'Position',[XPos+Width*5/3+XGap*3/2 YPos Width/3-XGap/2 buttonHeight],...
      'String',num2str(syncTR/1000),...
      'Style','edit');

  YPos = YPos-(buttonHeight+2*YGap);
  hStartCircuit = uicontrol('Parent',hMainFigure,...         %Start circuit
      'BackgroundColor',dGray,...
    'Callback',{@mainCallback,'StartCircuit'},...
      'FontSize',1.5*FontSize,...
      'HorizontalAlignment','center',...
      'Interruptible','on',...
    'Position',[XPos YPos Width buttonHeight], ...
      'Style','pushbutton',...
    'String','Start circuit');

  hStopCircuit = uicontrol('Parent',hMainFigure,...          %Stop circuit
      'BackgroundColor',dGray,...
      'BusyAction','queue',...
      'Enable','off',...
    'Callback',{@mainCallback,'StopCircuit'},...
      'FontSize',1.5*FontSize,...
      'HorizontalAlignment','center',...
    'Position',[XPos+Width+XGap YPos Width buttonHeight], ...
      'Style','pushbutton',...
    'String','Stop Circuit');

  YPos = YPos-(buttonHeight+YGap);
  hStartRun = uicontrol('Parent',hMainFigure,...              %Start run
      'BackgroundColor',dGray,...
    'Callback',{@mainCallback,'StartRun'},...
      'Enable','off',...
      'FontSize',1.5*FontSize,...
      'HorizontalAlignment','center',...
      'Interruptible','on',...
    'Position',[XPos YPos Width buttonHeight], ...
      'Style','pushbutton',...
    'String','Start run');

  hStopRun = uicontrol('Parent',hMainFigure,...                %Stop run
      'BackgroundColor',dGray,...
    'Callback',{@mainCallback,'StopRun'},...
      'Enable','off',...
      'FontSize',1.5*FontSize,...
      'HorizontalAlignment','center',...
      'Interruptible','on',...
    'Position',[XPos+Width+XGap YPos Width buttonHeight], ...
      'Style','pushbutton',...
    'String','Stop run');



%%%%%%%%%%%%%%%%%%%%%%% run some callbacks to initialize parameter values
  mainCallback(hParticipant,[],'Participant');
  mainCallback(hParamsFunction,[],'paramFunction'); %choses the first parameter function in the list and populate the additional parameter
  mainCallback(hEpochsPerRun,[],'nEpochsPerRun'); %read the default nEpochsPerRun value and update run information
  mainCallback(hTR,[],'TR'); %read the default TR value and update run information


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Callback function
  % each case corresponds to control in the GUI
  function mainCallback(handleCaller,dummy,item,option)

    switch(item)

      case('Participant')
        participant = upper(get(handleCaller,'String')); %capitalize participant initials
        set(hParticipant,'String',participant)
        
      % user chooses a parameter function
      case('paramFunction')   
        switch(get(handleCaller,'style'))
          case 'popupmenu'
            functionList = get(handleCaller,'string');
            parameterFunction = functionList{get(handleCaller,'value')}; %get the selected parameter function name
          case 'edit'
            parameterFunction = get(hParamsFunction,'String');
        end
        if ~isempty(parameterFunction)
          updateParameters  %populate parameter edit controls
          updateRunInfo     %update the run duration according to the new number of stimuli
        end
        
      %in case no parameter function is found, user selects the parameter function file in a browser  
      case('Browse')
        parameterFunction = uigetfile('*.m','Parameter function');
        if ~isnumeric(parameterFunction)
          [dummy, parameterFunction]=fileparts(parameterFunction); %remove extension ?
          set(hParamsFunction,'String',parameterFunction); %put the function name in the edit window
          updateParameters  %populate parameter edit controls
          updateRunInfo     %update the run duration according to the new number of stimuli
        end   

      case('nEpochsPerRun')
        nRepeatsPerRun = eval(get(handleCaller,'String'));
        updateRunInfo    %update the run duration according to the new number of repeats

      case('TR')
        TR = 1000*eval(get(handleCaller,'String'));
        TDTcycle = ceil(minTDTcycle/TR)*TR;
        minTR = TDTcycle-TR/2;  % the minimum delay between consecutive received scanner pulses (useful to skip scanner pulses in continuous sequences)
        nStimTRs = round(TDTcycle/stimTR);    %number of stimTRs that fit in a TDT cycle
        nTRs = round(TDTcycle/TR);    %number of stimTRs that fit in a TDT cycle
        updateRunInfo   %update the run duration according to the new TR value
        plotSignal(zeros(1,nStimTRs*signalSize()));

      case('stimTR')
        stimTR = 1000*eval(get(handleCaller,'String'));
        nStimTRs = round(TDTcycle/stimTR);    %number of stimTRs that fit in a TDT cycle
        updateRunInfo   %update the run duration according to the new stimTR value
        
      case('noiseLevel')
        NLevel=eval(get(handleCaller,'String'))-SNR1dB; % actual background noise level (dB SPL) (instead of adding SNR1dB to the signal levels, we subtract it from the noise level)

      case('AMfrequency')
        AMfrequency=eval(get(handleCaller,'String')); % 

      case 'Parameter'
        params.(paramNames{option})=  eval(['[' str2mat(get(handleCaller,'String')) ']']);
        updateRunInfo   %update the run duration according to the new parameters
      
      case('displaySounds')
        displaySounds=get(handleCaller,'Value'); % actual background noise level (dB SPL) (instead of adding SNR1dB to the signal levels, we subtract it from the noise level)
        if ~displaySounds
          plotSignal(zeros(1,nStimTRs*signalSize()));
        end
        
      case('headphones')
        headphones=headphonesOptions{get(handleCaller,'Value')}; % actual background noise level (dB SPL) (instead of adding SNR1dB to the signal levels, we subtract it from the noise level)
        
      case 'SynTrig' %user presses the simulated trigger button (this is only possible during a run)
        %the button has two states (3 = pushed, 4 = released)
        if exist('option','var') && ~isempty(option)
          %if callback called with option =3 or 4, set the button to the required state
          simulatedTriggerToggle=option;
        else
          %otherwise toggle between the two states 
          simulatedTriggerToggle = 4-mod(simulatedTriggerToggle+1,2);
        end
        if TDT %switch simulated trigger according to state (3=on, 4=off)
          invoke(RP2,'SoftTrg',simulatedTriggerToggle); 
        end
        % The state of the button is symbolized by its background colour
        if simulatedTriggerToggle==3
            set(hSimulatedTrigger,'BackgroundColor',[1 1 1]) 
    %         displayMessage({'Start Simulated TRIGGER'})
        else
            set(hSimulatedTrigger,'BackgroundColor',dGray)
    %         displayMessage({'Stop Simulated TRIGGER'})
        end

      case('SyncTR')
        syncTR = 1000*eval(get(handleCaller,'String'));
        
      case('StartCircuit')    

        if TDT
          displayMessage({'Creating TDT ActiveX interface...'})
          HActX = figure('position',[0.2*ScreenPos(3)/100 (75+2.25)*ScreenPos(4)/100 (100-0.4)*ScreenPos(3)/100 (25-4.3)*ScreenPos(4)/100],...
              'menubar','none',...
              'numbertitle','off',...
              'name','TDT ActiveX Interface',...
              'visible','off');
          pos = get(HActX,'Position');

          RP2 = actxcontrol('RPco.x',pos,HActX);  %create an activeX control for TDT RP2
          invoke(RP2,'ConnectRP2','USB',1); %connect to the RP2 via the USB port
          invoke(RP2,'ClearCOF');
          circuitFilename = [pathString '\tdtMRI.rcx'];
          if ~exist(circuitFilename,'file') %check that the circuit object file exists
              displayMessage({sprintf('==> Cannot find circuit %s',circuitFilename)});
              return
          end
          invoke(RP2,'LoadCOF',circuitFilename);  %load the circuit
          invoke(RP2,'Run');  %start the circuit
          if ~testRP2() %test if the circuit is running properly
            delete(HActX) %if not, delete the activeX figure
            return
          else
            displayMessage({'RP2 circuit loaded and running!'})
          end
          displayMessage({sprintf('==> Make sure TDT HB7 gain is set to %.0f dB and NNL gain to %.0f !',HB7Gain, NNLsetting)});
          displayMessage('==> Make sure the red BNC is connected to the HB7 left output (for NNL headphones)');
          
          %check that the sampling rate of the circuit is the same as the one set in this program
          % (alternatively, could read the sampling rate from the circuit)
          SF = invoke(RP2,'GetSFreq');
          if ~strcmp(sprintf('%1.4e',SF),sprintf('%1.4e',1000/sampleDuration))
              displayMessage({'==> ERROR: TDT sampling rate does not match!'})
              invoke(RP2,'Halt');    
              delete(HActX)
              return
          end
          signalBufferMaxSize = invoke(RP2,'GetTagVal','SignalBufSize'); % this is the signal buffer size at circuit compilation
          noiseBufferSize = invoke(RP2,'GetTagVal','NoiseBufSize');   %get the noise buffer size                
        else
          displayMessage({'Not using TDT'});
          noiseBufferSize=261900;
        end
        
        displayMessage({''})
        circuitRunning = true; %to check if the circuit is supposed to be running from outside this function
        set(hStartCircuit,'Enable','off')
        set(hStartRun,'Enable','on')
        set(hStopCircuit,'Enable','on')
        displayMessage({'Proceed by pressing <Start run> ...'});
        

      case('StopCircuit')
        if TDT && circuitRunning
          displayMessage({'Stopping TDT circuit, please wait'});
          invoke(RP2,'Halt');
          delete(HActX)
        end
        if exist('hStartRun','var')
            set(hStartRun,'Enable','off')
        end
        if exist('hStopCircuit','var')
            set(hStopCircuit,'Enable','off')
        end
        if exist('hStartCircuit','var')
            set(hStartCircuit,'Enable','on')
        end
        if exist('hMessage','var')
            displayMessage({'Circuit stopped';''});
        end
        circuitRunning = false;
          
        
      case('StartRun')  

        %make sure we have all the information we need
        abort=false;
        if isempty(params)
            displayMessage({'==> WARNING: parameters are not specified!'})
            abort=true;
        end
        if isempty(participant)
            displayMessage({'==> WARNING: participant''s name not specified!'})
            abort=true;
        end
        if isempty(nRepeatsPerRun)
            displayMessage({'==> WARNING: nRepeatsPerRun not specified!'})
            abort=true;
        end
        if isempty(TR)
            displayMessage({'==> WARNING: TR not specified!'})
            abort=true;
        end
        if rem(TR,stimTR)
            displayMessage({'==> WARNING: TR must be an integer multiple of stimTR!'})
            abort=true;
        end
        if abort
          return
        end
        
        %check that the circuit is running (in case TDT has been turned off)
        if TDT && ~testRP2()
          mainCallback(handleCaller,[],'StopCircuit');
          return
        end       
        displayMessage({'Initializing circuit, please wait...'});
        %check that there is enough space in the SerSource buffer for
        %signal plus trailing zeroes
        if TDT
          if nStimTRs*signalSize()>= signalBufferMaxSize - signalExtraZeroes % cannot allocate more memory than that set 
              % at circuit compilation (currently 300000 samples ~= 12.8 seconds)
              displayMessage({'==> ERROR: TR is too long.';'Increase initial SignalBufSize in circuit'}) 
              return
          end
        end
        
        lastButtonPressed = 'start run';   %this will be used to check if the run completed without interruption
        currentRun=currentRun+1;
        % update current run in GUI
        strg = get(hCurrentRun,'String'); Idx = strfind(strg,':');
        set(hCurrentRun,'String',[strg(1:Idx) sprintf(' %g (%g completed)',currentRun,completedRuns)])
        
        %disable buttons/edit boxes
        set(hStartRun,'Enable','off')
        set(hStopCircuit,'Enable','off')
        set(hInserts,'Enable','off')
        set(hParticipant,'Enable','off')
        set(hSyncTR,'Enable','off')
        set(hParamsFunction,'Enable','off')
        set(hEpochsPerRun,'Enable','off')
        set(hTR,'Enable','off')
        set(hStimTR,'Enable','off')
        set(hNLevel,'Enable','off')
        set(hAMfrequency,'Enable','off')
        set(hParams(1:usedAddParams),'Enable','off')
        %enable simulated trigger and stop run buttons
        set(hStopRun,'Enable','on')
        set(hSimulatedTrigger,'Enable','on')
        
        %compute the gain to apply to background noise and sounds
        switch headphones
          case 'NNL Inserts'
            calibrationLevel = 65.5;  % level (in dB SPL) of a 1Volt 1kHz sinewave recorded at the inserts with the above calibration settings (TDT output = -27dB and NNL output = 6)
            calibrationLevelLeft  = 80.9; % calibration 04/03/2016 left side (varies quite a lot depending on how the earplug is inserted in the coupler)
            calibrationLevelRight = 72.0; % calibration 04/03/2016 right side
            transferFunctionFile = 'clicks_596avg_8V.csv';  %csv file containing the impulse reponse of the NNL inserts (seems to correspond to right side)
            %new frequency transfer measurements to be read using loadTransferFunction.m instead of loadInsertsTransfer.m previously
            transferFunctionFileLeft = 'NNLinsertsLeftFFT.csv';  %csv file containing the impulse reponse of the NNL insert earphones (measured on 08/03/2016)
            transferFunctionFileRight = 'NNLinsertsRightFFT.csv';  %csv file containing the impulse reponse of the NNL insert earphones (measured on 08/03/2016)
          case 'NNL Headphones'
%             calibrationLevel = 81.4; % estimated level for the same noise using NNL headphones 
%                                      % (estimated from difference between NNL inserts and headphones transfer functions at 1kHz)
            calibrationLevel = 82.3; % level (in dB SPL) of a 1Volt 1kHz sinewave recorded at the NNL headphones with the above calibration settings
            calibrationLevelLeft  = 83.2; % calibration 04/03/2016 left side
            calibrationLevelRight = 84.4; % calibration 04/03/2016 right side
            transferFunctionFile = 'HD_clicks_752avg_8V.csv';  %csv file containing the impulse reponse of the headphones
            %new frequency transfer measurements to be read using loadTransferFunction.m instead of loadInsertsTransfer.m previously
            transferFunctionFileLeft = 'NNLheadphonesLeftFFT.csv';  %csv file containing the impulse reponse of the NNL headphones (measured on 08/03/2016)
            transferFunctionFileRight = 'NNLheadphonesRightFFT.csv';  %csv file containing the impulse reponse of the NNL headphones (measured on 08/03/2016)
          case 'Sennheiser HD 212Pro'
%             calibrationLevel = 100; % estimated level for the same noise using Sennheiser HD 212Pro directly plugged to the TDT HB7 driver
%                                     %(estimated from difference between NNL inserts and Senheiser headphones transfer functions at 1kHz
%                                     % correcting for differences in amplitudes of the impulse)
            calibrationLevel = 84.3; % calibration level estimated by hear so that the level of these headphones roughly match those of the NNL headphones/inserts
            calibrationLevelLeft  = 77.4; % calibration 04/03/2016 left side
            calibrationLevelRight = 81.6; % calibration 04/03/2016 right side
            transferFunctionFile = 'click_50003pts.mat';  %csv file containing the impulse reponse of the Sennheiser headphones
            %new frequency transfer measurements to be read using loadTransferFunction.m instead of loadInsertsTransfer.m previously
            transferFunctionFileLeft = 'Senheiser212ProLeftFFT.csv';  %csv file containing the impulse reponse of the Senheiser 212 Pro headphones (measured on 08/03/2016)
            transferFunctionFileRight = 'Senheiser212ProRightFFT.csv';  %csv file containing the impulse reponse of the Senheiser 212 Pro headphones (measured on 08/03/2016)
          case 'Sensimetrics S14'
            calibrationLevelLeft = 80.4; % calibration 04/03/2016 left side
            calibrationLevelRight = 78.8; % calibration 04/03/2016 right side
            transferFunctionFile = 'EQF_396L.bin';  %csv file containing the impulse reponse of the Sensimetrics S14 insert earphones (provided by vendor)
            transferFunctionFile = 'EQF_396R.bin';  %csv file containing the impulse reponse of the Sensimetrics S14 insert earphones (provided by vendor)
            %new frequency transfer measurements to be read using loadTransferFunction.m instead of loadInsertsTransfer.m previously
            transferFunctionFileLeft = 'S14insertsLeftFFT.csv';  %csv file containing the impulse reponse of the Sensimetrics S14 insert earphones (measured on 08/03/2016)
            transferFunctionFileRight = 'S14insertsRightFFT.csv';  %csv file containing the impulse reponse of the Sensimetrics S14 insert earphones (measured on 08/03/2016)
          case 'None'
            calibrationLevelLeft = 77.4;   % calibration values from Senheiser headphones. Use these as the level of a 1kHz sinewave 
            calibrationLevelRight = 81.6;  % so that its max voltage is 1 (on the corresponding side)
        end
        calibrationLevelLeft = calibrationLevelLeft + 3; %corresponding level for a 1voltRMS noise
        calibrationLevelRight = calibrationLevelRight + 3; %corresponding level for a 1voltRMS noise
        calibrationGainLeft = -calibrationLevelLeft+HB7CalibGain+NNLGain(NNLCalibSetting)-HB7Gain-NNLGain(NNLsetting); 
        calibrationGainRight = -calibrationLevelRight+HB7CalibGain+NNLGain(NNLCalibSetting)-HB7Gain-NNLGain(NNLsetting); % correction factor (in dB) to apply to the 
        %the intended sound level so that it actually results in the corresponding sound level, given the HB7 and NNL settings
        %Explanation: with calibration settings of HB7CalibGain=-27dB and NNLGain=0dB, it was recorded that a 1 kHz sinewave
        %with peak amplitude 1V (rms=1/sqrt(2)) results in a 65.5dB SPL sound level. Therefore an arbitrary signal with rms=1V would result in
        %a 68.5 dB SPL level (*sqrt(2) <-> +3dB)
        %Therefore, to present a 1Vrms signal at 70 dB SPL with the same attenuation/amplification settings as during calibration,
        %the signal would have to be amplified by 70 - 68.5 = 1.5 dB.
        %However, if the attenuation/amplification settings change (say HB7Gain = -24dB and NNLGain = -6.2dB), the signal would have
        %to be amplified (attenuated) by 70 - 68.5 + HB7CalibGain + NNLCalibGain - HB7Gain - NNLGain = 70-68.5-27+0+24+6.2 = 4.7 dB
        % (= 70 + calibrationGain) in order to result in the same output level of 70 dB SPL.
        
        %load insert transfer inverse filter parameters
        if ~strcmp(headphones,'None')
%           transferFunction=loadInsertsTransfer([fileparts(which('tdtMRI')) '/' transferFunctionFile],noiseBufferSize,sampleDuration);
          transferFunction=loadTransferFunction([fileparts(which('tdtMRI')) '/' transferFunctionFileLeft]);
          transferFunction(2)=loadTransferFunction([fileparts(which('tdtMRI')) '/' transferFunctionFileRight]);
        end
        
        if TDT
          %write background noise to TDT
          fNoise = lcfMakeNoise(noiseBufferSize,sampleDuration,0);  % synthesize broadband noise   
          invoke(RP2,'WriteTagVEX','FNoise',0,'I16',round(fNoise/10*2^15));  % fill the noise buffer with 16-bit integers           
          invoke(RP2,'SetTagVal','NAmpL',10^((NLevel+calibrationGainLeft-LEE)/20)); %set the noise level
          invoke(RP2,'SetTagVal','NAmpR',10^((NLevel+calibrationGainRight-LEE)/20)); %set the noise level
          invoke(RP2,'SetTagVal','SplitScale',maxVoltage/(2^15-1)); %set the scaling factor that converts the signals from 16-bit integers to floats after splitting the two channels
          invoke(RP2,'SetTagVal','minTR',round((minTR)/sampleDuration)+1); 
        end
        
        %write log file header
        logFile = fopen(sprintf('%s\\%s_%s_%s%02d.txt',pwd,participant,datestr(now,'yyyy-mm-dd_HH-MM-SS'),parameterFunction,currentRun),'wt');
        fprintf(logFile, 'Current date and time: \t %s \n',datestr(now));
        fprintf(logFile, 'Subject: \t \t %s \n', participant);
        fprintf(logFile, 'Parameter function: \t %s \n', parameterFunction);
        maxParamNameLength = 0; for iParams = 1:length(paramNames),maxParamNameLength=max(maxParamNameLength,length(paramNames{iParams}));end
        for iParams = 1:length(paramNames)
          fprintf(logFile, '  %s = %s%s \n',paramNames{iParams},repmat(' ',1,maxParamNameLength-length(paramNames{iParams})),num2str(params.(paramNames{iParams})));
        end
        fprintf(logFile, '\nDynamic scan duration (ms): \t %d \n', TR);
        fprintf(logFile, 'Noise Level: \t %d dB (%.3f dB SPL)\n', NLevel, NLevel-SNR1dB);
        fprintf(logFile, '----------------------\n');
        fprintf(logFile, 'scan\tcond.\tfreq.(kHz)\tlevel(dB)\tbandwidth(kHz)\tduration(ms)\tname\tapproximate time (MM:SS)\n');

        try
          lcfOneRun %% run the stimulation
        catch id
          displayMessage({'There was an error running the circuit'})
          disp(getReport(id));
          lastButtonPressed = 'stop run';
        end
        %close the log file
        if strcmp(lastButtonPressed,'start run') %if the stop button has not been pressed
          completedRuns = completedRuns+1;
          fprintf(logFile, '----------------------\n');
          fprintf(logFile, '\nRUN COMPLETED\n');
        else
          fprintf(logFile, '\nRUN INTERRUPTED\n');
        end
        fclose(logFile);
        %update current run in the GUI
        strg = get(hCurrentRun,'String'); Idx = strfind(strg,':');
        set(hCurrentRun,'String',[strg(1:Idx) sprintf(' not running (%g completed)', completedRuns)])
        
        %disable simulated trigger and stop run buttons
        set(hStopRun,'Enable','off')
        set(hSimulatedTrigger,'Enable','off')
        %enable buttons/edit boxes
        set(hParticipant,'Enable','on')
        set(hParamsFunction,'Enable','on')
        set(hEpochsPerRun,'Enable','on')
        set(hTR,'Enable','on')
        set(hStimTR,'Enable','on')
        set(hNLevel,'Enable','on')
        set(hAMfrequency,'Enable','on')
        set(hParams(1:usedAddParams),'Enable','on')
        set(hStartRun,'Enable','on')
        set(hStopCircuit,'Enable','on')
        set(hInserts,'Enable','on')
        set(hSyncTR,'Enable','on')
        mainCallback([],[],'SynTrig',4); %reset Simulated trigger button to off state
        displayMessage({'Proceed by pressing <Start run> ...'});
        
      case('StopRun')
        lastButtonPressed = 'stop run';
          
      case('QuitExp')
        %make sure the circuit is stopped and clean-up activeX object/figures
        mainCallback(handleCaller,[],'StopCircuit');
        delete(handleCaller)  %deleted the main GUI figure
        fprintf(1,'\nGoodbye ...\n\n\n');

    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ***** lcfOneRun *****
  function lcfOneRun()

    % Compute stimulus parameters for this run
    [dump,stimulus]= feval(parameterFunction,params,nRepeatsPerRun,stimTR,TR);
    %add at least one empty stimulus at the end (or as many as necessary so that 
    %the total number of stimuli is a multiple of nStimTRs and the last entire TDT cycle is empty)
    nCycles = ceil(length(stimulus)/nStimTRs)+1;
    for iStim = length(stimulus)+1:nCycles*nStimTRs
      stimulus(iStim).frequency=NaN;
      stimulus(iStim).level=NaN;
      stimulus(iStim).bandwidth=NaN;
      stimulus(iStim).duration = stimTR;
      stimulus(iStim).number=0;
      stimulus(iStim).name='No stimulus';
    end
    nScans = (nCycles-1)*nTRs+1;

    %synthesize signal for first stimulus/trials
    signal = makeSignal(stimulus(1:nStimTRs),signalSize());

    if TDT
      invoke(RP2,'SetTagVal','SignalSize',nStimTRs*signalSize()+signalExtraZeroes); %this is when to stop the serSource if a trigger has not been received
      invoke(RP2,'SetTagVal','NTrials',length(stimulus)+1);     %set this to something larger than the number of dynamic scans
      invoke(RP2,'WriteTagVEX','Signal',0,'I16',round(signal(:,1:nStimTRs*signalSize()/2)/maxVoltage*(2^15-1)));   %write first half of first stimulus to buffer
      invoke(RP2,'WriteTagVEX','Signal',nStimTRs*signalSize()/2,'I16',round(zeros(2,signalExtraZeroes)/maxVoltage*(2^15-1)));   %write zeroes at the end of buffer
      invoke(RP2,'SoftTrg',1);                                  %start run
      displayMessage({'Starting noise'});
    end

    displayMessage({'Waiting for trigger...'});
    currentTrigger = 0;
    nextTrigger = 0;
    hClipWarning=[];
    
    if displaySounds  
      [hCursorT, hCursorF] = plotSignal(signal);  %plot signal for next stimulus
    else
      hCursorT=[];
      hCursorF=[];
    end

    % wait for RP2 to receive the scanner/simulated trigger (i.e. start the stimulus + increase trial counter by one)
    while nextTrigger<= currentTrigger && ~strcmp(lastButtonPressed,'stop run')
      pause(0.05) % leave a chance to user to press a button
      if TDT
        nextTrigger=double(invoke(RP2,'GetTagVal','Trigger')); %get the current trial number from TDT (should increase by one each time a trigger is received)
      elseif simulatedTriggerToggle==3      % or if there is no TDT running, just check that the simulated trigger is on)
        nextTrigger=currentTrigger+1;
      end
    end
    timeTrigger = now;  % get a timestamp (note that there is a ~.5sec delay in getting the value from the RP2)
    timeStart = timeTrigger; % remember time of first trigger (not that this includes the ~.5sec delay, so that, assuming this delay is constant, the times in the log file should be correct)
    displayMessage({'Received trigger'});
   
    %Main loop
    while currentTrigger<nCycles-1 && ~strcmp(lastButtonPressed,'stop run')
        
      currentTrigger=nextTrigger;
      currentTrials = (currentTrigger-1)*nStimTRs+(1:nStimTRs);
      currentScans = ceil(currentTrials/nStimTRs*nTRs);
      updatelogFile(stimulus(currentTrials),currentScans,timeTrigger-timeStart); %print stimulus to log file
      %update current condition information
      updateTrialInfo(currentScans(1),nScans,stimulus(currentTrials(1)).number,stimulus(currentTrials(1)).name);
      
      if currentTrigger>0 
        if displaySounds  
          [hCursorT, hCursorF] = plotSignal(signal);  %plot signal for next stimulus
        else
          hCursorT=[];
          hCursorF=[];
        end
      end
      if max(signal)>maxVoltage
        %find which TDT attenuation setting would solve the problem
        newHB7Gain = 3*ceil(20*(log10(max(signal)/maxVoltage))/3) + HB7Gain;
        hClipWarning = text(TDTcycle/1000/2,0,{['TDT AMPLITUDE > ' num2str(maxVoltage) 'V !!!'],...
                                         ['Set TDT HB7 Gain to ' num2str(newHB7Gain) 'dB and restart the application.']},...
                       'parent',hTimeseries,'FontWeight','bold','color','red','horizontalAlignment','center');
      else
        if ishandle(hClipWarning)
          delete(hClipWarning);
        end
      end
      
      thisSyncTR=round(syncTR+(rand(1)-0.5)*10); %add random value to sync TR
%     thisSyncTR=round(syncTR+rand(1)*1000));          
      if TDT %write second half of signal to buffer (trial i) while the first half is playing
        invoke(RP2,'WriteTagVEX','Signal',nStimTRs*signalSize()/2,'I16',round(signal(:,nStimTRs*signalSize()/2+1:end)/maxVoltage*(2^15-1)));      
        invoke(RP2,'SetTagVal','SynTR',thisSyncTR/sampleDuration);      %set duration of simulated trigger TR in samples (with a  bit of jitter)    
      end
      
      %compute signal for next stimulus/trials (i+1)
      signal = makeSignal(stimulus(currentTrigger*nStimTRs+(1:nStimTRs)),signalSize());

      if TDT %get the sample counter
        bufferCount =  double(invoke(RP2,'GetTagVal','BufIdx'));
      else %if no TDT is running, just get an estimate of sample count based on elapsed time
        elapsedTime = datevec(now-timeTrigger);
        bufferCount = round((elapsedTime(6))*1000/sampleDuration);
      end
      % wait for RP2 to get to middle of buffer 
      while bufferCount<nStimTRs*signalSize()/2 && ~strcmp(lastButtonPressed,'stop run') 
        pause(0.05)                                                           
        % update the cursor position to the estimated elapsed time since the start of the signal
        if ishandle(hCursorT)  
          set(hCursorT,'Xdata',ones(1,2)*bufferCount*sampleDuration/1000+getTagValDelay);    
          set(hCursorF,'Xdata',ones(1,2)*bufferCount*sampleDuration/1000+getTagValDelay);  
        end
        if TDT
          bufferCount = double(invoke(RP2,'GetTagVal','BufIdx'));
        else
          elapsedTime = datevec(now-timeTrigger);
          bufferCount = round((elapsedTime(6))*1000/sampleDuration);
        end
      end

      if strcmp(lastButtonPressed,'stop run') %if stop has been pressed at that point, 
        break                   %break out of the loop
      end

      if TDT % write first half of new stimulus to buffer (cond i+1) while second half is being played
        invoke(RP2,'WriteTagVEX','Signal',0,'I16',round(signal(:,1:nStimTRs*signalSize()/2)/maxVoltage*(2^15-1)));   
      end
 
      % wait for RP2 to receive the next scanner/simulated trigger 
      while nextTrigger<= currentTrigger && ~strcmp(lastButtonPressed,'stop run')
        pause(0.05) % leave a chance to user to press a button
        if currentTrigger>0 & ishandle(hCursorT)  % update the cursor position to the estimated elapsed time since the start of the signal
          elapsedTime = datevec(now-timeTrigger);
          bufferCount = round((elapsedTime(6))*1000/sampleDuration);
          set(hCursorT,'Xdata',ones(1,2)*bufferCount*sampleDuration/1000+getTagValDelay);    
          set(hCursorF,'Xdata',ones(1,2)*bufferCount*sampleDuration/1000+getTagValDelay);    
        end
        if TDT
          nextTrigger=double(invoke(RP2,'GetTagVal','Trigger')); %get the current trial number from TDT (should increase by one each time a trigger is received)
        else %or if there is no TDT running
          if any(datevec(now-timeTrigger)>ceil((minTR+1)/thisSyncTR)*thisSyncTR/1000)    %otherwise, see if enough time has passed
                nextTrigger=currentTrigger+1;
          end
        end
      end                            
      timeTrigger = now;  % get a timestamp (note that there is a ~.5sec delay in getting the value from the RP2)

    end
    
    %erase signal visualisation
    plotSignal(zeros(1,nStimTRs*signalSize()));
    updateTrialInfo([],[],[]);
    if TDT    %stop stimulus presentation 
      invoke(RP2,'SoftTrg',2); %prevents trigger from sending new signal
      invoke(RP2,'WriteTagVEX','Signal',0,'I16',round(zeros(2,signalBufferMaxSize)/maxVoltage*(2^15-1))); %erase all signal in  serial source 
%       invoke(RP2,'WriteTagVEX','Signal',nStimTRs*signalSize()/2,'I16',round(signal(:,nStimTRs*signalSize()/2+1:end)/maxVoltage*(2^15-1))); %write second half of last (empty) stimulus to buffer
%       (this should be enough, but sometimes there's something left form previous runs, not sure why...)
    end
    if strcmp(lastButtonPressed,'stop run')
      for II = 1:3
          beep, pause(0.5)
      end
      displayMessage({'Run terminated by user!';' '});
    else
      displayMessage({sprintf('==> Run %d completed!',currentRun);' '});
    end
    
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% noise synthesizing functions
  
  % ********** makeSignal **********
  function totalSignal = makeSignal(stimulus,totalSamples)
    
    totalSignal = zeros(2,length(stimulus)*totalSamples);
    for iStim = 1:length(stimulus)
      if any(any(diff([size(stimulus(iStim).frequency);size(stimulus(iStim).bandwidth);size(stimulus(iStim).level);size(stimulus(iStim).duration)])))
        error('(makeSignal) Mismatching dimensions in signal parameters')
      end

      %convert durations to samples
      samples = round(stimulus(iStim).duration/sampleDuration);
      if any(sum(samples,2)>totalSamples) %desired signal is larger than totalSamples
        samples(:,end) = samples(:,end) - sum(samples,2) + totalSamples; %reduce the duration of the last stimulus so that it fits
      end
      Gate = round(gateDuration/sampleDuration);
      Gate = Gate + mod(Gate,2); %even number of gate samples 

      signal = zeros(2,totalSamples+Gate);
      currentSample = 0;
      for i = 1:size(stimulus(iStim).frequency,1)
        for j = 1:size(stimulus(iStim).frequency,2)
          if ~isnan(stimulus(iStim).frequency(i,j)) && ~isnan(stimulus(iStim).bandwidth(i,j)) && ~isnan(stimulus(iStim).level(i,j))
            thisSignal = makeNoiseBand(stimulus(iStim).frequency(i,j),stimulus(iStim).bandwidth(i,j),samples(i,j)+Gate);
            thisSignal(1,:) = thisSignal(1,:).*10^((stimulus(iStim).level(i,j)+calibrationGainLeft)/20);  
            thisSignal(2,:) = thisSignal(2,:).*10^((stimulus(iStim).level(i,j)+calibrationGainRight)/20);  
            signal(1,currentSample+(1:samples(i,j)+Gate))= signal(1,currentSample+(1:samples(i,j)+Gate))+lcfGate(thisSignal(1,:),Gate);
            signal(2,currentSample+(1:samples(i,j)+Gate))= signal(2,currentSample+(1:samples(i,j)+Gate))+lcfGate(thisSignal(2,:),Gate);
  %           signal(1,currentSample+(1:samples(i,j)+Gate))= zeros(size(signal(1,currentSample+(1:samples(i,j)+Gate))));
          end
          currentSample = currentSample+samples(i,j);
        end
      end
      signal = signal(:,Gate/2+(1:totalSamples));
      signal = lcfGate(signal,Gate);

      % A sinusoid with a peak amplitude of 1 has an RMS amplitude of 1/sqrt(2) = -3dB less than RMS = 1; 
      % A sinusoid with amplitude 1 in combination with HB7 gain = -27 and NNLGain = 6 creates 65.5 dB SPL -> 
      % correction factor = 65.5 + 27 - 6 = 86.5 ; for noise: correction factor = 89.5    
      
      totalSignal(:,(iStim-1)*totalSamples+(1:totalSamples)) = signal;
    end
  end

  % ***** lcfGate *****
  function stim = lcfGate(stim,Gate)
    env = repmat(cos(pi/2*(0:Gate-1)/(Gate-1)),size(stim,1),1);
    stim(:,1:Gate) = stim(:,1:Gate).*sqrt(1-env.^2);
    stim(:,end-Gate+1:end) = stim(:,end-Gate+1:end).*env;
  end
  
  % ********** makeNoiseBand **********
  function noise = makeNoiseBand(FSig,BW,N)
    
    AMod = AMfrequency/1000; %Amplitude modulation
    if isinf(BW)    %if bandwidth is infinite, make an equally-exciting noise
      noise=lcfMakeNoise(N,sampleDuration,AMod);
    elseif BW==0    %if bandwith=0, make a pure tone
      noise = sin(2*pi*FSig*sampleDuration*(0:N-1));
      if logical(AMod) %apply amplitude modulation
        modenv = sin(2*pi*AMod*sampleDuration*(0:N-1));
        noise = (1+modenv).*noise;    
      end

      noise = repmat(noise/sqrt(mean(noise.^2)),2,1);  %normalize amplitude to rms=1 and duplicate for left and right channels
      if ~strcmp(headphones,'None')  %apply inverse of headphones transfer function
        for i=1:2
%         [~,whichFrequency] = min(abs(transferFunction.frequencies-FSig)); %find closest frequency in transfer function 
%         noise(i,:)=noise(i,:)./10.^(transferFunction.fft(whichFrequency)/20); %and attenuate by corresponding coefficient 
        %use interpolation to find attenuation coefficient at pure tone frequency
            noise(i,:) = noise(i,:)./10.^(interp1(transferFunction(i).frequencies,transferFunction(i).fft,FSig)/20);
        end
      end
      
    else
      evenN = N+mod(N,2); %make N even
      power2N = 2^ceil(log2(evenN)); %find next larger power of 2
      DF = 1/(sampleDuration*power2N);
      F1 = FSig-BW/2;
      F2 = FSig+BW/2;
      bp = zeros(1,power2N/2);

      bp(round(F1/DF):round(F2/DF)) = 1; %create bandpass-filtered noise F1 > F > F2 
      noise = randn(1,power2N);
      noise = real(ifft([bp fliplr(bp)].*fft(noise)));
      if logical(AMod) %apply amplitude modulation
        modenv = sin(2*pi*AMod*sampleDuration*(0:power2N-1));
        noise = (1+modenv).*noise;    
      end
      noise = repmat(noise/sqrt(mean(noise.^2)),2,1);  %normalize amplitude to rms=1 and duplicate for left and right channels

      if ~strcmp(headphones,'None')  %apply inverse of headphones transfer function
        noise = applyInverseTransfer(noise);
      end

      noise = noise(:,(power2N-evenN)/2+(1:N)); %keep central portion
    end
  end
  
  % ********** lcfMakeFNoise **********
  function fNoise = lcfMakeNoise(N,sampleDuration,AMod)
    %synthesizes an equally-exciting noise (which stimulates auditory filters with constant energy at any frequency, that is
    %which compensates for the increasing critical bandwidth of the cochlear filters with increasing frequency)
    power2N = 2^ceil(log2(N)); %find next larger power of 2
    DF = 1/(sampleDuration*power2N);
    frq = DF*(1:power2N/2); %frequency vector at the frequency resolution given by the signal length
    lev = -10*log10(lcfErb(frq)); %at any frequency, the energy is proportional to the critical bandwidth; this is converted to an attenuation in dB
    eeFilter = 10.^(lev/20); %convert to amplification/attenuation coefficient 
    % Note that these two last lines are equivalent to eeFilter = 10.^(log10(lcfErb(frq)*-1/2)=lcfErb(frq).^-1/2 = 1/sqrt(lcfErb(frq))
    % which means that the weighting is inversely proportional to the bandwidth when expressed as energy,
    % or to the square root of the bandwidth when expressed as pressure 

    noise = randn(1,power2N); %create random Gaussian noise in time domain
    fNoise = real(ifft([eeFilter fliplr(eeFilter)].*fft(noise))); %transform noise into frequency domain, apply gain and transform back into time domain
    
    if logical(AMod) %apply amplitude modulation
      modenv = sin(2*pi*AMod*sampleDuration*(0:power2N-1));
      fNoise = (1+modenv).*fNoise;    
    end
    
    fNoise = repmat(fNoise/sqrt(mean(fNoise.^2)),2,1);  %normalize amplitude to rms=1 and duplicate for left and right channels
    
    if ~strcmp(headphones,'None')  %apply inverse of headphones transfer function
      fNoise = applyInverseTransfer(fNoise);
    end
    
    fNoise = fNoise(:,1:N);
  end

  % ***** lcfLEE *****
  function LEE = lcfLEE(N,F,sampleDuration)
    %LEE is the level of an equally exciting stimulus with RMS of 0 dB (rms
    %amplitude equals 1) with an ERB around F
    DF = 1/(sampleDuration*N);
    frq = DF*(1:N/2);

    lev = -10*log10(lcfErb(frq));   %these two lines are equivalent to:
    eeFilter = 10.^(lev/20);        % eeFilter = 1./sqrt(lcfErb(frq))   (see also lcfMakeNoise)

    NF = lcfNErb(F);
    F1 = lcfInvNErb(NF-0.5);
    F2 = lcfInvNErb(NF+0.5);
    bpFilter = zeros(1,N/2);
    bpFilter(round(F1/DF):round(F2/DF)) = 1;

    LEE = 10*log10(sum((eeFilter.*bpFilter).^2)/sum(eeFilter.^2));
  end

  % ********** lcfErb **********
  function erb = lcfErb(f)
    erb = 24.7*(4.37*f+1);
  end

  % ********** lcfNErb **********
  function nerb = lcfNErb(f)
    nerb = 21.4*log10(4.37*f+1);
  end

  % ***** lcfInvNErb *****
  function f = lcfInvNErb(nerb)
    f = 1/4.37*(10^(nerb/21.4)-1);
  end


  % ***** applyInverseTransfer
  function noise = applyInverseTransfer(noise)
%       %first downsample headphones transfer fft coefficients
%       downsampleFactor = round((1/sampleDuration)/length(noise)/transferFunction.freqResolution);
%       insertsFFT = transferFunction.fft(downsampleFactor:downsampleFactor:end);
    %instead of downsampling, interpolate the transfer function at the
    %frequency resolution of the fft for this particular sound (this takes
    %longer than the previous 2 lines but it works for any resolution and
    %doens't require the original transfer function to be oversampled (by an
    %integer factor) relative to the desired fft)
    for i=1:2
      insertsFFT = interp1(transferFunction(i).frequencies,transferFunction(i).fft,(0:length(noise)/2-1)/(sampleDuration*length(noise)),'spline');
      insertsFFT = [insertsFFT insertsFFT(end:-1:1)];
      
%       figure;subplot(3,1,1);plot((0:length(insertsFFT)-1)*transferFunction.freqResolution*downsampleFactor,abs(fft(noise)));
%       subplot(3,1,2);plot((0:length(insertsFFT)-1)*transferFunction.freqResolution*downsampleFactor,insertsFFT);
%       subplot(3,1,3);plot((0:length(insertsFFT)-1)*transferFunction.freqResolution*downsampleFactor,abs(fft(noise)./10.^(insertsFFT/20)));

      noise(i,:) = real(ifft(fft(noise(i,:))./10.^(insertsFFT/20)));
    end
  end
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% RP2-related functions
  
  % ***** testRP2 *****
  function testRP2 = testRP2()
    testRP2 = true;
    Status = uint32(invoke(RP2,'GetStatus'));
    if bitget(Status,1)==0;
        displayMessage({'==> Error connecting to RP2! Check that it is turned on.'})
        testRP2=false;
    elseif bitget(Status,2)==0;
        displayMessage({'==> Error loading circuit!'})
        testRP2=false;
    elseif bitget(Status,3)==0;
        displayMessage({'==> Error running circuit!'})
        testRP2=false;
    end
  end

  % ***** signalSize *****
  function signalSize = signalSize()
    signalSize = round(stimTR/sampleDuration);
    signalSize = signalSize+mod(signalSize,2); %has to be an even number for double buffering method
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Display functions
  
  % ***** plotSignal *****
  function [hCursorT, hCursorF] = plotSignal(signal)
    
    signal = signal(1,:);
    time = sampleDuration*(0:length(signal)-1)/1000;
    hold(hTimeseries,'off');
    plot(hTimeseries,time,signal,'k')
    hold(hTimeseries,'on');
    plot(hTimeseries,[0 TDTcycle/1000],[maxVoltage maxVoltage],'r--');
    plot(hTimeseries,[0 TDTcycle/1000],-1*[maxVoltage maxVoltage],'r--');
    hCursorT = plot(hTimeseries,[0 0],get(hTimeseries,'Ylim'),'r');
    set(hTimeseries,'XLim',[0 TDTcycle/1000])
    set(get(hTimeseries,'XLabel'),'String','Time(s)','FontName','Arial','FontSize',10)
    set(get(hTimeseries,'YLabel'),'String','Amplitude','FontName','Arial','FontSize',10)
    set(hTimeseries,'XLim',[0 TDTcycle/1000]);
    title(hTimeseries,'Cursor position is approximate !');

    [specg,frq,t] = spectrogram(signal,round(100/sampleDuration),round(80/sampleDuration),round(50/sampleDuration),1000/sampleDuration);
    hold(hSpectrogram,'off');
    surf(hSpectrogram,t,frq,10*log10(abs(specg)),'EdgeColor','none');
    hold(hSpectrogram,'on');
    grid(hSpectrogram,'off');
    box(hSpectrogram,'on');
    view(hSpectrogram,0,90); 
    axis(hSpectrogram,'tight'); 
    colormap(hSpectrogram,jet); 
    hCursorF = plot(hSpectrogram,[0 0],get(hSpectrogram,'Ylim'),'k');
    set(hSpectrogram,'XLim',[0 TDTcycle/1000]);
    set(get(hSpectrogram,'XLabel'),'String','Time (s)','FontName','Arial','FontSize',10)
    set(get(hSpectrogram,'YLabel'),'String','Frequency (Hz)','FontName','Arial','FontSize',10)

  end

  % ***** scansToMinutes *****
  function timeString = scansToMinutes(NScans,TR)
    durationSec = NScans * TR / 1000; 
    timeString = sprintf('%g min %g sec', floor(durationSec/60),rem(durationSec,60));
  end

  % ***** updateRunInfo *****
  function updateRunInfo

    if ~isempty(params) && ~isempty(nRepeatsPerRun)
      [~,stimulus]= feval(parameterFunction,params,nRepeatsPerRun,stimTR,TR); %get a set of stimuli for the current parameter values
      strg = get(hNScans,'String'); %display the number of dynamic scans
      % compute and display the run length in TR and minutes (I add one because the there is always an extra TR with no stimulus at the end)
      totalTRs = ceil(length(stimulus)*stimTR/TR)+1;
      set(hNScans,'string',sprintf('%s %g (%s)',strg(1:strfind(strg,':')),totalTRs,scansToMinutes(totalTRs,TR)));
    end
  end

  % ***** updateTrialInfo *****
  function updateTrialInfo(scanNumber,totalScans,conditionNumber,conditionName)

    strg = get(hcurrentTrigger,'String'); Idx = strfind(strg,':');  
    if ~isempty(scanNumber)
      set(hcurrentTrigger,'String',[strg(1:Idx) sprintf(' %d',scanNumber)]);
    else
      set(hcurrentTrigger,'String',strg(1:Idx));
    end  

    strg = get(hCurrentCondition,'String'); Idx = strfind(strg,':');  
    if ~isempty(conditionNumber)
      set(hCurrentCondition,'String',[strg(1:Idx) sprintf('%i = %s', conditionNumber, conditionName)]);
    else
      set(hCurrentCondition,'String',strg(1:Idx));
    end

    strg = get(hRemainingTime,'String'); Idx = strfind(strg,':');     
    if ~isempty(scanNumber)
      set(hRemainingTime,'String',[strg(1:Idx) scansToMinutes(totalScans-(scanNumber-1),TR)]); 
    else
      set(hRemainingTime,'String',strg(1:Idx)); 
    end
  end

  % ***** updateParameters *****
  function updateParameters
    try
      params = feval(parameterFunction);   %get default parameters from function
    catch id
      displayMessage({sprintf('There was an error evaluating function %s:',parameterFunction)})
      disp(id.message)
      return
    end
    displayMessage({sprintf('Selected parameter function %s:',parameterFunction)})
    %populate parameter text/edit controls
    paramNames = fieldnames(params);
    usedAddParams = min(length(paramNames),nAddParam);
    for iParam = 1:nAddParam
      if iParam<=length(paramNames)
        set(hParamNames(iParam),'string',paramNames{iParam},'enable','on')
        set(hParams(iParam),'string',num2str(params.(paramNames{iParam})),'enable','on');
      else
        set(hParamNames(iParam),'string','unused','enable','off')
        set(hParams(iParam),'string','','enable','off');
      end
    end
  end

  % ***** updatelogFile *****
  function updatelogFile(stimulus,scans,timestamp)
    for iStim = 1:length(stimulus)
      dateString=datestr(datenum(datevec(timestamp)+[0 0 0 0 0 (iStim-1)*stimTR/1000]),'MM:SS.FFF');
      totalDuration=0;
      for i=1:size(stimulus(iStim).frequency,2)
        fprintf(logFile,'%d\t%d\t%2.3f\t\t%2.2f\t\t%2.3f\t\t%d\t\t"%s"\t%s\n', ...
          scans(iStim),stimulus(iStim).number,stimulus(iStim).frequency(i),stimulus(iStim).level(i),stimulus(iStim).bandwidth(i),stimulus(iStim).duration(i),stimulus(iStim).name,dateString);
        totalDuration = totalDuration + stimulus(iStim).duration(i);
      end
      if totalDuration<stimTR %add line for silent end of stimulus train
        fprintf(logFile,'%d\t%d\t%2.3f\t\t%2.2f\t\t%2.3f\t\t%d\t\t"%s"\t%s\n', ...
          scans(iStim),stimulus(iStim).number,NaN,NaN,NaN,stimTR-totalDuration,stimulus(iStim).name,dateString);
      end
    end
  end

  % ***** displayMessage ***** 
  function displayMessage(newStrings)

    oldString = cellstr(get(hMessage,'String'));
    if isequal(oldString,{''})
      string=newStrings;
    else
      string = [oldString;newStrings];
    end
    string = string(max(end-messageNLines+1,1):end);
    set(hMessage,'String',string)

  end

end