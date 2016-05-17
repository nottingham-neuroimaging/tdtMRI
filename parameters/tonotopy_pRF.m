function [params,stimulus] = tonotopy_pRF(params,nRepeatsPerRun,TR)

% TO DO
% change params based on TR
%    nConsPerScan
% make nFrequencies with random CF in between lowFreq and highFreq
% look at random number generation
% ask Julien how to make it morse code
% how many frequencies can we present
% how many silent conditions do we need

% stimulus = struct array with fields:
%frequency (kHz)
%bandwidth
%level (dB)
%duration (ms)
%name
%number


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
    params.nFrequencies = 150;
end
if fieldIsNotDefined(params,'nRepeats')
    params.nRepeats = 2;
end
if fieldIsNotDefined(params,'nNull')
    params.nNull = 4;  %ratio of null trials - 1/nNull
end
if fieldIsNotDefined(params,'nBaseline')
    params.nBaseline = 6;  %ratio of base line blocks - 1/nNull
end
if fieldIsNotDefined(params,'nMorseTrain')
    params.nMorseTrain = 7; % number of beeps in train
end
if fieldIsNotDefined(params,'blockOnA')
    params.blockOnA = 50;
end
if fieldIsNotDefined(params,'blockOnb')
    params.blockOnb = 200;
end
if fieldIsNotDefined(params,'intStimGap')
    params.intStimGap = 50;
end
if fieldIsNotDefined(params,'bandwidthERB')
    params.bandwidthERB = 1;
end
if fieldIsNotDefined(params,'onset')
    params.onset = 2500;
end
if fieldIsNotDefined(params,'level')
    params.level = 70;
end
if fieldIsNotDefined(params,'blockDur')
    params.blockDur = 2000; % morse train duration - ms
end
if fieldIsNotDefined(params,'AquistionType')
    params.AquistionType = 1; % 1 = TR = block duration ie continuous
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

allduration = [50 50 50 200 200 200 200];
% nStimsInTrain = floor((TR-params.onset)/params.soa);


stimulus.frequency=[];
stimulus.duration=[];
stimulus.level=[];
stimulus.bandwidth=[];
stimulus.name=[];
stimulus.number=[];
% create frequency moorse code trains
c=0;
for i=1:length(allFrequencies)
    c=c+1;
    freqStimulus(c).frequency =  [repmat([allFrequencies(i) NaN],1,params.nMorseTrain) NaN];
    ix = randperm(params.nMorseTrain);
    dur = allduration(ix);
    for ii = 1:length(allduration)
        freqStimulus(c).duration =  [repmat([dur(ii) params.intStimGap],1,params.nMorseTrain) NaN];
    end
    freqStimulus(c).bandwidth  = [repmat([allBandwidths(i) NaN],1,params.nMorseTrain) NaN];
    freqStimulus(c).level = params.level;
    freqStimulus(c).name = sprintf('Tone %dHz',round(allFrequencies(i)*1000));
end
% create silent block
silenceStimulus.frequency = NaN;
silenceStimulus.duration =  params.blockDur; % modify to be length of frequency block automatically
silenceStimulus.bandwidth  = NaN;
silenceStimulus.level = NaN;
silenceStimulus.name = sprintf('Silence');

% create presentation groups
nBlocks = length(allFrequencies)/params.nNull;
x = 0;
for i = 1:nBlocks
    x=x+1;
    % silience
    blockStimulus(x) = silenceStimulus;
    blockStimulus(x+1) = freqStimulus(x);
    blockStimulus(x+2) = freqStimulus(x+1);
    blockStimulus(x+3) = freqStimulus(x+2);
    x = x+nBlocks;
end

% if aquistion continuous randomise where silience is
if aquistionType == 1
    ix = randperm(length(blockStimulus));
    blockStimulus = blockStimulus(ix);
end

nGroups= length(allFrequencies)/params.nBaseline;
x = 0;
for i = 1:nGroups
    x=x+1;
    % randomise y to move silent group
    y = 0:params.nBaseline;
    ix = randperm(params.nBaseline);
    y = y(ix);
    for ii = 0:params.nBaseline;
    % use if to select silent
    z = y(ii);
    if z == 1
        stimulus(x+z) = silenceStimulus;
        stimulus(x+z+1) = silenceStimulus;
        stimulus(x+z+2) = silenceStimulus;
        stimulus(x+z+3) = silenceStimulus;
    else
    stimulus(x+z) = blockStimulus(x+z);
    stimulus(x+z+1) = blockStimulus(x+z+1);
    stimulus(x+z+2) = blockStimulus(x+z+2);
    stimulus(x+z+3) = blockStimulus(x+z+3);
    end
    end
    x = x+nGroups;
end

% if aquistion continuous
if aquistionType == 1
    ix = randperm(length(stimulus));
    stimulus = stimulus(ix);
end

for i = 1:length(stimulus)
    stimulus(i).number = i;
end

runTime = length(stimulus) * params.blockDur/60;

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
