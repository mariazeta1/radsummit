***Project: Science Education***
***Author: Maria Luisa Zeta 
***Objective: This .do file outputs a clean dta from the imported dta that is called "encuesta docentes" and also introduces corrections mistakes conducted in the preload of the ids

***Prepping stata
clear all
set more off 

**Directories

global root "X:\Box.net\Science Education Paraguay\07_Questionnaires&Data\Endline_Quant\03_DataManagement\00 Data\03 data"
local sample "D:\Box Sync\Science Education Paraguay\04_ResearchDesign\02 Randomization\output\randomized_sample"
global pii "X:\Box.net\Science Education Paraguay\07_Questionnaires&Data\Baseline_Quant\03_DataManagement\00 Data\01 data\05 PII"
*Using the imported file for the survey 

use "$root\02 imported\encuesta_docentes"

	destring treated, replace 
	ren escuela_id CdigoInstitucin
	merge m:1 CdigoInstitucin using "`sample'", gen (_merge2)
	keep if _merge2==3
	
	ren CdigoInstitucin escuela_id
	drop if docente_id==""

	destring docente_id, replace
	format docente_id %12.0g
	
	
*We will fix some ID issues with some teachers 

replace docente_id=3287001 if docente_id==3287002 // mistake in selection of teacher 
replace docente_id=3455991 if docente_id==3455002 //mistake in selection of teacher
replace turno=2 if escuela_id==3372
	
	bysort docente_id turno: gen dup=cond(_N==1, 0, _n) //teachers were interviewed in both of their shifts therefore the unique id is the docente_id + turno in which she or he teaches 
	drop if dup>1
	drop dup

*We verify the restrictions
*So in the survey we did not want to motivate the teacher to just add hours to a given area to get to the total, so we did not apply a restriction there. 
*What we will do is add a variable of not reported hours that effectively add up to the total and also have a second measure of total hours that is the sum
*of the currently reported hours

*we check for duplicates


egen horas_total_2=rowtotal(hrs_social hrs_ciencias hrs_mate hrs_arte hrs_com hrs_otra)

gen hrs_notreported= abs(horas_total_2-horas_total)

drop deviceid subscriberid simid username duracion caseid verificador deviceid turno_id
drop ver_done-no_asiste_1_033201101

*So teacher belonging to school 3394 did not answer teacher survey 2 therefore no PII data is available and does not match. However, their kids did take the survey 

merge m:1 docente_id using "$pii\PII_docentes_merged_updated", gen (_merge3) keepusing (cod_docente cod_esc) 

*We are gonna fixed manually the teachers code that are missing due to the fact that teachers did not complete the paper survey

gen cod_temp=""
replace cod_temp="002" if escuela_id==3130 & _merge3==1
replace cod_temp="001" if escuela_id==3151 & _merge3==1
replace cod_temp="991" if  escuela_id==3394 & _merge3==1



replace cod_esc="549248" if escuela_id==3130
replace cod_esc="493922" if escuela_id==3151
replace cod_esc="149884" if escuela_id==3394

egen cod_corrected=concat (cod_esc cod_temp)

replace cod_docente=cod_corrected if cod_docente==""

drop if _merge3==2
*Dropping variables that will not be used for analysis 
order strata, last 
drop note_areas1 area_social area_ciencias area_mate area_arte area_com area_otra  starttime endtime formdef_version otra_area cod_temp

drop Distrito-horas_total_2

ren treated treatment 

la var hrs_notreported "Horas no reportadas" 
la var treatment "Tratado"

*we take out the PII 

drop escuela_id docente_id submissiondate _merge3 cod_corrected key
order cod_esc cod_docente turno, first 
save "D:\Box Sync\Science Education Paraguay\07_Questionnaires&Data\Endline_Quant\03_DataManagement\00 Data\03 data\08 clean_noPII\clean_timeuse", replace 


