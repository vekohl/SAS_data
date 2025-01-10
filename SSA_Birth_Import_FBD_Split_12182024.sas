


/* Define Input Folder and Identify Input File */
%let input_folder = C:\sas_input\birth;
filename indir "&input_folder.";

data _null_;
    rc = filename('inf', "&input_folder.");
    did = dopen('inf');
    if did > 0 then do;
        input_file = dread(did, 1); 
        call symputx('input_file', input_file);
        rc = dclose(did);
    end;
    rc = filename('inf');
run;

%let input_file_path = &input_folder.\&input_file;

/* Today's Date for Folder Name */
data _null_;
    today_date = put(today(), yymmddn8.); /* Format date as YYYYMMDD */
    call symputx('today_date', today_date); /* Save date to macro variable */
run;

%let output_folder = C:\sas_output\birth\&today_date; /* Define output folder path */

/* Create the output folder */
options noxwait;
x "mkdir &output_folder";

/* Import Data */
data work.imported_data;
    infile "&input_file_path" lrecl=112 firstobs=1 truncover; /* Fixed-width file options */
    input
        Last_Name $ 1-21               /* Last Name: Columns 1–21 */
        First_Name $ 22-37             /* First Name: Columns 22–37 */
        Middle_Name $ 38-53            /* Middle Name: Columns 38–53 */
        Suffix $ 54-57                 /* Suffix: Columns 54–57 */
        DOB $ 58-65                    /* Date of Birth: Columns 58–65 */
        City_of_Birth $ 66-77          /* City of Birth: Columns 66–77 */
        State_of_Birth $ 78-79         /* State of Birth: Columns 78–79 */
        Mothers_Maiden_Name $ 80-91    /* Mother's Maiden Name: Columns 80–91 */
        SFN $ 92-102                   /* SFN: Columns 92–102 */
        SSN $ 103-112;                 /* SSN: Columns 103–112 */
run;

/* Count number of split files needed */
proc sql noprint;
    select ceil(count(*) / 400) into :num_splits from work.imported_data;
quit;

%put NOTE: Number of splits required: &num_splits.;

/* Macro to Split Data */
%macro split_and_save;
    %do i = 0 %to %eval(&num_splits. -1);
		data _null_; 
			current_date = today() + &i.; 
			formatted_date = put(current_date, yymmddn6.); 
			call symputx('split_date', formatted_date); 
		run; 

        data work.split&i.;
            set work.imported_data;
            if _n_ > (%eval((&i.*400))) and _n_ <= (%eval((&i.+1)*400));
        run;

    
        %let output_file = &output_folder.\CO&split_date..FBD;

				data _null_;
				    set work.split&i.;
				    file "&output_file" lrecl=112; /* Fixed-width record length */
				    put 
				        @1   Last_Name $char21.        /* Ensure fixed-width: 21 characters */
				        @22  First_Name $char16.       /* Ensure fixed-width: 16 characters */
				        @38  Middle_Name $char16.      /* Ensure fixed-width: 16 characters */
				        @54  Suffix $char4.            /* Ensure fixed-width: 4 characters */
				        @58  DOB $char8.               /* Ensure fixed-width: 8 characters */
				        @66  City_of_Birth $char12.    /* Ensure fixed-width: 12 characters */
				        @78  State_of_Birth $char2.    /* Ensure fixed-width: 2 characters */
				        @80  Mothers_Maiden_Name $char12. /* Ensure fixed-width: 12 characters */
				        @92  SFN $char11.              /* Ensure fixed-width: 11 characters */
				        @103 SSN $char10.              /* Adjusted to include trailing space */
				        @112 ' ';                      /* Add a single space at the end */
				run;


        /* Log the number of records in each split */
        proc sql noprint;
            select count(*) into :num_records from work.split&i.;
        quit;
        %put NOTE: File CO&split_date..FBD contains &num_records. records.;
    %end;
%mend split_and_save;

%split_and_save;
