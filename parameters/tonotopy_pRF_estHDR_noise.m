function [params,stimulus] = tonotopy_pRF_estHDR_noise(params,nRepeatsPerRun,StimTR,TR)

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
if fieldIsNotDefined(params,'AquistionType')
    params.AquistionType = 0; % 1 = TR = block duration ie continuous
    % 0 = TR > block duration ie sparse
end
if fieldIsNotDefined(params,'level')
    params.level = 75;
end
if fieldIsNotDefined(params,'nRepeats')
    params.nRepeats = 10; % per position
end
if fieldIsNotDefined(params,'nBlocks')
    params.nBlocks = 4;  % number of blocks in a group
end
if fieldIsNotDefined(params,'nBaseline')
    params.nBaseline = 2;  % multiple of number of noise groups (nCondtions = (nBlocks-1 *nRepeats)) of silent baseline groups
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
if fieldIsNotDefined(params,'lowFrequency')
    params.lowFrequency = .1;
end
if fieldIsNotDefined(params,'highFrequency')
    params.highFrequency = 8;
end
if fieldIsNotDefined(params,'CF')
    params.CF = (params.highFrequency - params.lowFrequency) / 2;
end
if fieldIsNotDefined(params,'bandwidthERB')
    params.bandwidthERB = inf;
%    params.bandwidthERB = round(lcfNErb((params.highFrequency - params.lowFrequency)));
end


if fieldIsNotDefined(params,'blockDur')
    %     params.blockDur = TR * 1000;
    params.blockDur = 2000; % morse train duration - ms
end

if nargout==1
    return;
end

check = params.nMorseTrain - (params.nblockOnA + params.nblockOnB);
if check<0
    error('There are too many morse trains');
end
check = params.blockDur - ((params.blockOnA*params.nblockOnA)+(params.blockOnB*params.nblockOnB));
if check<0
    error('The stimulus block is longerthan the TR');
end

allduration = [repmat([params.blockOnA],1,params.nblockOnA) repmat([params.blockOnB],1,params.nblockOnB)];
% create noise morse code trains
c=0;
% if aquistion continuous
% for continuous - need noise in each block of group
% for sparse - don't won't noise in the first block of each group
if params.AquistionType == 1
    nCons = params.nBlocks * params.nRepeats;
else
    nCons = (params.nBlocks-1) * params.nRepeats;
end

% create random trains for all presentations
for i=1:nCons
    c=c+1;
    stimulus(c).frequency =  [repmat([params.CF NaN],1,params.nMorseTrain)];
    ix = randperm(params.nMorseTrain);
    dur = allduration(ix);
    x = 0;
    for ii = 1:length(allduration)
        x = x+1;
        stimulus(c).duration(x) =  dur(ii);
        stimulus(c).duration(x+1) = params.intStimGap;
        x = x+1;
    end
    stimulus(c).bandwidth  = [repmat([params.bandwidthERB NaN],1,params.nMorseTrain)];
    stimulus(c).level = [repmat([params.level NaN],1,params.nMorseTrain)];
    stimulus(c).name = sprintf('Noise');
end

% create silent block
silence.frequency = NaN;
silence.duration =  params.blockDur; % modify to be length of frequency block automatically
silence.bandwidth  = NaN;
silence.level = NaN;
silence.name = sprintf('Silence');

% order sequence
% if aquistion continuous
% for sparse - add first silence after randomising


if params.AquistionType == 1
    pad = repmat(silence,params.nBlocks-1,length(stimulus));
else
    pad = repmat(silence,params.nBlocks-2,length(stimulus));
end
stimulus = [stimulus; pad];
% index 4 by length of cons 1:4 shifting
for i = 1:size(stimulus,1)
    ishift(i,:) = circshift([1:size(stimulus,1)],[1,params.nBlocks-i]);
end
ishift = repmat(ishift,1,params.nRepeats);
stimulus = stimulus(ishift);
% randomise position of noise
for i = 1:size(stimulus,2)
    %     ix = randperm(size(stimulus,1));
    %     stimulus(:,i) = stimulus(ix,i);
    for ii = 1:size(stimulus,1)
        if strcmp(stimulus(ii,i).name,'Noise')
            stimulus(ii,i).number = ii;
        else
            stimulus(ii,i).number = params.nBlocks +1;
        end
    end
end

% add number to silence for buffer and baseline to call
silence.number =  params.nBlocks +1; % number of fields in strucutres need to match to be concatenated
% if aquistion sparse
% add silent buffer at start of each group
if params.AquistionType == 0
    buffer = repmat(silence,1,size(stimulus,2));
    stimulus = [buffer; stimulus];
end

% nfCons = (params.nFrequencies * params.nRepeats)/(params.nNull-1);
tCons = (100*nCons) / ((1/params.nBaseline)*100);
nSilenceGroups = round(tCons - nCons);
baseline = repmat(silence,params.nBlocks,nSilenceGroups);

% randomise presentation order
stimulus = [stimulus baseline];
ix = randperm(size(stimulus,2));
stimulus = stimulus(:,ix);

stimulus = stimulus(:);

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
