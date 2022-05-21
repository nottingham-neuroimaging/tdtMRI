function [params,stimulus] = oneBackTask(params,TR)

% stimulus = struct array with fields:    
    %condition (integer, 0 = baseline)
    %conditionName (string)
    %duration (s)  
    %filename
    %widthDeg (stimulus width in degrees of visual angle)
    %centreDeg (stimulus center coordinates in degrees relative to center of screen)
    %scramble (whether to phase-scramble the image)

%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)
if isNotDefined('params')
  params = struct;
end
if fieldIsNotDefined(params,'nBlockTypes')
  params.nBlockTypes = 10;
end
if fieldIsNotDefined(params,'nBlockRepeats')
  params.nBlockRepeats = 2;
end
if fieldIsNotDefined(params,'blockDurationS')
  params.blockDurationS = 30;
end
if fieldIsNotDefined(params,'blockGapS')
  params.blockGapS = 4;
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
  params.widthDeg = 4;
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


blockTypes = {'Faces','scrambledFaces','Houses','scrambledHouses','English','scrambledEnglish','Arabic','scrambledArabic','Telugu','scrambledTelugu'};
scramble = [false,true,false,true,false,true,false,true,false,true];

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

stimFilenames{4} = {'House01','House02','House03','House04','House05',...
                    'House06','House07','House08','House09','House10',...
                    'House11','House12','House13','House14','House15',...
                    'House16','House17','House18','House19','House20'};

stimFilenames{5} = {'eng1','eng2','eng3','eng4','eng5',...
                    'eng6','eng7','eng8','eng9','eng10',...
                    'eng11','eng12','eng13','eng14','eng15',...
                    'eng16','eng17','eng18','eng19','eng20'};

stimFilenames{6} = {'eng1','eng2','eng3','eng4','eng5',...
                    'eng6','eng7','eng8','eng9','eng10',...
                    'eng11','eng12','eng13','eng14','eng15',...
                    'eng16','eng17','eng18','eng19','eng20'};

stimFilenames{7} = {'arb1','arb2','arb3','arb4','arb5',...
                    'arb6','arb7','arb8','arb9','arb10',...
                    'arb11','arb12','arb13','arb14','arb15',...
                    'arb16','arb17','arb18','arb19','arb20'};

stimFilenames{8} = {'arb1','arb2','arb3','arb4','arb5',...
                    'arb6','arb7','arb8','arb9','arb10',...
                    'arb11','arb12','arb13','arb14','arb15',...
                    'arb16','arb17','arb18','arb19','arb20'};

stimFilenames{9} = {'tel1','tel2','tel3','tel4','tel5',...
                    'tel6','tel7','tel8','tel9','tel10',...
                    'tel11','tel12','tel13','tel14','tel15',...
                    'tel16','tel17','tel18','tel19','tel20'};

stimFilenames{10} = {'tel1','tel2','tel3','tel4','tel5',...
                    'tel6','tel7','tel8','tel9','tel10',...
                    'tel11','tel12','tel13','tel14','tel15',...
                    'tel16','tel17','tel18','tel19','tel20'};


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
  
  
  if ~iBlock % Baseline
    
    cStim = cStim+1;
    stimulus(cStim).conditionName = 'Baseline';
    stimulus(cStim).condition = 0;
    stimulus(cStim).filename='None';
    stimulus(cStim).duration= params.blockDurationS;
    stimulus(cStim).widthDeg = [];
    stimulus(cStim).centreDeg = [];
    stimulus(cStim).scramble = [];
    
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
      stimulus(cStim).scramble = scramble(iBlock);
      % end each presentation with a blank
      cStim = cStim+1;
      stimulus(cStim).conditionName = blockTypes{iBlock};
      stimulus(cStim).condition = iBlock;
      stimulus(cStim).filename = 'None';
      stimulus(cStim).duration = params.ISI; 
      stimulus(cStim).widthDeg = [];
      stimulus(cStim).centreDeg = [];
      stimulus(cStim).scramble = [];
    end
    
  end
end


%%%%%%%%%%% Local functions - Do not delete
function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));


