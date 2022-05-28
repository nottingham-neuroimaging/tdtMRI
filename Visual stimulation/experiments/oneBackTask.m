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


stimFilenames{1} = {'Female03','Female04','Female07','Female10','Female11',...
                    'Female13','Female16','Female19','Female22','Female23',...
                    'Female31','Female36','Female38','Female41','Female43',...
                    'Female46','Female50','Female51','Female54','Female55',...
                    'Female56','Female57','Female59','Female67','Female92',...
                    'Male02','Male04','Male05','Male07','Male09',...
                    'Male10','Male11','Male13','Male15','Male16',...
                    'Male20','Male21','Male24','Male28','Male35',...
                    'Male38','Male39','Male42','Male43','Male53',...
                    'Male58','Male60','Male74','Male79','Male80'};

stimFilenames{2} = {'Female03','Female04','Female07','Female10','Female11',...
                    'Female13','Female16','Female19','Female22','Female23',...
                    'Female31','Female36','Female38','Female41','Female43',...
                    'Female46','Female50','Female51','Female54','Female55',...
                    'Female56','Female57','Female59','Female67','Female92',...
                    'Male02','Male04','Male05','Male07','Male09',...
                    'Male10','Male11','Male13','Male15','Male16',...
                    'Male20','Male21','Male24','Male28','Male35',...
                    'Male38','Male39','Male42','Male43','Male53',...
                    'Male58','Male60','Male74','Male79','Male80'};

stimFilenames{3} = {'House01','House02','House03','House04','House05',...
                    'House06','House07','House08','House09','House10',...
                    'House11','House12','House13','House14','House15',...
                    'House16','House17','House18','House19','House20',...
                    'House21','House22','House23','House24','House25',...
                    'House26','House27','House28','House29','House30',...
                    'House31','House32','House33','House34','House35'};

stimFilenames{4} = {'English01','English02','English03','English04','English05',...
                    'English06','English07','English08','English09','English10',...
                    'English11','English12','English13','English14','English15',...
                    'English16','English17','English18','English19','English20',...
                    'English21','English22','English23','English24','English25',...
                    'English26','English27','English28','English29','English30',...
                    'English31','English32','English33','English34','English35',...
                    'English36','English37','English38','English39','English40',...
                    'English41','English42','English43','English44','English45',...
                    'English46','English47','English48','English49','English50'};

stimFilenames{5} = {'Arabic01','Arabic02','Arabic03','Arabic04','Arabic05',...
                    'Arabic06','Arabic07','Arabic08','Arabic09','Arabic10',...
                    'Arabic11','Arabic12','Arabic13','Arabic14','Arabic15',...
                    'Arabic16','Arabic17','Arabic18','Arabic19','Arabic20',...
                    'Arabic21','Arabic22','Arabic23','Arabic24','Arabic25',...
                    'Arabic26','Arabic27','Arabic28','Arabic29','Arabic30',...
                    'Arabic31','Arabic32','Arabic33','Arabic34','Arabic35',...
                    'Arabic36','Arabic37','Arabic38','Arabic39','Arabic40',...
                    'Arabic41','Arabic42','Arabic43','Arabic44','Arabic45',...
                    'Arabic46','Arabic47','Arabic48','Arabic49','Arabic50'};

stimFilenames{6} = {'Telugu01','Telugu02','Telugu03','Telugu04','Telugu05',...
                    'Telugu06','Telugu07','Telugu08','Telugu09','Telugu10',...
                    'Telugu11','Telugu12','Telugu13','Telugu14','Telugu15',...
                    'Telugu16','Telugu17','Telugu18','Telugu19','Telugu20',...
                    'Telugu21','Telugu22','Telugu23','Telugu24','Telugu25',...
                    'Telugu26','Telugu27','Telugu28','Telugu29','Telugu30',...
                    'Telugu31','Telugu32','Telugu33','Telugu34','Telugu35',...
                    'Telugu36','Telugu37','Telugu38','Telugu39','Telugu40',...
                    'Telugu41','Telugu42','Telugu43','Telugu44','Telugu45',...
                    'Telugu46','Telugu47','Telugu48','Telugu49','Telugu50'};


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
      stimulus(cStim).gaussianWidth = params.widthDeg/4;
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


