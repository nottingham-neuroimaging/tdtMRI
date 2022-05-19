function scrambledImg = scramblePhase(img)

minImg = min(img(:));
maxImg = max(img(:));
imgFft = fft2(img);
mag = abs(imgFft);
phase = angle(imgFft);
randomPhase = angle(fft2(rand(size(phase))));
scrambledPhase = phase + randomPhase;
scrambledImg = real(ifft2(mag.*exp(1i*scrambledPhase)));
scrambledImg(scrambledImg<minImg) = minImg;
scrambledImg(scrambledImg>maxImg) = maxImg;
% figure;histogram(img);hold on;histogram(scrambledImg);