//Jan 31, 2012  (but an updated version of Jan_20_vacant.do)




**** major change ****************
* develpable vacant land and undevelopable vacant are treated in one regression equation, with a dummy variable for developable 
**********************************


//classify vacant land into developable & undevelopable (dvlp = 1 == developable) 
//developability are based from LU_08 and Ross' calculations D:\summer, 2011\Yuntao\developability\



clear all
log close _all
log using jan_20_vacant, replace
set more off
set mem 1g
cd "I:\summer project\summer, 2011_backup\Vacant Land"

/*
insheet using "I:\summer project\summer, 2011_backup\zone\Vacant_3000\vacant3000_fsub_cbd3.csv", clear
//in this 3*** vacant parcels' data processing in ArcGis, LAX_ATT served as input tables, while LAparcelMZ served as join tables. So scagxyid and lu08 were used as primary indicator of selection, compared to scag_xyid and lu_08 of non 3*** vacant parcels. Now just put this matter away, and assume that they are the same.
capture rename freeway fwy
drop scag_xyid lu_08
rename scagxyid  scag_xyid 
rename lu08 lu_08
save vacant3000_fsub_cbd3.dta, replace


insheet using "I:\summer project\summer, 2011_backup\zone\join2_backup\Keep_all_records\SIX_merge.csv", clear
capture rename freeway fwy
capture drop scagxyid
capture drop lu08
destring scag_xyid, replace force
save SIX_merge.dta, replace
*/

use SIX_merge.dta, clear
append using vacant3000_fsub_cbd3.dta, force
//there are serious duplication in scag_xyid in the 3*** data, will look at it later

/*
duplicates tag scag_xyid, gen(dup)
drop if dup != 0
drop dup
*/
// above is one difference from jan_20_vacant.do, reason => unknown (maybe scag_xyid may not be unique identifier of parcels of land)

merge m:1 scag_xyid using "D:\summer, 2011\Yuntao\Und_VTSBRVOCLAIM_2.dta", force
drop if _merge == 2  //appeared only in using dataset (# = 96341/581024 = 17%, this is because of LAX_ATT.dbf selection based on lu08 and LAparcelMZ.dbf selection based on lu_08, so double selection reduced sample size)
//data processing in this part has been started, and waiting to be finished in February 

replace dvlp = 0 if dvlp == 1   //miscoding of develpability in original data
replace dvlp = 1 if missing(dvlp)
replace dvlp = 0 if lu_08 >= 1800 & lu_08 < 1900 & lu_08 != 1810 & lu_08 != 1840

save jan_20_vacant.dta, replace                                                            

//use jan_20_vacant.dta, clear                                                                                      
replace fwy = fwy * 0.00062137
replace ocean = ocean * 0.00062137
replace totvalue07 = . if totvalue07 == 0
replace shape_area = . if shape_area == 0                            
replace saleyr = . if saleyr == 1899 | saleyr == 0 
gen saleyr_bk = saleyr
//replace  scag_gp_co = . if  scag_gp_co == 0 | scag_gp_co == 9999 (one difference from jan_20_vacant.do, reason => different coding of missing scag_gp_co may have different meanings)
collapse vsq_mz* if !missing(vsq_mz_1) & !missing(vsq_mz_0), by(mz)
outsheet  vsq_mz* mz using jan_20_vacant.csv, comma replace

gen lgvsq = ln( totvalue07/ shape_area * 0.09290304)      
gen lgvsq2000 = .
encode city_name , gen(citynum)
xtset citynum

//developable as a dummy explanatory variable
xtreg  lgvsq  fsub cbd fwy ocean i.dvlp i.saleyr i.lu_08 i.scag_gp_co if !missing(saleyr), fe
levelsof saleyr if e(sample), local(lvsaleyr)
foreach lv of local lvsaleyr {
    capture replace lgvsq2000 =  lgvsq - _b[`lv'.saleyr] + _b[2000.saleyr]  if saleyr == `lv'  & e(sample)
}
replace saleyr = 2000 if e(sample) == 0  
predict lgvsq_p if dvlp
replace saleyr = saleyr_bk
replace lgvsq2000 = lgvsq_p if e(sample) == 0 & dvlp
drop  lgvsq_p
                                                           collapse vsq_mz* if !missing(vsq_mz_1) & !missing(vsq_mz_0), by(mz)
outsheet  vsq_mz* mz using jan_20_vacant.csv, comma replace                                      
gen v2000 =  exp(lgvsq2000) * shape_area * 10.7639104
gen tsample = !missing(shape_area) & !missing(v2000)
gen tsample_1 = tsample & dvlp
gen tsample_0 = tsample & !dvlp

forvalues i = 0/1 {collapse vsq_mz* if !missing(vsq_mz_1) & !missing(vsq_mz_0), by(mz)
outsheet  vsq_mz* mz using jan_20_vacant.csv, comma replace
    replace tsample = tsample_`i'
    bysort mz: egen area_total = total(shape_area) if tsample
    by mz: egen val_total = total(v2000) if tsample
    gen vsq_mz_`i' = val_total / area_total  
    drop area_total val_total
}

save jan_31_vacant_results.dta, replace


//collapse vsq_mz* if !missing(vsq_mz_1) & !missing(vsq_mz_0), by(mz)
collapse vsq_mz*, by(mz)




outsheet  vsq_mz* mz using jan_31_vacant.csv, comma replace







/*
//count the # of parcels
use jan_20_vacant.dta, replace
bysort mz: egen n1 = count(mz) if dvlp == 1
bysort mz: egen n0 = count(mz) if dvlp == 0
collapse n1 n0, by(mz)
outsheet using test.csv, comma replace




foreach var of varlist fsub cbd fwy ocean tot* saleyr {
   bysort dvlp: sum `var'
}
*/
