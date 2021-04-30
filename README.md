# Stack cropping macro for Fiji
Fiji [1] macro that crops any given image stack without having to load it into memory first.

Additional features:
 * user defined rotation around the z-axis of the stack
 * creation of log file with ROI-coordinates and rotation angle for reproducible results
 * optional contrast enhancement

 *   Should run on Linux, Win & iOS.

To use the macro,  
  - either drag and drop the \*.ijm- file into the Fiji main window and click "Run" or press Ctrl+R on your keyboard
  - or store a copy of the \*.ijm- file in the "Macros" folder (Fiji.app/plugins/Macros). If the file name ends with an underscore (e.g. stack_cropping_1-0-0_.ijm), the macro will be available from the Fiji menu at Plugins > Macros > stack cropping 1-0-0

Please cite the following paper when you use this macro:
Rühr et al. (in rev.): Juvenile ecology drives adult morphology in two insect orders.

References:
[1] Schindelin J et al. 2012 Fiji: an open-source platform for biological-image analysis. Nat. Methods 9, 676–682. (doi:10.1038/nmeth.2019)
