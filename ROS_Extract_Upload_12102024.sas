

/***********************************************************************************************
 Program:     Outgoing ROSTER file processing
 Author:      Vanessa Kohl
 Created:     [12-JUL-2024]
 Purpose:     This program processes death records from the `death` master dataset. It identifies
              records of individuals who were born outside of Colorado but died within the state.
              The program applies IJE standards for formatting, creates alias records, and merges
              these with the original dataset. The final combined data is exported for further
              processing and automatic upload.

 Data Sources:
    - `death.death&dsn` : Main death records dataset.

 Output:
    - A formatted file is exported to:
      `\\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\DraftDthROSTER\co&fn.a.ros`
    - The file is also copied to:
      `\\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\ROSTER\`

 Modifications:
    - [12-JUL-2024] - Initial creation of the program.
    - [16-JUL-2024] - Adjusted variable handling for better compatibility with IJE standards.
    - [10-DEC-2024] - Added comments for readability.

 Steps:
    1. Filter records for non-Colorado births with Colorado deaths.
    2. Apply date filters using `state_register_date`.
    3. Format and assign variables to match IJE standards.
    4. Create alias records based on alternative names (e.g., AKA1FirstName).
    5. Merge alias records with the original dataset.
    6. Perform deduplication and additional cleaning.
    7. Export the final dataset to the draft directory and copy it to the outgoing directory.

 Notes:
    - Ensure the connection to the `death` library is active.
    - Update macro variables (`start_date`, `end_date`, `dsn`) before running.
    - Review output file paths for any network changes.

***********************************************************************************************/




/*Define macro variable for date range (filtered by state file date using these dates to start-end*/
%let start_date = '10DEC2024'd; *last run Jan 7, 2024 for 12/10/24 - 1/7/25;
%let end_date = %sysfunc(today(), yymmdd10.);

/* Set up the library pointing to the directory containing the data */
libname death base "W:\death\master";

/* Define macros and macro variables */
%let dsn=24;
%let draft_dir=\\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\DraftDthROSTER;
%let dest_path = \\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\ROSTER\;

/* Create a macro for variable lengths */
%macro var_lengths;
	length 
		STATEBTH $20 BPLACE_ST $2 GNAME $50 MIDNAME $50 LNAME $50
		STATETEXT_D $20 DSTATE $2 DOD_MO $2 DOD_DY $2 DOD_YR $4
		DOB_MO $2 DOB_DY $2 DOB_YR $4 SEX $1 FILENO $6
		DADFNAME $50 DADMIDNAME $50 DADLNAME $50 MOMGNAME $50 MOMMIDNAME $50 MOMMAIDNAME $50
		SUFF $10 DADSUFF $10 MOMSUFF $10 BLANK1 $2 DMAIDEN $50
		STATETEXT_R $28 STATEC $2 BPLACE_CT $2 DCOUNTRYC $2 COUNTRYC $2
		SSN $9 ALIAS $1 REPLACE $1 BLANK2 $29;
%mend;

/* Create a format for state codes to postal abbreviations per NCHS FIPS documentation */
proc format;
	value $StateCode
		'01' = 'AL'
		'02' = 'AK'
		'03' = 'AZ'
		'04' = 'AR'
		'05' = 'CA'
		'06' = 'CO'
		'07' = 'CT'
		'08' = 'DE'
		'09' = 'DC'
		'10' = 'FL'
		'11' = 'GA'
		'12' = 'HI'
		'13' = 'ID'
		'14' = 'IL'
		'15' = 'IN'
		'16' = 'IA'
		'17' = 'KS'
		'18' = 'KY'
		'19' = 'LA'
		'20' = 'ME'
		'21' = 'MD'
		'22' = 'MA'
		'23' = 'MI'
		'24' = 'MN'
		'25' = 'MS'
		'26' = 'MO'
		'27' = 'MT'
		'28' = 'NE'
		'29' = 'NV'
		'30' = 'NH'
		'31' = 'NJ'
		'32' = 'NM'
		'33' = 'NY'
		'34' = 'NC'
		'35' = 'ND'
		'36' = 'OH'
		'37' = 'OK'
		'38' = 'OR'
		'39' = 'PA'
		'40' = 'RI'
		'41' = 'SC'
		'42' = 'SD'
		'43' = 'TN'
		'44' = 'TX'
		'45' = 'UT'
		'46' = 'VT'
		'47' = 'VA'
		'48' = 'WA'
		'49' = 'WV'
		'50' = 'WI'
		'51' = 'WY'
		'52' = 'PR'
		'53' = 'XX'
		'54' = 'XX'
		'55' = 'XX'
		'56' = 'XX'
		'57' = 'XX'
		'.'  = 'XX'
		'99' = 'XX'
		other = 'YY';
run;

/* Query the dataset for cases where the person was born outside of Colorado but died inside Colorado */
data ROSout;
	set death.death&dsn.;
	where BirthState not in ("COLORADO") and DeathState in ('COLORADO');
	state_register_date = datepart(state_register_dt);
	format state_register_date yymmdd10.;
run;

/* Filter the dataset by state_register_dt */
data filtered_rosout;
	set rosout;
	if &start_date le state_register_date and state_register_date ge &end_date;
run;


/* Create the transformed_data dataset with the specified variable lengths and transformations */
data transformed_data;
	%var_lengths;
	set filtered_ROSout;

	/* Transform and assign the values to the new variables using substr function */
	STATEBTH = substr(BirthState, 1, 20);
	BPLACE_ST = put(birthstatecode, $statecode.);
	GNAME = substr(DecedentFirstName, 1, 50);
	MIDNAME = substr(DecedentMiddleName, 1, 50);
	LNAME = substr(DecedentLastName, 1, 50);
	STATETEXT_D = substr(DeathState, 1, 20);
	DSTATE = put(DeathStateCode, $statecode.);
	DOD_MO = substr(DeathDtMonth, 1, 2);
	DOD_DY = substr(DeathDtDay, 1, 2);
	DOD_YR = substr(DeathDtYear, 1, 4);
	DOB_MO = substr(BirthDtMonth, 1, 2);
	DOB_DY = substr(BirthDtDay, 1, 2);
	DOB_YR = substr(BirthDtYear, 1, 4);
	SEX = substr(Sex, 1, 1);
	FILENO = substr(certnum, 5, 6);
	DADFNAME = substr(FatherFirstName, 1, 50);
	DADMIDNAME = substr(FatherMiddleName, 1, 50);
	DADLNAME = substr(FatherLastName, 1, 50);
	MOMGNAME = substr(MotherMaidenFName, 1, 50);
	MOMMIDNAME = substr(MotherMaidenMName, 1, 50);
	MOMMAIDNAME = substr(MotherMaidenLName, 1, 50);
	SUFF = substr(DecedentTitle, 1, 10);
	DADSUFF = " ";
	MOMSUFF = " ";
	BLANK1 = " ";
	DMAIDEN = " ";
	STATETEXT_R = substr(residestate, 1, 50);
	STATEC = put(residestatecode, $statecode.);
	BPLACE_CT = "US";
	DCOUNTRYC = "US";
	COUNTRYC = "US";
	SSN = substr(SSN, 1, 9);
	ALIAS = "0";
	REPLACE = "0";
	BLANK2 = "0";
run;

/* Create a new dataset alias_data for alias records */
data alias_data;
	%var_lengths;
	set filtered_ROSout;

	if AKA1FirstName ne " " then
		do;
			STATEBTH = substr(BirthState, 1, 20);
			BPLACE_ST = put(birthstatecode, $statecode.);
			GNAME = AKA1FirstName;
			MIDNAME = AKA1MiddleName;
			LNAME = AKA1LastName;
			STATETEXT_D = substr(DeathState, 1, 20);
			DSTATE = put(DeathStateCode, $statecode.);
			DOD_MO = substr(DeathDtMonth, 1, 2);
			DOD_DY = substr(DeathDtDay, 1, 2);
			DOD_YR = substr(DeathDtYear, 1, 4);
			DOB_MO = substr(BirthDtMonth, 1, 2);
			DOB_DY = substr(BirthDtDay, 1, 2);
			DOB_YR = substr(BirthDtYear, 1, 4);
			SEX = substr(Sex, 1, 1);
			FILENO = substr(certnum, 5, 6);
			DADFNAME = substr(FatherFirstName, 1, 50);
			DADMIDNAME = substr(FatherMiddleName, 1, 50);
			DADLNAME = substr(FatherLastName, 1, 50);
			MOMGNAME = substr(MotherMaidenFName, 1, 50);
			MOMMIDNAME = substr(MotherMaidenMName, 1, 50);
			MOMMAIDNAME = substr(MotherMaidenLName, 1, 50);
			SUFF = substr(DecedentTitle, 1, 10);
			DADSUFF = " ";
			MOMSUFF = " ";
			BLANK1 = " ";
			DMAIDEN = " ";
			STATETEXT_R = substr(residestate, 1, 50);
			STATEC = put(residestatecode, $statecode.);
			BPLACE_CT = "US";
			DCOUNTRYC = "US";
			COUNTRYC = "US";
			SSN = substr(SSN, 1, 9);
			ALIAS = "1";
			REPLACE = "0";
			BLANK2 = "0";
			output;
		end;
run;

/* Combine the original and alias records into a single dataset */
data combined_data;
	set transformed_data alias_data;
run;

/* Further filter combined_data */
data combined_data;
	set combined_data;

	if BPLACE_ST in ("XX") then
		delete;

	if BPLACE_ST in ("YY") then
		delete;

	if GNAME = " " then
		GNAME = "UNKNOWN";
run;

/* Creates macros for date for file name*/
data _null_;
	datetime = datetime();
	format datetime datetime16.;
	call symputx('datetime',put(datetime,datetime16.));
run;

data calc_date;
	tdate = today();
	year = year(tdate);
	dy = day(tdate);
	month = month(tdate);
	mo = put(month,Z2.);
	day = put(dy,Z2.);
	yr = substr(year,11,2);
	filename = cats(yr,mo,day);
	src_filename = cats(year,day,mo);
	call symput('fn',trim(left(put(filename,$8.))));
	call symput('scfn',trim(left(put(src_filename,$8.))));
run;

proc sort data=combined_data nodupkey;
	by GNAME MIDNAME LNAME SSN STATETEXT_R;
run;

/* Export the data to a file */
data _null_;
	file "&draft_dir.\co&fn.a.ros" dsd recfm=v lrecl=675;
	set combined_data;
	put 
		STATEBTH $1-20
		BPLACE_ST $21-22
		GNAME $23-72
		MIDNAME $73-122
		LNAME $123-172
		STATETEXT_D $173-192
		DSTATE $193-194
		DOD_MO $195-196
		DOD_DY $197-198
		DOD_YR $199-202
		DOB_MO $203-204
		DOB_DY $205-206
		DOB_YR $207-210
		SEX $211-211
		FILENO $212-217
		DADFNAME $218-267
		DADMIDNAME $268-317
		DADLNAME $318-367
		MOMGNAME $368-417
		MOMMIDNAME $418-467
		MOMMAIDNAME $468-517
		SUFF $518-527
		DADSUFF $528-537
		MOMSUFF $538-547
		BLANK1 $548-549
		DMAIDEN $550-599
		STATETEXT_R $600-627
		STATEC $628-629
		BPLACE_CT $630-631
		DCOUNTRYC $632-633
		COUNTRYC $634-635
		SSN $636-644
		ALIAS $645-645
		REPLACE $646-646
		BLANK2 $647-675;
run;

option noxwait;
 x "copy \\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\DraftDthROSTER\co&fn.a.ros* 
         \\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\ROSTER\";
run;
