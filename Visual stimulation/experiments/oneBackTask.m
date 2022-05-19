function [params,stimulus] = oneBackTask(params,TR)

% stimulus = struct array with fields:    
    %condition (integer, 0 = baseline)
    %conditionName (string)
    %duration (s)  
    %filename
    %widthDeg (stimulus width in degrees of visual angle)
    %centreDeg (stimulus center coordinates in degrees relative to center of screen)

%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)
if isNotDefined('params')
  params = struct;
end
if fieldIsNotDefined(params,'nBlockTypes')
  params.nBlockTypes = 2;
end
if fieldIsNotDefined(params,'nBlockRepeats')
  params.nBlockRepeats = 3;
end
if fieldIsNotDefined(params,'blockDurationS')
  params.blockDurationS = 30;
end
if fieldIsNotDefined(params,'stimPerBlock')
  params.stimPerBlock = 20;
end
if fieldIsNotDefined(params,'repeatPeriod')
  params.repeatPeriod = 6; % average number of stimuli between target repeated stimuli
end
if fieldIsNotDefined(params,'ISI')
  params.ISI = .2;
end
if fieldIsNotDefined(params,'widthDeg') % stimulus width in degrees of visual angle
  params.widthDeg = 15;
end

if nargout==1
  return;
end

blockTypes = {'Females','Males'};

stimFilenames{1} = {'Female1','Female2','Female3','Female4','Female8',...
                    'Female10','Female11','Female13','Female19','Female20',...
                    'Female21','Female22','Female27','Female28','Female31',...
                    'Female32','Female33','Female35','Female37','Female38',...
                    'Female39','Female77','Female79','Female80','Female84'};
stimFilenames{2} = {'Male42','Male44','Male46','Male47','Male49',...
                    'Male50','Male51','Male54','Male56','Male57',...
                    'Male58','Male59','Male62','Male63','Male66',...
                    'Male67','Male68','Male69','Male71','Male75',...
                    'Male76','Male78','Male81','Male82','Male83'};

% block order
blocks = [];
for iBlock = 1:params.nBlockRepeats
  blocks = [blocks randperm(params.nBlockTypes) 0];
end

% create stimulus structure
cStim = 0;
for iBlock = blocks
  if ~iBlock % Baseline
    
    cStim = cStim+1;
    stimulus(cStim).conditionName = 'Baseline';
    stimulus(cStim).condition = 0;
    stimulus(cStim).filename='None';
    stimulus(cStim).duration= params.blockDurationS;
    stimulus(cStim).widthDeg = [];
    stimulus(cStim).centreDeg = [];
    
  else
    
    repeatPreviousStim = false;
    whichStim = randperm(length(stimFilenames{iBlock}),1); %choose first stimulus at random
    previousStim = whichStim;
    for iStim  = 1:params.stimPerBlock
      cStim = cStim+1;
      if repeatPreviousStim % repeated stimulus (1-back task target)
        whichStim = previousStim;
        repeatPreviousStim = false; % never repeat twice in a row
      else
        % randomly choose a stimulus in this block type (without repetition)
        while whichStim == previousStim
          whichStim = randperm(length(stimFilenames{iBlock}),1);
        end
        % decide whether to repeat this stimulus next
        if iStim > 1 % (never repeat the first stimulus)
          repeatPreviousStim =  randperm(params.repeatPeriod,1) == params.repeatPeriod;
        end
      end
      previousStim = whichStim;
      
      % stimulus properties
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = stimFilenames{iBlock}{whichStim};
      stimulus(cStim).duration = params.blockDurationS/params.stimPerBlock - params.ISI;
      stimulus(cStim).widthDeg = params.widthDeg;
      stimulus(cStim).centreDeg = [0,0]; % X,Y in degrees relative to center of screen
      % end each presentation with a blank
      cStim = cStim+1;
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = 'None';
      stimulus(cStim).duration = params.ISI; 
      stimulus(cStim).widthDeg = [];
      stimulus(cStim).centreDeg = [];
    end
    
  end
end


%%%%%%%%%%% Local functions - Do not delete
function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));


