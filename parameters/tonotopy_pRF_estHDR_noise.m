function [params,stimulus] = tonotopy_pRF_estHDR_noise(params,nRepeatsPerRun,TR)

% stimulus = struct array with fields:
%frequency (kHz)
%bandwidth
%level (dB)
%duration (ms)
%name
%number

% TR = stimTR

%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)
if isNotDefined('params')
    params = struct;
end
if fieldIsNotDefined(params,'nRepeats')
    params.nRepeats = 5; % per position
end
if fieldIsNotDefined(params,'nBlocks')
    params.nBlocks = 4;  % number of blocks in a group
end
if fieldIsNotDefined(params,'nBaseline')
    params.nBaseline = 1;  % multiple of number of noise groups (nCondtions = (nBlocks-1 *nRepeats)) of silent baseline groups
end
if fieldIsNotDefined(params,'nMorseTrain')
    params.nMorseTrain = 8; % number of beeps in train
end
if fieldIsNotDefined(params,'blockOnA')
    params.blockOnA = 50;
end
if fieldIsNotDefined(params,'blockOnB')
    params.blockOnB = 200;
end
if fieldIsNotDefined(params,'nblockOnA')
    params.nblockOnA = 3;
end
if fieldIsNotDefined(params,'nblockOnB')
    params.nblockOnB = 5;
end
if fieldIsNotDefined(params,'intStimGap')
    params.intStimGap = 50;
end
if fieldIsNotDefined(params,'bandwidthERB')
    params.bandwidthERB = inf;
end
if fieldIsNotDefined(params,'CF')
    params.CF = 2;
end
if fieldIsNotDefined(params,'level')
    params.level = 70;
end
if fieldIsNotDefined(params,'blockDur')
%     params.blockDur = TR * 1000;
    params.blockDur = 2000; % morse train duration - ms
end
if fieldIsNotDefined(params,'AquistionType')
    params.AquistionType = 0; % 1 = TR = block duration ie continuous
    % 0 = TR > block duration ie sparse
end

if nargout==1
    return;
end

allduration = [repmat([params.blockOnA],1,params.nblockOnA) repmat([params.blockOnB],1,params.nblockOnB)];
check = params.nMorseTrain - (params.nblockOnA + params.nblockOnB);
if check<0
  error('There are too many morse trains');
end
check = params.blockDur - ((params.blockOnA*params.nblockOnA)+(params.blockOnB*params.nblockOnB));
if check<0
  error('The stimulus block is longerthan the TR');
end

% create noise morse code trains
c=0;
nCons = params.nBlocks * params.nRepeats;

for i=1:nCons
    c=c+1;
    stimulus(c).frequency =  [repmat([params.CF NaN],1,params.nMorseTrain) NaN];
    ix = randperm(params.nMorseTrain);
    dur = allduration(ix);
    for ii = 1:length(allduration)
        stimulus(c).duration =  [repmat([dur(ii) params.intStimGap],1,params.nMorseTrain) NaN];
    end
    stimulus(c).bandwidth  = [repmat([params.bandwidthERB NaN],1,params.nMorseTrain) NaN];
    stimulus(c).level = params.level;
    stimulus(c).name = sprintf('Noise');
end
% create silent block
silence.frequency = NaN;
silence.duration =  params.blockDur; % modify to be length of frequency block automatically
silence.bandwidth  = NaN;
silence.level = NaN;
silence.name = sprintf('Silence');

% order sequence
%  stimulus = reshape(stimulus,params.nNull-1,length(stimulus)/(params.nNull-1));
 pad = repmat(silence,params.nBlocks-2,length(stimulus));
 stimulus = [stimulus; pad];
 
 for i = 1:size(stimulus,2)
     ix = randperm(size(stimulus,1));
 stimulus(:,i) = stimulus(ix(1:3),i);
 end
 buffer = repmat(silence,1,size(stimulus,2));
 stimulus = [buffer; stimulus];
 
 baseline = repmat(silence,params.nBlocks,round(length(stimulus)*params.nBaseline));% number of baseline groups to noise groups
 stimulus = [stimulus baseline];
 ix = randperm(size(stimulus,2));
 stimulus = stimulus(:,ix);
 
 
% if aquistion continuous
if params.AquistionType == 1
    ix = randperm(numel(stimulus));
    stimulus = stimulus(ix);
else
    ix = 1:numel(stimulus);
    stimulus = stimulus(ix);
end

for i = 1:numel(stimulus)
    stimulus(i).number = i;
end

runTime = numel(stimulus) * params.blockDur/1000;


end



function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);
end

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));
end

% ********** lcfNErb **********
function nerb = lcfNErb(f)
nerb = 21.4*log10(4.37*f+1);
end

% ***** lcfInvNErb *****
function f = lcfInvNErb(nerb)
f = 1/4.37*(10.^(nerb/21.4)-1);
end
