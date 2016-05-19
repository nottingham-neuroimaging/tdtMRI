function [params,stimulus] = adaptationTrainsFilterBW(params,nRepeatsPerRun,stimTR,TR)

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
  params.lowFrequency = .25;
end
if fieldIsNotDefined(params,'highFrequency')
  params.highFrequency = 6;
end
if fieldIsNotDefined(params,'probeFrequencies')
  params.probeFrequencies = [6];
end
if fieldIsNotDefined(params,'adapterFrequencies')
  params.adapterFrequencies = [2 3 4 5 6];
end
if fieldIsNotDefined(params,'adapterDuration')
  params.adapterDuration = 50;
end
if fieldIsNotDefined(params,'nAdapters')
  params.nAdapters = 4;
end
if fieldIsNotDefined(params,'probeDuration')
  params.probeDuration = 50;
end
if fieldIsNotDefined(params,'gap')
  params.gap = 30;
end
if fieldIsNotDefined(params,'soa')
  params.soa = 500;
end
if fieldIsNotDefined(params,'nFrequencies')
  params.nFrequencies = 7; 
end
if fieldIsNotDefined(params,'nNull')
  params.nNull = 3;  %number of null trials
end
if fieldIsNotDefined(params,'probeOnly')
  params.probeOnly = 1;
end
if fieldIsNotDefined(params,'adaptationTonotopyRatio')
  params.adaptationTonotopyRatio = 1; % ratio of the trial number for stimuli used  both tonotopy and adaptation purposes 
                                        % to that for stimuli used uniquely for tonotopy
end
%find the number of times the sequence has to be repeated so that all condition trial numbers are integers
sequenceRepeats=0;
remainder=inf;
while remainder>0 && sequenceRepeats<10
  sequenceRepeats=sequenceRepeats+1;
  remainder=rem(params.adaptationTonotopyRatio*sequenceRepeats,1);
end
if sequenceRepeats==10
  error('adaptationTonotopyRatio must be a rational number with a denominator <10')
end
if fieldIsNotDefined(params,'nPermute') %number of events over which to randomly permute
  params.nPermute = params.nFrequencies+length(params.probeFrequencies)*length(params.adapterFrequencies)+params.nNull;  
  params.nPermute = (params.nFrequencies-length(params.adapterFrequencies))*sequenceRepeats+...
                    round((length(params.probeFrequencies)+1)*length(params.adapterFrequencies)*params.adaptationTonotopyRatio*sequenceRepeats)+...
                    params.nNull*params.adaptationTonotopyRatio*sequenceRepeats;  
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

if nargout==1
  return;
end

%parameter check
isi = params.soa - params.probeDuration - params.nAdapters * (params.adapterDuration + params.gap);
if isi<0
  error('The soa must be larger than the duration of adapter and probes');
end
if any([max(params.probeFrequencies) max(params.adapterFrequencies)]>params.nFrequencies)
  error('Adapter and Probe frequencies must be less than the number of different frequencies (%d)',params.nFrequencies);
end
%---------------- enumerate all different conditions

allFrequencies = lcfInvNErb(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies));
lowCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)-params.bandwidthERB/2);
highCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)+params.bandwidthERB/2);
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);


nStimsInTrain = floor((stimTR-params.onset)/params.soa);

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
  stimulus(c).frequency =  [NaN repmat([repmat([allFrequencies(i) NaN],1,params.nAdapters) NaN NaN],1,nStimsInTrain)];
  stimulus(c).bandwidth =  [NaN repmat([repmat([allBandwidths(i) NaN],1,params.nAdapters)  NaN NaN],1,nStimsInTrain)];
  stimulus(c).name = sprintf('Adapter %dHz',round(allFrequencies(i)*1000));
  if ismember(c,params.adapterFrequencies)
    usedForAdaptation(c)= 1;
  else
    usedForAdaptation(c)=0;
  end
end

for i=params.probeFrequencies
  for j=params.adapterFrequencies
    %conditions that mix frequencies (adapter + probe)
    c=c+1;
    stimulus(c).frequency =  [NaN repmat([repmat([allFrequencies(j) NaN],1,params.nAdapters) allFrequencies(i) NaN],1,nStimsInTrain)];
    stimulus(c).bandwidth =  [NaN repmat([repmat([allBandwidths(j) NaN],1,params.nAdapters) allBandwidths(i) NaN],1,nStimsInTrain)];
    stimulus(c).name = sprintf('Adapter %dHz Probe %dHz',round(allFrequencies(j)*1000),round(allFrequencies(i)*1000));
    usedForAdaptation(c)= 1;
  end  
end

%Probe only condition
if params.probeOnly
  for i=params.probeFrequencies
    c=c+1;
    stimulus(c).frequency =  [NaN repmat([repmat([NaN NaN],1,params.nAdapters) allFrequencies(i) NaN],1,nStimsInTrain)];
    stimulus(c).bandwidth =  [NaN repmat([repmat([NaN NaN],1,params.nAdapters) allBandwidths(i) NaN],1,nStimsInTrain)];
    stimulus(c).name = sprintf('Probe %dHz',round(allFrequencies(i)*1000));
    usedForAdaptation(c)= 1;
  end
end  

%things that don't change between stimuli
for i=1:c
  stimulus(i).duration = [params.onset repmat([repmat([params.adapterDuration params.gap],1,params.nAdapters) params.probeDuration isi],1,nStimsInTrain)];
  stimulus(i).level = [NaN repmat([repmat([params.level NaN],1,params.nAdapters) params.level NaN],1,nStimsInTrain)];
  stimulus(i).number = i;
end

%No stimulus
cNull=c+1;
for i=1:params.nNull
  c=c+1;
  stimulus(c).frequency = NaN;
  stimulus(c).name = 'No stimulus';
  stimulus(c).level = NaN;
  stimulus(c).bandwidth = NaN;
  stimulus(c).duration = stimTR;
  stimulus(c).number = cNull;
  usedForAdaptation(c)= 0;
end


%------------------------------------- sequence randomization
shortestSequence = [repmat(find(~usedForAdaptation),1,sequenceRepeats) repmat(find(usedForAdaptation),1,sequenceRepeats*params.adaptationTonotopyRatio)];
c = length(shortestSequence);
nPermute = max(1,round(params.nPermute/c))*c;
nPermutations = floor(nRepeatsPerRun*c/nPermute/sequenceRepeats);
sequence = [];
thisSequence = repmat(shortestSequence,1,nPermute/c);
for i = 1:nPermutations
  sequence = [sequence thisSequence(randperm(nPermute))];
end    

%---------------------------apply sequence to stimuli
stimulus = stimulus(sequence);





function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));

% ********** lcfNErb **********
function nerb = lcfNErb(f)
  nerb = 21.4*log10(4.37*f+1);

% ***** lcfInvNErb *****
function f = lcfInvNErb(nerb)
  f = 1/4.37*(10.^(nerb/21.4)-1);


