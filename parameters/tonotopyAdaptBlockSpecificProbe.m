function [params,stimulus] = tonotopyAdaptBlockSpecificProbe(params,nRepeatsPerRun,stimTR,TR)

% stimulus = struct array with fields:    
    %frequency
    %bandwidth
    %level
    %duration (ms)  
    %name
    %number

HemoDelay = 4000;
HWindow = 1000; %jitter onset HWindow around HemoDelay
order=0; %set ordered or not


%default parameters
if isNotDefined('params')
  params = struct;
end
if fieldIsNotDefined(params,'probeFrequency')
  params.probeFrequency = 2;
end
if fieldIsNotDefined(params,'nAdapterFrequencies')
  params.nAdapterFrequencies = 4; %number of adapter frequencies on each side the probe frequency
end
if fieldIsNotDefined(params,'probeBandwidth')
  params.probeBandwidth = .05;
end
if fieldIsNotDefined(params,'probeLevel')
  params.probeLevel = 70;
end
if fieldIsNotDefined(params,'adapterBandwidth')
  params.adapterBandwidth = params.probeBandwidth;
end
if fieldIsNotDefined(params,'adapterLevel')
  params.adapterLevel = params.probeLevel;
end

if nargout==1
  return;
end

%---------------- enumerate all different conditions
adapterFrequency = params.probeFrequency*2.^((-params.nAdapterFrequencies:params.nAdapterFrequencies)*.5);
adapterFrequency = [adapterFrequency NaN];
probeFrequency = [repmat(params.probeFrequency,1,size(adapterFrequency,2)) NaN(1,size(adapterFrequency,2))];
adapterFrequency = repmat(adapterFrequency,1,2);
numberConditions = size(adapterFrequency,2);
adapterLevel = repmat(params.adapterLevel,1,numberConditions);
probeLevel = repmat(params.probeLevel,1,numberConditions);
adapterBandwidth = repmat(params.adapterBandwidth,1,numberConditions);
probeBandwidth = repmat(params.probeBandwidth,1,numberConditions);
for iCond = 1:numberConditions
  if isnan(adapterFrequency(iCond)) & isnan(probeFrequency(iCond))
    name{iCond} = 'No stimulus';
  elseif isnan(adapterFrequency(iCond))
    name{iCond} = sprintf('%dHz Probe only',round(probeFrequency(iCond)*1000));
  elseif isnan(probeFrequency(iCond))
    name{iCond} = sprintf('%dHz Adapter (No Probe)',round(adapterFrequency(iCond)*1000));
  else
    name{iCond} = sprintf('%dHz Adapter + %dHz Probe',round(adapterFrequency(iCond)*1000),round(probeFrequency(iCond)*1000));
  end
end

%------------------------------------- sequency randomization
localiser=0;
if localiser == 1    
    epochLocaliser = [1 1 2 2];    
    sequence = [];
    for I = 1:nRepeatsPerRun;
        sequence = [sequence epochLocaliser];     
    end
else        
    MRITrig = [];
    for I = 1:nRepeatsPerRun
       MRITrig = [MRITrig randperm(numberConditions/2)];
    end    
    sequence = zeros(1,2*length(MRITrig));       
    if order==1
        %fixed order adapter/probe (adapter - adapter+probe etc...)
        I=1:length(MRITrig);
        %conditions alternate between adapter & adapter + probe
        % i.e., 1,11, 2,12, 10,20 etc...
        N = (2*I)-1;    %odd
        K = 2*I;        %even
        sequence(N)=MRITrig(I);
        sequence(K)=numberConditions/2 + MRITrig(I);  
    else
        %random order of adapter/probe
        for I=1:length(MRITrig);
            N = (2*I)-1;    %odd
            K = 2*I;        %even
            if randn(1)>0
                sequence(N)=MRITrig(I);
                sequence(K)=numberConditions/2 + MRITrig(I);
            else
                sequence(K)=MRITrig(I);
                sequence(N)=numberConditions/2 + MRITrig(I);
            end
        end
    end 
end


OnsB=stimTR-(HemoDelay+HWindow);
OnsE=stimTR-(HemoDelay-HWindow);                            

onsets1 = OnsB + (OnsE-OnsB).*rand(length(MRITrig),1); %keep onsets for adapter / adapter+probe the same
onsets=[]; %start with Nan
for i=1:length(MRITrig)
    onsets = [onsets repmat(onsets1(i),1,2)];
end

%---------------------------apply sequence to stimuli
for i=1:length(sequence)
  stimulus(i).frequency = [adapterFrequency(sequence(i)) probeFrequency(sequence(i))];
  stimulus(i).bandwidth = [adapterBandwidth(sequence(i)) probeBandwidth(sequence(i))];
  stimulus(i).level = [adapterLevel(sequence(i)) probeLevel(sequence(i))];
  stimulus(i).duration = round([onsets(i) 250]);
  stimulus(i).name = name{sequence(i)};
  stimulus(i).number = sequence(i);
end





function out = isNotDefined(name)

out = evalin('caller',['~exist(''' name ''',''var'')|| isempty(''' name ''')']);

function out = fieldIsNotDefined(structure,fieldname)

out = ~isfield(structure,fieldname) || isempty(structure.(fieldname));
