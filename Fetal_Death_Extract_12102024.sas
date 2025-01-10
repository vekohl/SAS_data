

/***********************************************************************************************
 Program:     Fetal Death Data Extraction for NCHS
 Author:      Vanessa Kohl
 Date:        July 2024
 Purpose:     This program extracts fetal death data from an Access database, processes and formats
              the data to meet the requirements for the NCHS contractual agreement, and exports it 
              as a file for submission to NCHS. 

 Libraries:
    - `san` : Points to the directory where vital statistics location data is stored.

 Input Data:
    - Access database located at: 
      "\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\fetaldthdata_2007.accdb"
    - Access tables: 
      - `tblFetalDth2015` (main fetal death data)
      - `tblCtryState` (country/state codes)
      - `tblfacility` (facility information)

 Output:
    - Final data file: Exported to NCHS at `c:\sas_output\fetal\co[year][file].fet`
    - Quality Control Reports: PDF and Excel reports summarizing data completeness and discrepancies, saved in the Quality folder within the directory.

 Steps:
    1. **Directory Scan**: Scans the target directory for the latest fetal death files.
    2. **Data Import**: Imports relevant tables from the Access database.
    3. **Quality Control**: Sorts and audits the `certnum` field for missing or out-of-sequence values.
    4. **Data Transformation**: Applies required transformations and joins for merging location and facility details.
    5. **Final Export**: Creates the final dataset with only NCHS-required variables, exports it to `.fet` format, and copies it to the NCHS Outbound folder.
    6. **Audit Reporting**: Generates PDF and Excel reports for numeric value missingness and sequence checks.

 Modifications:
    - [Date: November 2024] - Recovered created.
    - [Additional dates and changes should be added here as the program evolves.]

 Notes:
    - Ensure the Access database and required libraries are accessible.
    - Only fetal death data for the specified year (`year` macro parameter) is extracted.
    - Update this program to include STEVE fields as needed.

***********************************************************************************************/

/*CHECK FOR ANY 2024 RECORDS*/

/**************   Date: August 2015                                 
/*Used to extract the Fetal Death Data from the ACCESS Db 
/*Created to satisfy the NCHS contractual agreement       
/*Creates exportable file to send to NCHS/STEVE           
/*Currently captures ONLY NCHS fields NOT STEVE             
/*                                              *********/

libname san "W:\vsdata";/*Library Set up*/
%macro fetalupdate (year);

filename pipedir pipe ' dir "\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\Files\" /S' lrecl=5000;

data indata;
today=today(); format today mmddyy10.;
curyear=year(today);
infile pipedir truncover;
input line $char1000.;
length directory $1000;
retain directory;
if line =' ' or
index(upcase(line),'<DIR>') or
left(upcase(line))=:'VOLUME' then
delete;
if left(upcase(line))=:'DIRECTORY OF' then
directory=left(substr(line,index(upcase(line),'DIRECTORY OF')+12));
if left(upcase(line))=:'DIRECTORY OF' then
delete;
if input(substr(line,1,10),?? mmddyy10.) = . then
substr(line,1,10)='12/31/2999';
date=input(substr(line,1,10),?? mmddyy10.);
format date mmddyy10.;
year=year(date);
month=month(date);
day=day(date);
if index(upcase(line),'FET');
if year(date) = 2999 then delete;
run;

proc sort data=indata;
by year month day;
run;

data select_file; 
 set indata; 
  by year month day;
  length filenum $3;
 yr=substr(line,42,2); 
 if yr EQ "&year";
 filenum=substr(line,44,3);
 fnum = input (filenum, best.);
 format fnum z3.;
 nextfile=fnum+1; format nextfile z3.;
 n_file=put(nextfile,z3.);
 folder=substr(directory,60,8);
 ndate=date+7;
 cdate=today;
 n_dayy=day(ndate); 
 n_day=put(n_dayy,z2.);
 c_dayy=day(cdate);
 c_day=put(c_dayy,z2.);
 n_monthh=month(ndate);
 n_month=put(n_monthh,z2.);
 c_monthh=month(cdate);
 c_month=put(c_monthh,z2.);
 n_year=year(ndate);
 c_year=year(cdate);
 nextfolder=cats(n_month,n_day,n_year);
 currfolder=cats(c_month,c_day,c_year);
 call symput('targetfldr',put(folder,$8.));
 call symput('yr',put(yr,$2.));
 call symput('n_file',put(n_file,$3.));
 call symput('nextfldr',put(nextfolder,$8.));
 call symput('currfldr',put(currfolder,$8.));
 drop n_dayy n_monthh c_dayy c_monthh;
 filename=cat('co',"&year",n_file,'a');
 call symput('filename',put(filename,$8.));
 run; 

%put &filename; 

proc sort data = select_file; by yr n_file; run; 

 data select_year; 
  set select_file;
   by yr;  
   if last.yr then output;
 run;

PROC IMPORT OUT= WORK.fetalDth2015   
            DATATABLE= "tblFetalDth2015" 
            DBMS=ACCESS REPLACE;
     DATABASE="\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\fetaldthdata_2007.accdb"; 
     SCANMEMO=YES;
     USEDATE=NO; 
     SCANTIME=YES;
RUN; 
PROC IMPORT OUT= WORK.tblCtryState   
            DATATABLE= "tblCtryState" 
            DBMS=ACCESS REPLACE;
     DATABASE="\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\fetaldthdata_2007.accdb"; 
	 SCANMEMO=YES;
     USEDATE=NO; 
     SCANTIME=YES;
RUN;
PROC IMPORT OUT= WORK.tblfacility  
            DATATABLE= "tblfacility" 
            DBMS=ACCESS REPLACE;
     DATABASE="\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\fetaldthdata_2007.accdb"; 
	 SCANMEMO=YES;
     USEDATE=NO; 
     SCANTIME=YES;
RUN;

/*Check for missing or out of sequence SFN's*/
proc sort data = fetalDth2015; 
 by certnum;
run;

data tmp1; 
 set fetalDth2015 (keep=certnum CertCCYY);
  if CertCCYY EQ ("20&year");
  cnum = certnum * 1;
  cknum = lag(cnum);
  calc = cknum - cnum;
run; 

proc sort data = san.states out = states1 (rename=(state=st_abr)); by fips; run; 
proc sort data = san.statecodes out = states2; by fips; run; 

data states_info; 
 merge states1 (in=a)
       states2 (in=b); 
	    by fips;

		if state NE ' ';
run; 

/*Start preparing of fetal death extract */
/*****************************************/

data prep;
 set fetaldth2015; 
  if voidflag NE ' ' then delete;

  if CertCCYY EQ ("20&year");

  tod=timepart(EventDateTime); format tod time8.;
  hh=hour(tod); format hh Z2.;
  mm=minute(tod); format mm Z2.;
  hhchar=put(hh, z2.);
  mmchar=put(mm, z2.);
  length time $4;
  time=cats(hhchar,mmchar); 

  citycode = MthrResCityCode*1;
  countycode = MthrResCountyCode*1;
  statecode = MthrResStateCode*1;

  if FetusWeightUnit = 2 then do;
   pounds = substr(FetusWeight,1,2) * 1;
   ounces = substr(FetusWeight,3,4) * 1;
   R=pounds*453.592;
   S=ounces*28.35;
   G=R+S; grams = int(G);
  end;

run; 

proc sql;
	create table prepa as
		select * 
		 from prep as a 
		  left join tblctrystate as tcs on a.MotherBirthPlace=tcs.CtryStateCode
   		  left join san.cocity94 as ccod on a.citycode=ccod.city and a.countycode=ccod.coor
          left join san.counties as cnty on a.countycode=cnty.coor
          left join states_info as state on a.statecode=state.VSCode
          left join tblfacility as facility on a.facilitycode=facility.FacilityCode;
quit; 

data export;
length fdod_yr 4 fileno $6 Auxno $12 fsex $1 cntyo 3 limits $1 marn $1 methnic5 $20
       mrace16-mrace23 $30 attend $1 wic $1;
 set prepa;
           fdod_yr=CertCCYY*1;
           dstate='CO';
		   certn=certnum*1;
		   fileno=put(input(certn,best12.),z6.);
           Void=0;
           Auxno=' ';
		   td=time; if time = ' ' then td = '9999'; if time = '2400' then td= '0000'; drop time;
           fsex=sex;
		   fdod=datepart(eventdatetime);
		   fdod_mo=month(fdod); format fdod_mo Z2.;
		   fdod_dy=day(fdod); format fdod_dy Z2.;
           cntyo=(OccurCountyCode*2)-1; format cntyo Z3.; /*FIPS County Cd*/
           dplace = placeofdelivery; format dplace 1.; if dplace = . then dplace = 9;
           fnpi = facilityid;
		   sfn=put(input(facilitycode,best4.),z4.);
		   mdob=datepart(MthrBirthDate);
		   mdob_yr=year(mdob); if mdob_yr = . then mdob_yr = 9999;
		   mdob_mo=month(mdob); format mdob_mo Z2.; if mdob_mo = . then mdob_mo = 99;
		   mdob_dy=day(mdob); format mdob_dy Z2.; if mdob_dy = . then mdob_dy = 99;
           mage_bypass = 0;

           length bplacec_st_ter $2; 
                  bplacec_st_ter = CtryStateAbrv; 
		          if CtryStateCode = '57' then bplacec_st_ter = 'XX';
				  if bplacec_st_ter = ' ' then bplacec_st_ter = 'ZZ';

           length bplacec_cnt $2; 
		          bplacec_cnt = 'ZZ';
                  if bplacec_st_ter NOT IN ('XX','ZZ') then bplacec_cnt = 'US'; 
                  if bplacec_st_ter IN ('XX') then bplacec_cnt = 'MX';                   

           length cityc $5 city_d $28; 
		          cityc = '99999'; 
				  if st_abr EQ 'CO' then do; cityc = cocity; city_d=cityname; end;
 
           length countyc $3 cnty_d $28; 
                  countyc = '999';   
				  if st_abr EQ 'CO' then do; countyc = fipstxt; cnty_d=upcase(cntyname); end;

           length statec $2; 
                  statec = 'ZZ';
				  if st_abr NE ' ' then statec = st_abr;

           countryc='ZZ';
		          if st_abr NE ' ' then countryc = 'US';

		   length hosp_d $50;
		          if st_abr EQ 'CO' then do; if facilityname=' ' then hosp_d='UNKNOWN'; else hosp_d=facilityname; end;

		   length countytxt $28;
		          countytxt=' ';
				  if st_abr EQ 'CO' then do; countytxt=upcase(cntyname); end;

		   length citytxt $28; 
		          citytxt=' '; 
				  if st_abr EQ 'CO' then do; citytxt=cityname; end;
 
           length statetxt $28; 
                  statetxt=' ';
				  if st_abr NE ' ' then statetxt = state;
		   
		   length cntrytxt $28;
                  cntrytxt=' ';
				  if st_abr NE ' ' then cntrytxt='UNITED STATES';

           predir=MthrResStreetDir;
           postdir=' '; 
		   stdesig=' ';

		   Address=left(upcase(compbl(left(MthrResStreetNum)||" "||(MthrResStreetDir)||" "||left(MthrResStreetName)||" "||left(MthrResStreetAptNum))));

           limits=MthrResCityLimit;
		   fdob=datepart(FthrBirthDate);
		   fdob_yr=year(fdob); if fdob_yr = . then fdob_yr = 9999;
		   fdob_mo=month(fdob); format fdob_mo Z2.; if fdob_mo = . then fdob_mo = 99;
		   fdob_dy=day(fdob); format fdob_dy Z2.; if fdob_dy = . then fdob_dy = 99;
           fage_bypass=0;
           mare='U';
           marn=MthrMarried; if MthrMarried = 'C' then marn = 'U';
           length filler1 $1; filler1 = '';
           meduc=MotherEducation; if meduc = . then meduc=9;
           meduc_bypass=0;

	/*--1;"No, not Spanish/Hispanic/Latina";2;"Yes, Mexican, Mexican American, Chicana";3;"Yes, Puerto Rican";4;"Yes, Cuban";5;"Yes, Other Spanish/Hispanic/Latina";6;"Unknown"*/
		   if Motherhispanic IN (2) and NOT (.) then methnic1 = 'H'; else methnic1 = 'N'; 
            if Motherhispanic = . then methnic1 = 'U';
           if Motherhispanic IN (3) and NOT (.) then methnic2 = 'H'; else methnic2 = 'N'; 
            if Motherhispanic = . then methnic2 = 'U';
           if Motherhispanic IN (4) and NOT (.) then methnic3 = 'H'; else methnic3 = 'N'; 
            if Motherhispanic = . then methnic3 = 'U';
           if Motherhispanic IN (5) and NOT (.) then methnic4 = 'H'; else methnic4 = 'N'; 
            if Motherhispanic = . then methnic4 = 'U';

           methnic5=MotherHispanicOther;

		   if MotherRaceWhite = -1 then mrace1 = 'Y'; else mrace1 = 'N'; 
	       if MotherRaceBlack = -1 then mrace2 = 'Y'; else mrace2 = 'N'; 
		   if MotherRaceAmerInd = -1 then mrace3 = 'Y'; else mrace3 = 'N';
		   if MotherAsianInd = -1 then mrace4 = 'Y'; else mrace4 = 'N';
 		   if MotherRaceChinese = -1 then mrace5 = 'Y'; else mrace5 = 'N';
		   if MotherRaceFilipino = -1 then mrace6 = 'Y'; else mrace6 = 'N';
 		   if MotherRaceJapanese = -1 then mrace7 = 'Y'; else mrace7 = 'N';
           if MotherRaceKorean = -1 then mrace8 = 'Y'; else mrace8 = 'N'; 
           if MotherRaceVietnamese = -1 then mrace9 = 'Y'; else mrace9 = 'N'; 
		   if MotherRaceOtherAsian = -1 then mrace10 = 'Y'; else mrace10 = 'N'; 
		   if MotherRaceNativeHawaiian = -1 then mrace11 = 'Y'; else mrace11 = 'N'; 
           if MotherRaceGuamanian = -1 then mrace12 = 'Y'; else mrace12 = 'N';
           if MotherRaceSamoan = -1 then mrace13 = 'Y'; else mrace13 = 'N'; 
           if MotherRaceOtherPacIsland = -1 then mrace14 = 'Y'; else mrace14 = 'N'; 
           if MotherRaceOther = -1 then mrace15 = 'Y'; else mrace15 = 'N'; 

           mrace16 = MotherTribe; 
           mrace17 = ' ';
           mrace18 = MotherRaceOtherAsianDesc; 
           mrace19 = ' ';
           mrace20 = MotherRaceOtherPacIslandDesc; 
           mrace21 = ' ';
           mrace22 = MotherRaceOtherDesc; 
           mrace23 = ' ';
           mrace1e = ' ';
		   mrace2e = ' ';
           mrace3e = ' ';
           mrace4e = ' ';
           mrace5e = ' ';   
           mrace6e = ' ';
           mrace7e = ' ';
           mrace8e = ' ';
           mrace16c =' ';
           mrace17c =' ';
           mrace18c =' ';
           mrace19c =' ';
           mrace20c =' ';
           mrace21c =' ';
           mrace22c =' ';  
           mrace23c =' ';
           attend=AttnTypeCode; if AttnTypeCode = . then attend = 9;
		   tran=MotherMaternalMedical; if MotherMaternalMedical = ' ' then tran = 'U';

           dofp=datepart(DateFirstPrenatalCareVisit);
		   dofp_yr=year(dofp); /*if dofp_yr = . then dofp_yr = 9999;*/
		   dofp_mo=month(dofp); format dofp_mo Z2.; /*if dofp_mo = . then dofp_mo = 99;*/
		   dofp_dy=day(dofp); format dofp_dy Z2.; /*if dofp_dy = . then dofp_dy = 99;*/
           drop dofp;

           if PrenatlCareBeginMonth = '0' then do; dofp_yr = 8888; dofp_mo=88; dofp_dy=88; end;
		   if PrenatlCareBeginMonth = '-' then do; dofp_yr = 9999; dofp_mo=99; dofp_dy=99; end; 
		   if DateFirstPrenatalCareVisit = . and PrenatlCareBeginMonth NOT IN ('0','-') then do; dofp_yr = 9999; dofp_mo=99; dofp_dy=99; end; 
           
           dolp=datepart(DateLastPrenatalCareVisit);
		   dolp_yr=year(dolp); if dolp_yr = . then dolp_yr = 9999;
		   dolp_mo=month(dolp); format dolp_mo Z2.; if dolp_mo = . then dolp_mo = 99;
		   dolp_dy=day(dolp); format dolp_dy Z2.; if dolp_dy = . then dolp_dy = 99;
           drop dolp;

           nprev=PrenatlVisits*1; format nprev Z2.; if nprev=. then nprev=99;
           nprev_bypass=0;
           hft=MotherHeightFeet; if hft IN (0,.) then hft = 9;
		   hin=MotherHeightInches; format hin Z2.; if hin=. or hin GT 11 then hin = 99;
           hgt_bypass=0;
		   
           pwgt=MotherPregnancyWeight; format pwgt Z3.; if pwgt = . or pwgt GT 400 then pwgt = 999;
           pwgt_bypass=0;

           dwgt=MotherDeliveryWeight; format dwgt Z3.; if dwgt = . then dwgt = 999;
           dwgt_bypass=0;

           wic=MotherWIC; if wic = ' ' then wic = 'U';
           
		   plbl = LiveBirthNowLive *1; format plbl Z2.; if plbl = . then plbl = 99;
           plbd = LiveBirthNowDead *1; format plbd Z2.; if plbd = . then plbd = 99;
           popo = OtherTermination *1; format popo Z2.; if popo = . then popo = 99;
           
           llbd=datepart(LastLiveBirthDate);
		   mllb=month(llbd); format mllb Z2.; if mllb = . then mllb = 99; 
                if plbl IN (99) then mllb = 99;
				if plbd IN (99) then mllb = 99;
				if plbl IN (00) and plbd IN (00) then mllb = 88;
		   yllb=year(llbd); if yllb = . then yllb = 9999; 
                if plbl IN (99) then yllb = 9999;
				if plbd IN (99) then yllb = 9999;
				if plbl IN (00) and plbd IN (00) then yllb = 8888;
		   drop llbd;

           otd=datepart(OtherTermDate);
		   mopo=month(otd); format mopo Z2.; if mopo = . then mopo = 99;
		   yopo=year(otd); if yopo = . then yopo = 9999;
		   drop otd;

		   /*--packs vs cigs*/
		   /*cigpn*/
		   if CigThreeMonthBefore IN (.,99) and 0 <= CigPackThreeMonthBefore <= 98 then CigThreeMonthBefore = 0;
		   if CigPackThreeMonthBefore IN (.,99) and 0 <= CigThreeMonthBefore <= 98 then CigPackThreeMonthBefore = 0;
		   cigpn =  sum (of CigThreeMonthBefore,(CigPackThreeMonthBefore*20));format cigpn Z2.; if cigpn = . then cigpn = 99;
           if CigThreeMonthBefore = 99 and CigPackThreeMonthBefore = 99 then cigpn = 99;

		   /*cigfn*/
           if CigFirstThreeMonth IN (.,99) and 0 <= CigPackFirstThreeMonth <= 98 then CigFirstThreeMonth = 0;
		   if CigPackFirstThreeMonth IN (.,99) and 0 <= CigFirstThreeMonth <= 98 then CigPackFirstThreeMonth = 0;
		   cigfn =  sum (of CigFirstThreeMonth,(CigPackFirstThreeMonth*20));format cigfn Z2.; if cigfn = . then cigfn = 99;
           if CigFirstThreeMonth = 99 and CigPackFirstThreeMonth = 99 then cigfn = 99;

		   /*cigsn*/
           if CigSecondThreeMonth IN (.,99) and 0 <= CigPackSecondThreeMonth <= 98 then CigSecondThreeMonth = 0;
		   if CigPackSecondThreeMonth IN (.,99) and 0 <= CigSecondThreeMonth <= 98 then CigPackSecondThreeMonth = 0;
		   cigsn =  sum (of CigSecondThreeMonth,(CigPackSecondThreeMonth*20));format cigsn Z2.; if cigsn = . then cigsn = 99;
           if CigSecondThreeMonth = 99 and CigPackSecondThreeMonth = 99 then cigsn = 99;

		   /*cigln*/
           if CigThirdThreeMonth IN (.,99) and 0 <= CigPackThirdThreeMonth <= 98 then CigThirdThreeMonth = 0;
		   if CigPackThirdThreeMonth IN (.,99) and 0 <= CigThirdThreeMonth <= 98 then CigPackThirdThreeMonth = 0;
		   cigln =  sum (of CigThirdThreeMonth,(CigPackThirdThreeMonth*20));format cigln Z2.; if cigln = . then cigln = 99;
           if CigThirdThreeMonth = 99 and CigPackThirdThreeMonth = 99 then cigln = 99;

           dlmp=datepart(MthrLastMensesDate); 
		   dlmp_yr=year(dlmp); if dlmp_yr = . then dlmp_yr = 9999;
		   dlmp_mo=month(dlmp); format dlmp_mo Z2.; if dlmp_mo = . then dlmp_mo = 99;
		   dlmp_dy=day(dlmp); format dlmp_dy Z2.; if dlmp_dy = . then dlmp_dy = 99;
		   drop dlmp;

           if RiskDiabetesPrePregnancy = -1 then pdiab = 'Y'; else pdiab = 'N'; 							
           if RiskDiabetesGestational = -1 then gdiab = 'Y'; else gdiab = 'N';  
           if RiskHyperPrepregnancy = -1 then phype = 'Y'; else phype = 'N';
           if RiskHyperGestational = -1 then ghype = 'Y'; else ghype = 'N';
           if RiskPreviousPreTerm = -1 then ppb = 'Y'; else ppb = 'N';
           if RiskOtherPreviousPoorOutcome = -1 then ppo = 'Y'; else ppo = 'N';
           vb = ' ';
		   if RiskInfertilityTreatment = -1 then inft = 'Y'; else inft = 'N';
           if RiskPreviousCesarean = -1 then pces = 'Y'; else pces = 'N';
           npces = RiskPreviousCesareanHowMany; if npces = . then npces = 00; format npces Z2.;
           npces_bypass = 0;

		   if DXTXGonorrhea = -1 then gon = 'Y'; else gon = 'N';
		   if DXTXSyphilis = -1 then syph = 'Y'; else syph = 'N';
		   hsv = 'U';
		   if DXTXChalmydia = -1 then cham = 'Y'; else cham = 'N';
		   if DXTXListeria = -1 then lm = 'Y'; else lm = 'N';
		   if DXTXGroupBStrep = -1 then gbs = 'Y'; else gbs = 'N';
		   if DXTXCytomegalovirus = -1 then cmv = 'Y'; else cmv = 'N';
		   if DXTXParvovirus = -1 then b19 = 'Y'; else b19 = 'N';
		   if DXTXToxoplasmosis = -1 then toxo = 'Y'; else toxo = 'N';
		   if DXTXOther = -1 then otheri = 'Y'; else otheri = 'N';

           length attf $1; attf=MODForceps; if attf = ' ' then attf = 'U';
										
           length attv $1; attv=MODVacuum;  if attv = ' ' then attv = 'U';
		   
		  /*--"C";"Cephalic";"B";"Breech";"O";"Other" */
		   pres = 9;
		   if MODFetalPresentation = 'C' then pres = 1;
           if MODFetalPresentation = 'B' then pres = 2;
           if MODFetalPresentation = 'O' then pres = 3; 
           
		  /*--"S";"Vaginal/Spontaneous";"F";"Vaginal/Forceps";"V";"Vaginal/Vacuum";"C";"Cesarean"*/
		   rout = 9;
           if MODFinalRoute = 'S' then rout = 1;
           if MODFinalRoute = 'F' then rout = 2;
           if MODFinalRoute = 'V' then rout = 3;
           if MODFinalRoute = 'C' then rout = 4;

           length tlab $1; tlab = MODFinalRouteCesarean; if tlab = ' ' then tlab = 'U'; 
           length hyst $1; hyst = MODHysterotomy; if hyst = ' ' then hyst = 'U'; 

		   if rout IN (1,2,3,9) then tlab = 'X';

           if MatMorbMaternalTRansfusion = -1 then mtr = 'Y'; else mtr = 'N';
		   if MatMorb3rdor4thperineal = -1 then plac = 'Y'; else plac = 'N';
		   if MatMorbRupturedUterus = -1 then rut = 'Y'; else rut = 'N';
		   if MatMorbUnplannedHysterectomy = -1 then uhys = 'Y'; else uhys = 'N';
		   if MatMorbAdmissionICU = -1 then aint = 'Y'; else aint = 'N';
		   if MatMorbUnplannedORP = -1 then uopr = 'Y'; else uopr = 'N';

           if grams >0 then fwg = grams*1; else fwg = FetusWeight*1; format fwg Z4.;
		   fw_bypass = 0;

           owgest = EstGest*1; if owgest = . then owgest = 99;
           owgest_bypass = 0;  /*--failed*/

		   if EstimatedTimeOfFetalDeath = 'Dead at time of first assessment, labor ongoing' then etime = 'L';
		   if EstimatedTimeOfFetalDeath = 'Dead at time of first assessment, no labor ongoing' then etime = 'N';
		   if EstimatedTimeOfFetalDeath = 'Died during labor, after first assessment' then etime = 'A';
           if EstimatedTimeOfFetalDeath = 'Unknown time of fetal death' then etime = 'U';
           if EstimatedTimeOfFetalDeath = ' ' then etime = 'U';

           length autop $1;  autop=Autopsy;
		   length histop $1; histop=HistologicalPlacentalExamPerform;
		   length autopf $1; autopf=AutopsyUsedInCOD; 

		   if autop IN (" ","U") then do; 
            autop = 'P'; 
            histop = 'P'; 
            autopf = 'X'; 
           end; 

		   if histop = ' ' then histop = 'P';
		   if autopf = ' ' then autopf = 'N';

           if autop = 'N' then do; 
		    if histop = 'N' then autopf = 'X';
			if histop = 'P' then autopf = 'X';
		   end; 
		   if autop = 'P' then do; 
		    if histop = 'N' then autopf = 'X';
			if histop = 'P' then autopf = 'X';
		   end;

           plur=Plurality*1;  if plur IN (.,9) then plur = 99; format plur Z2.;
           sord=BirthOrder*1; if sord IN (.,9) then sord = 99; format sord Z2.; 
 
           fdth = 99;
           match = 999999;

           plur_bypass = 0;

		   if ANOMAnecephaly = -1 then anen = 'Y'; else anen = 'N';
		   if ANOMMeningomyelocele = -1 then mnsb = 'Y'; else mnsb = 'N';
		   if ANOMCyanotic = -1 then cchd = 'Y'; else cchd = 'N';
		   if ANOMCongenitalDiaph = -1 then cdh = 'Y'; else cdh = 'N';
		   if ANOMOmphalocele = -1 then omph = 'Y'; else omph = 'N';
		   if ANOMGastroschisis = -1 then gast = 'Y'; else gast = 'N';
		   if ANOMLimbReduction = -1 then limb = 'Y'; else limb = 'N';
		   if ANOMCleftLip = -1 then cl = 'Y'; else cl = 'N';
		   if ANOMCleftPalate = -1 then cp = 'Y'; else cp = 'N';
		   if ANOMDownSyndrome = -1 then dowt = 'C'; else dowt = 'N';
		   if ANOMChromosomal = -1 then cdit = 'C'; else cdit = 'N';
		   if ANOMHypospadias = -1 then hypo = 'Y'; else hypo = 'N';

		   /*NCHS Use Only*/
		   length r_yr $4; r_yr = '   ';
		   length r_mo $2; r_mo = ' ';
		   length r_dy $2; r_dy = ' ';
           
           somedate=today();
		   mbirth=datepart(MthrBirthDate); format mbirth mmddyy10.;
		   mager = floor((intck('month',mbirth,somedate)- (day(somedate) < day(mbirth))) / 12); 
            if mager = . then mager = 99; format mager Z2.;

		   fbirth=datepart(FthrBirthDate); format fbirth mmddyy10.;
		   fager = floor((intck('month',fbirth,somedate)- (day(somedate) < day(fbirth))) / 12); 
            if fager = . then fager = 99; format fager Z2.;

		   drop somedate mbirth fbirth; 

           if RiskHyperEclampsia = -1 then ehype = 'Y'; else ehype = 'N';
		   if RiskFertilityEnhance = -1 then inft_drg = 'Y'; else inft_drg = 'N';
		   if RiskAssistedRepro = -1 then inft_art = 'Y'; else inft_art = 'N';

		   if inft = 'N' then do; inft_drg = 'X'; inft_art = 'X'; end; 
		   
		   length dor_yr $4; dor_yr = '    ';
           length dor_mo $2; dor_mo = '  ';
           length dor_dy $2; dor_dy = '  ';

		   length filler2 $3; filler2 = '  ';

		   if CauseMembraneRupture = -1 then cod18a1 = 'Y'; else cod18a1 = 'N';
		   if CauseAbruptioPlacenta = -1 then cod18a2 = 'Y'; else cod18a2 = 'N';
		   if CausePlacentalInsuffiency = -1 then cod18a3 = 'Y'; else cod18a3 = 'N';
		   if CauseProlapsedCord = -1 then cod18a4 = 'Y'; else cod18a4 = 'N';
		   if CauseChorioamnionitis = -1 then cod18a5 = 'Y'; else cod18a5 = 'N';
		   if CauseOther = -1 then cod18a6 = 'Y'; else cod18a6 = 'N';
		   if CauseUnk = -1 then cod18a7 = 'Y'; else cod18a7 = 'N';

           length cod18a8  $60; cod18a8=CauseMaternalConditions;
           length cod18a9  $60; cod18a9=CauseOtherDesc ;
           length cod18a10 $60; cod18a10=OtherObstetrical; 
           length cod18a11 $60; cod18a11=FetalAnomaly  ;
           length cod18a12 $60; cod18a12=FetalInjury  ;
           length cod18a13 $60; cod18a13=FetalInfection ; 
           length cod18a14 $60; cod18a14=OtherFetalConditions; 

		   if OtherCauseMembraneRupture = -1 then cod18b1 = 'Y'; else cod18b1 = 'N';
		   if OtherCauseAbruptioPlacenta = -1 then cod18b2 = 'Y'; else cod18b2 = 'N';
		   if OtherCausePlacentalInsuffiency = -1 then cod18b3 = 'Y'; else cod18b3 = 'N';
		   if OtherCauseProlapsedCord = -1 then cod18b4 = 'Y'; else cod18b4 = 'N';
		   if OtherCauseChorioamnionitis = -1 then cod18b5 = 'Y'; else cod18b5 = 'N';
		   if OtherCauseOther = -1 then cod18b6 = 'Y'; else cod18b6 = 'N';
		   if OtherCauseUnk = -1 then cod18b7 = 'Y'; else cod18b7 = 'N';

           length cod18b8  $240; cod18b8=OtherCauseMaternalConditions; 
           length cod18b9  $240; cod18b9=OtherCauseOtherDesc;
           length cod18b10 $240; cod18b10=OtherOtherObstetrical;
           length cod18b11 $240; cod18b11=OtherFetalAnomaly;
           length cod18b12 $240; cod18b12=OtherFetalInjury; 
           length cod18b13 $240; cod18b13=OtherFetalInfection;
           length cod18b14 $240; cod18b14=OtherOtherFetalConditions;

           length icod  $5; icod = ' ';
           length ocod1 $5; ocod1 =' ';
           length ocod2 $5; ocod2 =' ';
           length ocod3 $5; ocod3 =' ';
           length ocod4 $5; ocod4 =' ';
           length ocod5 $5; ocod5 =' ';
           length ocod6 $5; ocod6 =' ';
           length ocod7 $5; ocod7 =' ';
		   length filler3 $1; filler3 = 'X';

		   /*2022 Revision*/
           APTNUMB=MthrResStreetAptNum;
           PREDIR=MthrResStreetDir;
           STNAME=MthrResStreetName;
           STNUM=MthrResStreetNum;
           ZIPCODE=MthrResZip;
		    /*2023 Revision*/
		   MOMFNAME=MotherFirstName;
           MOMMMID=MotherMdlInit;
           MOMLNAME=MotherLastName;

keep
FDOD_YR
DSTATE
FILENO
VOID
AUXNO
TD
FSEX
FDOD_MO
FDOD_DY
CNTYO
DPLACE
FNPI
SFN
MDOB_YR
MDOB_MO
MDOB_DY
MAGE_BYPASS
BPLACEC_ST_TER
BPLACEC_CNT
CITYC
COUNTYC
STATEC
COUNTRYC
LIMITS
FDOB_YR
FDOB_MO
FDOB_DY
FAGE_BYPASS
MARE
MARN
FILLER1
MEDUC
MEDUC_BYPASS
METHNIC1
METHNIC2
METHNIC3
METHNIC4
METHNIC5
MRACE1
MRACE2
MRACE3
MRACE4
MRACE5
MRACE6
MRACE7
MRACE8
MRACE9
MRACE10
MRACE11
MRACE12
MRACE13
MRACE14
MRACE15
MRACE16
MRACE17
MRACE18
MRACE19
MRACE20
MRACE21
MRACE22
MRACE23
MRACE1E
MRACE2E
MRACE3E
MRACE4E
MRACE5E
MRACE6E
MRACE7E
MRACE8E
MRACE16C
MRACE17C
MRACE18C
MRACE19C
MRACE20C
MRACE21C
MRACE22C
MRACE23C
ATTEND
TRAN
DOFP_MO
DOFP_DY
DOFP_YR
DOLP_MO
DOLP_DY
DOLP_YR
NPREV
NPREV_BYPASS
HFT
HIN
HGT_BYPASS
PWGT
PWGT_BYPASS
DWGT
DWGT_BYPASS
WIC
PLBL
PLBD
POPO
MLLB
YLLB
MOPO
YOPO
CIGPN
CIGFN
CIGSN
CIGLN
DLMP_YR
DLMP_MO
DLMP_DY
PDIAB
GDIAB
PHYPE
GHYPE
PPB
PPO
VB
INFT
PCES
NPCES
NPCES_BYPASS
GON
SYPH
HSV
CHAM
LM
GBS
CMV
B19
TOXO
OTHERI
ATTF
ATTV
PRES
ROUT
TLAB
HYST
MTR
PLAC
RUT
UHYS
AINT
UOPR
FWG
FW_BYPASS
OWGEST
OWGEST_BYPASS
ETIME
AUTOP
HISTOP
AUTOPF
PLUR
SORD
FDTH
MATCH
PLUR_BYPASS
ANEN
MNSB
CCHD
CDH
OMPH
GAST
LIMB
CL
CP
DOWT
CDIT
HYPO
R_YR
R_MO
R_DY
MAGER
FAGER
EHYPE
INFT_DRG
INFT_ART
DOR_YR
DOR_MO
DOR_DY
FILLER2
COD18a1
COD18a2
COD18a3
COD18a4
COD18a5
COD18a6
COD18a7
COD18a8
COD18a9
COD18a10
COD18a11
COD18a12
COD18a13
COD18a14
COD18b1
COD18b2
COD18b3
COD18b4
COD18b5
COD18b6
COD18b7
COD18b8
COD18b9
COD18b10
COD18b11
COD18b12
COD18b13
COD18b14
ICOD
OCOD1
OCOD2
OCOD3
OCOD4
OCOD5
OCOD6
OCOD7
HOSP_D
CITY_D
CNTY_D
CITYTXT
COUNTYTXT
CNTRYTXT
STATETXT
APTNUMB
PREDIR
POSTDIR
STDESIG
STNAME
STNUM
ZIPCODE
ADDRESS
MOMFNAME
MOMMMID
MOMLNAME
FILLER3
;

run;

data export2; 
RETAIN
FDOD_YR
DSTATE
FILENO
VOID
AUXNO
TD
FSEX
FDOD_MO
FDOD_DY
CNTYO
DPLACE
FNPI
SFN
MDOB_YR
MDOB_MO
MDOB_DY
MAGE_BYPASS
BPLACEC_ST_TER
BPLACEC_CNT
CITYC
COUNTYC
STATEC
COUNTRYC
LIMITS
FDOB_YR
FDOB_MO
FDOB_DY
FAGE_BYPASS
MARE
MARN
FILLER1
MEDUC
MEDUC_BYPASS
METHNIC1
METHNIC2
METHNIC3
METHNIC4
METHNIC5
MRACE1
MRACE2
MRACE3
MRACE4
MRACE5
MRACE6
MRACE7
MRACE8
MRACE9
MRACE10
MRACE11
MRACE12
MRACE13
MRACE14
MRACE15
MRACE16
MRACE17
MRACE18
MRACE19
MRACE20
MRACE21
MRACE22
MRACE23
MRACE1E
MRACE2E
MRACE3E
MRACE4E
MRACE5E
MRACE6E
MRACE7E
MRACE8E
MRACE16C
MRACE17C
MRACE18C
MRACE19C
MRACE20C
MRACE21C
MRACE22C
MRACE23C
ATTEND
TRAN
DOFP_MO
DOFP_DY
DOFP_YR
DOLP_MO
DOLP_DY
DOLP_YR
NPREV
NPREV_BYPASS
HFT
HIN
HGT_BYPASS
PWGT
PWGT_BYPASS
DWGT
DWGT_BYPASS
WIC
PLBL
PLBD
POPO
MLLB
YLLB
MOPO
YOPO
CIGPN
CIGFN
CIGSN
CIGLN
DLMP_YR
DLMP_MO
DLMP_DY
PDIAB
GDIAB
PHYPE
GHYPE
PPB
PPO
VB
INFT
PCES
NPCES
NPCES_BYPASS
GON
SYPH
HSV
CHAM
LM
GBS
CMV
B19
TOXO
OTHERI
ATTF
ATTV
PRES
ROUT
TLAB
HYST
MTR
PLAC
RUT
UHYS
AINT
UOPR
FWG
FW_BYPASS
OWGEST
OWGEST_BYPASS
ETIME
AUTOP
HISTOP
AUTOPF
PLUR
SORD
FDTH
MATCH
PLUR_BYPASS
ANEN
MNSB
CCHD
CDH
OMPH
GAST
LIMB
CL
CP
DOWT
CDIT
HYPO
R_YR
R_MO
R_DY
MAGER
FAGER
EHYPE
INFT_DRG
INFT_ART
DOR_YR
DOR_MO
DOR_DY
FILLER2
COD18a1
COD18a2
COD18a3
COD18a4
COD18a5
COD18a6
COD18a7
COD18a8
COD18a9
COD18a10
COD18a11
COD18a12
COD18a13
COD18a14
COD18b1
COD18b2
COD18b3
COD18b4
COD18b5
COD18b6
COD18b7
COD18b8
COD18b9
COD18b10
COD18b11
COD18b12
COD18b13
COD18b14
ICOD
OCOD1
OCOD2
OCOD3
OCOD4
OCOD5
OCOD6
OCOD7
HOSP_D
CITY_D
CNTY_D
CITYTXT
COUNTYTXT
CNTRYTXT
STATETXT
APTNUMB
PREDIR
POSTDIR
STDESIG
STNAME
STNUM
ZIPCODE
ADDRESS
MOMFNAME
MOMMMID
MOMLNAME
FILLER3
;
 set export;
run;

proc sort data = export2; by fileno; run; 

filename out "\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\Files\20&year\co&year.&n_file.a.fet" lrecl=6000;

data _null_; 
set export2;
file out;  
put
@	1	FDOD_YR
@	5	DSTATE
@	7	FILENO
@	13	VOID
@	14	AUXNO
@	26	TD
@	30	FSEX
@	31	FDOD_MO
@	33	FDOD_DY
@	35	CNTYO
@	38	DPLACE
@	39	FNPI
@	51	SFN
@	55	MDOB_YR
@	59	MDOB_MO
@	61	MDOB_DY
@	63	MAGE_BYPASS
@	64	BPLACEC_ST_TER
@	66	BPLACEC_CNT
@	68	CITYC
@	73	COUNTYC
@	76	STATEC
@	78	COUNTRYC
@	80	LIMITS
@	81	FDOB_YR
@	85	FDOB_MO
@	87	FDOB_DY
@	89	FAGE_BYPASS
@	90	MARE
@	91	MARN
@	92	FILLER1
@	93	MEDUC
@	94	MEDUC_BYPASS
@	95	METHNIC1
@	96	METHNIC2
@	97	METHNIC3
@	98	METHNIC4
@	99	METHNIC5
@	119	MRACE1
@	120	MRACE2
@	121	MRACE3
@	122	MRACE4
@	123	MRACE5
@	124	MRACE6
@	125	MRACE7
@	126	MRACE8
@	127	MRACE9
@	128	MRACE10
@	129	MRACE11
@	130	MRACE12
@	131	MRACE13
@	132	MRACE14
@	133	MRACE15
@	134	MRACE16
@	164	MRACE17
@	194	MRACE18
@	224	MRACE19
@	254	MRACE20
@	284	MRACE21
@	314	MRACE22
@	344	MRACE23
@	374	MRACE1E
@	377	MRACE2E
@	380	MRACE3E
@	383	MRACE4E
@	386	MRACE5E
@	389	MRACE6E
@	392	MRACE7E
@	395	MRACE8E
@	398	MRACE16C
@	401	MRACE17C
@	404	MRACE18C
@	407	MRACE19C
@	410	MRACE20C
@	413	MRACE21C
@	416	MRACE22C
@	419	MRACE23C
@	422	ATTEND
@	423	TRAN
@	424	DOFP_MO
@	426	DOFP_DY
@	428	DOFP_YR
@	432	DOLP_MO
@	434	DOLP_DY
@	436	DOLP_YR
@	440	NPREV
@	442	NPREV_BYPASS
@	443	HFT
@	444	HIN
@	446	HGT_BYPASS
@	447	PWGT
@	450	PWGT_BYPASS
@	451	DWGT
@	454	DWGT_BYPASS
@	455	WIC
@	456	PLBL
@	458	PLBD
@	460	POPO
@	462	MLLB
@	464	YLLB
@	468	MOPO
@	470	YOPO
@	474	CIGPN
@	476	CIGFN
@	478	CIGSN
@	480	CIGLN
@	482	DLMP_YR
@	486	DLMP_MO
@	488	DLMP_DY
@	490	PDIAB
@	491	GDIAB
@	492	PHYPE
@	493	GHYPE
@	494	PPB
@	495	PPO
@	496	VB
@	497	INFT
@	498	PCES
@	499	NPCES
@	501	NPCES_BYPASS
@	502	GON
@	503	SYPH
@	504	HSV
@	505	CHAM
@	506	LM
@	507	GBS
@	508	CMV
@	509	B19
@	510	TOXO
@	511	OTHERI
@	512	ATTF
@	513	ATTV
@	514	PRES
@	515	ROUT
@	516	TLAB
@	517	HYST
@	518	MTR
@	519	PLAC
@	520	RUT
@	521	UHYS
@	522	AINT
@	523	UOPR
@	524	FWG
@	528	FW_BYPASS
@	529	OWGEST
@	531	OWGEST_BYPASS
@	532	ETIME
@	533	AUTOP
@	534	HISTOP
@	535	AUTOPF
@	536	PLUR
@	538	SORD
@	540	FDTH
@	542	MATCH
@	548	PLUR_BYPASS
@	549	ANEN
@	550	MNSB
@	551	CCHD
@	552	CDH
@	553	OMPH
@	554	GAST
@	555	LIMB
@	556	CL
@	557	CP
@	558	DOWT
@	559	CDIT
@	560	HYPO
@	561	R_YR
@	565	R_MO
@	567	R_DY
@	569	MAGER
@	571	FAGER
@	573	EHYPE
@	574	INFT_DRG
@	575	INFT_ART
@	576	DOR_YR
@	580	DOR_MO
@	582	DOR_DY
@	584	FILLER2
@	587	COD18a1
@	588	COD18a2
@	589	COD18a3
@	590	COD18a4
@	591	COD18a5
@	592	COD18a6
@	593	COD18a7
@	594	COD18a8
@	654	COD18a9
@	714	COD18a10
@	774	COD18a11
@	834	COD18a12
@	894	COD18a13
@	954	COD18a14
@	1014	COD18b1
@	1015	COD18b2
@	1016	COD18b3
@	1017	COD18b4
@	1018	COD18b5
@	1019	COD18b6
@	1020	COD18b7
@	1021	COD18b8
@	1261	COD18b9
@	1501	COD18b10
@	1741	COD18b11
@	1981	COD18b12
@	2221	COD18b13
@	2461	COD18b14
@	2701	ICOD
@	2706	OCOD1
@	2711	OCOD2
@	2716	OCOD3
@	2721	OCOD4
@	2726	OCOD5
@	2731	OCOD6
@	2736	OCOD7
@   2905    HOSP_D
@   3111    CNTY_D
@   3139    CITY_D
@   3257    MOMFNAME
@   3357    MOMLNAME
@   3467    MOMMMID
@   3577    STNUM
@   3587    PREDIR
@   3597    STNAME
@   3647    STDESIG
@   3657    POSTDIR
@   3667    APTNUMB
@   3674    ADDRESS
@   3724    ZIPCODE
@   3733    COUNTYTXT
@   3761    CITYTXT
@   3789    STATETXT
@   3817    CNTRYTXT
@   6000    FILLER3
;
run; 

filename out2 "c:\sas_output\fetal\co&year.&n_file.a.fet" lrecl=6000;

data _null_; 
set export2;
file out2;  
put
@	1	FDOD_YR
@	5	DSTATE
@	7	FILENO
@	13	VOID
@	14	AUXNO
@	26	TD
@	30	FSEX
@	31	FDOD_MO
@	33	FDOD_DY
@	35	CNTYO
@	38	DPLACE
@	39	FNPI
@	51	SFN
@	55	MDOB_YR
@	59	MDOB_MO
@	61	MDOB_DY
@	63	MAGE_BYPASS
@	64	BPLACEC_ST_TER
@	66	BPLACEC_CNT
@	68	CITYC
@	73	COUNTYC
@	76	STATEC
@	78	COUNTRYC
@	80	LIMITS
@	81	FDOB_YR
@	85	FDOB_MO
@	87	FDOB_DY
@	89	FAGE_BYPASS
@	90	MARE
@	91	MARN
@	92	FILLER1
@	93	MEDUC
@	94	MEDUC_BYPASS
@	95	METHNIC1
@	96	METHNIC2
@	97	METHNIC3
@	98	METHNIC4
@	99	METHNIC5
@	119	MRACE1
@	120	MRACE2
@	121	MRACE3
@	122	MRACE4
@	123	MRACE5
@	124	MRACE6
@	125	MRACE7
@	126	MRACE8
@	127	MRACE9
@	128	MRACE10
@	129	MRACE11
@	130	MRACE12
@	131	MRACE13
@	132	MRACE14
@	133	MRACE15
@	134	MRACE16
@	164	MRACE17
@	194	MRACE18
@	224	MRACE19
@	254	MRACE20
@	284	MRACE21
@	314	MRACE22
@	344	MRACE23
@	374	MRACE1E
@	377	MRACE2E
@	380	MRACE3E
@	383	MRACE4E
@	386	MRACE5E
@	389	MRACE6E
@	392	MRACE7E
@	395	MRACE8E
@	398	MRACE16C
@	401	MRACE17C
@	404	MRACE18C
@	407	MRACE19C
@	410	MRACE20C
@	413	MRACE21C
@	416	MRACE22C
@	419	MRACE23C
@	422	ATTEND
@	423	TRAN
@	424	DOFP_MO
@	426	DOFP_DY
@	428	DOFP_YR
@	432	DOLP_MO
@	434	DOLP_DY
@	436	DOLP_YR
@	440	NPREV
@	442	NPREV_BYPASS
@	443	HFT
@	444	HIN
@	446	HGT_BYPASS
@	447	PWGT
@	450	PWGT_BYPASS
@	451	DWGT
@	454	DWGT_BYPASS
@	455	WIC
@	456	PLBL
@	458	PLBD
@	460	POPO
@	462	MLLB
@	464	YLLB
@	468	MOPO
@	470	YOPO
@	474	CIGPN
@	476	CIGFN
@	478	CIGSN
@	480	CIGLN
@	482	DLMP_YR
@	486	DLMP_MO
@	488	DLMP_DY
@	490	PDIAB
@	491	GDIAB
@	492	PHYPE
@	493	GHYPE
@	494	PPB
@	495	PPO
@	496	VB
@	497	INFT
@	498	PCES
@	499	NPCES
@	501	NPCES_BYPASS
@	502	GON
@	503	SYPH
@	504	HSV
@	505	CHAM
@	506	LM
@	507	GBS
@	508	CMV
@	509	B19
@	510	TOXO
@	511	OTHERI
@	512	ATTF
@	513	ATTV
@	514	PRES
@	515	ROUT
@	516	TLAB
@	517	HYST
@	518	MTR
@	519	PLAC
@	520	RUT
@	521	UHYS
@	522	AINT
@	523	UOPR
@	524	FWG
@	528	FW_BYPASS
@	529	OWGEST
@	531	OWGEST_BYPASS
@	532	ETIME
@	533	AUTOP
@	534	HISTOP
@	535	AUTOPF
@	536	PLUR
@	538	SORD
@	540	FDTH
@	542	MATCH
@	548	PLUR_BYPASS
@	549	ANEN
@	550	MNSB
@	551	CCHD
@	552	CDH
@	553	OMPH
@	554	GAST
@	555	LIMB
@	556	CL
@	557	CP
@	558	DOWT
@	559	CDIT
@	560	HYPO
@	561	R_YR
@	565	R_MO
@	567	R_DY
@	569	MAGER
@	571	FAGER
@	573	EHYPE
@	574	INFT_DRG
@	575	INFT_ART
@	576	DOR_YR
@	580	DOR_MO
@	582	DOR_DY
@	584	FILLER2
@	587	COD18a1
@	588	COD18a2
@	589	COD18a3
@	590	COD18a4
@	591	COD18a5
@	592	COD18a6
@	593	COD18a7
@	594	COD18a8
@	654	COD18a9
@	714	COD18a10
@	774	COD18a11
@	834	COD18a12
@	894	COD18a13
@	954	COD18a14
@	1014	COD18b1
@	1015	COD18b2
@	1016	COD18b3
@	1017	COD18b4
@	1018	COD18b5
@	1019	COD18b6
@	1020	COD18b7
@	1021	COD18b8
@	1261	COD18b9
@	1501	COD18b10
@	1741	COD18b11
@	1981	COD18b12
@	2221	COD18b13
@	2461	COD18b14
@	2701	ICOD
@	2706	OCOD1
@	2711	OCOD2
@	2716	OCOD3
@	2721	OCOD4
@	2726	OCOD5
@	2731	OCOD6
@	2736	OCOD7
@   2905    HOSP_D
@   3111    CNTY_D
@   3139    CITY_D
@   3257    MOMFNAME
@   3357    MOMLNAME
@   3467    MOMMMID
@   3577    STNUM
@   3587    PREDIR
@   3597    STNAME
@   3647    STDESIG
@   3657    POSTDIR
@   3667    APTNUMB
@   3674    ADDRESS
@   3724    ZIPCODE
@   3733    COUNTYTXT
@   3761    CITYTXT
@   3789    STATETXT
@   3817    CNTRYTXT
@   6000    FILLER3
;
run; 

/*Create audit reports for review*/
ods listing close;
ods pdf file = "\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\Quality\Fetal_Var_Frequency&year..pdf" notoc startpage=off style = minimal;
ods noproctitle;
options orientation=portrait papersize=letter nocenter topmargin=0 in bottommargin=0 in;
/*(1)*/proc freq data = export2; run;

options nocenter ;
proc print data=tmp1 noobs label;
where calc NOT IN (-1,.);
  var cknum cnum;
  label cknum = "Certnum"
        cnum = "Next Certnum";
title "Cert Numbers Out of Sequence Report";
run; 

title "First and Last Cert Numbers"; 
ods noproctitle;
proc means data = tmp1 min max maxdec=0; 
 var cnum;
 output out = means min= max= /autoname;
run; 
  
data void;
set fetalDth2015 (keep=certnum voidflag CertCCYY);  
  if CertCCYY EQ ("20&year"); 
run;

title " ";
proc print data = void;
where voidflag ne ' ';
format certnum $10. voidflag $1. CertCCYY $4.; 
run;
ods pdf close;
ods listing;

ods listing close;
ods pdf file = "\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\Quality\Fetal_Missing Numeric Values Summary&year..pdf" notoc startpage=off style = minimal;
ods noproctitle;
options orientation=portrait papersize=letter nocenter topmargin=0 in bottommargin=0 in;
title 'Fetal Death Audit - Numeric Elements';
title2 'Count Summary of Missing Values';
/*(2)*/proc means data = export2 n nmiss;
  var _numeric_;
run;
ods pdf close;
ods listing;

/*(3)*/data test1;
  set export2;
  miss_n = cmiss(of FDOD_YR -- OCOD7);
run;

options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\Programs\HSVR\VITAL RECORDS\Program Support\Access Databases\Fetal Death\Fetalupdate\Quality"
                    file="fetalExtract&year..xls" 
                    style=htmlblue
                    OPTIONS ( Orientation = 'landscape'
                              FitToPage = 'yes'
							  center_verticle = 'no'
                              Pages_FitWidth = '1'
                              Pages_FitHeight = '100'
	                          Zoom = '90'
                              Sheet_Name = "AUDIT"
                              FROZEN_HEADERS = 'Yes' 
							  AUTOFILTER='Yes'	
                              AUTOFILTER_TABLE='1'
							  FROZEN_ROWHEADERS='Yes'
                              );

title;
title2;

proc print data=test1 noobs label;
run; quit;

ods tagsets.ExcelXP close;

ods listing ;

option noxwait;
 x "copy c:\sas_output\fetal\&filename..fet
         \\dphe.local\cheis\datalib\NCHSExport\Thinclient\Outbound\NCHSFET\";
run;
 
data _null_; 
 datetime = datetime(); format datetime datetime16.;
 call symputx('datetime',put(datetime,datetime16.)); 
run; 

data _NULL_;
	if 0 then set export2 nobs=n;
	call symputx('nrows',trim(left(put(n,comma11.))));
	stop;
run;

%put nobs=&nrows;
%mend fetalupdate;

%fetalupdate (24);
* %fetalupdate (25); 
