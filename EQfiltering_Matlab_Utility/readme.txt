EQFiltering MATLAB Utility:

load_filter.m is a small utility function that will load the EQ Filtering filters into Matlab so that you can process stimuli as you wish.  The zip file contains this code together with two demo filter files.  Please note that this code is Matlab P-Code.  You will need the file load_filter.p in your Matlab path in order to use the function.  The load_filter.m file basically exists as a 'help' file for the utility that gives the call structure.

To use this code you would type:

[h,Fs] = load_filter('filename.bin'), where 'filename.bin' is the name of the file that contains the filter to load.  These files, one for Left and one for Right, are customized for your particular S14 earphones and have been provided on the CD with the EQ Fitlering software.  The function returns the filter impulse response and the sampling rate of the impulse response.  You can then use this impulse response as you would use any impulse response in Matlab (with appropriate re-sampling to equalize the sampling rate, of course).  NOTE: there are separate impulse responses to equalize the left and right outputs of the S14 hardware.  So, any Matlab code would need to load the left and right impulse responses (using two calls to the load_filter function).  You would then process the left and right signals separately with the corresponding impulse responses prior to merging the outputts into a stereo stimulus to be sent to your system's audio device. 


©2014 - Sensimetrics Corporation