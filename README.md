# Stack cropping macro for Imagej/Fiji

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.5482982.svg)](https://doi.org/10.5281/zenodo.5482982)

Imagej [1] / Fiji [2] macro that crops any given image stack without having to load it into memory first.

Features:
 * Region of interest (ROI) definition in image stack of any size
 * Original stack on which the ROI is defined is loaded rapidly as a virtual stack without clocking up memory 
 * user defined rotation of the ROI around the z-axis of the stack
 * creation of log file with ROI-coordinates and rotation angle for reproducible results
 * optional contrast enhancement

 *   Should run on Linux, Win & iOS.

To use the macro,  
  - either drag and drop the \*.ijm- file into the Fiji main window and click "Run" or press Ctrl+R on your keyboard
  - or store a copy of the \*.ijm- file in the "Macros" folder (./Fiji.app/plugins/Macros). If the file name ends with an underscore (e.g. stack_cropping_1-0-0_.ijm), the macro will be available from the Fiji menu at "Plugins > Macros > stack cropping 1-0-0" after the next restart of Fiji.

Please cite the following paper when you use this macro:
Rühr et al. (2021): Juvenile ecology drives adult morphology in two insect orders. Proceedings of the Royal Society B 288: 20210616. https://doi.org/10.1098/rspb.2021.0616

References:
[1] Schneider, C. A., Rasband, W. S., & Eliceiri, K. W. (2012). NIH Image to ImageJ: 25 years of image analysis. Nature Methods, 9, 671–675. (doi: 10.1038/nmeth.2089)

[2] Schindelin J et al. 2012 Fiji: an open-source platform for biological-image analysis. Nat. Methods 9, 676–682. (doi: 10.1038/nmeth.2019)
