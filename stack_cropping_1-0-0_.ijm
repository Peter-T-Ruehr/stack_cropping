/*
 * Crops image stack in 3 dimensions without having to load it into the system memory first.
 * Additional features:
 *   - user defined rotation around the z-axis of the stack
 *   - creation of log file with ROI-coordinates and rotation angle for reproducible results
 *   - optional contrast enhancement
 *   
 *   Should run on Linux, Win & iOS.
 *   
 *   v. 1.0.0
 *   
 *   Please cite the following paper when you use this macro:
 *   Rühr et al. (in rev.): Juvenile ecology drives adult morphology in two insect orders.
 *   
 *  BSD 3-Clause License
 *  Copyright (c) 2021, Peter-T-Ruehr
 *  All rights reserved.
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
 
//get source dir from user and define other directories
parent_dir_path = getDirectory("Select source Directory");
parent_dir_name = File.getName(parent_dir_path);
print("Directory: "+parent_dir_name+"...");

specimen_name = parent_dir_name;
source_dir = parent_dir_path;

//get file list from source dir
file_list_unsorted = getFileList(source_dir);

//start ROI_def_time
ROI_def_start = getTime();


print("Trying to open virtual stack from "+source_dir+"...");
open(source_dir,"virtual");
run("Out [-]");
Stack.getDimensions(width_orig, height_orig, channels, slices, frames);
setSlice(file_list_unsorted.length/2);
makeRectangle(width_orig/4, height_orig/4, width_orig/2, height_orig/2);
resetMinAndMax();
run("Enhance Contrast", "saturated=0.35");
run("Select None");


voxel_number = width_orig*height_orig*slices;
if(bitDepth() == 8){
	stack_size = voxel_number/(1024*1024*1024);
	print("Stack size: ~"+stack_size+" GB @ 8-bit.");
}
else if(bitDepth() == 16){
	stack_size = voxel_number*2/(1024*1024*1024);
	print("Stack size: ~"+stack_size+" GB @ 16-bit.");
}
else if(bitDepth() == 32){
	stack_size = voxel_number*4/(1024*1024*1024);
	print("Stack size: ~"+stack_size+" GB @ 32-bit.");
}
else{
	stack_size = voxel_number/(1024*1024*1024);
	print("Estimated stack size (unsure about bit depth): "+stack_size+" GB.");
}

x_center_orig = width_orig/2;
y_center_orig = height_orig/2;

// ask user if the stack was checked, to so he/she can decide on cropping parameters in the following dialog
setTool("rectangle");
waitForUser("Please check the stack to decide on cropping parameters. Then click Okay.\nStack is contrast-enhanced (0.3% sat.) in this preview.");

//create first settings dialog
Dialog.create("Settings");
Dialog.addMessage("___________________________________");
	Dialog.addString("Specimen name correct?", specimen_name);
	Dialog.addMessage("___________________________________");
	Dialog.addCheckbox("Crop region of interest (ROI) in x and y?", true);
	Dialog.addCheckbox("Crop region of interest (ROI) in z?", true);
	Dialog.addCheckbox("Define rotated ROI?*", true);
	Dialog.addString("Name of ROI:", "ROI");
	Dialog.addMessage("___________________________________");
	Dialog.addMessage("Current stack size: "+stack_size+" GB");
	Dialog.addNumber("Scale to: ", 280, 0, 5, "MB");
	Dialog.addMessage("___________________________________");
	Dialog.addCheckbox("Enhance contrast?", true);
	Dialog.addNumber("Saturated pixels after contr. enh.:", 0.00001, 5, 6, "%")
	Dialog.addMessage("___________________________________");
	Dialog.addString("Input format: ", ".tif", 5);
	Dialog.addMessage("___________________________________");
	Dialog.addCheckbox("Save full sized stack in addition to downsampled stack?", false);
	Dialog.addMessage("___________________________________");
	Dialog.addMessage("___________________________________");
	Dialog.addMessage("* If this option is checked, a ROI definition in x and y will be done\n  even if it is unchecked above because the rotation angle\n  is calculated from the ROI definition in x and y.");
	Dialog.addMessage("Please cite the following paper when you use this macro:\nRühr et al. (in rev.):\nJuvenile ecology drives adult morphology in two insect orders.");
	Dialog.addMessage("Current version availabla at\nhttps://github.com/Peter-T-Ruehr/stack_cropping");
	Dialog.addMessage("BSD 3-Clause License\nCopyright (c) 2021, Peter-T-Ruehr\nAll rights reserved.");
	Dialog.show();
	specimen_name = Dialog.getString();
	crop_xy = Dialog.getCheckbox();
	crop_z = Dialog.getCheckbox();
	crop_rot = Dialog.getCheckbox();
	ROI_name = Dialog.getString();
	d_size = Dialog.getNumber()/1024;  //MB/1024=GB
	enhance_contrast = Dialog.getCheckbox();
	enhance_contrast_saturation = Dialog.getNumber();
	format_in = Dialog.getString();
	save_as_stack = Dialog.getCheckbox;
	print("Working on "+" "+specimen_name+"...");

if(crop_rot == true){
	crop_xy = true;
}

//define output directory
target_dir = source_dir+dir_sep+specimen_name+"_"+ROI_name;

getPixelSize(unit_, px_size, ph, pd);

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


//DO THIS IF CROPPING AND ROTATING:
if(crop_rot==true){
	//draw first line defining anterior and fronterior edges along the axis
	setTool("line");
	waitForUser("1) Draw a line from the fronterior/dorsal edge to the posterior/ventral edge of the sample along its axis\n    with the line selection tool to define upper and lower ROI borders and the rotation angle.\n2) AFTERWARDS, click 'Ok'."); 
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

// DO THIS IF ONLY CROPPING, NOT ROTATING
else if(crop_xy == true){
	//define rectangle
	waitForUser("1) Go through your stack and draw the region of Interest (ROI)\n    with the rectangle selection tool.\n2) AFTERWARDS, click 'Ok'."); 
	getSelectionCoordinates(x, y);
}

// DO THIS IF Z-CROPPING
if(crop_z == true){
	// DO THIS IF Z-CROPPING AND ROI FILE IS NOT LOADED
	
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

//Create target directory to save tiffs in
print("Creating target directory...");
File.makeDirectory(target_dir);
log_dir_path = target_dir+dir_sep+'log';
File.makeDirectory(log_dir_path);
ROI_log_file = specimen_name+"_"+ROI_name+".log";

// START THE ACTUAL PROCESS
print("Starting work on "+" "+specimen_name+"...");
print("************************************");

setBatchMode(true);
//get starting time and define some flags
start = getTime();
error_flag = false;

line_rot_calc_flag = false;

if(crop_xy){
	else{
		print("Closing preview image...");
		run("Close");
		print("Loading stack into memory...");
		run("Image Sequence...", "open="+source_dir+" file=tif starting="+first_image+" number="+last_image-first_image+1+" sort");
	
		
		if(enhance_contrast == true){
			print("Enhancing contrast (", enhance_contrast_saturation,"% sat.)...");
			run("Enhance Contrast...", "saturated="+enhance_contrast_saturation+" process_all use");
		}
	
		if(crop_rot==true){
			//rotate image
			run("Select None");
			print("1st Rotation...");
			run("Rotate... ", "angle="+alpha+" grid=1 interpolation=Bicubic enlarge stack");
	
			//calculate rotation <-- this must be done here, because the function needs the dimensions of the image after enlargement of rotated image 
			if(line_rot_calc_flag==false){
				line_strich_AB = rotate_line(beta,x,y);
				line_strich_CD = rotate_line(beta,v,w);
				print("Calculated scaled carthesian rotation!");
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

if (bitDepth() != 8){
	print("************************************");
	print("Converting to 8-bit...");
	run("8-bit");
}

run("Properties...", "unit=um pixel_width=px_size pixel_height=px_size voxel_depth=px_size");
if(save_as_stack == true){
	print("************************************");
	print("Saving full-sized stack images...");
	
	//Create target directory to save full-sized stack images in
	print("Creating new directory...");
	target_dir_final = target_dir+dir_sep+specimen_name+"_"+ROI_name+"_"+"full_size";
	File.makeDirectory(target_dir_final);
	
	run("Image Sequence... ", "format=TIFF save="+target_dir_final+dir_sep+specimen_name+"_"+ROI_name+"_.tif");
	
	print("Stack images saved as 8bits. (location: "+target_dir_final+")");
	print("************************************");
	final_stack_name = "full";
}

// calculate if scaling is necessary later
Stack.getDimensions(width_orig, height_orig, channels, slices, frames);
o_size = width_orig*height_orig*slices/(1024*1024*1024);
print("New stack size: "+o_size/1024+" MB.");
d = pow(d_size/o_size,1/3);
perc_d = round(100 * d);
d = perc_d/100;

if(perc_d < 100){
	print("Scaling stack to "+perc_d+"% to reach stack size of ~"+d_size+" GB...");
	run("Scale...", "x="+d+" y="+d+" z="+d+" interpolation=Bicubic average process create");
	getPixelSize(unit_, px_size, ph, pd);
	print("New px size = "+px_size+" um.");
	
	//Create target directory to save full-sized stack images in
	print("Creating new directory...");
	target_dir_final = target_dir+dir_sep+specimen_name+"_"+ROI_name+"_red"+perc_d;
	File.makeDirectory(target_dir_final);
	
	run("Image Sequence... ", "format=TIFF save="+target_dir_final+dir_sep+specimen_name+"_"+ROI_name+"_red"+perc_d+"_.tif");
}
else{
	print("No scaling necessary; stack is already smaller than "+d_size+" GB.");
	if(save_as_stack == true){
		print("************************************");
		print("Stack is already saved in "+target_dir_final+".");
	}
	else{
		print("************************************");
		//Create target directory to save full-sized stack images in
		print("Creating new directory...");
		target_dir_final = target_dir+dir_sep+specimen_name+"_"+ROI_name+"_full_size";
		File.makeDirectory(target_dir_final);
		
		run("Image Sequence... ", "format=TIFF save="+target_dir_final+dir_sep+specimen_name+"_"+ROI_name+"_.tif");
		
		print("Stack images saved in: "+target_dir_final+")");
	}
	print("************************************");
}

//close();
//--------------------------------------

//--------------------------------------

ex_time = (getTime()-start)/1000;
total_time = ROI_def_ex_time+ex_time;

print("************************************");
print("Creating ROI coordinate file ("+ROI_log_file+")...");
open_log_file = File.open(log_dir_path+dir_sep+ROI_log_file);
if(crop_rot == true){
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

File.close(open_log_file)
print("************************************");
run("Close All");

setBatchMode(false);

open(target_dir_final,"virtual");

beep();
print("************************************");
if(error_flag==false){
	print("All done!");
}
else{
	print("All done, but with errors (several files already existetd before this process) -> Check outcome!");
}
print("************************************");
print("Specimen: "+ specimen_name);
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
