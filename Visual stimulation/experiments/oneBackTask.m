function [params,stimulus] = oneBackTask(params,TR)

% stimulus = struct array with fields:    
    %condition (integer, 0 = baseline)
    %conditionName (string)
    %duration (s)  
    %filename
    %widthDeg (stimulus width in degrees of visual angle)
    %centreDeg (stimulus center coordinates in degrees relative to center of screen)
    %scramble (whether to phase-scramble the image)
    %gaussianWidth (width parameter of a Gaussian used to mask the image, treated as a boolean for now)

%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)
if isNotDefined('params')
  params = struct;
end
if fieldIsNotDefined(params,'nBlockTypes')
  params.nBlockTypes = 6;
end
if fieldIsNotDefined(params,'nBlockRepeats')
  params.nBlockRepeats = 2;
end
if fieldIsNotDefined(params,'blockDurationS')
  params.blockDurationS = 18;
end
if fieldIsNotDefined(params,'blockGapS')
  params.blockGapS = 3.6;
end
if fieldIsNotDefined(params,'stimPerBlock')
  params.stimPerBlock = 15;
end
if fieldIsNotDefined(params,'repeatsPerBlock')
  params.repeatsPerBlock = 3; % exact number of stimulus repeats in a block (for one-back task)
end
if fieldIsNotDefined(params,'ISI')
  params.ISI = .7;
end
if fieldIsNotDefined(params,'widthDeg') % stimulus width in degrees of visual angle
  params.widthDeg = 5;
end

if nargout==1
  return;
end

if rem(params.blockDurationS,TR)
  error('Block duration must be an exact multiple of the TR');
end
if rem(params.blockGapS,TR)
  error('Gap between blocks must be an exact multiple of the TR');
end


blockTypes = {'Faces','scrambledFaces','Houses','English','Arabic','Telugu'};
scramble = [false,true,false,false,false,false];

% stimFilenames{1} = {'Female01','Female02','Female03','Female04','Female08',...
%                     'Female10','Female11','Female13','Female19','Female20',...
%                     'Female21','Female22','Female27','Female28','Female31',...
%                     'Female32','Female33','Female35','Female37','Female38',...
%                     'Female39','Female77','Female79','Female80','Female84'};
% stimFilenames{2} = {'Male42','Male44','Male46','Male47','Male49',...
%                     'Male50','Male51','Male54','Male56','Male57',...
%                     'Male58','Male59','Male62','Male63','Male66',...
%                     'Male67','Male68','Male69','Male71','Male75',...
%                     'Male76','Male78','Male81','Male82','Male83'};

stimFilenames{1} = {'Female01','Female02','Female03','Female04','Female08',...
                    'Female20','Female38','Female79','Female80','Female84',...
                    'Male42','Male44','Male46','Male47','Male49',...
                    'Male63','Male69','Male75','Male76','Male82'};

stimFilenames{2} = {'Female01','Female02','Female03','Female04','Female08',...
                    'Female20','Female38','Female79','Female80','Female84',...
                    'Male42','Male44','Male46','Male47','Male49',...
                    'Male63','Male69','Male75','Male76','Male82'};

stimFilenames{3} = {'House01','House02','House03','House04','House05',...
                    'House06','House07','House08','House09','House10',...
                    'House11','House12','House13','House14','House15',...
                    'House16','House17','House18','House19','House20'};

stimFilenames{4} = {'English.001','English.002','English.003','English.004','English.005',...
                    'English.006','English.007','English.008','English.009','English.010',...
                    'English.011','English.012','English.013','English.014','English.015',...
                    'English.016','English.017','English.018','English.019','English.020'};

stimFilenames{5} = {'Arabic.001','Arabic.002','Arabic.003','Arabic.004','Arabic.005',...
                    'Arabic.006','Arabic.007','Arabic.008','Arabic.009','Arabic.010',...
                    'Arabic.011','Arabic.012','Arabic.013','Arabic.014','Arabic.015',...
                    'Arabic.016','Arabic.017','Arabic.018','Arabic.019','Arabic.020'};

stimFilenames{6} = {'Telugu.001','Telugu.002','Telugu.003','Telugu.004','Telugu.005',...
                    'Telugu.006','Telugu.007','Telugu.008','Telugu.009','Telugu.010',...
                    'Telugu.011','Telugu.012','Telugu.013','Telugu.014','Telugu.015',...
                    'Telugu.016','Telugu.017','Telugu.018','Telugu.019','Telugu.020'};


% block order
blocks = 0; %temporary baseline block
for iBlock = 1:params.nBlockRepeats
  blockOrder = randperm(params.nBlockTypes+1)-1;
  while blockOrder(1) == blocks(end) % never start with a block that the same as the last block
    blockOrder = randperm(params.nBlockTypes+1)-1;
  end
  blocks = [blocks blockOrder];
end
blocks(1) = []; % remove temporary baseline block

% create stimulus structure
cStim = 0;
for iBlock = blocks
  
  cStim = cStim+1; % gap between blocks
  stimulus(cStim).conditionName = 'Interval';
  stimulus(cStim).condition = 0;
  stimulus(cStim).filename='None';
  stimulus(cStim).duration= params.blockGapS;
  stimulus(cStim).widthDeg = [];
  stimulus(cStim).centreDeg = [];
  stimulus(cStim).scramble = [];
  stimulus(cStim).gaussianWidth = [];
  
  if ~iBlock % Baseline
    
    cStim = cStim+1;
    stimulus(cStim).conditionName = 'Baseline';
    stimulus(cStim).condition = 0;
    stimulus(cStim).filename='None';
    stimulus(cStim).duration= params.blockDurationS;
    stimulus(cStim).widthDeg = [];
    stimulus(cStim).centreDeg = [];
    stimulus(cStim).scramble = [];
    stimulus(cStim).gaussianWidth = [];
    
  else
    
    % randomly draw which stims will be repeated
    nDifferentStims = params.stimPerBlock-params.repeatsPerBlock;
    blockStims = randperm(length(stimFilenames{iBlock}),nDifferentStims);
    % randomly draw which of these will be repeated
    repeated = 1:params.repeatsPerBlock;
    while ismember(1,diff(repeated)) % require that two consecutive stimuli are never repeated (?)
      repeated = sort(randperm(nDifferentStims,params.repeatsPerBlock));
    end
    % apply the repetitions
    for stim = fliplr(repeated)
      blockStims = blockStims([1:stim stim stim+1:end]);
    end
    
    for stim  = blockStims
      cStim = cStim+1;
      
      % stimulus properties
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = stimFilenames{iBlock}{stim};
      stimulus(cStim).duration = params.blockDurationS/params.stimPerBlock - params.ISI;
      stimulus(cStim).widthDeg = params.widthDeg;
      stimulus(cStim).centreDeg = [0,0]; % X,Y in degrees relative to center of screen
      stimulus(cStim).scramble = scramble(iBlock);
      stimulus(cStim).gaussianWidth = params.widthDeg/5;
      % end each presentation with a blank
      cStim = cStim+1;
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = 'None';
      stimulus(cStim).duration = params.ISI; 
      stimulus(cStim).widthDeg = [];
      stimulus(cStim).centreDeg = [];
      stimulus(cStim).scramble = [];
      stimulus(cStim).gaussianWidth = [];
    end
    
  end
end


%%%%%%%%%%% Local functions - Do not delete
function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));


