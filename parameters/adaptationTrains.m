function [params,stimulus] = adaptationTrains(params,nRepeatsPerRun,TR)

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
if fieldIsNotDefined(params,'nSideFrequencies')
  params.nSideFrequencies = 2; %number of adapter frequencies on each side the probe frequency
end
if fieldIsNotDefined(params,'duration')
  params.duration = 500;
end
if fieldIsNotDefined(params,'gap')
  params.gap = 500;
end
if fieldIsNotDefined(params,'interaction')
  params.interaction = 1;
end
if fieldIsNotDefined(params,'oneSided')
  params.oneSided = 0;
end
if fieldIsNotDefined(params,'centerFrequency')
  params.centerFrequency = 2;
end
if fieldIsNotDefined(params,'level')
  params.level = 70;
end
if fieldIsNotDefined(params,'bandwidth')
  params.bandwidth = 0.05;
end
if fieldIsNotDefined(params,'isi')
  params.isi = 2000;
end

if nargout==1
  return;
end

%---------------- enumerate all different conditions

pairDuration = 2*(params.duration+params.gap);
numberPairs = floor((TR-params.isi)/pairDuration);

if params.oneSided
  allFrequencies = params.centerFrequency*2.^((-params.nSideFrequencies:0)*.5);
else
  allFrequencies = params.centerFrequency*2.^((-params.nSideFrequencies:params.nSideFrequencies)*.5);
end
c=0;
stimulus.frequency=[];
stimulus.duration=[];
stimulus.level=[];
stimulus.bandwidth=[];
stimulus.name=[];
stimulus.number=[];
for i=1:length(allFrequencies)
  %conditions with only one frequency  
  c=c+1;
  if params.interaction
    if i~=params.nSideFrequencies+1
      stimulus(c).frequency =  [NaN repmat([allFrequencies(i) NaN NaN NaN],1,numberPairs)];
    else
      stimulus(c).frequency =  [NaN repmat([NaN NaN allFrequencies(i) NaN],1,numberPairs)];
    end
  else
    stimulus(c).frequency =  [NaN repmat([allFrequencies(i) NaN],1,2*numberPairs)];
  end
  stimulus(c).name = sprintf('Identical %dHz',round(allFrequencies(i)*1000));
  %conditions that mix center frequency and side frequencies
  if i~=params.nSideFrequencies+1
    c=c+1;
    stimulus(c).frequency =  [NaN repmat([allFrequencies(i) NaN params.centerFrequency NaN],1,numberPairs)];
    stimulus(c).name = sprintf('Mixed %dHz %dHz',round(allFrequencies(i)*1000),round(params.centerFrequency*1000));
  end
end

%things that don't change between stimuli
for i=1:c
  stimulus(i).duration = [params.isi repmat([params.duration params.gap],1,2*numberPairs)];
  stimulus(i).level = [NaN repmat([params.level NaN],1,2*numberPairs)];
  stimulus(i).bandwidth = [NaN repmat([params.bandwidth NaN],1,2*numberPairs)];
  stimulus(i).number = i;
end

%No stimulus
c=c+1;
stimulus(c).frequency = NaN;
stimulus(c).name = 'No stimulus';
stimulus(c).level = NaN;
stimulus(c).bandwidth = NaN;
stimulus(c).duration = NaN;
stimulus(c).number = c;

%------------------------------------- sequency randomization
sequence = [];
for I = 1:nRepeatsPerRun
  sequence = [sequence randperm(c)];
end    

%---------------------------apply sequence to stimuli
stimulus = stimulus(sequence);





function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));
