function [params,stimulus] = pureTone(params,nRepeatsPerRun,TR)

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
if fieldIsNotDefined(params,'level')
    params.level = 70;
end
% if fieldIsNotDefined(params,'bandwidth')
%   params.bandwidth = 0;
% end
if fieldIsNotDefined(params,'onset')
    params.onset = 1.5;
end
if fieldIsNotDefined(params,'nFrequencies')
    params.nFrequencies = 500;
end
if fieldIsNotDefined(params,'nNull')
    params.nNull = 4;  %ratio of null trials - 1/nNull
end
if fieldIsNotDefined(params,'blockDur')
    params.blockDur = 2000;
end
if fieldIsNotDefined(params,'nMorseTrain')
    params.nMorseTrain = 8; % number of beeps in train
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

if nargout==1
    return;
end


allFrequencies = lcfInvNErb(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies));
allFrequencies = repmat(allFrequencies,nRepeats);
ix = randperm(length(allFrequencies));
allFrequencies = allFrequencies(ix);
lowCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)-params.bandwidthERB/2);
highCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)+params.bandwidthERB/2);
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);

allduration = [50 50 50 200 200 200 200];
% nStimsInTrain = floor((TR-params.onset)/params.soa);

c=0;
stimulus.frequency=[];
stimulus.duration=[];
stimulus.level=[];
stimulus.bandwidth=[];
stimulus.name=[];
stimulus.number=[];
for i=1:length(allFrequencies)
    %conditions with only one frequency (adapter)
    c=c+1;
    % same frequencie for each index (c)
    % make frequency varible random then index normally
    % how to randomise moorse code pattern?
    stimulus(c).frequency =  [repmat([allFrequencies(i) NaN],1,params.nMorseTrain) NaN];
    % loop duration index - length of number of frequencies
    ix = randperm(params.nMorseTrain);
    dur = allduration(ix);
    for ii = 1:length(allduration)
        stimulus(c).duration =  [repmat([dur(ii) params.intStimGap],1,params.nMorseTrain) NaN];
    end
    stimulus(c).bandwidth  = [NaN repmat([allBandwidths(i) NaN],1,params.nMorseTrain) NaN];
    stimulus(c).name = sprintf('Tone %dHz',round(allFrequencies(i)*1000));
    
%       if ismember(c,params.adapterFrequencies)
%         usedForAdaptation(c)= 1;
%       else
%         usedForAdaptation(c)=0;
%       end
end

nBuffers = length(allFrequencies)/nNull;
for i = 1:nBuffers
    c=c+1;
    
%loop to create groups
% 4 blocks
% 1 silence 3 tones
% randomise for continious scanning
end

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


