//updated on Aug 12, 2014
// updated because the regression sample for vacant parcels are changed. 
// The missing parcels in RV county has been found back.

cd "/Users/huiling/Dropbox/Vacant Land"

capture log close 
log using aug122014_aggregatelandval, replace
set more off

******* Characteristics **************
* (0) use regression setup 2: lnv ~ lna + ...
* (1) estimate land values for all land use types other than vacant land.
* (2) Guess need a multiplication factor for each major land uses

*****************************************
clear
clear matrix
set mem 1g

use aug12014_vacant.dta if dvlp, clear  
drop if mz >= 96 & mz <= 97                                                                                    
replace fwy = fwy * 0.00062137
replace ocean = ocean * 0.00062137
replace totvalue07 = . if totvalue07 == 0
replace shape_area = . if shape_area == 0                            
replace saleyr = . if saleyr == 1899 | saleyr == 0 
replace saleyr = . if saleyr < 1980

gen lnv = ln( totvalue07)
gen lna = ln( shape_area)      
gen vsq = totvalue07/ shape_area * 0.09290304

gen cbd2 = cbd^2
gen ocean2 = ocean^2

replace scag_gp_co = 0 if missing(scag_gp_co)
replace city_name = "Unknown" if missing(city_name)

// to apply the coefficients to other land uses, cannot have current land uses.
* xtreg  lgvsq  fsub cbd fwy ocean i.saleyr i.lu_08 i.scag_gp_co if !missing(saleyr) & dvlp, fe
* xi: reg lnv lna fsub cbd cbd2 fwy ocean ocean2 i.city_name i.saleyr if !missing(saleyr)
//use scag_gp_co as lu_08 for developed parcels
* char _dta[omit] "prevelant"
* xi: reg lnv lna fsub cbd cbd2 fwy ocean ocean2 i.city_name i.saleyr i.scag_gp_co if !missing(saleyr)
encode city_name, gen(city_n)
reg lnv lna fsub cbd cbd2 fwy ocean ocean2 i.city_n i.saleyr i.scag_gp_co if !missing(saleyr)
estimates save developable_tool_lnv, replace  //note the difference from standard dsevelopable coefficients

collapse city_n, by(city_name)
save cityid_name_correspondence.dta, replace


******************************
** Part 1: residential
******************************


use fsub cbd fwy ocean city  shape_area lu_08 mz saleyr sale_price using "/Users/huiling/Documents/summer, 2011/Third Project/Final_data/residential_six_final_3category.dta", clear
rename city city_name 
gen cbd2 = cbd^2
gen ocean2 = ocean^2
rename lu_08 scag_gp_co
replace shape_area = . if shape_area == 0
gen lna = ln(shape_area)

merge m:1 city_name using cityid_name_correspondence.dta
tab city_name if _merge == 1
replace city_n = 89 if _merge == 1 // los angeles city
drop if _merge == 2


********** Impute missing County ****************
gen county = ""
replace county = "LA" if mz >= 1 & mz <= 46
replace county = "VT" if mz >= 47 & mz <= 49
replace county = "OR" if mz >= 50 & mz <= 66
replace county = "SB" if mz >= 67 & mz <= 80
replace county = "RV" if mz >= 81 & mz <= 95
replace county = "IM" if mz >= 96 & mz <= 97


//Infer missing counties from city_name
replace county = "LA" if city_name == "unincorporated_la"
replace county = "OR" if city_name == "unincorporated_or"
replace county = "RV" if city_name == "unincorporated_rv"
replace county = "SB" if city_name == "unincorporated_sb"
replace county = "VT" if city_name == "unincorporated_vn"


encode county, gen(county_n)


levelsof city_name, local(citylist)
foreach lc of local citylist {
		sum county_n if city_name == "`lc'" & !missing(county), meanonly
		replace county_n = r(mean) if city_name == "`lc'" & missing(county)
}

//some cities have parcels in more than one county, then county_n is no longer integer 
//list if mod(county_n,1) != 0
//just a few of them, so change one-by-one

decode county_n, gen(county_s)	
replace county_s = "LA" if city_name == "Avalon" | city_name == "Cerritos"| city_name == "La Mirada" | city_name == "Lakewood"
replace county_s = "LA" if city_name == "Long Beach" | city_name == "Los Angeles"
replace county_s = "SB" if city_name == "Chino" | city_name == "Colton" | city_name == "Fontana" | city_name == "Yucaipa" | city_name == "Montclair"
replace county_s = "OR" if city_name == "La Habra" | city_name == "Los Alamitos" 
replace county_s = "VT" if city_name == "Thousand Oaks"





drop county
rename county_s county

drop if county == "IM"
**************************************************




/*
// be careful with large scale missing shape_area in la county
replace shape_area = . if shape_area == 0
count if missing(shape_area)
* weird, this problem is gone. 
*/



//potential problem: some city may not have vacant land, so their coefs may be unknown
//in vacant sample, there are 176 unique cities, while in residential sample there are 167
estimates use developable_tool_lnv
replace saleyr = 2000


predict lnv2000
gen landval = exp(lnv2000) 
gen sfr = scag_gp_co >= 1110 & scag_gp_co < 1120
* save july17landval_residential.dta, replace
save aug122014landval_residential.dta, replace

bysort county sfr: egen nparcel = count(fsub)
collapse (mean) nparcel (sum) landval shape_area, by(county sfr)


//Table 13 in paper **  
gen shape_area_sqft = shape_area * 10.7639
format landval shape_area shape_area_sqft %14.0f 
outsheet using table13_aug122014.xls if sfr, replace
outsheet using table12_mfr_aug122014.xls if !sfr, replace






******************************************************
** Part 2: Non-Residential Non-Vacant
******************************************************
use "/Users/huiling/Dropbox/Vacant Land/aggregate_land_values/six_counties_nonresidential_nonvacant.dta", clear
rename city city_name 
gen fwy = freeway * 0.00062137
replace ocean = ocean * 0.00062137
gen saleyr = 2000
replace shape_area = . if shape_area == 0
gen lna = ln(shape_area)
count if missing(shape_area)

gen cbd2 = cbd^2
gen ocean2 = ocean^2


// scag_gp_co (at most three efficient digits) is more general than lu_08 (four efficient digits)
// in order to apply regression coefs based on scag_gp_co to lu_08, I need to do the following change
replace lu_08 = lu_08 /10
gen test = int(lu_08) 
replace test = test * 10
replace test = 4000 if test > 4000 & test < 5000
replace test = 1400 if test > 1430 & test < 1500
 
rename test scag_gp_co




merge m:1 city_name using cityid_name_correspondence.dta
tab city_name if _merge == 1
replace city_n = 89 if _merge == 1 // los angeles city
drop if _merge == 2


********** Impute missing County ****************
gen county = ""
replace county = "LA" if mz >= 1 & mz <= 46
replace county = "VT" if mz >= 47 & mz <= 49
replace county = "OR" if mz >= 50 & mz <= 66
replace county = "SB" if mz >= 67 & mz <= 80
replace county = "RV" if mz >= 81 & mz <= 95
replace county = "IM" if mz >= 96 & mz <= 97


//Infer missing counties from city_name
replace county = "LA" if city_name == "unincorporated_la"
replace county = "OR" if city_name == "unincorporated_or"
replace county = "RV" if city_name == "unincorporated_rv"
replace county = "SB" if city_name == "unincorporated_sb"
replace county = "VT" if city_name == "unincorporated_vn"


encode county, gen(county_n)


levelsof city_name, local(citylist)
foreach lc of local citylist {
		sum county_n if city_name == "`lc'" & !missing(county), meanonly
		replace county_n = r(mean) if city_name == "`lc'" & missing(county)
}

//some cities have parcels in more than one county, then county_n is no longer integer 
//list if mod(county_n,1) != 0
//just a few of them, so change one-by-one

decode county_n, gen(county_s)	
replace county_s = "LA" if city_name == "Avalon" | city_name == "Cerritos"| city_name == "La Mirada" | city_name == "Lakewood"
replace county_s = "LA" if city_name == "Long Beach" | city_name == "Los Angeles"
replace county_s = "SB" if city_name == "Chino" | city_name == "Colton" | city_name == "Fontana" | city_name == "Yucaipa" | city_name == "Montclair" | city_name == "Ontario"
replace county_s = "OR" if city_name == "La Habra" | city_name == "Los Alamitos" 
replace county_s = "VT" if city_name == "Thousand Oaks"




drop county
rename county_s county

drop if county == "IM"
**************************************************





estimates use developable_tool_lnv
predict lnv2000
gen landval = exp(lnv2000)
* save july17landval_nonresidential_nonvacant.dta, replace
save aug122014landval_nonresidential_nonvacant.dta, replace
*collapse (sum) landval shape_area, by(county)
bysort county: egen nparcel = count(lnv2000)
collapse (mean) nparcel (sum) landval shape_area, by(county)

//Table 12_nonresidential: 
gen shape_area_sqft = shape_area * 10.7639
format landval shape_area shape_area_sqft %14.0f 
outsheet using table13_nonresidential_aug122014.xls, replace



********************************************************************************
** I forgot to estimate the land value for office parcels
*******************************************************************************
use "/Users/huiling/Documents/summer, 2011/Third Project/office_builing/Data/five_parcelMZ_office.dta", clear
cd "/Users/huiling/Dropbox/Vacant Land"

replace saleyr = 2000
replace shape_area = . if shape_area == 0
gen lna = ln(shape_area)
count if missing(shape_area)

gen cbd2 = cbd^2
gen ocean2 = ocean^2



// scag_gp_co (at most three efficient digits) is more general than lu_08 (four efficient digits)
// in order to apply regression coefs based on scag_gp_co to lu_08, I need to do the following change
replace lu_08 = lu_08 /10
gen test = int(lu_08) 
replace test = test * 10
replace test = 4000 if test > 4000 & test < 5000
replace test = 1400 if test > 1430 & test < 1500
 
rename test scag_gp_co


drop city_name
rename city city_name


merge m:1 city_name using cityid_name_correspondence.dta
tab city_name if _merge == 1
replace city_n = 89 if _merge == 1 // los angeles city
drop if _merge == 2


********** Impute missing County 
gen county = ""
replace county = "LA" if mz >= 1 & mz <= 46
replace county = "VT" if mz >= 47 & mz <= 49
replace county = "OR" if mz >= 50 & mz <= 66
replace county = "SB" if mz >= 67 & mz <= 80
replace county = "RV" if mz >= 81 & mz <= 95
replace county = "IM" if mz >= 96 & mz <= 97


//Infer missing counties from city_name
replace county = "LA" if city_name == "unincorporated_la"
replace county = "OR" if city_name == "unincorporated_or"
replace county = "RV" if city_name == "unincorporated_rv"
replace county = "SB" if city_name == "unincorporated_sb"
replace county = "VT" if city_name == "unincorporated_vn"


encode county, gen(county_n)


levelsof city_name, local(citylist)
foreach lc of local citylist {
		sum county_n if city_name == "`lc'" & !missing(county), meanonly
		replace county_n = r(mean) if city_name == "`lc'" & missing(county)
}

decode county_n, gen(county_s)	
replace county_s = "LA" if city_name == "Avalon" | city_name == "Cerritos"| city_name == "La Mirada" | city_name == "Lakewood"
replace county_s = "LA" if city_name == "Long Beach" | city_name == "Los Angeles" | city_name == "Hawaiian Gardens"
replace county_s = "SB" if city_name == "Chino" | city_name == "Colton" | city_name == "Fontana" | city_name == "Yucaipa" | city_name == "Montclair"
replace county_s = "OR" if city_name == "La Habra" | city_name == "Los Alamitos" 
replace county_s = "VT" if city_name == "Thousand Oaks"

drop county
rename county_s county



estimates use developable_tool_lnv
predict lnv2000
gen landval = exp(lnv2000)
*save july17landval_office.dta, replace


/*
//==========================================================
** land values by aggregate land uses -- Apendix in paper.
* use july17landval_nonresidential_nonvacant.dta, clear
use aug122014landval_nonresidential_nonvacant.dta, clear
rename scag_gp_co lu_08
drop if lu_08 >= 4000

gen retail = lu_08 < 1230 & lu_08 >= 1220
gen other_commercial = lu_08 == 1200 | (lu_08 < 1240 & lu_08 >= 1230)
gen public = lu_08 < 1300 & lu_08 >= 1240
gen warehousing = lu_08 == 1340
gen other_industrial = lu_08 < 1340 & lu_08 >= 1300
gen transportation = lu_08 < 1500 & lu_08 >= 1400
gen mixed = (lu_08 == 1500) | (lu_08 == 1600)

gen landuse = ""
local land_use  retail other_commercial public warehousing other_industrial  transportation mixed
foreach lu of local land_use {
replace landuse = "`lu'" if `lu'
}

bysort county landuse: egen nparcel = count(landval)

collapse (sum) landval shape_area (mean) nparcel, by(county landuse)
*/


