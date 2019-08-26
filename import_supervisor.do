* import_supervisor.do
*
* 	Imports and aggregates "supervisor" (ID: supervisor) data.
*
*	Inputs: .csv file(s) exported by the SurveyCTO Sync
*	Outputs: "X:/Box.net/Science Education Paraguay/07_Questionnaires&Data/Endline_Quant/03_DataManagement/00 Data/03 data/01 do/01 import/supervisor.dta"
*
*	Output by the SurveyCTO Sync February 1, 2018 11:44 AM.

* initialize Stata
clear all
set more off
set mem 100m

* initialize form-specific parameters
local csvfile "X:/Box.net/Science Education Paraguay/07_Questionnaires&Data/Endline_Quant/03_DataManagement/00 Data/03 data/00 raw/supervisor.csv"
local dtafile "X:/Box.net/Science Education Paraguay/07_Questionnaires&Data/Endline_Quant/03_DataManagement/00 Data/03 data/02 imported/supervisor.dta"
local corrfile "X:/Box.net/Science Education Paraguay/07_Questionnaires&Data/Endline_Quant/03_DataManagement/00 Data/03 data/00 raw/supervisor_corrections.csv"
local repeat_groups_csv1 "info_encuest"
local repeat_groups_stata1 "info_encuest"
local repeat_groups_short_stata1 "info_encuest"
local note_fields1 "intronote note_roster info_encuest_count note_resumen"
local text_fields1 "deviceid subscriberid simid username duration caseid inicio* problemas* comment* incidentes_desc"
local date_fields1 ""
local datetime_fields1 "submissiondate starttime endtime"

disp
disp "Starting import of: `csvfile'"
disp

* import data from primary .csv file
insheet using "`csvfile'", names clear

* drop extra table-list columns
cap drop reserved_name_for_field_*
cap drop generated_table_list_lab*

* continue only if there's at least one row of data to import
if _N>0 {
	* merge in any data from repeat groups (which get saved into additional .csv files)
	forvalues i = 1/100 {
		if "`repeat_groups_csv`i''" ~= "" {
			foreach repeatgroup in `repeat_groups_csv`i'' {
				* save primary data in memory
				preserve
				
				* load data for repeat group
				insheet using "X:/Box.net/Science Education Paraguay/07_Questionnaires&Data/Endline_Quant/03_DataManagement/00 Data/03 data/00 raw/supervisor-`repeatgroup'.csv", names clear

				* drop extra table-list columns
				cap drop reserved_name_for_field_*
				cap drop generated_table_list_lab*
		
				* drop extra repeat-group fields
				forvalues j = 1/100 {
					if "`repeat_groups_short_stata`j''" ~= "" {
						foreach innergroup in `repeat_groups_short_stata`j'' {
							cap drop setof`innergroup'
						}
					}
				}
					
				* if there's data in the group, sort and reshape it
				if _N>0 {
					* sort, number, and prepare for merge
					sort parent_key, stable
					by parent_key: gen rownum=_n
					drop key
					rename parent_key key
					sort key rownum
					tostring rownum, replace
                    replace rownum = "__" + rownum

					* reshape the data
					ds key rownum, not
					local allvars "`r(varlist)'"
					reshape wide `allvars', i(key) j(rownum) string
				}
				else {
					* otherwise, just fix the key to be a string for merging in the fields
					tostring key, replace
				}
				
				* save to temporary file
				tempfile rgfile
				save "`rgfile'", replace
						
				* restore primary data		
				restore
				
				* merge in repeat-group data
				merge 1:1 key using "`rgfile'", nogen
			}
		}
	}
	
	* drop extra repeat-group fields (if any)
	forvalues j = 1/100 {
		if "`repeat_groups_stata`j''" ~= "" {
			foreach repeatgroup in `repeat_groups_stata`j'' {
				drop setof`repeatgroup'
			}
		}
	}
	
	* drop note fields (since they don't contain any real data)
	forvalues i = 1/100 {
		if "`note_fields`i''" ~= "" {
			drop `note_fields`i''
		}
	}
	
	* format date and date/time fields
	forvalues i = 1/100 {
		if "`datetime_fields`i''" ~= "" {
			foreach dtvarlist in `datetime_fields`i'' {
				foreach dtvar of varlist `dtvarlist' {
					tempvar tempdtvar
					rename `dtvar' `tempdtvar'
					gen double `dtvar'=.
					cap replace `dtvar'=clock(`tempdtvar',"MDYhms",2025)
					* automatically try without seconds, just in case
					cap replace `dtvar'=clock(`tempdtvar',"MDYhm",2025) if `dtvar'==. & `tempdtvar'~=""
					format %tc `dtvar'
					drop `tempdtvar'
				}
			}
		}
		if "`date_fields`i''" ~= "" {
			foreach dtvarlist in `date_fields`i'' {
				foreach dtvar of varlist `dtvarlist' {
					tempvar tempdtvar
					rename `dtvar' `tempdtvar'
					gen double `dtvar'=.
					cap replace `dtvar'=date(`tempdtvar',"MDY",2025)
					format %td `dtvar'
					drop `tempdtvar'
				}
			}
		}
	}

	* ensure that text fields are always imported as strings (with "" for missing values)
	* (note that we treat "calculate" fields as text; you can destring later if you wish)
	tempvar ismissingvar
	quietly: gen `ismissingvar'=.
	forvalues i = 1/100 {
		if "`text_fields`i''" ~= "" {
			foreach svarlist in `text_fields`i'' {
				foreach stringvar of varlist `svarlist' {
					quietly: replace `ismissingvar'=.
					quietly: cap replace `ismissingvar'=1 if `stringvar'==.
					cap tostring `stringvar', format(%100.0g) replace
					cap replace `stringvar'="" if `ismissingvar'==1
				}
			}
		}
	}
	quietly: drop `ismissingvar'


	* consolidate unique ID into "key" variable
	replace key=instanceid if key==""
	drop instanceid


	* label variables
	label variable key "Unique submission ID"
	cap label variable submissiondate "Date/time submitted"
	cap label variable formdef_version "Form version used on device"


	label variable supervisor "Seleccione su nombre"
	note supervisor: "Seleccione su nombre"
	label define supervisor 90 "Martha Vera" 91 "Maria Soledad González de Mendez"
	label values supervisor supervisor

	label variable num_escuelas "¿Cuantas escuelas visitó usted hoy?"
	note num_escuelas: "¿Cuantas escuelas visitó usted hoy?"

	label variable num_encuest "¿Cuanto(a)s encuestadore(a)s supervisionó usted hoy?"
	note num_encuest: "¿Cuanto(a)s encuestadore(a)s supervisionó usted hoy?"

	label variable team_esc "¿Cuantas escuelas fueron visitadas por su equipo hoy?"
	note team_esc: "¿Cuantas escuelas fueron visitadas por su equipo hoy?"

	label variable team_prueba "¿Cuantas pruebas realizó su equipo hoy?"
	note team_prueba: "¿Cuantas pruebas realizó su equipo hoy?"

	label variable incidente "¿Ocurrió algun incidente notable en este día con un(a) encuestador(a), una escue"
	note incidente: "¿Ocurrió algun incidente notable en este día con un(a) encuestador(a), una escuela o con usted?"
	label define incidente 1 "Si" 0 "No" 98 "No aplica"
	label values incidente incidente

	label variable incidentes_desc "Describa este(s) incidente(s)"
	note incidentes_desc: "Describa este(s) incidente(s)"



	capture {
		foreach rgvar of varlist encuestador__* {
			label variable `rgvar' "Seleccione uno(a) de lo(a)s encuestadore(a)s que ha supervisionado hoy"
			note `rgvar': "Seleccione uno(a) de lo(a)s encuestadore(a)s que ha supervisionado hoy"
			label define `rgvar' 1 "Delia Peralta" 2 "Elio José Osorio" 3 "Marizza Esteche Rodas" 4 "Margarita Zaragoza" 5 "Gertrudis Martínez" 6 "Laura Noelia Viera Davalos" 7 "Perla Ortiz Morinigo" 8 "Andrea Celeste Benitez Bruno" 9 "Lia Noelia Aveiro Davalos" 10 "Sady Luján Arias de Roa" 11 "Diana Concepción Fariña" 12 "Beba Edelira Alfonso de Wiegert" 13 "Lisa Liz Mendez Insfran" 14 "Maria Rosana Ledezma Rios" 15 "Teresa Colmán" 16 "Aldo Morel" 17 "Andrés Escobar" 18 "Mario Ocampos" 88 "Elisa Britos Barrios"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist visita_tiempo__* {
			label variable `rgvar' "¿En qué estado de la visita llegó usted?"
			note `rgvar': "¿En qué estado de la visita llegó usted?"
			label define `rgvar' 1 "Al principio" 2 "En medio de la visita" 3 "Hacia el final de la visita"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist inicio__* {
			label variable `rgvar' "Seleccione las opciones que mejor describen el/la encuestador(a)"
			note `rgvar': "Seleccione las opciones que mejor describen el/la encuestador(a)"
		}
	}

	capture {
		foreach rgvar of varlist nino__* {
			label variable `rgvar' "¿Cómo aplica el/la encuestador(a) la prueba de niños?"
			note `rgvar': "¿Cómo aplica el/la encuestador(a) la prueba de niños?"
			label define `rgvar' 1 "La aplica de forma pausada, vocalizando correctamente" 2 "La aplica de forma apurada, sería mejor que sea más lento" 3 "La aplica sin ganas. No anima al niño a seguir" 4 "La aplica de forma correcta pero en algunas partes debe mejorar"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist trata__* {
			label variable `rgvar' "¿Cómo trata el/la encuestador(a) a los niños?"
			note `rgvar': "¿Cómo trata el/la encuestador(a) a los niños?"
			label define `rgvar' 1 "Muy bien, los trata con paciencia y atención" 2 "Bien, los trata de forma cordial" 3 "Mal, no tiene paciencia con ellos"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist feedback__* {
			label variable `rgvar' "¿Cuándo usted le corrige, el/la encuestador(a) mejora?"
			note `rgvar': "¿Cuándo usted le corrige, el/la encuestador(a) mejora?"
			label define `rgvar' 1 "Si" 0 "No" 98 "No aplica"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist proactiv__* {
			label variable `rgvar' "¿El/La encuestador(a) es proactivo(a) a buscar niños ausentes?"
			note `rgvar': "¿El/La encuestador(a) es proactivo(a) a buscar niños ausentes?"
			label define `rgvar' 1 "Si" 0 "No" 98 "No aplica"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist problemas__* {
			label variable `rgvar' "Este(a) encuestador(a):"
			note `rgvar': "Este(a) encuestador(a):"
		}
	}

	capture {
		foreach rgvar of varlist num_prueba__* {
			label variable `rgvar' "¿Cuántas pruebas de niños completó el/la encuestador(a) con su supervisión?"
			note `rgvar': "¿Cuántas pruebas de niños completó el/la encuestador(a) con su supervisión?"
		}
	}

	capture {
		foreach rgvar of varlist comment__* {
			label variable `rgvar' "¿Tiene algún comentario adicional del(a) encuestador(a)?"
			note `rgvar': "¿Tiene algún comentario adicional del(a) encuestador(a)?"
		}
	}




	* append old, previously-imported data (if any)
	cap confirm file "`dtafile'"
	if _rc == 0 {
		* mark all new data before merging with old data
		gen new_data_row=1
		
		* pull in old data
		append using "`dtafile'"
		
		* drop duplicates in favor of old, previously-imported data
		sort key
		by key: gen num_for_key = _N
		drop if num_for_key > 1 & new_data_row == 1
		drop num_for_key

		* drop new-data flag
		drop new_data_row
	}
	
	* save data to Stata format
	save "`dtafile'", replace

	* show codebook and notes
	codebook
	notes list
}

disp
disp "Finished import of: `csvfile'"
disp

* apply corrections (if any)
capture confirm file "`corrfile'"
if _rc==0 {
	disp
	disp "Starting application of corrections in: `corrfile'"
	disp

	* save primary data in memory
	preserve

	* load corrections
	insheet using "`corrfile'", names clear
	
	if _N>0 {
		* number all rows (with +1 offset so that it matches row numbers in Excel)
		gen rownum=_n+1
		
		* drop notes field (for information only)
		drop notes
		
		* make sure that all values are in string format to start
		gen origvalue=value
		tostring value, format(%100.0g) replace
		cap replace value="" if origvalue==.
		drop origvalue
		replace value=trim(value)
		
		* correct field names to match Stata field names (lowercase, drop -'s and .'s)
		replace fieldname=lower(subinstr(subinstr(fieldname,"-","",.),".","",.))
		
		* format date and date/time fields (taking account of possible wildcards for repeat groups)
		forvalues i = 1/100 {
			if "`datetime_fields`i''" ~= "" {
				foreach dtvar in `datetime_fields`i'' {
					gen origvalue=value
					replace value=string(clock(value,"MDYhms",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
					* allow for cases where seconds haven't been specified
					replace value=string(clock(origvalue,"MDYhm",2025),"%25.0g") if strmatch(fieldname,"`dtvar'") & value=="." & origvalue~="."
					drop origvalue
				}
			}
			if "`date_fields`i''" ~= "" {
				foreach dtvar in `date_fields`i'' {
					replace value=string(clock(value,"MDY",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
				}
			}
		}

		* write out a temp file with the commands necessary to apply each correction
		tempfile tempdo
		file open dofile using "`tempdo'", write replace
		local N = _N
		forvalues i = 1/`N' {
			local fieldnameval=fieldname[`i']
			local valueval=value[`i']
			local keyval=key[`i']
			local rownumval=rownum[`i']
			file write dofile `"cap replace `fieldnameval'="`valueval'" if key=="`keyval'""' _n
			file write dofile `"if _rc ~= 0 {"' _n
			if "`valueval'" == "" {
				file write dofile _tab `"cap replace `fieldnameval'=. if key=="`keyval'""' _n
			}
			else {
				file write dofile _tab `"cap replace `fieldnameval'=`valueval' if key=="`keyval'""' _n
			}
			file write dofile _tab `"if _rc ~= 0 {"' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab _tab `"disp "CAN'T APPLY CORRECTION IN ROW #`rownumval'""' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab `"}"' _n
			file write dofile `"}"' _n
		}
		file close dofile
	
		* restore primary data
		restore
		
		* execute the .do file to actually apply all corrections
		do "`tempdo'"

		* re-save data
		save "`dtafile'", replace
	}
	else {
		* restore primary data		
		restore
	}

	disp
	disp "Finished applying corrections in: `corrfile'"
	disp
}
