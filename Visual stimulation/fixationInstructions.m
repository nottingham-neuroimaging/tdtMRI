% This function returns the instruction string for the the fixation screen
% It is saved in a different file because Arabic characters are not correctly copied across 
% by git. Any change to the lines including Arabic characters (and possibly other lines) should
% therefore not be added/committed to the Git repository, but modified computer by computer

function fixationInstructions = fixationInstructions

if  strcmp(getenv('COMPUTERNAME'),'DESKTOP-S355HDV')
  fixationInstructions = double('Starting Soon... ﺎﺒﻳﺮﻗ ﺃﺪﺒﻧ ﻑﻮﺳ      Get ready! !ﻱ\ﺪﻌﺘﺳﺍ     ');
else
  fixationInstructions = double('Waiting for scanner... ﺎﺒﻳﺮﻗ ﺃﺪﺒﻧ ﻑﻮﺳ      Get ready! !ﻱ\ﺪﻌﺘﺳﺍ     ');
end

