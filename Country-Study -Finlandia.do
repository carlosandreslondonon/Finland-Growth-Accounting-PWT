****************************************************
* COUNTRY STUDY - FINLANDIA
* Contabilidad del crecimiento con PWT
* Autor: Andrés Londoño
****************************************************

clear all
set more off


****************************************************
* ENTORNO PORTABLE – CREAR Finland_Project
****************************************************

* 1. Obtener directorio actual (donde se ejecuta el do-file)
local current_dir "`c(pwd)'"

display "Directorio actual: `current_dir'"

* 2. Crear carpeta principal Finland_Project
capture mkdir "`current_dir'/Finland_Project"

* 3. Entrar a esa carpeta
cd "`current_dir'/Finland_Project"

* 4. Definir root como Finland_Project
global root "`c(pwd)'"

display "Proyecto ejecutándose en: $root"

* 5. Crear subcarpetas
capture mkdir "BASES"
capture mkdir "TABLAS"
capture mkdir "GRAFICAS"


****************************************************
* 1) DESCARGA DE DATOS (GITHUB RAW)
****************************************************

local url "https://raw.githubusercontent.com/carlosandreslondonon/Finland-Growth-Accounting-PWT/refs/heads/master/BASES/Growth.csv"

import delimited "`url'", clear

****************************************************
* 2) LIMPIEZA Y PREPARACIÓN
****************************************************

* Si tu CSV trae 4 filas basura arriba, descomenta estas líneas:
* drop in 1/4

* Asegurar variable de año
capture confirm variable year
if _rc!=0 {
    display as error "No encuentro la variable 'year'. Revisa el CSV (nombres de columnas)."
    exit 198
}

destring year, replace force
sort year
tsset year

****************************************************
* 3) VALIDACIONES DE VARIABLES CLAVE
****************************************************

* Producto, trabajo y capital humano
foreach v in rgdpna emp hc {
    capture confirm variable `v'
    if _rc!=0 {
        display as error "No encuentro la variable '`v'' en el archivo. Revisa el CSV."
        exit 198
    }
}

* Capital: preferir rknna; si no existe, usar rkna
local capvar ""
capture confirm variable rnna
if _rc==0 local capvar "rnna"
else {
    capture confirm variable rnna
    if _rc==0 local capvar "rnna"
    else {
        display as error "No encuentro rknna ni rkna en el archivo. Revisa el CSV."
        exit 198
    }
}

display as text "Variable de capital utilizada: `capvar'"

****************************************************
* 4) LOGS Y TASAS DE CRECIMIENTO (Δ ln)
****************************************************

gen lnY = ln(rgdpna)
gen lnK = ln(`capvar')
gen lnH = ln(hc)

* Trabajo: si existe avh (horas promedio), usar trabajo efectivo emp*avh; si no, emp
capture confirm variable avh
if _rc==0 {
    gen L_eff = emp * avh
    gen lnL = ln(L_eff)
    label var lnL "ln(trabajo efectivo = emp*avh)"
}
else {
    gen lnL = ln(emp)
    label var lnL "ln(empleo)"
}

* Crecimientos (diferencias logarítmicas)
gen gY = D.lnY
gen gK = D.lnK
gen gL = D.lnL
gen gH = D.lnH

****************************************************
* 5) ALFA (PARTICIPACIÓN DEL CAPITAL)
****************************************************

* Si existe labsh, alpha_t = 1 - labsh; si no, alpha_t = 0.33
capture confirm variable labsh
if _rc==0 {
    gen alpha_t = 1 - labsh
}
else {
    gen alpha_t = 0.33
}

* Restringir a un rango razonable (evitar valores raros)
replace alpha_t = 0.33 if missing(alpha_t)
replace alpha_t = 0.10 if alpha_t < 0.10
replace alpha_t = 0.60 if alpha_t > 0.60

****************************************************
* 6) CONTABILIDAD DEL CRECIMIENTO: CONTRIBUCIONES Y PTF
****************************************************

gen contrib_K = alpha_t * gK
gen contrib_L = (1 - alpha_t) * gL
gen contrib_H = (1 - alpha_t) * gH

* PTF (residuo de Solow)
gen gA = gY - contrib_K - contrib_L - contrib_H

* Mantener observaciones completas
keep if !missing(gY,gK,gL,gH,alpha_t,contrib_K,contrib_L,contrib_H,gA)

* Guardar base lista (opcional)
save "BASES/base_growth_finland.dta", replace


****************************************************
* 6.1) SERIE TEMPORAL: CONTRIBUCIONES ANUALES (pp)
****************************************************

* Pasar a puntos porcentuales (pp)
gen contribK_pp = 100*contrib_K
gen contribL_pp = 100*contrib_L
gen contribH_pp = 100*contrib_H
gen gA_pp       = 100*gA

label var contribK_pp "Capital (K)"
label var contribL_pp "Trabajo (L)"
label var contribH_pp "Capital humano (H)"
label var gA_pp       "PTF (A)"

* Límites verticales para las barras (constantes numéricas)
local ymin = -6
local ymax =  6

twoway ///
(line contribK_pp year, lwidth(medthick) lcolor("128 0 32")) ///
(line contribL_pp year, lwidth(medthick) lcolor("255 140 0")) ///
(line contribH_pp year, lwidth(medthick) lcolor(gs10)) ///
(line gA_pp       year, lwidth(medthick) lcolor(gs6)) ///
, ///
xtitle("Año", size(small)) ///
ytitle("Contribución al crecimiento (puntos porcentuales)", size(small)) ///
xlabel(1950(10)2023, nogrid labsize(small)) ///
ylabel(, nogrid labsize(small)) ///
xscale(range(1950 2023)) ///
yline(0, lpattern(dash) lcolor(gs6)) ///
/* Crisis bancaria */ ///
xline(1990 1993, lcolor("0 32 96") lpattern(dash) lwidth(medthick)) ///
/* Crisis financiera global */ ///
xline(2008 2014, lcolor("0 32 96") lpattern(dash) lwidth(medthick)) ///
legend(order(1 "Capital (K)" 2 "Trabajo (L)" 3 "Capital humano (H)" 4 "PTF (A)") ///
       size(small) cols(2) region(lstyle(none))) ///
graphregion(color(white) lstyle(none)) ///
plotregion(lstyle(none)) ///
scheme(s1mono)

graph export "GRAFICAS/figura3_contribuciones_series_crisis.pdf", replace


****************************************************
* 7) DEFINIR 8 PERIODOS
****************************************************

gen periodo = .
replace periodo = 1 if inrange(year, 1954, 1969)
replace periodo = 2 if inrange(year, 1970, 1979)
replace periodo = 3 if inrange(year, 1980, 1989)
replace periodo = 4 if inrange(year, 1990, 1993)
replace periodo = 5 if inrange(year, 1994, 2000)
replace periodo = 6 if inrange(year, 2001, 2007)
replace periodo = 7 if inrange(year, 2008, 2014)
replace periodo = 8 if inrange(year, 2015, 2023)

label define periodo_lbl ///
    1 "1954-1969" ///
    2 "1970-1979" ///
    3 "1980-1989" ///
    4 "1990-1993" ///
    5 "1994-2000" ///
    6 "2001-2007" ///
    7 "2008-2014" ///
    8 "2015-2023"
label values periodo periodo_lbl

keep if !missing(periodo)

****************************************************
* 8) TABLA LATEX (PROMEDIOS POR PERIODO, pp)
****************************************************

preserve
collapse (mean) gY contrib_K contrib_L contrib_H gA, by(periodo)

foreach v in gY contrib_K contrib_L contrib_H gA {
    replace `v' = 100*`v'
}

format gY contrib_K contrib_L contrib_H gA %9.2f

ssc install listtex, replace

listtex periodo gY contrib_K contrib_L contrib_H gA ///
    using "TABLAS/tabla_contribuciones_por_periodo.tex", ///
    replace rstyle(tabular) ///
    head("\begin{tabular}{lccccc} \toprule \toprule \rowcolor{purple} Periodo & Crecimiento PIB & Capital (K) & Trabajo (L) & Capital humano (H) & PTF (A) \\ \midrule") ///
    foot("\bottomrule \end{tabular}")

restore

****************************************************
* 9) FIGURA 1: ln(PIB real)
****************************************************

twoway ///
(line lnY year, lwidth(medium) lcolor("128 0 32")) ///
, ///
xtitle("Año", size(small)) ///
ytitle("Logaritmo del PIB real", size(small)) ///
xlabel(1950(10)2023, nogrid labsize(small)) ///
ylabel(, nogrid labsize(small)) ///
xscale(range(1950 2023)) ///
xline(1991, lpattern(dash) lcolor(gs6)) ///
xline(2008, lpattern(dash) lcolor(gs6)) ///
legend(off) ///
scheme(s1mono)

graph export "GRAFICAS/figura1_ln_gdp.pdf", replace

****************************************************
* 10) FIGURA 2: contribuciones apiladas por periodo
****************************************************

preserve
collapse (mean) contrib_K contrib_L contrib_H gA, by(periodo)

foreach v in contrib_K contrib_L contrib_H gA {
    replace `v' = 100*`v'
}

graph bar contrib_K contrib_L contrib_H gA, ///
    over(periodo, label(labsize(small))) ///
    stack ///
    bar(1, color("128 0 32")) ///
    bar(2, color("255 140 0")) ///
    bar(3, color(gs10)) ///
    bar(4, color(gs6)) ///
    ytitle("Contribución al crecimiento (puntos porcentuales)", size(small)) ///
    ylabel(, nogrid labsize(small)) ///
    yline(0, lpattern(dash) lcolor(gs6)) ///
    legend(order(1 "Capital (K)" 2 "Trabajo (L)" 3 "Capital humano (H)" 4 "PTF (A)") ///
           size(small) cols(2) region(lstyle(none))) ///
    graphregion(color(white) lstyle(none)) ///
    plotregion(lstyle(none)) ///
    scheme(s1mono)

graph export "GRAFICAS/figura2_contribuciones_apiladas.pdf", replace
restore

****************************************************
* FIN
****************************************************

display as text "Listo: tabla LaTeX y figuras PDF generadas en:"
display as text "  " c(pwd)
display as text "Carpetas: BASES/  TABLAS/  GRAFICAS/"
