  % ***** loadInsertTranser
  function [insertsTransfer,data] = loadInsertsTransfer(impulseFilePath,maxSamples,tdtSampleDuration)
  
  if ~exist('maxSamples','var') || isempty(maxSamples)
    maxSamples = 2^18;
  end
  if ~exist('tdtSampleDuration','var') || isempty(tdtSampleDuration)
    tdtSampleDuration = 1/25;
  end
    
  %import insert calibration data
  [dump,filename,extension]=fileparts(impulseFilePath);
  switch(extension)
    case '.csv'
      data = importdata(impulseFilePath);
    case '.mat'
      data = load(impulseFilePath);
      fieldname = fieldnames(data);
      data = data.(fieldname{1});
      data = data(:,[1 3 2]);
    case '.bin'
      [h,Fs]=load_filter(impulseFilePath);
      zeroLocation = 200; %set arbitrary 0 time sample just before impulse reponse
      data = ((1:length(h))' - zeroLocation)*1/Fs;
      data(zeroLocation,2)= 0.25; %pulse with arbitrary voltage
      data(:,3)=h;
  end
  %first colum is the time in seconds
  time = data(:,1)*1000; %convert to ms
  scopeSampleDuration = (time(end) - time(1))/(size(data,1)-1); %in ms
  %second column is the TDT impulse
  impulse = data(:,2);
  %third column is the microphone-recorded insert impulse response
  impulseResponse = data(:,3);
  %mean center
  impulseResponse = impulseResponse - mean(impulseResponse);
  impulse = impulse - mean(impulse);

  %select relevant portion
  startTime=-1; %in ms
  endTime=5;  %in ms
  samplesToKeep = find(time>startTime & time<endTime);
  time = time(samplesToKeep);

  %window
  win = hann(round(2/scopeSampleDuration)+mod(round(2/scopeSampleDuration),2)); 
  win = [win(1:end/2);ones(length(time)-length(win),1);win(end/2+1:end)];
  impulseResponse = impulseResponse(samplesToKeep).*win;
  impulse = impulse(samplesToKeep).*win;

  %decimate/downsample
  dsFactor = tdtSampleDuration/scopeSampleDuration; %downsampling factor we're aiming for
  maxDsFactor =10; %maximum decimate/downsampling factor applied at once
  while dsFactor>0
    if dsFactor>maxDsFactor
      thisDsFactor=maxDsFactor;
    else
      thisDsFactor=dsFactor;
    end
    impulseResponse = decimate(impulseResponse,thisDsFactor);
    impulse = decimate(impulse,thisDsFactor);
    time = downsample(time,thisDsFactor);
    scopeSampleDuration = scopeSampleDuration*thisDsFactor;
    dsFactor=floor(dsFactor/maxDsFactor);
  end

  % compute FFT 
  nFFT = 2^nextpow2(maxSamples);
  transferFreqResolution = 1/scopeSampleDuration/nFFT;
  frequencies = (0:nFFT/2-1)*transferFreqResolution;

  impulseResponseFft = 20*log10(abs(fft(impulseResponse,nFFT)));
  impulseFft = 20*log10(abs(fft(impulse,nFFT)));
  impulseResponseFft = impulseResponseFft(1:end/2);
  impulseFft = impulseFft(1:end/2);
  insertsTransferFft = impulseResponseFft - impulseFft;

%     %smooth the Fourier transform
%     smoothingFrequency = 500; %in Hz
%     nSmooth = round(smoothingFrequency/1000/transferFreqResolution); %number of samples in the moving average
%     nSmooth = nSmooth+mod(nSmooth,2); %make sure it is an even number
%     coefficients= ones(1,nSmooth)/nSmooth;
%     insertsTransferFft = [repmat(insertsTransferFft(1),nSmooth/2,1);insertsTransferFft;repmat(insertsTransferFft(end),nSmooth/2-1,1)];
%     insertsTransferFft = conv(insertsTransferFft,coefficients','valid');

  %center at 1kHz
  [dump,index_f1kHz] = min(abs(frequencies-1)); %find index of frequency closest to 1 kHz
  insertsTransferFft = insertsTransferFft -insertsTransferFft(index_f1kHz);

  %sample at the max frequency resolution (that of the background noise)
  insertsTransfer.freqResolution = (1/tdtSampleDuration)/nFFT;
  insertsTransfer.frequencies = (0:nFFT/2-1)*insertsTransfer.freqResolution;
  insertsTransfer.fft = interp1(frequencies,insertsTransferFft,insertsTransfer.frequencies,'spline');
  insertsTransfer.impulseFft = interp1(frequencies,impulseFft,insertsTransfer.frequencies,'spline');
  insertsTransfer.impulseResponseFft = interp1(frequencies,impulseResponseFft,insertsTransfer.frequencies,'spline');

%     %window to 0 at high frequencies
%     cutoff = 10; %in kHw
%     win = hann(2*round((insertsTransfer.frequencies(end)-cutoff)/insertsTransfer.freqResolution))';
%     win = [ones(1,length(insertsTransfer.frequencies)-length(win)/2) win(end/2+1:end)];
%     insertsTransfer.fft = insertsTransfer.fft.*win;

  end
