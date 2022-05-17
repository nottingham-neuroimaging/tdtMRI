function [params,stimulus] = test(params,TR)

% stimulus = struct array with fields:    
    %condition (integer, 0 = baseline)
    %conditionName (string)
    %duration (s)  
    %filename

%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)
if isNotDefined('params')
  params = struct;
end
if fieldIsNotDefined(params,'nBlockTypes')
  params.nBlockTypes = 2;
end
if fieldIsNotDefined(params,'blockDuration')
  params.blockDuration = 8;
end
if fieldIsNotDefined(params,'nBlockRepeats')
  params.nBlockRepeats = 3;
end
if fieldIsNotDefined(params,'stimPerBlock')
  params.stimPerBlock = 8;
end
if fieldIsNotDefined(params,'ISI')
  params.ISI = .2;
end

if nargout==1
  return;
end

blockTypes = {'Males','Females'};

stimFilenames{1} = {'Male1','Male2','Male3','Male4'};
stimFilenames{2} = {'Female1','Female2','Female3','Female4'};

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
    stimulus(cStim).duration= params.blockDuration;
  else
    for iStim  = 1:params.stimPerBlock
      % randomly choose a stimulus in this block type
      cStim = cStim+1;
      whichStim = randperm(length(stimFilenames{iBlock}),1); 
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = stimFilenames{iBlock}{whichStim};
      stimulus(cStim).duration = params.blockDuration/params.stimPerBlock - params.ISI;
      % end each presentation with a blank
      cStim = cStim+1;
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = 'None';
      stimulus(cStim).duration = params.ISI; 
    end
  end
end


%%%%%%%%%%% Local functions - Do not delete
function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));


