function [params,stimulus] = pureTone(params,nRepeatsPerRun,stimTR,TR)

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
if fieldIsNotDefined(params,'frequency')
  params.frequency = 1;
end
if fieldIsNotDefined(params,'bandwidth')
  params.bandwidth = 0;
end
if fieldIsNotDefined(params,'onset')
  params.onset = 0;
end
if fieldIsNotDefined(params,'level')
  params.level = 65.49;
end
if fieldIsNotDefined(params,'nStimOn')
  params.nStimOn = 1;
end
if fieldIsNotDefined(params,'nStimOff')
  params.nStimOff = 0;
end

if nargout==1
  return;
end


stimulus(1).frequency=[NaN params.frequency];
stimulus(1).bandwidth = [NaN params.bandwidth];
stimulus(1).level=[NaN params.level];
stimulus(1).duration= [params.onset stimTR-params.onset];
stimulus(1).name = 'on';
stimulus(1).number = 1;

stimulus(2).frequency=NaN;
stimulus(2).bandwidth = NaN;
stimulus(2).level=params.level;
stimulus(2).duration=stimTR;  
stimulus(2).name = 'off';
stimulus(2).number = 2;

stimulus = stimulus(repmat([ones(1,params.nStimOn) 2*ones(1,params.nStimOff)],1,nRepeatsPerRun));





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


