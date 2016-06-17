function tf = loadTransferFunction(filename)

[path,file,extension] = fileparts(filename);
switch(extension)
  case '.csv'  % transfer functions measured using IHR Brüel&Kjær microphone and 2cc coupler
    ffts = csvread(filename,29,1);
    ffts = ffts(:,1:end-3); %remove last 3 columns corresponding to two different weighted averages and an empty column


    tf.frequencies = (0:size(ffts,2)-1)*3.125; %assuming frequency resolution of 3.125 Hz, but should find a way to read from file (readcsv encounters an error)
    tf.frequencies = tf.frequencies/1000; %convert to kHz
    tf.fft = mean(ffts(6:end,:));
    tf.fft = conv(tf.fft,ones(1,20)/20,'same');
    
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
[~,f1kHz] = min(abs(tf.frequencies-1));
tf.fft = tf.fft - tf.fft(f1kHz);
% %cap at minAttenuation dB
% minAttenuation = -20;
% tf.fft(tf.fft<minAttenuation) = minAttenuation;
