function [params,stimulus] = tonotopyFilterBW(params,NEpochsPerRun,stimTR,TR)

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
if fieldIsNotDefined(params,'nFrequencies')
  params.nFrequencies = 6; 
end
if fieldIsNotDefined(params,'nPermute')
  params.nPermute = 6;  %number of events over which to randomly permute
end
if fieldIsNotDefined(params,'lowFrequency')
  params.lowFrequency = 0.25;
end
if fieldIsNotDefined(params,'highFrequency')
  params.highFrequency = 6;
end
if fieldIsNotDefined(params,'bandwidthERB')
  params.bandwidthERB = 1;
end
if fieldIsNotDefined(params,'onset')
  params.onset = 50;
end
if fieldIsNotDefined(params,'level')
  params.level = 70;
end

if nargout==1
  return;
end

%---------------- enumerate all different conditions

allFrequencies = lcfInvNErb(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies));
lowCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)-params.bandwidthERB/2);
highCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)+params.bandwidthERB/2);
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);

for i=1:params.nFrequencies
  if i>params.nFrequencies
    stimulus(i).name = 'No stimulus';
    stimulus(i).bandwidth = NaN;
    stimulus(i).frequency = NaN;
    stimulus(i).duration = stimTR;
    stimulus(i).level = NaN;
  else
    stimulus(i).name = sprintf('%dHz',round(allFrequencies(i)*1000));
    stimulus(i).bandwidth = [NaN allBandwidths(i)];
    stimulus(i).frequency = [NaN allFrequencies(i)];
    stimulus(i).duration = [params.onset stimTR-params.onset];
    stimulus(i).level = [NaN params.level];
  end
  stimulus(i).number = i;
end


%------------------------------------- sequence randomization
nPermute = max(1,round(params.nPermute/params.nFrequencies))*params.nFrequencies;
nPermutations = floor(NEpochsPerRun*params.nFrequencies+1/nPermute);
sequence = [];
for i = 1:nPermutations
  thisSequence = repmat([1:params.nFrequencies],1,nPermute/params.nFrequencies);
  sequence = [sequence thisSequence];
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


