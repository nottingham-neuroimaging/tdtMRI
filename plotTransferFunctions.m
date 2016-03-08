function plotTransferFunctions

files = [dir([pwd '\*clicks_*.csv']);dir([pwd '\*click_*.mat']);dir([pwd '\*.bin'])];

startTime=-1; %in ms
endTime=5;  %in ms

monitorPosition = get(0,'monitorPositions');
monitorPosition = monitorPosition(1,:);
figure('position',monitorPosition);
h3 = subplot(6,3,[2 3 5 6]);
hold on
ylabel('Level (dB)');
title('Impulse');
h4 = subplot(6,3,[8 9 11 12]);
hold on
ylabel('Level (dB)');
title('Transfer function');
h5 = subplot(6,3,[14 15 17 18]);
hold on
xlabel('Frequency (kHz)');
ylabel('Level (dB)');
title('Impulse Response');

h1 = subplot(6,3,[1 4 7]);
hold on
ylabel('Amplitude (Volts)');
title('Impulse');
h2 = subplot(6,3,[10 13 16]);
hold on
xlabel('Time (ms)');
ylabel('Amplitude (Volts)');
title('Impulse Response');

count=0;
colors = 'bgrmk';
for iFile = 1:length(files)
  [transfer,data] = loadInsertsTransfer([pwd '/' files(iFile).name]);
  if strfind(files(iFile).name,'HD')
    style = '--';
  else
    style = '-';
  end
  k = strfind(files(iFile).name,'V');
  if ~isempty(k) && ~isempty(str2num(files(iFile).name(k-1)))
    switch(str2num(files(iFile).name(k-1)))
      case 1
        color = 'b';
      case 2
        color = 'g';
      case 4
        color = 'r';
      case 5
        color = 'm';
      case 8
        color = 'k';
        count=count+1;
        switch count
          case 2
            style = ':';
          case 3
            style = '-.';
        end
    end
  else
    color = colors(mod(iFile,length(colors))+1);
  end
  [~,legends{iFile}] = fileparts(files(iFile).name);
  subplot(h3);
  plot(transfer.frequencies,transfer.impulseFft,[style color]);
  subplot(h4);
  plot(transfer.frequencies,transfer.fft,[style color]);
  subplot(h5);
  plot(transfer.frequencies,transfer.impulseResponseFft,[style color]);
  
  %plot relevant portion of impulse and impulse response
  data(:,1) = data(:,1)*1000; %convert to ms
  samplesToKeep = find(data(:,1)>startTime & data(:,1)<endTime);
  subplot(h1);
  plot(data(samplesToKeep,1),data(samplesToKeep,2),[style color])
  subplot(h2);
  plot(data(samplesToKeep,1),data(samplesToKeep,3),[style color])

end

subplot(h3);
legend(legends,'interpreter','none','location','southWest');

set(h3,'ylim',get(h5,'ylim'));