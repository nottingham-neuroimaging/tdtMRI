function tf = loadTransferFunction(filename)


ffts = csvread(filename,29,1);
ffts = ffts(:,1:end-3); %remove last 3 columns corresponding to two different weighted averages and an empty column


tf.frequencies = (0:size(ffts,2)-1)*3.125; %assuming frequency resolution of 3.125 Hz, but should find a way to read from file (readcsv encounters an error)
tf.frequencies = tf.frequencies/1000; %convert to kHz
tf.fft = mean(ffts(6:end,:));
tf.fft = conv(tf.fft,ones(1,20)/20,'same');
%centre on 1kHz
[~,f1kHz] = min(abs(tf.frequencies-1));
tf.fft = tf.fft - tf.fft(f1kHz);
%cap at 8 kHz
maxHighFrq = 8;
tf.fft(tf.frequencies>maxHighFrq) = tf.fft(find(tf.frequencies>maxHighFrq,1,'first'));