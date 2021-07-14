function tf = loadTransferFunction(filename,center_at_oneKH,maxFrequency)

if ~exist('maxFrequency','var') || isempty(maxFrequency)
  maxFrequency = 0;
end

[path,file,extension] = fileparts(filename);
switch(extension)
  case '.csv'  % transfer functions measured using IHR Brüel&Kjær microphone and 2cc coupler
               % or measured using AUB PCB microphone and 2 cc coupler and TDT SigCalRP 
    try
      ffts = csvread(filename,29,1); % if any non-numeric data are found, this will fail and go in the catch statement below
      %if it works, it is a file from an IHR calibration
      ffts = ffts(:,1:end-3); %remove last 3 columns corresponding to two different weighted averages and an empty column

      tf.frequencies = (0:size(ffts,2)-1)*(20000/(size(ffts,2)-1)); % Frequency step size based on number of sample points
      tf.frequencies = tf.frequencies/1000; %convert to kHz
      tf.fft = mean(ffts(6:end,:));
      tf.fft = conv(tf.fft,ones(1,20)/20,'same');    
    catch %it is doesn't, it is an AUB calibration file
      % read CSV file
      fid = fopen(filename, 'rt');
      x = fread(fid, inf, '*char');
      fclose(fid);

      x = x(:)';
      lines = regexp(x, newline, 'split');
      l1 = lines{1};

      parts = regexp(l1, char(44), 'split');
      test_signal = parts{end};
      temp = str2double(regexp(test_signal, '\d+.\d+', 'match'));

      calib_V = temp(1);
      calib_dB = temp(2);

      tf.frequencies = [];
      tf.fft = [];
      for i = 2:length(lines)-1
          parts = regexp(lines{i}, char(44), 'split');
          tf.frequencies = [tf.frequencies; str2double(parts{1})];
          tf.fft = [tf.fft; str2double(parts{3})];
      end
      %convert to kHz
      tf.frequencies = tf.frequencies/1000;
    end

      
  case '.mat'  %transfer functions measured using Kemar microphone at BRAMS
    tf = load(filename);
    tf.frequencies = tf.frequencies/1000; %convert to kHz
    tf.fft = 20*log10(tf.fft);  %convert to dB
    tf.fft = conv(tf.fft,ones(1,2000)/2000,'same'); %smooth
    tf.fft = tf.fft(1:100:end);  %downsample
    tf.frequencies = tf.frequencies(1:100:end);
    
  case '.bin' %Sensimetrics S14 impulse response provided by manufacturer
    [h,Fs] = load_filter(filename);
    impulseResponse=h;
    zeroLocation = 25; %set arbitrary 0 time sample just before impulse reponse
    Fs = Fs/1000;%convert to ms
    time = ((1:length(h))' - zeroLocation)*1/Fs; %convert to ms
    impulse = zeros(size(time));
    impulse(zeroLocation)= 0.25; %pulse with arbitrary voltage

    % compute FFT
    nFFT = 2^nextpow2(size(time,1));
    transferFreqResolution = Fs/nFFT;
    tf.frequencies = (0:nFFT/2-1)*transferFreqResolution;

    impulseResponseFft = 20*log10(abs(fft(impulseResponse,nFFT)));
    impulseFft = 20*log10(abs(fft(impulse,nFFT)));
    impulseResponseFft = impulseResponseFft(1:end/2);
    impulseFft = impulseFft(1:end/2);
    tf.fft = impulseFft - impulseResponseFft;  %not sure why I need to take the negative of the impulse response

end
%centre on 1kHz

if center_at_oneKH % Edit by Moussa. Added an option to display the absolute values in dB on the graph.
  [~,f1kHz] = min(abs(tf.frequencies-1));
  tf.fft = tf.fft - tf.fft(f1kHz);
end

% %cap at minAttenuation dB
% minAttenuation = -20;
% tf.fft(tf.fft<minAttenuation) = minAttenuation;

%this is to avoid problems with interpolating the function to match the fft of the synthesized sounds:
if tf.frequencies(1) > 0 %if there is no 0Hz attenuation
  % force it to equal the attenuation at the smallest frequency measured
  tf.frequencies = [0; tf.frequencies];
  tf.fft = [tf.fft(1); tf.fft];
end
if tf.frequencies(end)< maxFrequency %if there is no attenuation above the max frequency of the synthesized sounds
  %set it to the attenuation value of the largest frequency measured
  tf.frequencies = [tf.frequencies; maxFrequency];
  tf.fft = [tf.fft; tf.fft(end)];
end

% figure('name',file);
% plot(tf.frequencies,tf.fft);
