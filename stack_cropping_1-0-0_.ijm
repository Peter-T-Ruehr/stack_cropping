/*
 * Crops in 3 dimensions including
 *   - user defined rotation
 *   - folder name and log file readouts from
 *     - HZG p05 beamline (DESY_II & DESY_III)
 *     - HZG nanotom
 *     - SLS TOMCAT beamline
 *     - KIT TopoTomo
 *     - Bruker Skyscan 1272
 *   - if no log filep available: manual input of px size and sample
 *   		identifiers necessary
 *   - creation of ROI definition log file for reproducible results  
 *   - choice of working in memory or on disk
 *   - creation of analyze library
 *   - creation of OBJ-mesh (opt.: downsampled)
 *   - creation of checkpoint file and the dependent (scaled) TIFF library
 *   - optional contrast enhancement
 *   - optional stack contrast normalization
 *   
 *   Should run on Linux, Win & iOS.
 *   
 *   PTR (2019)
 */

requires("1.39l");
if (isOpen("Log")) { 
     selectWindow("Log"); 
     run("Close"); 
} 
if (isOpen("Results")) { 
     selectWindow("Results"); 
     run("Close"); 
}

plugins = getDirectory("plugins");
unix = '/plugins/';
windows = '\\plugins\\';

if(endsWith(plugins, unix)){
	print("Running on Unix...");
	dir_sep = "/";
}
else if(endsWith(plugins, windows)){
	print("Running on Windows...");
	dir_sep = "\\";
}

//define scaling values (deprecated)
load_increment = 1;
load_scale_perc = 100;

//define output format list
format_outs = newArray("TIFF", "8-bit TIFF", "JPEG", "GIF", "PNG",
 "PGM", "BMP", "FITS", "Text Image", "ZIP", "Raw");

//get source dir from user and define other directories
parent_dir_path = getDirectory("Select source Directory");
parent_dir_name = File.getName(parent_dir_path);
print("Directory: "+parent_dir_name+"...");

//guess the data source
//print(parent_dir_path+parent_dir_name+".pca");
types = newArray("HZG_nnt", "HZG_p05_II", "TOMCAT", "KIT", "none", "HZG_p05_III", "HZG_nnt_2018", "Skyscan_1272");
if(matches(parent_dir_path, ".*nnt.*")){
	type = types[0];
	print("This seems to be a HZG nanotome 2017 dataset.");
}
else if(matches(parent_dir_path, ".*DESY_II_2017.*")){ //File.exists(parent_dir_path+"\\reco")
	type = types[1];
	print("This seems to be a HZG p05 (DESY_II_2017) dataset.");
}
else if(matches(parent_dir_path, ".*psi.*")){
	type = types[2];
	print("This seems to be a SLS TOMCAT dataset.");
}
else if(matches(parent_dir_path, ".*KIT.*")){
	type = types[3];
	print("This seems to be a KIT TopoTomo dataset.");
}
else if(File.exists(parent_dir_path+parent_dir_name+".pca")){
	type = types[6];
	print("This seems to be a HZG nanotome 2018 dataset.");
}
else if(matches(parent_dir_path, ".*DESY_III.*")){ 
	type = types[5];
	if(File.exists(parent_dir_path+"\\proj_1st_half") || File.exists(parent_dir_path+"\\a_proj_1st_half")){ // the 'a_' is an artefact from stacking
		if(File.exists(parent_dir_path+"\\proj_1st_half"+dir_sep+"reco"+dir_sep+"float_rawBin2") || File.exists(parent_dir_path+"\\a_proj_1st_half"+dir_sep+"reco"+dir_sep+"float_rawBin2")){ // the 'a_' is an artefact from stacking
			binning = 2; // if available, 2x binning is preferred
		}
		else if(File.exists(parent_dir_path+"\\proj_1st_half"+dir_sep+"reco"+dir_sep+"float_rawBin4") || File.exists(parent_dir_path+"\\a_proj_1st_half"+dir_sep+"reco"+dir_sep+"float_rawBin4")){ // the 'a_' is an artefact from stacking
			binning = 4;
		}
		print("This seems to be a "+binning+"x binned HZG p05 (DESY_III_2018) dataset (incl. proj_1st_half).");
		proj_1st_half = true;
	} else{
		if(File.exists(parent_dir_path+"reco"+dir_sep+"float_rawBin2") || File.exists(parent_dir_path+"reco"+dir_sep+"binning_2")){
			binning = 2; // if available, 2x binning is preferred
		}
		else if(File.exists(parent_dir_path+"reco"+dir_sep+"float_rawBin4")  || File.exists(parent_dir_path+"reco"+dir_sep+"binning_4")){
			binning = 4;
		}
		print("This seems to be a "+binning+"x binned HZG p05 (DESY_III_2018) dataset (excl. proj_1st_half).");
		proj_1st_half = false;
	}
}
else{
	
	if(File.exists(parent_dir_path+parent_dir_name+".pca")){
		type = types[7];
		print("This seems to be a Skyscan 1272 dataset.");
	}
	type = types[4];
	print("Can't identify specific dataset.");
}

// COMMENT FOLLOWING LINE AFTER DEBUGGING
//type = "Skyscan_1272";

//create dialog to ask if new stack should be loaded
Dialog.create("Load new stack?");
Dialog.addMessage("Check box if you want to load a new stack, leave it unchecked if you want to use the stack already loaded into ImageJ.\nYou can reuse an already existing ROI.\nNo files will be overwritten.");
Dialog.addCheckbox("Load new stack?", true);
Dialog.addMessage("___________________________________");
Dialog.addChoice("Data type correct?", types, type);
Dialog.addMessage("___________________________________");
Dialog.show();
load_new_stack = Dialog.getCheckbox();
type_old = type;
type = Dialog.getChoice();

if(type != type_old){
	print("\n! ! ! ! ! ! ! ! ! ! !");
	print("You manually changed the acquisition machine and therefore most likely encountered an error.");
	print("Please check your data...");
	print("! ! ! ! ! ! ! ! ! ! !\n");
}

if(type == "HZG_p05_II"){
	start_specimen_number_string = 9;
	end_specimen_number_string = start_specimen_number_string+4; //end_specimen_number_string = lengthOf(parent_dir_name)
}
else if(type == "HZG_p05_III"){
	
	if(matches(parent_dir_path, ".*stack.*")){
		start_specimen_number_string = 0;
		end_specimen_number_string = start_specimen_number_string+4;
		stack = true;
	}
	else{
		start_specimen_number_string = 9;
		end_specimen_number_string = start_specimen_number_string+4;
		stack = false;
	}
}
else if(type == "HZG_nnt"){
	start_specimen_number_string = 8;
	end_specimen_number_string = lengthOf(parent_dir_name);
}
else if(type == "HZG_nnt_2018"){
	start_specimen_number_string = 4;
	end_specimen_number_string = lengthOf(parent_dir_name);
}
else if(type == "TOMCAT"){
	start_specimen_number_string = 13;
	end_specimen_number_string = lengthOf(parent_dir_name)-1;
}
else if(type == "KIT"){
	if(lengthOf(parent_dir_name) < 10){
		start_specimen_number_string = 0;
		end_specimen_number_string = 4;
	}
	else{
		start_specimen_number_string = 11;
		end_specimen_number_string = 15;
	}
}
else if(type == "Skyscan_1272"){
	start_specimen_number_string = 0;
	end_specimen_number_string = 4;
}


if(type != "none"){	
	specimen_number = substring(parent_dir_name, start_specimen_number_string, end_specimen_number_string);
}
else{
	specimen_number = parent_dir_name;
	source_dir = parent_dir_path;
}

if(type == "HZG_p05_II"){
	source_dir = parent_dir_path+"reco"+dir_sep+"binning_2"; //source dir has dir_sep included, even though it does not print it
}
else if(type == "HZG_p05_III"){
	if(stack == true){
		source_dir = parent_dir_path;
	}
	else if(proj_1st_half == true){
		source_dir = parent_dir_path+"proj_1st_half"+dir_sep+"reco"+dir_sep+"float_rawBin"+binning; //source dir has dir_sep included, even though it does not print it
	} 
	else{
		source_dir = parent_dir_path+"reco"+dir_sep+"float_rawBin"+binning; //source dir has dir_sep included, even though it does not print it
	}
}
else if(type == "HZG_nnt"){
	source_dir = parent_dir_path+"uzk_nnt_"+specimen_number+"_reco"; //source dir has dir_sep included, even though it does not print it
}
else if(type == "HZG_nnt_2018"){
	source_dir = parent_dir_path+"uzk_"+specimen_number+"_rec"; //source dir has dir_sep included, even though it does not print it
}
else if(type == "TOMCAT"){
	source_dir = parent_dir_path+"rec_8bit_Paganin_0"; //source dir has dir_sep included, even though it does not print it
}
else if(type == "KIT"){
	// Check for different folder structures of KIT data sets
	if(File.exists(parent_dir_path+"\\slices_8bit\\slice_00100.tif")){
		source_dir = parent_dir_path+"\\slices_8bit";
	}
	else if(File.exists(parent_dir_path+"\\slice_00100.tif")){
		source_dir = parent_dir_path;
	}
	else{
	rack = substring(parent_dir_name,0, 10); //e.g., ->uzk_rack_2<-_0531_z_0
	source_dir = parent_dir_path+rack+dir_sep+specimen_number+"_z_0"+dir_sep+"slices_8bit"; //source dir has dir_sep included, even though it does not print it
	}
	
	KIT_log_list_file_5 = "\\\\blanke-nas-1\\DATA\\RAWDATA\\KIT_2018_01_A\\ERC_numbers_5.txt";
	//KIT_log_list_file_5 = "\\\\blanke-nas-1\\PUBLIC\\ROIs\\KIT_files\\ERC_numbers_5.txt";
	file_string_5 = File.openAsString(KIT_log_list_file_5); 
	KIT_ERC_nos_5 = split(file_string_5, "\n");
	
	KIT_log_list_file_10 = "\\\\blanke-nas-1\\DATA\\RAWDATA\\KIT_2018_01_A\\ERC_numbers_10.txt";
	//KIT_log_list_file_10 = "\\\\blanke-nas-1\\PUBLIC\\ROIs\\KIT_files\\KIT_2018_01_A\\ERC_numbers_10.txt";
	file_string_10 = File.openAsString(KIT_log_list_file_10); 
	KIT_ERC_nos_10 = split(file_string_10, "\n");
}
else if(type == "Skyscan_1272"){
	source_dir = parent_dir_path;
}

//get file list from source dir
file_list_unsorted = getFileList(source_dir);
// move log files from Bruker into new folder
if(type == "Skyscan_1272"){
	//clean file list
	print("Cleaning file list and removing the following items from it");
	file_list = newArray();
	for(k=0; k<file_list_unsorted.length; k++){
		curr_file = file_list_unsorted[k];
		if(endsWith(curr_file, "log") || endsWith(curr_file, "bmp") || endsWith(curr_file, "spr.tif")){  // 
			print(curr_file);
		}
		else {
			file_list = Array.concat(file_list,file_list_unsorted[k]);
		}
	}
	file_list_unsorted = file_list;
}

//start ROI_def_time
ROI_def_start = getTime();

//load new stack if wanted
if(load_new_stack == true){
	//open(source_dir,"virtual");
	//run("Image Sequence...", "open="+source_dir+" increment="+load_increment+" scale="+scale_perc+" sort");
	print("Trying to open virtual stack from "+source_dir+"...");
	open(source_dir,"virtual");
	run("Out [-]");
	//get current stack dimensions
	Stack.getDimensions(width_orig, height_orig, channels, slices, frames);
	setSlice(file_list_unsorted.length/2);
	makeRectangle(width_orig/4, height_orig/4, width_orig/2, height_orig/2);
	resetMinAndMax();
	run("Enhance Contrast", "saturated=0.35");
	run("Select None");
}
//get current stack dimensions
Stack.getDimensions(width_orig, height_orig, channels, slices, frames);
voxel_number = width_orig*height_orig*slices/(1024*1024*1024);
if(bitDepth() == 8){
	stack_size = voxel_number;
	print("Stack size: "+stack_size+" GB @ 8-bit.");
}
else if(bitDepth() == 16){
	stack_size = voxel_number*2;
	print("Stack size: "+stack_size+" GB @ 16-bit.");
}
else if(bitDepth() == 32){
	stack_size = voxel_number*4;
	print("Stack size: "+stack_size+" GB @ 32-bit.");
}
else{
	stack_size = voxel_number;
	print("Estimated stack size (unsure about bit depth): "+stack_size+" GB.");
}

x_center_orig = width_orig/2;
y_center_orig = height_orig/2;

// ask user if the stack was checked, to so he/she can decide on cropping parameters in the following dialog
setTool("rectangle");
waitForUser("Please check the stack to decide on cropping parameters. Then click Okay.");

//create first settings dialog
Dialog.create("Settings 1");
Dialog.addMessage("___________________________________");
	Dialog.addString("Species name correct?", "xxx");
	Dialog.addString("Species number correct?", specimen_number);
	Dialog.addMessage("___________________________________");
	Dialog.addCheckbox("Crop to region of interest (ROI) in x and y?", true);
	Dialog.addCheckbox("Crop to region of interest (ROI) in z?", true);
	Dialog.addCheckbox("Define rotated ROI?", true);
	Dialog.addCheckbox("Use existing ROI file for cropping??", false);
	Dialog.addString("Name of ROI:", "head");
	Dialog.addMessage("___________________________________");
	Dialog.addNumber("Scale to [MB]: ", 280);
	Dialog.addNumber("Scale to [%] (deprecated): ", 100);
	Dialog.addMessage("___________________________________");
	Dialog.addCheckbox("Enhance contrast?", true);
	Dialog.addCheckbox("Normalize intensity fluctuations?*", false);
	Dialog.addMessage("___________________________________");
	Dialog.addString("Input format: ", ".tif", 5);
	Dialog.addChoice("Output format", format_outs, "8-bit TIFF");
	Dialog.addMessage("___________________________________");
	if(type != "none"){	
		if(type == "HZG_p05_II"){
			Dialog.addCheckbox("Get effective pixel size from p05 reconstruction.log?", true);
		}
		else if(type == "HZG_p05_III"){
			Dialog.addCheckbox("Get effective pixel size from p05 reco.log?", true);
		}
		else if(type == "HZG_nnt"){
			Dialog.addCheckbox("Get effective pixel size from nanotom *.pca?", true);
		}
		else if(type == "TOMCAT"){
			Dialog.addCheckbox("Get effective pixel size from TOMCAT *.log?", true);
		}	
		else if(type == "KIT"){
			Dialog.addCheckbox("Get effective pixel size from *.txt-file lists on server?", true);
		}
		Dialog.addMessage("___________________________________");
	}
	if(stack_size < 1000){ //in GB: disabled by setting a very high number.
		Dialog.addCheckbox("Work in memory", true);
	}
	else{
		Dialog.addCheckbox("Work in memory", false);
	}
	Dialog.addMessage("___________________________________");
	Dialog.addMessage("* handle with caution: Only for certain scans, needs external plugin (Capek et al. 2006)");
	Dialog.addMessage("  and usually mutually exclusive with contrast stack enhancement.");
	Dialog.addMessage("PTR, Jan. 2019");
	Dialog.addMessage("Inst. f. Zoologie, Koeln, GER");
	Dialog.show();
	species_name = Dialog.getString();
	specimen_number = Dialog.getString();
	crop_xy = Dialog.getCheckbox();
	crop_z = Dialog.getCheckbox();
	crop_rot_xy = Dialog.getCheckbox();
	use_ROI_file = Dialog.getCheckbox();
	ROI_name = Dialog.getString();
	d_size = Dialog.getNumber()/1024;  //MB/1024=GB
	scale_perc = Dialog.getNumber();
	scale = scale_perc/100;	
	enhance_contrast = Dialog.getCheckbox();
	normalize_bg = Dialog.getCheckbox();
	format_in = Dialog.getString();
	format_out = Dialog.getChoice();
	if(type != "none"){	// somethings strange here - I'm not so sure what this is all abaout anymore, but this feature is not in use anymore anyways
		reco_log = true;
		//does not work right now because KIT data is not implemented
		//reco_log = Dialog.getCheckbox(); 
	}
	else{
		reco_log = false;
	}
	memory = Dialog.getCheckbox();
	print("Working on "+species_name+" (# "+specimen_number+")...");
	
//define directory to save 8bit tifs in
target_dir = source_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name;

// define lof file path and log file name (not possible before because ROI name was unkown)	
log_dir_path = target_dir+dir_sep+'log';
ROI_log_file = specimen_number+"_"+species_name+"_"+ROI_name+".log";

//Create second settings dialog
Dialog.create("Settings 2");
	Dialog.addCheckbox("Create analyze library?", true);
	Dialog.addCheckbox("Create resampled analyze library in case of high stack size?", true);
	Dialog.addCheckbox("Save full sized stack?", true);
	Dialog.addCheckbox("Save full sized analyze library in addition to resampled one?", false);
	Dialog.addCheckbox("Create Checkpoint file?", true);
	Dialog.addCheckbox("Create wavefront?", false);
	Dialog.addCheckbox("automatically decide on resampling factor?", false);
	Dialog.addNumber("If not, define resampling factor:", 1);
	Dialog.show();
	analyze = Dialog.getCheckbox;
	save_red_analyze = Dialog.getCheckbox;
	save_as_stack = Dialog.getCheckbox;
	save_full_analyze = Dialog.getCheckbox;
	checkpoint = Dialog.getCheckbox;
	wavefront = Dialog.getCheckbox;
	auto_res = Dialog.getCheckbox();
	resample = Dialog.getNumber();

//load ROI file if wanted and get pixel size
if (use_ROI_file == true){
	print("Looking for ROI log file. (" + source_dir+dir_sep+ROI_log_file + ")...");
	ROI_in_filestring=File.openAsString(source_dir+dir_sep+ROI_log_file); 
	ROI_in_lines=split(ROI_in_filestring, "\n");
	print("Loaded ROI log file. (" + source_dir+dir_sep+ROI_log_file + ")");
	px_size = parseFloat(ROI_in_lines[2]);
}

//or load pixel size from reco_log
else if(use_ROI_file == false && reco_log == true){
	if(type == "HZG_p05_II"){
		if(File.exists(source_dir+dir_sep+"reconstruction.log")){
			reco_log=File.openAsString(source_dir+dir_sep+"reconstruction.log");
			reco_log_rows=split(reco_log, "\n");
			px_size = substring(reco_log_rows[6], 8, lengthOf(reco_log_rows[6]));
			px_size = parseFloat(px_size)*1000;
		}
		else{
			print("!!!!!!! no log file found --> pixel size set to 1um/px !!!!!!!");
			px_size = 1;
		}
	}
	if(type == "HZG_p05_III"){
		if(File.exists(parent_dir_path+"proj_1st_half"+dir_sep+"reco"+dir_sep+"reco.log")){
			reco_log=File.openAsString(parent_dir_path+"proj_1st_half"+dir_sep+"reco"+dir_sep+"reco.log");
			reco_log_rows=split(reco_log, "\n");
			for(l=0; l<reco_log_rows.length; l++){
				if(matches(reco_log_rows[l], "effective_pixel_size_binned.*")){
					px_size_line = l;
				}
			}
			print(reco_log_rows[px_size_line]+" @ "+binning+"x binning");
			px_size = substring(reco_log_rows[px_size_line], 30, 34);
		}
		else if(File.exists(parent_dir_path+"a_proj_1st_half"+dir_sep+"reco"+dir_sep+"reco.log")){ // the 'a_' is an artefact from stacking
			reco_log=File.openAsString(parent_dir_path+"a_proj_1st_half"+dir_sep+"reco"+dir_sep+"reco.log");
			reco_log_rows=split(reco_log, "\n");
			for(l=0; l<reco_log_rows.length; l++){
				if(matches(reco_log_rows[l], "effective_pixel_size_binned.*")){
					px_size_line = l;
				}
			}
			print(reco_log_rows[px_size_line]+" @ "+binning+"x binning");
			px_size = substring(reco_log_rows[px_size_line], 30, 34);
		}
		else if(File.exists(parent_dir_path+"reco"+dir_sep+"reco.log")){
			reco_log=File.openAsString(parent_dir_path+"reco"+dir_sep+"reco.log");
			reco_log_rows=split(reco_log, "\n");
			for(l=0; l<reco_log_rows.length; l++){
				if(matches(reco_log_rows[l], "effective_pixel_size_binned.*")){
					px_size_line = l;
				}
			}
			print(reco_log_rows[px_size_line]+" @ "+binning+"x binning");
			px_size = substring(reco_log_rows[px_size_line], 30, 34);
		}
		else{
			print("!!!!!!! no log file found --> pixel size set to 1um/px !!!!!!!");
			px_size = 1;
		}
	}
	else if(type == "HZG_nnt"){
		if(File.exists(parent_dir_path+"uzk_nnt_"+specimen_number+".pca")){
			reco_log=File.openAsString(parent_dir_path+"uzk_nnt_"+specimen_number+".pca");
			reco_log_rows=split(reco_log, "\n");
			px_size__ = substring(reco_log_rows[13], 11, lengthOf(reco_log_rows[13]));
			px_size_ = parseFloat(px_size__);
			px_size = px_size_ * 1000;
		}
		else{
			print("!!!!!!! no log file found --> pixel size set to 1um/px !!!!!!!");
			px_size = 1;
		}
	}
	else if(type == "HZG_nnt_2018"){
		if(File.exists(parent_dir_path+"uzk_"+specimen_number+".pca")){
			reco_log=File.openAsString(parent_dir_path+"uzk_"+specimen_number+".pca");
			reco_log_rows=split(reco_log, "\n");
			px_size__ = substring(reco_log_rows[13], 11, lengthOf(reco_log_rows[13]));
			px_size_ = parseFloat(px_size__);
			px_size = px_size_ * 1000;
		}
		else{
			print("!!!!!!! no log file found --> pixel size set to 1um/px !!!!!!!");
			px_size = 1;
		}
	}
	else if(type == "TOMCAT"){
		if(File.exists(parent_dir_path+dir_sep+"tif"+dir_sep+parent_dir_name+".log")){
			reco_log=File.openAsString(parent_dir_path+dir_sep+"tif"+dir_sep+parent_dir_name+".log");
			reco_log_rows=split(reco_log, "\n");
			px_size = substring(reco_log_rows[20], 30, lengthOf(reco_log_rows[20]));
		}
		else{
			print("!!!!!!! no log file found --> pixel size set to 1um/px !!!!!!!");
			px_size = 1;
		}
	}
	else if(type == "KIT"){
		px_size = 1;
		for(i=0; i<KIT_ERC_nos_10.length;i++){
			if(matches(specimen_number, KIT_ERC_nos_10[i])){
				px_size = 1.22;
			}
		}
		if(px_size == 1){
			for(i=0; i<KIT_ERC_nos_5.length;i++){
				if(matches(specimen_number, KIT_ERC_nos_5[i])){
					px_size = 2.44;
				}
			}
		}
	}
	else if(type == "Skyscan_1272"){
		getPixelSize(unit_, px_size, ph, pd);
		px_size = px_size * 10000; // skyscan 1272 tif has px size in cm
	}
	//print("Got pixel size from log file: "+px_size+" (" + source_dir+dir_sep+ROI_log_file + ")");
}

else{ //or set pixel size as 1 to be user defined later
	getPixelSize(unit_, px_size, ph, pd);
}
//Create dialog to check if pixel size is correct or user define it
Dialog.create("Check pixel size");
	Dialog.addNumber("Correct pixel size?:", px_size, 9, 15, "um")
	Dialog.show();
	px_size = Dialog.getNumber();
	unit = Dialog.getString();

//check if target dir exists already in order to ask user to delete it before continuing
while(File.exists(target_dir)){
	waitForUser("Please delete or rename the ROI folder ("+target_dir+")!");
}

if(memory == false){
	//clean file list
	print("Cleaning file list and removing the following items from it");
	file_list = newArray();
	for(k=0; k<file_list_unsorted.length; k++){ //delete everything that does not correspond to input file type from filelist
		if(endsWith(file_list_unsorted[k], format_in)){  //format_in
			file_list = Array.concat(file_list,file_list_unsorted[k]);
		}	
		else{
			print("... "+file_list_unsorted[k]);
		}
	}
}

//DO THIS IF CROPPING AND ROTATING:
if(crop_rot_xy==true){

	//DO THIS IF CROPPING AND ROTATING AND ROI FILE SHOULD BE LOADED
	if(use_ROI_file == true){

		/* ROI file looks as follows:
		0	crop_rot\n
		1	px_size\n"+
		2	px_size);
		3	z1\n"+
		4	first_image+"\n
		5	z2\n"+
		6	last_image+"\n
		7	AB1x\n"+
		8	line_strich_AB[0]+"\n
		9	AB1y\n"+
		10	line_strich_AB[1]+"\n
		11	AB2x\n"+
		12	line_strich_AB[2]+"\n
		13	AB2y\n"+
		14	line_strich_AB[3]+"\n
		15	CD1x\n"+
		16	line_strich_CD[0]+"\n
		17	CD1y\n"+
		18	line_strich_CD[1]+"\n
		19	CD2x\n"+
		20	line_strich_CD[2]+"\n
		21	CD2y\n"+
		22	line_strich_CD[3]+"\n
		23	nalpha\n"+
		24	alpha);
		*/

		//read the line poits of rotated lines (line_strich_AB&CD) from log file
		line_strich_AB = newArray(ROI_in_lines[8], ROI_in_lines[10], ROI_in_lines[12], ROI_in_lines[14]);
		line_strich_CD = newArray(ROI_in_lines[16], ROI_in_lines[18], ROI_in_lines[20], ROI_in_lines[22]);
		for(f=0;f<line_strich_AB.length;f++){
			line_strich_AB[f] = parseFloat(line_strich_AB[f]);
			line_strich_CD[f] = parseFloat(line_strich_CD[f]);
		}

		alpha = ROI_in_lines[24];	
		print("alpha = "+alpha);
		//alpha = parseFloat(alpha);
	}

	//DO THIS IF CROPPING AND ROTATING AND ROI FILE IS NOT LOADED: DEFINE LINES
	else{
		//draw first line defining anterior and fronterior edges along the axis
		setTool("line");
		waitForUser("1) Draw a line from the fronterior or ventral edge to the posterior or dorsal edge of the sample ALONG its axis\n    with the line selection tool to define rotation angle and first two ROI borders.\n2) AFTERWARDS, click 'Ok'."); 
		getSelectionCoordinates(x,y);
		print("fronterior and posterior:");
		for(i=0;i<x.length;i++){
			print(x[i]+"/"+y[i]);
		}
		
		//get roataion angle from first line
		run("Set Measurements...", "mean modal shape redirect=None decimal=0");
		List.setMeasurements();
		alpha = List.getValue("Angle");
		print("Roation angle alpha = "+alpha+'°');
		beta = 360-alpha; //because imageJ rotates clockwise which is mirrored to mathematical standard
		run("Select None");
		
		//draw second line to define lateral edges; axis doesn't matter now
		waitForUser("1) Draw a line from one side of the sample to the other with the line selection tool\n     to define third and fourth ROI borders. Angle and order of slecection do not matter here.\n2) AFTERWARDS, click 'Ok'."); 
		getSelectionCoordinates(v,w);
		print("left and right:");
		for(i=0;i<v.length;i++){
			print(v[i]+"/"+w[i]);
		}
	}
}

// DO THIS IF ONLY CROPPING, NOT ROTATING
else if(crop_xy == true){

	// DO THIS IF ONLY CROPPING, NOT ROTATING AND LOADING ROI FILE
	if(use_ROI_file == true){

		/* ROI file looks as follows:
		0	crop_xy_only\n
		1	px_size\n"+
		2	px_size);
		3	z1\n"+
		4	first_image+"\n
		5	z2\n"+
		6	last_image+"\n
		7	x1\n"+
		8	x[0]+"\n
		9	y1\n"+
		10	y[0]+"\n
		11	x2\n"+
		12	x[2]+"\
		13	ny2\n"+
		14	y[2]);
		*/

		//load rectangle coordinates and width & height values
		x = newArray(ROI_in_lines[8, ROI_in_lines[12], ROI_in_lines[12], ROI_in_lines[8]);//1551
		y = newArray(ROI_in_lines[10], ROI_in_lines[10], ROI_in_lines[14], ROI_in_lines[14]);//3377

		//select the rectangle (---why polygon?)
		makeSelection("polygon", x, y);
	}

	// DO THIS IF ONLY CROPPING, NOT ROTATING AND ROI FILE IS NOT LOADED
	else{
		//define rectangle
		waitForUser("1) Go through your stack and draw the region of Interest (ROI)\n    with the rectangle selection tool.\n2) AFTERWARDS, click 'Ok'."); 
		getSelectionCoordinates(x, y);
	}
}

// DO THIS IF Z-CROPPING
if(crop_z == true){
	// DO THIS IF Z-CROPPING AND ROI FILE IS LOADED
	if(use_ROI_file == true){
		first_image=ROI_in_lines[4];
		last_image=ROI_in_lines[6];
		//make image readouts numeric
		first_image = parseFloat(first_image);
		last_image = parseFloat(last_image);
	}

	// DO THIS IF Z-CROPPING AND ROI FILE IS NOT LOADED
	else{
		waitForUser("1) Check stack for first and last image number in z direction (ROI)\n2) AFTERWARDS, click 'Ok'."); 
		curr_slice = getSliceNumber();
		Dialog.create("Welcome");
		Dialog.addMessage("Please enter number of first and last image.");
		Dialog.addMessage("___________________________________");
		Dialog.addNumber("First image:", 1);
		Dialog.addNumber("Last image:", curr_slice);
		Dialog.show();
		
		first_image = Dialog.getNumber();
		last_image = Dialog.getNumber();
	}
}
else{
	// DO THIS IF NO Z-CROPPING
	//define first and last iamge of stack for z limitations of ROI
	first_image = 1;
	last_image = slices;
}

ROI_def_ex_time = (getTime()-ROI_def_start)/1000;
print("ROI definition time: " + ROI_def_ex_time +" s.");

//print out first and last images to be used
print("First and last:");
print(first_image+"/"+last_image);

//Create target directory to save 8-bit tiffs in
print("Creating target directory...");
File.makeDirectory(target_dir);
File.makeDirectory(log_dir_path);

// START THE ACTUAL PROCESS
print("Starting work on "+species_name+" (# "+specimen_number+")...");
print("************************************");

setBatchMode(true);
//get starting time and define some flags
start = getTime();
error_flag = false;

line_rot_calc_flag = false;
if(crop_z == true){
	if(memory == false){
		for (i=first_image-1; i<=last_image-1; i++) {
			if(endsWith(file_list[i], format_in)){
				if(File.exists(target_dir + dir_sep + file_list[i])){
					print("File '" + target_dir + dir_sep + file_list[i] + " already exists.");
					error_flag = true;
				}
				else{
					open(source_dir + dir_sep + file_list[i]);
					print("Processing " + specimen_number + " " + file_list[i] + " (" + i+2-first_image + dir_sep + (last_image-first_image+1) + ")");
	
					if(crop_rot_xy==true){
						//rotate image
						run("Select None");
						run("Rotate... ", "angle="+alpha+" grid=1 interpolation=Bicubic enlarge"); //enlarge 
	
						//calculate rotation <-- this must be done here, because the function needs the dimensions of the image after enlargement of rotated image 
						if(line_rot_calc_flag==false && use_ROI_file == false){
							line_strich_AB = rotate_line(beta,x,y);
							line_strich_CD = rotate_line(beta,v,w);
							print("Calculated scaled carthesian rotation!");
						}	
						else if(line_rot_calc_flag==false && use_ROI_file==true){
							print(line_strich_AB[0]);
							print(line_strich_AB[2]);
							print(line_strich_CD[1]);
							print(line_strich_CD[3]);
							Array.print(line_strich_AB);
							Array.print(line_strich_CD);
							print("Loaded scaled carthesian rotation!");
						}
	
						if(line_rot_calc_flag == false){
							upper_Lx = line_strich_AB[0];
							upper_Ly = line_strich_CD[3];
							width = line_strich_AB[2]-line_strich_AB[0];
							height = line_strich_CD[1]-line_strich_CD[3];
		
							if (height<0){
								upper_Lx = line_strich_AB[0];
								upper_Ly = line_strich_CD[1];
								height = line_strich_CD[3]-line_strich_CD[1];
								print("Width defined from right to left.");
							}
							else{
								print("Width defined from left to right.");
							}
							
							print("Rotated rectangle will be drawn as follows");
							print('upper_Lx = '+upper_Lx);
							print('upper_Ly = '+upper_Ly);
							print('width = '+width);
							print('height = '+height);
							print('after image rotation of '+alpha+'°');
							line_rot_calc_flag = true;
						}
						
						makeRectangle(upper_Lx, upper_Ly, width, height);
						run("Crop");
					}
					else if(crop_xy == true){
						makeSelection("polygon", x, y);
						run("Crop");
					}
					run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+px_size+" pixel_height="+px_size+" voxel_depth="+px_size);
					run("Rotate 90 Degrees Left");
					saveAs(format_out, target_dir + "/" + file_list[i]);
					close();
					showProgress(i, file_list.length);
				}
			}
		}
	}
	else{
		print("Closing preview image...");
		run("Close");
		print("Loading stack into memory...");
		run("Image Sequence...", "open="+source_dir+" file=tif starting="+first_image+" number="+last_image-first_image+1+" sort");
		
		if(crop_rot_xy==true){
			//rotate image
			run("Select None");
			print("1st Rotation...");
			run("Rotate... ", "angle="+alpha+" grid=1 interpolation=Bicubic enlarge stack");

			//calculate rotation <-- this must be done here, because the function needs the dimensions of the image after enlargement of rotated image 
			if(line_rot_calc_flag==false && use_ROI_file == false){
				line_strich_AB = rotate_line(beta,x,y);
				line_strich_CD = rotate_line(beta,v,w);
				print("Calculated scaled carthesian rotation!");
				print("************************************");
			}	
			else if(line_rot_calc_flag==false && use_ROI_file==true){
				print(line_strich_AB[0]);
				print(line_strich_AB[2]);
				print(line_strich_CD[1]);
				print(line_strich_CD[3]);
				Array.print(line_strich_AB);
				Array.print(line_strich_CD);
				print("Loaded scaled carthesian rotation!");
				print("************************************");
			}
	
			if(line_rot_calc_flag == false){
				upper_Lx = line_strich_AB[0];
				upper_Ly = line_strich_CD[3];
				width = line_strich_AB[2]-line_strich_AB[0];
				height = line_strich_CD[1]-line_strich_CD[3];
	
				if (height<0){
					upper_Lx = line_strich_AB[0];
					upper_Ly = line_strich_CD[1];
					height = line_strich_CD[3]-line_strich_CD[1];
					print("Width defined from right to left.");
				}
				else{
					print("Width defined from left to right.");
				}
				print("************************************");
				print("Rotated rectangle will be drawn as follows");
				print('upper_Lx = '+upper_Lx);
				print('upper_Ly = '+upper_Ly);
				print('width = '+width);
				print('height = '+height);
				print('after image rotation of '+alpha+'°');
				print("************************************");
				line_rot_calc_flag = true;
			}
			
			makeRectangle(upper_Lx, upper_Ly, width, height);
			//waitForUser("ok");
			print("Cropping...");
			run("Crop");
			print("************************************");
		}
		else if(crop_xy == true){
			makeSelection("polygon", x, y);
			print("Cropping...");
			run("Crop");
			print("************************************");
		}
		run("Properties...", "unit=um pixel_width="+px_size+" pixel_height="+px_size+" voxel_depth="+px_size);
		print("2nd Rotation...");
		run("Rotate 90 Degrees Left");
		print("************************************");
		//*************
	}
}

number_output_images = last_image-first_image; //must count files instead because if z cropping is deactivated, these numbers don't exist

print("Image transformations done!");
print("************************************");

if(memory == false){
	print("Opening target sequence...");
	run("Image Sequence...", "open=" + target_dir + " number=0 starting=1 increment=1 scale=100 file=tif sort"); //load 32bit ROI tifs
	print("Target sequence opened!");
	print("************************************");
}

title = getTitle();


if(normalize_bg == false){
	if(enhance_contrast == true){
		print("Enhancing contrast (0.00001% sat.)...");
		run("Enhance Contrast...", "saturated=0.1 process_all use");
	}
}

if (bitDepth() != 8){
	print("************************************");
	print("Converting to 8-bit...");
	run("8-bit");
}

if(normalize_bg == true){
	print("Normalizing background stack intensity...");
	Stack.getDimensions(width_, height_, channels_, slices_, frames_);
	middle_slice = slices_/2;
	setSlice(middle_slice);
	run("Stack Contrast Adjustment", "is");
	rename(specimen_number+"_"+species_name+"_"+ROI_name); // Stack normailizing plugin renames the stack window to 'compensate_xxx'
	if(enhance_contrast == true){
		print("Enhancing contrast (0.1% sat.)...");
		run("Enhance Contrast...", "saturated=0.1 process_all use");
	}
}

run("Properties...", "unit=um pixel_width=px_size pixel_height=px_size voxel_depth=px_size");
if(save_as_stack == true){
	print("************************************");
	//if(normalize_bg == false){
		//print("Saving stack images...");
		//run("Image Sequence... ", "format=TIFF use save="+target_dir+dir_sep+"jo.tif"); ////save 8bit ROI tifs || use <- uses slice labes --> x.tif becomes <slicename>.tif
	//}
	//else {
		print("Saving  stack images...");
		run("Image Sequence... ", "format=TIFF save="+target_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+"_.tif");
	//}
	
	print("Stack images saved as 8bits. (location: "+target_dir+")");
	print("************************************");
}

// calculate if scaling is necessary later
Stack.getDimensions(width_orig, height_orig, channels, slices, frames);
o_size = width_orig*height_orig*slices/(1024*1024*1024);
print("Target directory loaded. Stack size: "+o_size+" GB.");
d = pow(d_size/o_size,1/3);
perc_d = round(100 * d);
d = perc_d/100;

// save full size analyze file in case there is no scaling necessary or in case user explicitly wishes so
if(analyze == true){
	target_dir_analyze = target_dir+dir_sep+"analyze"; //this is needed in any case (scaling or not)
	File.makeDirectory(target_dir_analyze);
}

if((analyze==true && save_full_analyze==true) || perc_d >= 100){
	print("Saving as Analyze file...");
	run("Flip Vertically", "stack");
	run("Properties...", "unit=um pixel_width="+px_size/1000+" pixel_height="+px_size/1000+" voxel_depth="+px_size/1000); //must be divided by 1000 because for some reason ImageJ multiplies with 1000 when saving as Analyze
	analyze_file= target_dir_analyze+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+".img";
	run("Analyze... ", "save=analyze_file");
	print("Analyze file saved! ("+analyze_file+")");
	run("Properties...", "unit=um pixel_width="+px_size+" pixel_height="+px_size+" voxel_depth="+px_size); //changing back
	run("Flip Vertically", "stack");
	print("************************************");
}

if(wavefront == true){
		print("Creating wavefront mesh (resample = "+resample+").");
		print("This may take some minutes...");
		Stack.getDimensions(width, height, channels, slices, frames);
		stack_z_center = slices/2;
		setSlice(stack_z_center);
		run("Set Measurements...", "modal redirect=None decimal=0");
		List.setMeasurements();
		modal = List.getValue("Mode");
		run("Subtract...", "value="+modal+" stack");
		run("Make Binary", "method=Default background=Default");

		if(scale_perc<100){
			wavefront_file= target_dir_analyze+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+"_res"+resample+"_sc"+scale_perc+".obj";
			run("Wavefront .OBJ ...", "stack="+title_scaled+" threshold=2 resampling="+resample+" red green blue save=wavefront_file");
		}
		else{
			wavefront_file= target_dir_analyze+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+"_res"+resample+".obj";
			run("Wavefront .OBJ ...", "stack="+title+" threshold=2 resampling="+resample+" red green blue save=wavefront_file");
		}
		
		print("Wavefront mesh created! ("+wavefront_file+")");
		print("************************************");
	}
//close();
//--------------------------------------

if(memory == true){
	print("************************************");
	print("Loading "+target_dir+"...");
	run("Image Sequence...", "open=target_dir file=tif sort"); 
}

if(checkpoint==true){
	print("************************************");
	//print("Loading target directory for checkpoint file...");
	//run("Image Sequence...", "open=target_dir file=tif"); 
	
	if(perc_d < 100){
		print("Scaling stack to "+perc_d+"% to reach stack size of ~"+d_size+" GB...");
		run("Scale...", "x="+d+" y="+d+" z="+d+" interpolation=Bicubic average process create");
		getPixelSize(unit_, px_size, ph, pd);
		print("New px size = "+px_size+" um.");
		tiff_name = target_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+"_red"+perc_d;
		file_name = specimen_number+"_"+species_name+"_"+ROI_name+"_red"+perc_d+".tif\" ";
	}
	else{
		print("No scaling necessary; stack is already smaller than ~"+d_size+" GB.");
		tiff_name = target_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name;
		file_name = specimen_number+"_"+species_name+"_"+ROI_name+".tif\" ";
		print("************************************");
	}

	print("************************************");
	print("Saving stack as "+tiff_name+".tif for Checkpoint landmarks...");
	saveAs("Tiff", tiff_name);
	print("Saved stack.");
	print("************************************");
	
	checkpoint_file = File.open(target_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+".ckpt.");
	print(checkpoint_file, "Version 5");
	print(checkpoint_file, "Stratovan Checkpoint (TM)");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Specimen Information]");
	print(checkpoint_file, "Name: "+parent_dir_name+".ckpt");
	print(checkpoint_file, parent_dir_name);
	print(checkpoint_file, "Birthdate: ");
	print(checkpoint_file, "Sex: ");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Specimen Study]");
	print(checkpoint_file, "StudyInstanceUID: ");
	print(checkpoint_file, "StudyID: ");
	print(checkpoint_file, "StudyDate: ");
	print(checkpoint_file, "StudyTime: ");
	print(checkpoint_file, "StudyDescription: ");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Specimen Series]");
	print(checkpoint_file, "SeriesInstanceUID: ");
	print(checkpoint_file, "SeriesNumber: ");
	print(checkpoint_file, "SeriesDate: ");
	print(checkpoint_file, "SeriesTime: ");
	print(checkpoint_file, "SeriesModality: ");
	print(checkpoint_file, "SeriesProtocol: ");
	print(checkpoint_file, "SeriesPart: ");
	print(checkpoint_file, "SeriesDescription: ");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Specimen File(s)]");
	print(checkpoint_file, "NumberOfFolders: 1");
	print(checkpoint_file, "Folder: "+source_dir);
	print(checkpoint_file, "");
	print(checkpoint_file, "[Surface Information]");
	print(checkpoint_file, "NumberOfSurfaces: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Templates]");
	print(checkpoint_file, "NumberOfTemplates: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Landmarks]");
	print(checkpoint_file, "NumberOfPoints: 0");
	print(checkpoint_file, "Units: um");
	print(checkpoint_file, "");
	print(checkpoint_file, "[SinglePoints]");
	print(checkpoint_file, "NumberOfSinglePoints: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Curves]");
	print(checkpoint_file, "NumberOfCurves: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Patches]");
	print(checkpoint_file, "NumberOfPatches: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Joints]");
	print(checkpoint_file, "NumberOfJoints: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Lengths]");
	print(checkpoint_file, "NumberOfLengths: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Lines]");
	print(checkpoint_file, "NumberOfLines: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Angles]");
	print(checkpoint_file, "NumberOfAngles: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Planes]");
	print(checkpoint_file, "NumberOfPlanes: 0");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Image Stack]");
	print(checkpoint_file, "Units: um");
	print(checkpoint_file, "Spacing: "+px_size+" "+px_size+" "+px_size+" ");
	print(checkpoint_file, "NumberOfFiles: 1");
	print(checkpoint_file, "Files: \""+file_name);
	print(checkpoint_file, "");
	print(checkpoint_file, "[Contrast and Brightness]");
	print(checkpoint_file, "Width: 82");
	print(checkpoint_file, "Level: -19");
	print(checkpoint_file, "");
	print(checkpoint_file, "[Landmark Size]");
	print(checkpoint_file, "Size: 2");

	print("************************************");
	print("Saved checkpoint file as "+target_dir+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+".ckpt.");
	File.close(checkpoint_file);
	print("************************************");
}

if(perc_d < 100 && analyze==true && save_red_analyze == true){
	print("Saving as reduced Analyze file...");
	run("Flip Vertically", "stack");
	run("Properties...", "unit=um pixel_width="+px_size/1000+" pixel_height="+px_size/1000+" voxel_depth="+px_size/1000); //must be divided by 1000 because for some reason ImageJ multiplies with 1000 when saving as Analyze
	analyze_file_red = target_dir_analyze+dir_sep+specimen_number+"_"+species_name+"_"+ROI_name+"_red"+perc_d+".img";
	run("Analyze... ", "save=analyze_file_red");
	//run("Flip Vertically", "stack"); not necessary to sflip back because nothing else is done afterwards
	print("Resampled analyze file saved! ("+analyze_file_red+")");
	print("************************************");
}
//--------------------------------------

ex_time = (getTime()-start)/1000;
total_time = ROI_def_ex_time+ex_time;

print("************************************");
print("Creating ROI coordinate file ("+ROI_log_file+")...");
open_log_file = File.open(log_dir_path+dir_sep+ROI_log_file);
if(crop_rot_xy == true){
	print(open_log_file, "crop_rot");
	print(open_log_file, "px_size");
	print(open_log_file, px_size);
	print(open_log_file, "z1");
	print(open_log_file, first_image);
	print(open_log_file, "z2");
	print(open_log_file, last_image);
	print(open_log_file, "AB1x");
	print(open_log_file, line_strich_AB[0]);
	print(open_log_file, "AB1y");
	print(open_log_file, line_strich_AB[1]);
	print(open_log_file, "AB2x");
	print(open_log_file, line_strich_AB[2]);
	print(open_log_file, "AB2y");
	print(open_log_file, line_strich_AB[3]);
	print(open_log_file, "CD1x");
	print(open_log_file, line_strich_CD[0]);
	print(open_log_file, "CD1y");
	print(open_log_file, line_strich_CD[1]);
	print(open_log_file, "CD2x");
	print(open_log_file, line_strich_CD[2]);
	print(open_log_file, "CD2y");
	print(open_log_file, line_strich_CD[3]);
	print(open_log_file, "alpha");
	print(open_log_file, alpha);
	print(open_log_file, "ROI_def_time");
	print(open_log_file, ROI_def_ex_time);
	print(open_log_file, "ex_time");
	print(open_log_file, ex_time);
}
/*else if(rot_crop == true){
	print(open_log_file, "crop_xy_only"
	"px_size\n"
	px_size
	"z1"
	first_image
	"z2"
	last_image
	"x1"
	x[0]
	"y1"
	y[0]
	"x2"
	x[2]
	"y2"
	y[2]
	"ROI_def_time"
	ROI_def_ex_time
	"ex_time"
	ex_time);
}*/
File.close(open_log_file)
print("ROI coordinate file (" + ROI_log_file + ") created!");
print("************************************");

// create 3D projection to check 
setBatchMode(false);
//run("Properties...", "channels=1 slices=827 frames=1 unit=µm pixel_width=7.2727000 pixel_height=7.2727000 voxel_depth=7.2727000");
//run("3D Project...", "projection=[Brightest Point] axis=Y-Axis initial=0 total=90 rotation=45 lower=1 upper=255 opacity=0 surface=100 interior=50");
//setSlice(1);
open(target_dir,"virtual");

beep();
print("************************************");
if(error_flag==false){
	print("All done!");
}
else{
	print("All done, but with errors (several files already existetd before this process) -> Check outcome!");
}
print("************************************");
print("Specimen: "+ specimen_number + " (" + species_name + ")");
print("ROI definition time: " + ROI_def_ex_time +" s.");
print("Execution time: "+ex_time+" s.");
print("Total time: "+total_time+" s.");
print("************************************");

print("Check stack to confirm ROI.");
print("************************************");


//FUNCTIONS----------------------------------------------------------
function rotate_line(alpha,x,y){
	a_strich = rotate_point(alpha,x[0],y[0],x_center_orig,y_center_orig);
	b_strich = rotate_point(alpha,x[1],y[1],x_center_orig,y_center_orig);

	makeLine(a_strich[0],a_strich[1], b_strich[0],b_strich[1]);

	line_strich = newArray(a_strich[0], a_strich[1], b_strich[0], b_strich[1]);
	return line_strich;
}

function rotate_point(alpha,x,y,x_center_orig,y_center_orig){
	//calculate in rad
	alpha = PI/180*alpha;
	// Translate points to centre origin cartesian and radians
	x_cart = x-x_center_orig; 
	y_cart = -(y-y_center_orig);
	// Rotate point	
	x_cart_rot = (x_cart*cos(alpha))-(y_cart*sin(alpha));
	y_cart_rot = (x_cart*sin(alpha))+(y_cart*cos(alpha));
	// Translate back to imageJ coordinates
	x_strich = x_cart_rot + x_center_orig; 
	y_strich = y_center_orig-y_cart_rot;
	Stack.getDimensions(width_new, height_new, channels, slices, frames);
	x_strich = x_strich + (width_new - width_orig)/2;
	y_strich = y_strich + (height_new - height_orig)/2;
	point_strich = newArray(x_strich,y_strich);
	//print("Rotated around alpha:\n");
	//print(point_strich[0] + "/" + point_strich[1]);
	return point_strich;
}
