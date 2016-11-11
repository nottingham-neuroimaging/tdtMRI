function [params,stimulus] = corticalMagnification(params,StimTR,TR,ScanDuration)

% stimulus = struct array with fields:
%frequency (kHz)
%bandwidth
%level (dB)
%duration (ms)
%name
%number
% StimTR = 8
TR= 7.5
% TR = 2
% TR= 1.5
ScanDuration= 8
%default parameters: these are the parameters that will appear in the main
%window and can be changed between runs (the first few anyway)

if isNotDefined('params')
    params = struct;
end
if fieldIsNotDefined(params,'level')
    params.level = 80;
end
if fieldIsNotDefined(params,'sparse')
    params.sparse = 1;
end
if fieldIsNotDefined(params,'lowFrequency')
    params.lowFrequency = .1;
end
if fieldIsNotDefined(params,'highFrequency')
    params.highFrequency = 8;
end
if fieldIsNotDefined(params,'nFrequencies')
    params.nFrequencies = 32;
end
if fieldIsNotDefined(params,'nRepeats')
%     if params.sparse == 1
    params.nRepeats = round((ScanDuration*60/TR)/params.nFrequencies);
%     else
%     params.nRepeats = round((ScanDuration*60/TR)/params.nFrequencies)-1;    
%     end% use nRepeatsPerRun instead
end
if fieldIsNotDefined(params,'nSilence')
    params.nSilence = 8;  %ratio of silent conditions to total number of conditions - 1/nSilence
end
if fieldIsNotDefined(params,'acqDur')
    
    if params.sparse == 1
    params.acqDur = 2000;
    %     params.acqDur = 1525;
    else
        params.acqDur = 0;
    end
    %     params.blockDur = 2000; % morse train duration - ms
end
if fieldIsNotDefined(params,'stimWindow')
    params.stimWindow = (TR * 1000)-params.acqDur;
    %     params.blockDur = 2000; % morse train duration - ms
end
% if fieldIsNotDefined(params,'nMorseTrain')
%     params.nMorseTrain = 8; % number of beeps in train
%         if params.sparse == 1
%         params.nMorseTrain = params.nMorseTrain*4;
%     end
% end
if fieldIsNotDefined(params,'MorseA')
    params.MorseA = 50;
end
if fieldIsNotDefined(params,'MorseB')
    params.MorseB = 200;
end
if fieldIsNotDefined(params,'nMorseA')
    if TR == 1.5
        params.nMorseA = 2;
    elseif TR == 2
         params.nMorseA = 3;
    elseif TR == 7.5
        params.nMorseA = 10;
    end
end
if fieldIsNotDefined(params,'nMorseB')
    if TR == 1.5
        params.nMorseB = 4;
    elseif TR == 2
        params.nMorseB = 5;
    elseif TR == 7.5
        params.nMorseB = 16;
    end
end
if fieldIsNotDefined(params,'intStimGap')
    params.intStimGap = 50;
end
if fieldIsNotDefined(params,'blockDur')
    params.blockDur = ((params.MorseA*params.nMorseA)+(params.MorseB*params.nMorseB)+ (params.intStimGap*((params.nMorseA +params.nMorseB)-1)));
    %     params.blockDur = 2000; % morse train duration - ms
end
if fieldIsNotDefined(params,'bandwidthERB')
    params.bandwidthERB = 1;
end

if nargout==1
    return;
end

% check = params.nMorseTrain - (params.nMorseA + params.nMorseB);
% if check>0
%     error('There are too many morse trains');
% end
check = params.stimWindow - params.blockDur;
if check<0
    error('The stimulus block is longer than the TR');
end
params.nMorseTrain = params.nMorseA + params.nMorseB;

allFrequencies = lcfInvNErb(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies));
lowCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)-params.bandwidthERB/2);
highCuttingFrequencies = lcfInvNErb(lcfNErb(allFrequencies)+params.bandwidthERB/2);
allFrequencies = (lowCuttingFrequencies+highCuttingFrequencies)/2;
allBandwidths = (highCuttingFrequencies-lowCuttingFrequencies);

allduration = [repmat([params.MorseA],1,params.nMorseA) repmat([params.MorseB],1,params.nMorseB)];


c=0;

% create frequency morse code trains
for i=1:length(allFrequencies)
    if params.sparse == 1
        c=c+1;
        stimulus(c).frequency =  [NaN repmat([allFrequencies(i) NaN],1,params.nMorseTrain)];
        ix = randperm(length(allduration));
        dur = allduration(ix);
        x = 0;
        for ii = 1:length(allduration)
            x = x+1;
            stimulus(c).duration(x) =  dur(ii);
            stimulus(c).duration(x+1) = params.intStimGap;
            x = x+1;
        end
        stimulus(c).duration = [params.acqDur stimulus(c).duration];
        stimulus(c).bandwidth  = [NaN repmat([allBandwidths(i) NaN],1,params.nMorseTrain)];
        stimulus(c).level = [NaN repmat([params.level NaN],1,params.nMorseTrain)];
        stimulus(c).name = sprintf('Tone %dHz',round(allFrequencies(i)*1000));
        stimulus(c).number = c;
        
    else
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
        stimulus(c).level = [repmat([params.level NaN],1,params.nMorseTrain)];
        stimulus(c).name = sprintf('Tone %dHz',round(allFrequencies(i)*1000));
        stimulus(c).number = c;
    end
end

% create silent block
silence.frequency = NaN;
silence.duration =  TR; % modify to be length of frequency block automatically
silence.bandwidth  = NaN;
silence.level = NaN;
silence.name = sprintf('Silence');
silence.number = length(allFrequencies)+1;

silence = repmat(silence,1,(params.nFrequencies*params.nRepeats)/params.nSilence);
stimulus = repmat(stimulus,1,params.nRepeats);

stimulus = [stimulus silence];

optimiseRepeats = 1000;
glmType = 'hrfModel';
hrf = getCanonicalHRF(TR);
eMax = 0;
for i = 1:optimiseRepeats
ix = randperm(length(stimulus));
sequence= stimulus(ix);
[e(i), sequence_Opti] = testDesignEfficiency([sequence.number],params.nFrequencies,glmType,hrf);
    % find max efficiency
    if e(i)>eMax
        eMax = e(i);
        seqMax = sequence_Opti;
        sequenceMax_Opti = sequence;
    end         
end
%% Voxel duty cycle
sigma = 6.8;
voxelDutyCycle = voxelDutyCycle(seqMax,params.nFrequencies,sigma);

stimulus = sequenceMax_Opti;

PACerb = 17; % TW of PAC voxels in ERB
erbDif = mean(diff(linspace(lcfNErb(params.lowFrequency),lcfNErb(params.highFrequency),params.nFrequencies)));
% voxelDutyCycle = (PACerb /erbDif)*params.nRepeats/((params.nFrequencies * params.nRepeats) + (nSilenceGroups * params.nBlocks));

runTime = (numel(stimulus) * TR)/60;


% local functions
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   convolveModelResponseWithHRF   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function modelTimecourse = convolveModelResponseWithHRF(modelTimecourse,hrf)

n = length(modelTimecourse);
modelTimecourse = conv(modelTimecourse,hrf.hrf);
modelTimecourse = modelTimecourse(1:n);

%%%%%%%%%%%%%%%%%%%%%%%%%
%%   getCanonicalHRF   %%
%%%%%%%%%%%%%%%%%%%%%%%%%
function hrf = getCanonicalHRF(TR)
p.timelag = 1;
p.offset = 0;
p.tau = 0.6;
p.exponent = 4;
% add second gamma if this is a difference of gammas fit
p.diffOfGamma = 1;
p.amplitudeRatio = 0.25;
p.timelag2 = 2;
p.offset2 =0;
p.tau2 = 1.2;
p.exponent2 = 11;

sampleRate = TR;
lengthInSeconds = 16;

hrf.time = 0:sampleRate:lengthInSeconds;
hrf.hrf = getGammaHRF(hrf.time,p);

% normalize to amplitude of 1
hrf.hrf = hrf.hrf / max(hrf.hrf);

%%%%%%%%%%%%%%%%%%%%%
%%   getGammaHRF   %%
%%%%%%%%%%%%%%%%%%%%%
function fun = getGammaHRF(time,p)

fun = thisGamma(time,1,p.timelag,p.offset,p.tau,p.exponent)/100;
% add second gamma if this is a difference of gammas fit
if p.diffOfGamma
    fun = fun - thisGamma(time,p.amplitudeRatio,p.timelag2,p.offset2,p.tau2,p.exponent2)/100;
end

%%%%%%%%%%%%%%%%%%%
%%   thisGamma   %%
%%%%%%%%%%%%%%%%%%%
function gammafun = thisGamma(time,amplitude,timelag,offset,tau,exponent)

% exponent = round(exponent);
% gamma function
gammafun = (((time-timelag)/tau).^(exponent-1).*exp(-(time-timelag)/tau))./(tau*factorial(exponent-1));

% negative values of time are set to zero,
% so that the function always starts at zero
gammafun(find((time-timelag) < 0)) = 0;

% normalize the amplitude
if (max(gammafun)-min(gammafun))~=0
    gammafun = (gammafun-min(gammafun)) ./ (max(gammafun)-min(gammafun));
end
gammafun = (amplitude*gammafun+offset);


%% Voxel duty cycle
% duty cycle of each condition weighted by a gaussian function with TW == pTW
function voxelDC = voxelDutyCycle(sequence,nEvents,sigma)
mu = nEvents/2;
x = 1:nEvents;
gaus = 1 * exp(-(x - mu).^2/2/sigma^2);

gaus = gaus-(0.18/1.81); % values taken from Juliens study: offset = 0.18 Scale = 1.81
gaus = gaus/max(gaus);
gaus(gaus<0.1) = 0;
gausMat = repmat(gaus',1,length(sequence));
voxelDC = mean(sum(sequence .* gausMat,1));

function [e, sequence_Opti] = testDesignEfficiency(source,nEvents,glmType,hrf)
binSize = 1;
            sequence_Opti = zeros(nEvents,length(source));
            for n=1:nEvents
                seq = find(source==n);
                sequence_Opti(n,seq) = 1;
            end
    
    loopLength = nEvents/binSize;
    c = 1;
    if binSize ==1
        desMatBin_Opti = sequence_Opti;
    else
        for n = 1:loopLength
            desMatBin_Opti(n,:) = sum(sequence_Opti(c:c+binSize-1,:),1);
            c = c + binSize;
        end
        desMatBin_Opti(desMatBin_Opti>1) = 1;
    end
    
    switch(glmType)
        case('hrfModel')            
            for n = 1:nEvents/binSize
                desMat_Opti(n,:) = convolveModelResponseWithHRF(desMatBin_Opti(n,:),hrf);
            end
        case('revCorr')
            desMat_Opti = desMatBin_Opti;
            for j=1:Nh-1
                desMat_Opti = [desMat_Opti;circshift(desMatBin_Opti,[0,j])];
            end
    end
    desMat_Opti_e = desMat_Opti-repmat(mean(desMat_Opti,2),1,length(desMat_Opti));
    e_RandOp = 1/trace(inv(desMat_Opti_e * desMat_Opti_e'));
    e = 1/trace(inv(desMat_Opti_e * desMat_Opti_e'));
    
    SeqMeanRand = sequence_Opti-repmat(mean(sequence_Opti,2),1,length(sequence_Opti));
    eSeqRand = 1/trace(inv(SeqMeanRand * SeqMeanRand'));


%% Sequence duty cycle
% DutyCycle_Opti = mean(mean(sequenceMax_Opti));
% figure('name',sprintf('Optimised Random sequence %s , nEvents = %i, Duty Cycle = %.4f',sequenceType,nEvents,DutyCycle_Opti));
% subplot(2,2,1:2)
% hist(e_RandOp);
% title(sprintf('Efficiency: Design = %.4f,Sequence  = %.4f',eMax_Opti,eMax_opti_seq));
% corrSeqMaxu = corr(sequenceMax_Opti');
% corrDmaxu = corr(DesignMatMax_Opti');
% subplot(2,2,3);
% imagesc(corrSeqMaxu);
% title(sprintf('N = %i',length(sequence_Opti)));
% caxis([-1 1]);
% colorbar;

