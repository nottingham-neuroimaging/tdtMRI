function [params,stimulus] = tonotopySchonwiesnerTestSounds(params,NEpochsPerRun,stimTR,TR)

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
if fieldIsNotDefined(params,'onset')
  params.onset=250; % fixed silence duration in the beginning
end
if fieldIsNotDefined(params,'level')
  params.level = 80;
end
if fieldIsNotDefined(params,'nFrequencies')
  params.nFrequencies = 8;
end
if fieldIsNotDefined(params,'lowFrequency')
  params.lowFrequency = .2;
end
if fieldIsNotDefined(params,'highFrequency')
  params.highFrequency = 8;
end
if fieldIsNotDefined(params,'semitoneJitter')
  params.semitoneJitter = 1;
end
if fieldIsNotDefined(params,'bandwidthOctave')
  params.bandwidthOctave = 0.0;
end

if nargout==1
  return;
end

%---------------- enumerate all different conditions

%internal variables
toneDur=250; % 250 ms total per tone, including silence in the end
activeDur=187.5; % 187.5 ms tone duration
allFrequencies = params.lowFrequency*2.^(linspace(0,log2(params.highFrequency/params.lowFrequency),params.nFrequencies));
lowCuttingFrequencies = allFrequencies/2^params.bandwidthOctave;
highCuttingFrequencies = allFrequencies*2^params.bandwidthOctave;
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);

stimulus.name = 'All frequencies';
stimulus.bandwidth = [];
stimulus.frequency = [];
stimulus.duration = [];
stimulus.level = [];
stimulus.number = 1;
for i=1:params.nFrequencies
  perFreqMin=allFrequencies(i)*2^(-params.semitoneJitter/2/12);
  perFreqMax=allFrequencies(i)*2^(params.semitoneJitter/2/12);
  nRep=floor((stimTR/params.nFrequencies-params.onset)/toneDur);
  perFreqArr=linspace(perFreqMin,perFreqMax,nRep);
  perFreqArr=perFreqArr(randperm(nRep)); % permute frequencies

  stimulus.bandwidth = [stimulus.bandwidth NaN repmat([allBandwidths(i),NaN],1,nRep)];
  tmp=zeros(1,2*nRep); tmp(1:end)=NaN; tmp(1:2:end)=perFreqArr;
  stimulus.frequency = [stimulus.frequency NaN tmp];
  tmp=zeros(1,2*nRep); tmp(1:2:end)=activeDur; tmp(2:2:end)=toneDur-activeDur;
  stimulus.duration = [stimulus.duration params.onset tmp];
  stimulus.level = [stimulus.level NaN repmat([params.level NaN],1,nRep)];
end

stimulus = stimulus(ones(1,NEpochsPerRun));


function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));
