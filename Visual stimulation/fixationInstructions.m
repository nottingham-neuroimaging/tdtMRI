% This function returns the instruction string for the fixation screen, including Arabic characters
% It is saved in a different file because Arabic characters are not correctly 
% copied across by git. It should therefore not be added/committed to the Git repository
% but modified computer by computer

function fixationInstructions = fixationInstructions

% Arabic instructions must be written to file as numbers to be displayed correctly on some machines 
% (Possibly because Matlab versions before 2020a do not encode m files in UTF-8)
% Casting the Arabic characters to double in a function saved in a file gives the wrong codes
% whereas doing it from the terminal gives the correct ones
% The correct codes were obtained by passing the typed Arabic strings throught the online Arabic reshaper
% at https://reshaper.mpcabd.xyz/ and then casting the result as doubles
arabicInstructions{1} = [65166 65170 65267 65198 65239 32 65155 65194 65170 65255 32 65233 65262 65203]; % mat2str(double('????? ???? ???'))
arabicInstructions{2} = [33 65165 65203 65176 65228 65194 92 65265]; % mat2str(double('!?????\?'))

if  strcmp(getenv('COMPUTERNAME'),'DESKTOP-S355HDV')
  fixationInstructions = [double('Starting Soon... ') arabicInstructions{1} ...
                          double('      Get ready!  ') arabicInstructions{2} double('     ')];
else
  fixationInstructions = [double('Waiting for scanner... ') arabicInstructions{1} ...
                          double('      Get ready!  ') arabicInstructions{2} double('     ')];
end

