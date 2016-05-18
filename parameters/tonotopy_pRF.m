function [params,stimulus] = tonotopy_pRF(params,nRepeatsPerRun,TR)

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
if fieldIsNotDefined(params,'lowFrequency')
    params.lowFrequency = .1;
end
if fieldIsNotDefined(params,'highFrequency')
    params.highFrequency = 8;
end
if fieldIsNotDefined(params,'nFrequencies')
    params.nFrequencies = 150; % must be multiple of nNull-1
end
if fieldIsNotDefined(params,'nRepeats')
    params.nRepeats = 2;
end
if fieldIsNotDefined(params,'nNull')
    params.nNull = 4;  %ratio of null trials - 1/nNull
end
if fieldIsNotDefined(params,'nBaseline')
    params.nBaseline = 6;  %ratio of base line blocks - 1/nBaseline
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
    params.bandwidthERB = 1;
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

allFrequencies = lcfInvNErb(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies));
allFrequencies = repmat(allFrequencies,1,params.nRepeats);
ix = randperm(length(allFrequencies));
allFrequencies = allFrequencies(ix);
lowCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)-params.bandwidthERB/2);
highCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)+params.bandwidthERB/2);
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);

allduration = [repmat([params.blockOnA],1,params.nblockOnA) repmat([params.blockOnB],1,params.nblockOnB)];
check = params.nMorseTrain - (params.nblockOnA + params.nblockOnB);
if check>0
    error('There are too many morse trains');
end
check = params.blockDur - ((params.blockOnA*params.nblockOnA)+(params.blockOnB*params.nblockOnB));
if check<0
    error('The stimulus block is longerthan the TR');
end

% create frequency morse code trains
c=0;
% create silent block
silence.frequency = NaN;
silence.duration =  params.blockDur; % modify to be length of frequency block automatically
silence.bandwidth  = NaN;
silence.level = NaN;
silence.name = sprintf('Silence');

for i=1:length(allFrequencies)
    c=c+1;
    stimulus(c).frequency =  [repmat([allFrequencies(i) NaN],1,params.nMorseTrain)];
    ix = randperm(params.nMorseTrain);
    dur = allduration(ix);
    x = 0;
    for ii = 1:length(allduration)
        x = x+1;
        stimulus(c).duration(x) =  dur(ii);
        stimulus(c).duration(x+1) = params.intStimGap;
        x = x+1;
    end
    stimulus(c).bandwidth  = [repmat([allBandwidths(i) NaN],1,params.nMorseTrain)];
    stimulus(c).level = params.level;
    stimulus(c).name = sprintf('Tone %dHz',round(allFrequencies(i)*1000));
end

% order sequence
 stimulus = reshape(stimulus,params.nNull-1,length(stimulus)/(params.nNull-1));
 buffer = repmat(silence,1,size(stimulus,2));
 stimulus = [buffer; stimulus];
 silence = repmat(silence,params.nNull,round(length(stimulus)/params.nBaseline));% 1 in 6 groups silence

 stimulus = [stimulus silence];
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

% local functions
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
