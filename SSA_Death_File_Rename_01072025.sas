
%let in_path = C:\sas_input\death; 
%let out_path = C:\sas_output;
/* V:\VITAL RECORDS\Program Support\RDI Unit\Statistical Analyst\SSA Data Sharing\Death Sent to SSA; */

/* Use quotes in the command to handle spaces and special characters */
filename filelist pipe "dir /b ""&in_path""";

/* Step 1: Read file names from the directory */
data files;
    infile filelist truncover;
    input filename $100.;
    length oldname newname copy_command $300;

    /* Clean and prepare full paths for copying */
    filename = strip(filename); /* Remove trailing spaces */
    oldname = cats("&in_path\", filename); /* Full path of the original file */
    
    /* Extract and reformat the date */
    mmdd = substr(filename, 6, 4); /* Extract MMDD */
	yyyy = input(substr(filename, 11, 4), 4.); /* Extract YYYY from filename */

	/* Determine the YYMMDD based on the YYYY filename */
	if yyyy = 2024 then yymmdd = cats('24', mmdd);
	else yymmdd = substr(filename, 4, 6); 
    newname = cats("&out_path.\SCO.", yymmdd, ".DTH"); /* New name in the output directory */

    /* Construct the copy command */
    copy_command = catt('copy "', strip(oldname), '" "', strip(newname), '"');
    put "Generated Copy Command: " copy_command; /* Log the command for debugging */
run;

/* Step 2: Copy files to the new directory with new names */
data _null_;
    set files;
    call system(copy_command); /* Execute the copy command */
    if _n_ = 1 then put "Executing Copy Commands:";
    put copy_command; /* Log executed command */
run;
