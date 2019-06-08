function [params,stimulus] = tonotopySchonwiesner2015(params,NEpochsPerRun,stimTR,TR)

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
if fieldIsNotDefined(params,'level')
  params.level = 80;
end
if fieldIsNotDefined(params,'onset')
  params.onset=3500; % fixed silence duration in the beginning
end
if fieldIsNotDefined(params,'nFrequencies')
  params.nFrequencies = 8;
end
if fieldIsNotDefined(params,'semitoneJitter')
  params.semitoneJitter = 1;
end
if fieldIsNotDefined(params,'bandwidthOctave')
  params.bandwidthOctave = 0.0;
end
if fieldIsNotDefined(params,'lowFrequency')
  params.lowFrequency = .2;
end
if fieldIsNotDefined(params,'highFrequency')
  params.highFrequency = 8;
end
% if fieldIsNotDefined(params,'nPermute')
%   params.nPermute = 6;  %number of events over which to randomly permute
% end
if fieldIsNotDefined(params,'nPermute')%number of events over which to randomly permute
%   params.nPermute = params.nFrequencies+params.nAMfrequencies;  
  params.nPermute = 11;
end
if fieldIsNotDefined(params,'nNulls')%number of silences per permutation length (nPermute)
  params.nNulls = 2;  
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

for i=1:params.nFrequencies+1
  if i>params.nFrequencies
    stimulus(i).name = 'No stimulus';
    stimulus(i).bandwidth = NaN;
    stimulus(i).frequency = NaN;
    stimulus(i).duration = stimTR;
    stimulus(i).level = NaN;
  else
    perFreqMin=allFrequencies(i)*2^(-params.semitoneJitter/2/12);
    perFreqMax=allFrequencies(i)*2^(params.semitoneJitter/2/12);
    nRep=floor((stimTR-params.onset)/toneDur);
    perFreqArr=linspace(perFreqMin,perFreqMax,nRep);
    perFreqArr=perFreqArr(randperm(nRep)); % permute frequencies
      
    stimulus(i).name = sprintf('%dHz',round(allFrequencies(i)*1000));
    stimulus(i).bandwidth = [NaN repmat([allBandwidths(i),NaN],1,nRep)];
    tmp=zeros(1,2*nRep); tmp(1:end)=NaN; tmp(1:2:end)=perFreqArr;
    stimulus(i).frequency = [NaN tmp];
    tmp=zeros(1,2*nRep); tmp(1:2:end)=activeDur; tmp(2:2:end)=toneDur-activeDur;
    stimulus(i).duration = [params.onset tmp];
    stimulus(i).level = [NaN repmat([params.level NaN],1,nRep)];
  end
  stimulus(i).number = i;
end


%------------------------------------- sequence randomization
% nPermute = max(1,round(params.nPermute/(params.nFrequencies+1)))*(params.nFrequencies+1);
% nPermute = 15;
% 
% nPermutations = floor(NEpochsPerRun*(params.nFrequencies+1)/nPermute);
% sequence = [];
% for i = 1:nPermutations
%   thisSequence = repmat([1:(params.nFrequencies+1)],1,nPermute/(params.nFrequencies+1));
%   sequence = [sequence thisSequence(randperm(nPermute))];
% end    
% 
% %---------------------------apply sequence to stimuli
% stimulus = stimulus(sequence);
% 
% %------------------------------------- sequence randomization
% sequence = [];
% for i = 1:NEpochsPerRun
%   sequence = [sequence randperm(length(stimulus)-1)];
% end    

sequence = [];
for i = 1:NEpochsPerRun
  sequence = [sequence randperm(length(stimulus)-1)];
end    

sequence2 = [];
for i = 1:floor(length(sequence)/params.nPermute)
  thisSequence = [sequence((i-1)*params.nPermute+1:i*params.nPermute) length(stimulus)*ones(1,params.nNulls)];
  sequence2 = [sequence2 thisSequence(randperm(params.nPermute+params.nNulls))];
end    
sequence2 = [sequence2 sequence(floor(length(sequence)/params.nPermute)*params.nPermute+1:end)];

%---------------------------apply sequence to stimuli
stimulus = stimulus(sequence2);


function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));
