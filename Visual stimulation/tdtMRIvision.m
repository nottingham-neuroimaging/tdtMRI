% function tdtMRI()
%
%   author: Julien Besle, based on tdtMRI
%     date: 26/04/2021
%  purpose: Visual stimulus presentation for fMRI using PsychToolBox3 and a TDT RM1 real-time processor to get the scanner trigger

function tdtMRIvision

  % ~~~~~~~~~~~~~~~~~ Initialize variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~
  % initialize variables that will be used by nested functions 
  %(shared-scope variables) 

  lGray = 0.775*ones(1,3);
  mGray = 0.65*ones(1,3);
  dGray = 0.5*ones(1,3);
  ScreenPos = get(0,'ScreenSize');
  FontSize = 13;
  messageNLines = 12; %number of lines in the message window

  rand('twister',sum(100*clock));     
%     randn('state',sum(100*clock))
  participant = 'test';
  nAddParam = 8;          %max number of parameters of the parameter function that are editable in the GUI
  usedAddParams = 0;      %number of parameters that are actually editable (could be less than nAddParam)
  pathString = fileparts(which(mfilename));   %path to the function
  if isempty(pathString)
    fprintf('Function %s must be on your path or in the current folder\n',mfilename);
    return;
  end

  tdtOptions = {'RM1','None'};  %If you change the order of these options, changes are needed in code below
  if strcmp(getenv('COMPUTERNAME'),'DESKTOP-S355HDV')
      TDT = tdtOptions{2}; %set to None or Soundcard to debug without switching the TDT on
  else
      TDT = tdtOptions{1};
  end
  displayStim = false;
  if strcmp(getenv('COMPUTERNAME'),'DESKTOP-S355HDV')
      flipStim = 0;
  else
      flipStim = 1;
  end

  sampleDuration = 1/24.4140625;  %the duration of a TDT sample in milliseconds
  TR = 1.8;          % the expected delay between image acquisitions (scanner pulses) in seconds

  simulatedTriggerToggle=0; %state of the simulated trigger switch
  syncTR = 1.8;            % delay between simulated scanner pulses
  currentRun=0;    
  completedRuns=0;          %to keep track of completed runs

  params = [];              %structure that will contain the numerical parameters to the parameter function
  paramNames = [];          %names of these parameters
  lastButtonPressed = 'none';   %state of the start/stop run buttons
  experimentFunction = '';       %fid of the parameter function
  logFile=1;                    %fid of the log file
  RM1=[];          % activeX object for circuit control
  HActX = [];      % handle to the activeX figure (invisible)
  circuitRunning=false;   
  
  startPTBwithCircuit = true; % if true, PTB starts when starting the TDT circuit and different runs use the same PTB screen
  screenNumber = [];
  window = []; % Window pointer for PTB3
  white = 1;
  grey = 0.5;
%   ifi = []; % interframe interval
  triggerTolerance = [];
  screenSizePixels = []; % screen size in pixels [left top right bottom]
  debugScreenWidth = 0.6; % width of debug screen as a proportion of the monitor's screen
  
  monitors = {'AUB thinkvision (57 cm)', 'AUBMC Philips 3T scanner'};
  if strcmp(getenv('COMPUTERNAME'),'DESKTOP-S355HDV')
    monitor = monitors{1};
  else
    monitor = monitors{2};
  end
  
  screenWidthMm = []; % screen width in millimeters
  screenHeightMm = []; % screen height in millimeters
  screenDistanceCm = []; % screen distance in centimeters

  showFixation = false;
  fixCrossLengthDeg = 1;
  fixationWidthDeg = 0.1;

  
  % ~~~~~~~~~~~~~~~~~~~~ GUI ~~~~~~~~~~~~~~~~~~~~
  mainBottomGap=40;
  mainRightGap=4;
  mainMaxWidth=1000;
  mainMaxHeight=700;
  hMainFigure = figure('Color',lGray,...
      'Menubar','none',...
      'Name','tdtMRIvision',...
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
  editHeight = 0.032;
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
  uicontrol('Parent',hMainFigure,...                       % TR (expected time between received scanner pulses
      'BackgroundColor',mGray,...                          % this is also the duration of the synthesized sound sequence)
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','TR (sec):');
  hTR = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'TR'},...
      'Position',[XPos+Width+XGap YPos Width editHeight],...
      'String',num2str(TR),...
      'Style','edit');

  YPos = YPos-(editHeight+YGap);
  uicontrol('Parent',hMainFigure,...                      %Condition parameter file
      'BackgroundColor',mGray,...
      'Position',[XPos YPos Width editHeight],...
      'Style','text',...
      'String','Experiment Function:');
  
  %get a list of available parameter functions
  %all parameterFunctions should be saved as M files in a 'parameters' folder
  %located in same folder as tdtMRI.m
  parameterFunctions =  dir([pathString '/experiments/' '*.m']); %get the list of m files in that folder
  if ~isempty(parameterFunctions)
    parameterFunctionsList = cell(1,length(parameterFunctions));
    for iFile=1:length(parameterFunctions)
       parameterFunctionsList{iFile} = strtok(parameterFunctions(iFile).name,'.'); %remove extension 
       %(assumes there is no dot in the file name itself)
    end
    hExpFunction = uicontrol('Parent',hMainFigure, ... %create a popup menu to select the parameter function
        'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'expFunction'},...
        'Position',[XPos+Width+XGap YPos Width editHeight],...
        'String',parameterFunctionsList,...
        'Style','popup');
  else %in case no parameter function is found (unlikely), replace the popup menu by an edit box and a browser
    hExpFunction = uicontrol('Parent',hMainFigure, ...
        'BackgroundColor',[1 1 1],...
      'Callback',{@mainCallback,'expFunction'},...
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
      'Callback',{@mainCallback,'Experiment',iParam},...
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
  hCurrentTrigger = uicontrol('Parent',hMainFigure,...        %Current trial
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
      'String','Time remaining till end of run: ');

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

%%%%%%%%%%%%%%%%% Sequence and stimuli display Windows
  windowWidth = 0.4;
  windowHeight = 0.5;
  YGap = 0.07;
  XPos = 0.075;
  YPos = 0.27;
  hStimulus = axes('Parent',gcf,...
     'Units','normalized',...
     'Position',[XPos YPos windowWidth windowHeight],...
     'FontName','Arial',...
     'FontSize',10,...
     'Box','on');
  set(hStimulus,'Color','none','XColor', 'none','YColor','none')
  
  hSequence = axes('Parent',gcf,...
     'Units','normalized',...
     'Position',[XPos YPos+windowHeight+YGap windowWidth 1-windowHeight-2*YGap-YPos],...
     'FontName','Arial',...
     'FontSize',10,...
     'Box','on');
  set(hSequence,'Color','none','YColor','none')

  XGap = 0.025;
  YGap = 0.0075;
  XPos = 0.05;
  
  YPos = 0.2;
  uicontrol('Parent',hMainFigure,...    %Stimulus display checkbox
    'Callback',{@mainCallback,'displayStims'},...
    'BackgroundColor',lGray,...
    'Position',[XPos YPos Width*2/3 buttonHeight], ...
    'Style','checkbox',...
    'String','Display stimuli', ...
    'value',displayStim);
 
  uicontrol('Parent',hMainFigure,...    %Stimulus display checkbox
    'Callback',{@mainCallback,'flipStims'},...
    'BackgroundColor',lGray,...
    'Position',[XPos+Width*2/3+XGap YPos Width*2/3 buttonHeight], ...
    'Style','checkbox',...
    'String','Flip stimuli', ...
    'value',flipStim);
 
  uicontrol('Parent',hMainFigure,...    %Stimulus display checkbox
    'Callback',{@mainCallback,'showFixation'},...
    'BackgroundColor',lGray,...
    'Position',[XPos+Width*4/3+2*XGap YPos Width*2/3 buttonHeight], ...
    'Style','checkbox',...
    'String','Show fixation', ...
    'value',showFixation);
 
  YPos = 0.14;
  hTDT = uicontrol('Parent',hMainFigure,...    %TDT dropdown menu
    'Callback',{@mainCallback,'TDT'},...
    'Position',[XPos YPos Width/3 buttonHeight], ...
    'Style','popupmenu',...
    'String',tdtOptions, ...
    'value',find(ismember(tdtOptions,TDT)));

  hMonitor = uicontrol('Parent',hMainFigure,...    %Monitor dropdown menu
    'Callback',{@mainCallback,'Monitor'},...
    'Position',[XPos+Width/3+XGap/2 YPos Width*2/3 buttonHeight], ...
    'Style','popupmenu',...
    'String',monitors, ...
    'value',find(ismember(monitors,monitor)));

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
    'String',sprintf('Simulated Trigger (%.2f s)',syncTR), ...
    'Tag','SynTrig');
  hSyncTR = uicontrol('Parent',hMainFigure, ...
      'BackgroundColor',[1 1 1],...
    'Callback',{@mainCallback,'SyncTR'},...
      'Position',[XPos+Width*5/3+XGap*3/2 YPos Width/3-XGap/2 buttonHeight],...
      'String',num2str(syncTR),...
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
  mainCallback(hExpFunction,[],'expFunction'); %choses the first parameter function in the list and populate the additional parameter
  mainCallback(hTR,[],'TR'); %read the default TR value and update run information
  mainCallback(hTDT,[],'TDT'); %read the default TDT value to set trigger tolerance
  mainCallback(hMonitor,[],'Monitor'); %read the default Monitor value to set trigger tolerance

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Callback function
  % each case corresponds to control in the GUI
  function mainCallback(handleCaller,~,item,option)

    switch(item)

      case('Participant')
        participant = upper(get(handleCaller,'String')); %capitalize participant initials
        set(hParticipant,'String',participant)
        
      % user chooses an experiment function
      case('expFunction')   
        switch(get(handleCaller,'style'))
          case 'popupmenu'
            functionList = get(handleCaller,'string');
            experimentFunction = functionList{get(handleCaller,'value')}; %get the selected parameter function name
          case 'edit'
            experimentFunction = get(hExpFunction,'String');
        end
        if ~isempty(experimentFunction)
          updateExperimentControls  %populate parameter edit controls
          updateRunInfo     %update the run duration according to the new number of stimuli
        end
        
      %in case no parameter function is found, user selects the parameter function file in a browser  
      case('Browse')
        experimentFunction = uigetfile('*.m','Parameter function');
        if ~isnumeric(experimentFunction)
          [~, experimentFunction]=fileparts(experimentFunction); %remove extension ?
          set(hExpFunction,'String',experimentFunction); %put the function name in the edit window
          updateExperimentControls  %populate parameter edit controls
          updateRunInfo     %update the run duration according to the new number of stimuli
        end   

      case('TR')
        TR = eval(get(handleCaller,'String'));
        updateRunInfo   %update the run duration according to the new TR value
        
      case 'Experiment'
        params.(paramNames{option})=  eval(['[' str2mat(get(handleCaller,'String')) ']']);
        refreshParameters
        updateRunInfo   %update the run duration according to the new parameters
      
      case('displayStims')
        displayStim=get(handleCaller,'Value');
        
      case('flipStims')
        flipStim=get(handleCaller,'Value');
        
      case('showFixation')
        showFixation=get(handleCaller,'Value');
        
      case('TDT')
        TDT=tdtOptions{get(handleCaller,'Value')};
        switch(TDT)
          case tdtOptions{1}
            triggerTolerance = 0.020;
          case tdtOptions{2}
            triggerTolerance = .1;
        end
        
      case('Monitor')
        monitor=monitors{get(handleCaller,'Value')};
        switch(monitor)
          case 'AUB thinkvision (57 cm)'
            screenWidthMm = 375; % screen width in millimeters (AUB ThinkVision test monitor)
            screenHeightMm = 300; % screen height in millimeters (AUB ThinkVision test monitor)
            screenDistanceCm = 57; % screen distance in centimeters (at 57 cm, 1 deg = 1 cm)
          case 'AUBMC Philips 3T scanner'
            screenWidthMm = 650; % AUBMC Philips 3T MRI screen width in millimeters
            screenHeightMm = 390; % AUBMC Philips 3T MRI screen height in millimeters
            screenDistanceCm = 139; % AUBMC Philips 3T MRI screen distance in centimeters 
        end
        
      case 'SynTrig' %user presses the simulated trigger button (this is only possible during a run)
        %the button has two states (3 = pushed, 4 = released)
        if exist('option','var') && ~isempty(option)
          %if callback called with option =3 or 4, set the button to the required state
          simulatedTriggerToggle=option;
        else
          %otherwise toggle between the two states 
          simulatedTriggerToggle = 4-mod(simulatedTriggerToggle+1,2);
        end
        if ismember(TDT,tdtOptions(1)) %switch simulated trigger according to state (3=on, 4=off)
          invoke(RM1,'SoftTrg',simulatedTriggerToggle); 
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
        syncTR = eval(get(handleCaller,'String'));
        
      case('StartCircuit')    

        if startPTBwithCircuit
          displayMessage({'Starting Psychtoolbox'});
          success = initializePTB();
        else
          success = true;
        end
        
        if success
          if ismember(TDT,tdtOptions(1))
            displayMessage({'Creating TDT ActiveX interface...'})
            HActX = figure('position',[0.2*ScreenPos(3)/100 (75+2.25)*ScreenPos(4)/100 (100-0.4)*ScreenPos(3)/100 (25-4.3)*ScreenPos(4)/100],...
                'menubar','none',...
                'numbertitle','off',...
                'name','TDT ActiveX Interface',...
                'visible','off');
            pos = get(HActX,'Position');

            RM1 = actxcontrol('RPco.x',pos,HActX);  %create an activeX control for TDT RM1
            switch(TDT)
              case tdtOptions{1} % RM1
                invoke(RM1,'ConnectRM1','USB',1); %connect to the RM1 via the USB port
                circuitFilename = [pathString '\tdtMRIvision_RM1.rcx'];
            end
            invoke(RM1,'ClearCOF');
            if ~exist(circuitFilename,'file') %check that the circuit object file exists
                displayMessage({sprintf('==> Cannot find circuit %s',circuitFilename)});
                return
            end
            invoke(RM1,'LoadCOF',circuitFilename);  %load the circuit
            invoke(RM1,'Run');  %start the circuit
            if ~testRM1() %test if the circuit is running properly
              delete(HActX) %if not, delete the activeX figure
              return
            else
              displayMessage({'TDT circuit loaded and running!'})
            end

          else
            displayMessage({'Not using TDT'});
          end

          displayMessage({''})
          circuitRunning = true; %to check if the circuit is supposed to be running from outside this function
          set(hStartCircuit,'Enable','off')
          set(hStartRun,'Enable','on')
          set(hStopCircuit,'Enable','on')
          set(hTDT,'Enable','off')
          set(hMonitor,'Enable','off')
          displayMessage({'Proceed by pressing <Start run> ...'});
        end        

      case('StopCircuit')
        if ismember(TDT,tdtOptions(1)) && circuitRunning
          displayMessage({'Stopping TDT circuit, please wait'});
          invoke(RM1,'Halt');
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
        set(hTDT,'Enable','on')
        set(hMonitor,'Enable','on')
        if exist('hMessage','var')
            displayMessage({'Circuit stopped';''});
        end
        circuitRunning = false;
        
        if startPTBwithCircuit
          try
            sca; %close PTB3 window
          end
          figure(hMainFigure)% bring GUI back on top
        end
          
        
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
        if isempty(TR)
            displayMessage({'==> WARNING: TR not specified!'})
            abort=true;
        end
        if abort
          return
        end
        
        % check that there is a PTB window
        if ~Screen(window, 'WindowKind')
          displayMessage({'Restarting Psychtoolbox'});
          initializePTB();
        end
        
        % check that the circuit is running (in case TDT has been turned off)
        if ismember(TDT,tdtOptions(1)) 
          if ~testRM1()
            mainCallback(handleCaller,[],'StopCircuit');
            return
          end
          if ismember(TDT,tdtOptions(1))
            invoke(RM1,'SetTagVal','SynTR',syncTR/sampleDuration*1000);      %set duration of simulated trigger TR in samples (with a  bit of jitter)    
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
        set(hParticipant,'Enable','off')
        set(hSyncTR,'Enable','off')
        set(hExpFunction,'Enable','off')
        set(hTR,'Enable','off')
%         set(hStimTR,'Enable','off')
        set(hParams(1:usedAddParams),'Enable','off')
        %enable simulated trigger and stop run buttons
        set(hStopRun,'Enable','on')
        set(hSimulatedTrigger,'Enable','on')
        
        %write log file header
        refreshParameters;
        logFile = fopen(sprintf('%s\\%s_%s_%s%02d.txt',pwd,participant,datestr(now,'yyyy-mm-dd_HH-MM-SS'),experimentFunction,currentRun),'wt');
        fprintf(logFile, 'Current date and time: \t %s \n',datestr(now));
        fprintf(logFile, 'Subject: \t \t %s \n', participant);
        fprintf(logFile, 'Experiment function: \t %s \n', experimentFunction);
        maxParamNameLength = 0; for iParams = 1:length(paramNames),maxParamNameLength=max(maxParamNameLength,length(paramNames{iParams}));end
        for iParams = 1:length(paramNames)
          fprintf(logFile, '  %s = %s%s \n',paramNames{iParams},repmat(' ',1,maxParamNameLength-length(paramNames{iParams})),num2str(params.(paramNames{iParams})));
        end
        fprintf(logFile, '\nDynamic scan duration (s): \t %.3f \n', TR);
        fprintf(logFile, '----------------------\n');
        fprintf(logFile, 'scan\tcondition #\tcondition\tstimulus\tduration (s)\tapproximate onset time (MM:SS.FFF)\n');

        try
          lcfOneRun() %% run the stimulation
        catch id
          displayMessage({'There was an error running the experiment'})
          disp(getReport(id));
          if startPTBwithCircuit
            % Clear the screen.
            Screen('FillRect', window, grey);
            Screen('Flip', window);
          else
            sca
          end
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
        cla(hSequence);
        cla(hStimulus)
        strg = get(hCurrentRun,'String'); Idx = strfind(strg,':');
        set(hCurrentRun,'String',[strg(1:Idx) sprintf(' not running (%g completed)', completedRuns)])
        
        %disable simulated trigger and stop run buttons
        set(hStopRun,'Enable','off')
        set(hSimulatedTrigger,'Enable','off')
        %enable buttons/edit boxes
        set(hParticipant,'Enable','on')
        set(hExpFunction,'Enable','on')
        set(hTR,'Enable','on')
%         set(hStimTR,'Enable','on')
        set(hParams(1:usedAddParams),'Enable','on')
        set(hStartRun,'Enable','on')
        set(hStopCircuit,'Enable','on')
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
  function lcfOneRun

    if ~startPTBwithCircuit
      displayMessage({'Starting Psychtoolbox'});
      success = initializePTB();
    else
      success = true;
    end
    
    if success
      % Compute stimulus parameters and load images for this run
      [nScans,stimulus,images] = getStimulusSequence();
      nStims = length(stimulus);
      
      % display current stimulus in tdtMRI window
      hCursorT = plotSequence(stimulus);  %show timeline of the differnet blocks

      stimulus(nStims+1).onset = stimulus(nStims).onset + stimulus(nStims).duration; % add an extra stimulus to simplify the stimulus while loop

      if ismember(TDT,tdtOptions(1))
        invoke(RM1,'SetTagVal','NTrials',nStims+1);     %set this to something larger than the number of dynamic scans
        invoke(RM1,'SoftTrg',1);                                  %start run
      end

      Screen('TextSize',window, deg2pixels(1));
      DrawFormattedText(window,fixationInstructions(),'center','center',WhiteIndex(screenNumber),40,false,flipStim);
      if showFixation
        drawFixation(white);
      end
      Screen('Flip', window);

      prepareNextStim(stimulus(1),images); % Prepare first stimulus

      displayMessage({'Waiting for trigger...'});
      if strcmp(TDT,tdtOptions(2))
        displayMessage({'(Trigger = Alt key)'});
      end

      % wait for RM1 to receive the scanner/simulated trigger (i.e. start the stimulus + increase trial counter by one)
      currentTrigger = 0;
      nextTrigger = 0;
      while nextTrigger <= currentTrigger && ~strcmp(lastButtonPressed,'stop run')
        pause(0.01); % leave a chance to user to press a button in the GUI
        switch(TDT)
          case tdtOptions(1)
            nextTrigger = double(invoke(RM1,'GetTagVal','Trigger')); %get the current trial number from TDT (should increase by one each time a trigger is received)
            timeStart = GetSecs;
          case tdtOptions(2) %if no TDT RM1 is running, check the keyboard
            [keyIsDown,timeStart] = KbCheck;
            if keyIsDown
              nextTrigger = currentTrigger + 1;
              WaitSecs(0.15); % wait a bit so that the keyboard press is not caught by the next kbCheck in the main loop
            end
        end
      end
      currentTrigger = nextTrigger;
      if ~strcmp(lastButtonPressed,'stop run')
        displayMessage({'Received trigger'});
      end

      %Main loop
      currentStim = 0;
      while currentTrigger <= nScans && currentStim <= nStims && ~strcmp(lastButtonPressed,'stop run')

        %--------- Things that are done only for each new stimulus
        if (GetSecs - timeStart) > stimulus(currentStim+1).onset % one frame before the onset of the next stimulus
          % Flip screen for new current stimulus and get new timestamp
          timeStim = Screen('Flip', window);
          currentStim = currentStim + 1;
          if displayStim
            if stimulus(currentStim).imageNum
              imshow(images{stimulus(currentStim).imageNum},[0 255],'Parent',hStimulus);
            else
              cla(hStimulus);
            end
          end
          if currentStim <= nStims
            %print stimulus to log file
            updatelogFile(stimulus(currentStim),currentTrigger,timeStim-timeStart);
            %update current condition information
            updateTrialInfo(currentTrigger,nScans,stimulus(currentStim).condition,stimulus(currentStim).conditionName);
          end
          if currentStim < nStims % if this is not the last stimulus
            prepareNextStim(stimulus(currentStim+1),images); % prepare next stimulus (currentStim+1)
          end
        end

        %--------- Things that are done on every iteration of the while loop

        if displayStim
          % update the cursor position to the estimated elapsed time since the start of the signal
          if ishandle(hCursorT)  % this tends to mess up the timing a bit
            set(hCursorT,'Xdata',ones(1,2)*(GetSecs-timeStart));
          end
        end

        % check the trigger number
        if ismember(TDT,tdtOptions(1)) && currentTrigger<nScans
          nextTrigger=double(invoke(RM1,'GetTagVal','Trigger')); % get the current trial number from TDT (should increase by one each time a trigger is received)
          actualTriggerTime = GetSecs; % this should be delayed by the same .5s (?) delay when using the TDT
        else %or if there is no TDT running (or it is the last scan), see if the keyboard has been pressed
          [keyIsDown,actualTriggerTime,keyCode] = KbCheck;
          if keyIsDown
            if ismember(18,(find(keyCode))) %18 = alt key = trigger
              nextTrigger=currentTrigger + 1;
            elseif ismember(16,(find(keyCode))) %16 = shift = response (only when not using TDT since response button doesn't work at AUB scanner)
              %print stimulus to log file
              updatelogFile(stimulus(currentStim),currentTrigger,actualTriggerTime-timeStart,'Response', actualTriggerTime - timeStim);
            end
          end
          WaitSecs(0.15); % wait a bit so that the keyboard press is not caught by several successive iterations of the loop
        end

        % if we got the trigger for the next stimulus, check that it's at the predicted time
        if nextTrigger==currentTrigger+1
          actualTriggerTime = actualTriggerTime-timeStart; % this should be delayed by the same .5s (?) delay when using the TDT
          expectedTriggerTime = (nextTrigger-1)*TR; % relative to the time of the first trigger
          currentTrigger = nextTrigger;
          if actualTriggerTime <  expectedTriggerTime - triggerTolerance % stimulus was presented too early
            beep;
            displayMessage({sprintf('Trigger is early!! %f < %f',actualTriggerTime,expectedTriggerTime)});
          elseif actualTriggerTime > expectedTriggerTime + triggerTolerance % stimulus is presented too late
            beep;
            displayMessage({sprintf('Trigger is late!! %f > %f)',actualTriggerTime,expectedTriggerTime)});
          elseif ismember(TDT,tdtOptions(2))
            displayMessage({sprintf('Spot on!! %f ~= %f)',actualTriggerTime,expectedTriggerTime)});
          end
          %update current condition information
          updateTrialInfo(currentTrigger,nScans,stimulus(currentStim).condition,stimulus(currentStim).conditionName);
        end

        if strcmp(lastButtonPressed,'stop run') %if stop has been pressed at that point, 
          break                   %break out of the loop
        end

      end

      if startPTBwithCircuit
        % Clear the screen.
        Screen('FillRect', window, grey);
        Screen('Flip', window);
      else
        sca
        % bring GUI back on top after setting up PTB
        figure(hMainFigure)
      end

      updateTrialInfo([],[],[]);
      if ismember(TDT,tdtOptions(1))    %stop stimulus presentation
        invoke(RM1,'SoftTrg',2); %prevents trigger from sending new signal
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
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% RM1-related functions
  
  % ***** testRM1 *****
  function testRM1 = testRM1()
    testRM1 = true;
    Status = uint32(invoke(RM1,'GetStatus'));
    if bitget(Status,1)==0
        displayMessage({'==> Error connecting to RM1! Check that it is turned on.'})
        testRM1=false;
    elseif bitget(Status,2)==0
        displayMessage({'==> Error loading circuit!'})
        testRM1=false;
    elseif bitget(Status,3)==0
        displayMessage({'==> Error running circuit!'})
        testRM1=false;
    end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Display functions
  
  % ***** plotSequence *****
  function hCursorT = plotSequence(stimulus)
    
    % find blocks for the different conditions
    cBlock = 1;
    blockCondition = 0;
    blockEnd = 0; % end time of each block
    for iStim = 1:length(stimulus)
      if stimulus(iStim).condition == blockCondition(cBlock)
        blockEnd(cBlock) = blockEnd(cBlock) + stimulus(iStim).duration;
      else
        cBlock = cBlock + 1;
        blockCondition(cBlock) = stimulus(iStim).condition;
        blockEnd(cBlock) = blockEnd(cBlock-1) + stimulus(iStim).duration;
        if stimulus(iStim).condition
          blockNames{stimulus(iStim).condition} = stimulus(iStim).conditionName;
        end
      end
    end
    
    hold(hSequence,'on');
    for iBlock = 1:length(blockCondition)
      if blockCondition(iBlock)
        hBlock(blockCondition(iBlock)) = patch([blockEnd(iBlock-1) blockEnd(iBlock-1) blockEnd(iBlock) blockEnd(iBlock)],[0 1 1 0],blockCondition(iBlock));
      end
    end
    hCursorT = plot(hSequence,[0 0],[0 1],'r');
%     set(hTimeseries,'YLim',[0 1])
    set(get(hSequence,'XLabel'),'String','Time(s)','FontName','Arial','FontSize',10)
    set(get(hSequence,'YLabel'),'String','','FontName','Arial','FontSize',10)
    legend(hBlock,blockNames,'Location','eastoutside');
  end

  % ***** scansToMinutes *****
  function timeString = scansToMinutes(NScans,TR)
    durationSec = NScans * TR; 
    timeString = sprintf('%g min %g sec', floor(durationSec/60),rem(durationSec,60));
  end

  % ***** updateRunInfo *****
  function updateRunInfo

    if ~isempty(params)
      totalTRs = getStimulusSequence();
      % compute and display the run length in TR and minutes
      strg = get(hNScans,'String'); %display the number of dynamic scans
      set(hNScans,'string',sprintf('%s %g (%s)',strg(1:strfind(strg,':')),totalTRs,scansToMinutes(totalTRs,TR)));
    end
  end

  % ***** getStimulusSequence *****
  function [totalTRs, stimulus, images] = getStimulusSequence()

    [~,stimulus]= feval(experimentFunction,params,TR); %get a set of stimuli for the current parameter values
    
    if nargout==3 % loading and returning images
      imageNames = {};
      displayMessage({'Pre-loading stimulus files...'})
    end
    
    % add cumulated onset field to each stimulus
    onset = 0;
    for iStim = 1:length(stimulus)
      stimulus(iStim).onset = onset;
      onset = onset + stimulus(iStim).duration;
      if nargout==3 % if asking for the images, pre-load them
        if strcmp(stimulus(iStim).filename,'None')
          stimulus(iStim).imageNum = 0;
        else
          thisImageName = stimulus(iStim).filename;
          if stimulus(iStim).scramble
            thisImageName = [thisImageName '_S'];
          end
          [~,whichImage] = ismember(thisImageName,imageNames);
          if ~whichImage
            imageNames{end+1} = thisImageName;
            whichImage = length(imageNames);
          end
          images{whichImage} = imread(fullfile(pathString,'stimuli',[stimulus(iStim).filename '.jpeg']));
          if size(images{whichImage},3)>1
            images{whichImage} = images{whichImage}(:,:,1); % flatten RGB to grey scale
          end
          if stimulus(iStim).scramble % scramble phase
            images{whichImage} = scramblePhase(images{whichImage},[0 255]);
          end
          if stimulus(iStim).gaussianWidth % apply gaussian window (using background value for 0)
            imageDims = size(images{whichImage});
            imageCenter = ceil(imageDims/2);
            sigma = ceil(stimulus(iStim).gaussianWidth/stimulus(iStim).widthDeg*imageDims(2));
            [X,Y] = meshgrid(1:imageDims(1),1:imageDims(2));
            gaussian = exp(-((X-imageCenter(1)).^2/(2*sigma^2)+(Y-imageCenter(2)).^2/(2*sigma^2))); % 2D Gaussian function in XY plane
            
            images{whichImage} = uint8((double(images{whichImage}) - 127).*gaussian + 127); % assumes the range is 0-255 (i.e. using Screen rather than PsychImaging)
          end
          stimulus(iStim).imageNum = whichImage; % image index in images array
          
        end
          
      end
    end
    totalTRs = ceil(onset/TR);
    
  end

  % ***** updateTrialInfo *****
  function updateTrialInfo(scanNumber,totalScans,conditionNumber,conditionName)

    strg = get(hCurrentTrigger,'String'); Idx = strfind(strg,':');
    if ~isempty(scanNumber)
      set(hCurrentTrigger,'String',[strg(1:Idx) sprintf(' %d / %d',scanNumber,totalScans)]);
    else
      set(hCurrentTrigger,'String',strg(1:Idx));
    end  

    strg = get(hCurrentCondition,'String'); Idx = strfind(strg,':');  
    if ~isempty(conditionNumber)
      set(hCurrentCondition,'String',[strg(1:Idx) sprintf(' %i = %s', conditionNumber, conditionName)]);
    else
      set(hCurrentCondition,'String',strg(1:Idx));
    end

    strg = get(hRemainingTime,'String'); Idx = strfind(strg,':');     
    if ~isempty(scanNumber)
      set(hRemainingTime,'String',[strg(1:Idx) scansToMinutes(totalScans-(scanNumber-1),TR)]); 
    else
      set(hRemainingTime,'String',strg(1:Idx)); 
    end
    
    drawnow; % this is necessary when concurrently using PTB3 to display stimuli (otherwise GUI only gets updated when a key is pressed or PTB3 closes)
  end

  % ***** refreshParameters *****
  function refreshParameters
    %keep only the first nAddParams fields (the others will take the
    %default value from the parameter function)
    newParams = feval(experimentFunction,[],TR);
    fieldNames = fieldnames(newParams);
    for iParams = 1:min(nAddParam,length(fieldNames))
      newParams.(fieldNames{iParams}) = params.(fieldNames{iParams});
    end
    params=newParams;
  end

  % ***** updateExperimentControls *****
  function updateExperimentControls
    try
      params = feval(experimentFunction,[],TR);   %get default parameters from function
    catch id
      displayMessage({sprintf('There was an error evaluating function %s:',experimentFunction)})
      disp(id.message)
      return
    end
    displayMessage({sprintf('Selected parameter function: %s',experimentFunction)})
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
  function updatelogFile(stimulus,currentTrigger,timestamp, whichKey, TR)
    
    if nargin == 5 % this is a button press
      stimulus.filename = whichKey;
      stimulus.duration = TR;
    end
    fprintf(logFile,'%d\t%d\t%s\t%s\t%2.3f\t%02d:%06.3f\n', ...
      currentTrigger,stimulus.condition,stimulus.conditionName,stimulus.filename,stimulus.duration,floor(timestamp/60),rem(timestamp,60));

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
    
    drawnow; % this is necessary when concurrently using PTB3 to display stimuli (otherwise GUI only gets updated when a key is pressed or PTB3 closes)

  end

  function success = initializePTB
    
    success = true;
    try
      PsychDefaultSetup(1); % default settings
%       PsychImaging('PrepareConfiguration');
    catch
      success = false;
      displayMessage({'Could not initialize PsychToolbox, make sure it is installed'});
      return;
    end
%     PsychImaging('AddTask', 'General', 'FlipHorizontal'); % this doesn't work, so flipping is done in function prepareNextStim
    Screen('Preference', 'SkipSyncTests', 1);
    screenNumber = max(Screen('Screens')); % Screen number of external display
    if screenNumber < 2
      displayMessage({'No external monitor detected: running in debug mode'});
    end
    white = WhiteIndex(screenNumber);
    % Open an on screen window and color it grey.
    grey = white * 0.5;
    if screenNumber < 2 % if drawing on main screen, open a sub-window
      [window, screenSizePixels] = Screen('OpenWindow', screenNumber, grey,round(debugScreenWidth*Screen('Rect',screenNumber)));
    else % otherwise open a full-screen window
      [window, screenSizePixels] = Screen('OpenWindow', screenNumber, grey);% Open an on screen window using Screen and color it grey.
    end
%     [window, screenSizePixels] = PsychImaging('OpenWindow', screenNumber, grey);% using PsychImaging instead of Screen
%     ifi = Screen('GetFlipInterval', window);% Measure the vertical refresh rate of the monitor
%     [screenWidthMm,screenHeightMm] = Screen('DisplaySize',screenNumber); % this returns incorrect values
    Priority(MaxPriority(window));% Retrieve the maximum priority number and set max priority
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); % Set up alpha-blending for smooth (anti-aliased) lines
    % bring GUI back on top after setting up PTB
    figure(hMainFigure)
    
  end

  function prepareNextStim(stimulus, images)
          
    Screen('FillRect', window, grey);
    if ~strcmp(stimulus.filename,'None')
      % calculate stimulus position in pixelx from intended size and centre in degrees of visual angle
      stimWitdhPixels = deg2pixels(stimulus.widthDeg); % Convert stimulus width to pixels
      stimHeightPixels = stimWitdhPixels / size(images{stimulus.imageNum},2) * size(images{stimulus.imageNum},1);
      stimCentrePixels = deg2pixels(stimulus.centreDeg); % Convert stimulus coords to pixels (relative to center of screen)
      stimPosition = round([screenSizePixels(3)/2 + stimCentrePixels(1) - stimWitdhPixels/2, ...
                            screenSizePixels(4)/2 + stimCentrePixels(2) - stimHeightPixels/2, ...
                            screenSizePixels(3)/2 + stimCentrePixels(1) + stimWitdhPixels/2, ...
                            screenSizePixels(4)/2 + stimCentrePixels(2) + stimHeightPixels/2]);
      % display stimulus
      if flipStim
        thisImage = flipud(images{stimulus.imageNum});
      else
        thisImage = images{stimulus.imageNum};
      end
      stimtexture = Screen('MakeTexture', window, thisImage);
      Screen('DrawTexture', window, stimtexture, [], stimPosition);
    end
    
    if showFixation || stimulus.condition == 0
      if strcmp(stimulus.conditionName,'Interval')
        fixationColor = white*0.25;
      else
        fixationColor = 0;
      end
      drawFixation(fixationColor);
    end
    
  end

  function drawFixation(color)
    
    % Draw the fixation cross in white, set it to the center of our screen and set good quality antialiasing
    [xCenter, yCenter] = RectCenter(screenSizePixels);
    fixationCoordsPix = deg2pixels([-fixCrossLengthDeg fixCrossLengthDeg 0 0; ...
                                        0 0 -fixCrossLengthDeg fixCrossLengthDeg])/2;
    Screen('DrawLines', window, fixationCoordsPix, deg2pixels(fixationWidthDeg), color, [xCenter yCenter], 2);
   
  end

  function pixels = deg2pixels(degrees)
    
    pixels = ceil(tan(deg2rad(degrees))*screenDistanceCm*10/screenWidthMm*screenSizePixels(3));
    
  end

end