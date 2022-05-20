function scrambledImg = scramblePhase(img,range)

imgFft = fft2(img);
mag = abs(imgFft);
phase = angle(imgFft);
randomPhase = angle(fft2(rand(size(phase))));
scrambledPhase = phase + randomPhase;
scrambledImg = real(ifft2(mag.*exp(1i*scrambledPhase)));
if nargin == 2
  scrambledImg(scrambledImg<range(1)) = range(1);
  scrambledImg(scrambledImg>range(2)) = range(2);
end
scrambledImg = uint8(img);
% figure;histogram(img);hold on;histogram(scrambledImg);