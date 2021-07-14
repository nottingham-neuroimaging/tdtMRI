function plotTransferFunctions(center_at_oneKH)

if nargin == 0 % Added by Moussa. Option to display the absolute values in dB on the graph.
  center_at_oneKH = true;
end

[filenames,path] = uigetfile('*.*','multiselect','on');

if isnumeric(filenames) && ~filenames
  return
end
startTime=-1; %in ms
endTime=5;  %in ms

monitorPosition = get(0,'monitorPositions');
monitorPosition = monitorPosition(1,:);
figure('position',monitorPosition);
ylabel('Level (dB)');
title('Transfer function');
xlabel('Frequency (kHz)');

count=0;
colors = 'bgrmk';
for iFile = 1:length(filenames)
  transfer = loadTransferFunction([path filenames{iFile}],center_at_oneKH);
  [~,legends{iFile}] = fileparts(filenames{iFile});
  plot(transfer.frequencies,transfer.fft);
  hold on;
end
axis tight
legend(legends,'interpreter','none','location','southWest');

