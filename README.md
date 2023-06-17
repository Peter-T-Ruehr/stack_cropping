# Stack cropping and rotation macro for Imagej/Fiji

**Imagej [1] / Fiji [2] macro that crops any given image stack without the need of loading it into memory first.**

### Features
 * Region of interest (ROI) definition in image stack of any size
 * Original stack on which the ROI is defined is loaded rapidly as a virtual stack without clocking up memory 
 * user defined rotation of the ROI around the z-axis of the stack
 * creation of log file with ROI-coordinates and rotation angle for reproducible results
 * optional contrast enhancement
 * Should run on Linux, Win & iOS.

### Usage
  * either drag and drop the \*.ijm- file into the Fiji main window and click "Run" or press Ctrl+R on your keyboard
  * or store a copy of the \*.ijm- file in the "Macros" folder (./Fiji.app/plugins/Macros). If the file name ends with an underscore (e.g. stack_cropping_1-1-0_.ijm), the macro will be available from the Fiji menu at "Plugins > Macros > stack cropping 1-1-0" after the next restart of Fiji.

### Citation
Please cite the following paper when you use this macro:

Rühr et al. (**2021**): Juvenile ecology drives adult morphology in two insect orders. *Proceedings of the Royal Society B* **288*: 20210616. https://doi.org/10.1098/rspb.2021.0616

### General and in-house (development) versions
There is a version for general use ([./stack_cropping_.ijm](https://github.com/Peter-T-Ruehr/stack_cropping/blob/main/stack_cropping_.ijm)) and two development-versions of the cropping script ([./IEZ/ROI_cropping_devel_1_.ijm](https://github.com/Peter-T-Ruehr/stack_cropping/blob/main/IEZ/ROI_cropping_devel_1_.ijm), [./IEZ/ROI_cropping_devel_2_.ijm](https://github.com/Peter-T-Ruehr/stack_cropping/blob/main/IEZ/ROI_cropping_devel_2_.ijm)). The latter two automatically detect scan details (e.g., pixel size) from (SR)µCT-scans and their log-files of the following sources:
  * TOPOTOMO beamline of KIT Light Source (aka ANKA) at the Karlsruher Institut für Technologie (KIT) (from different file structures of different scan times)
  * p05 beamline run by Helmholtz-Zentrum hereon at DESY, Germany (from different file structures of different scan times)
  * TOMCAT beamline at Swiss Light Source (SLS), PSI, Switzerland
  * Pheoneix naotome run by Helmholtz-Zentrum hereon at Deutsches Elektronen Synchrotron (DESY), Germany
  * Bruker Skyscan 1272 run by Institute of Evolutionary Biology (IEZ), Germany

Note that files and folder strcutures may have changed over the years, so the development scripts will not work for all scans taken at the listed sources. The development scripts are mainly designed for in-house use and will be updated according to in-house needs. [Issues](https://github.com/Peter-T-Ruehr/stack_cropping/issues) regarding the general script, however, will be answered asap.

### References
[1] Schneider, C. A., Rasband, W. S., & Eliceiri, K. W. (2012). NIH Image to ImageJ: 25 years of image analysis. Nature Methods, 9, 671–675. (doi: 10.1038/nmeth.2089)

[2] Schindelin J et al. 2012 Fiji: an open-source platform for biological-image analysis. Nat. Methods 9, 676–682. (doi: 10.1038/nmeth.2019)
