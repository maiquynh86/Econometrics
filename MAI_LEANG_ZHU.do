drop _all

import delimited "C:\Users\mai\OneDrive\Máy tính\kc_house_data.csv"


                *****************************************
                         ***** I. CLEANING THE DATA
                 ***************************************** 
		
rename v19 lot
rename view view1
drop sqft_living15 sqft_lot15 sqft_above sqft_basement  sqft_lot bedrooms

* How long the appartment was built?
gen age = real(substr(date, 1, 4)) - yr_built

* Was the appartment renovated or not? 
gen renovated=1 
replace renovated=0 if yr_renovated == 0


* What is the distance from the house to the center?
sum lat, detail 
** median of lat is 47.5718 
sum lot, detail
** median of long is -122.23 
gen dist1 = lat - 47.5718 
gen dist1_sq = dist1*dist1
gen dist2 = lot + 122.23 
gen dist2_sq = dist2*dist2
gen dist_from_cent = sqrt(dist1_sq + dist2_sq)
drop dist1 dist1_sq dist2 dist2_sq 


                *****************************************
                         ***** II. DESCRIPTION OF THE DATA
                 ***************************************** 
* Summarize the data
sum price bathrooms sqft_living floors waterfront view1 condition grade age renovated dist_from_cent
*** ==> Looking at the table, we see that the standard deviation of price and sqft_living are high, probably we should log them
sum price, detail 
sum sqft_living, detail

* Diagram of variables
histogram price, name("graph1", replace)	
histogram bathrooms, name("graph2", replace)	
histogram sqft_living, name("graph3", replace)	
histogram floors, name("graph4", replace)
histogram waterfront, name("graph5", replace)
histogram view1, name("graph6", replace)
histogram condition, name("graph7", replace)
histogram grade, name("graph8", replace)
histogram age, name("graph9", replace)
histogram renovated, name("graph10", replace)
histogram dist_from_cent, name("graph11", replace)

graph combine graph1 graph3 
*** ==> We should logprice and logsqft_living because using the logarithm of one or more variables improves the fit of the model by transforming the distribution of the features to a more normally-shaped bell curve

* Generating log variables for continuous variables
gen logprice = log(price)
gen logsqft_living = log(sqft_living)

kdensity logprice, name ("graph01", replace) 
kdensity logsqft_living, name ("graph02", replace) 

graph combine graph01 graph02 
*** ==> more normally-shaped bell curve

* Latitude Vs Longitude, Colored by Price
sum price, detail

graph twoway (scatter lat lot if price <= 321950 , mcolor(blue) msize(0.5pt)) ||  (scatter lat lot if price >321950  & price <= 450000, mcolor(ebblue) msize(0.5pt)) || (scatter lat lot if price >450000 & price <= 645000 , mcolor(purple) msize(0.5pt)) || (scatter lat lot if price >645000  & price <= 887000 , mcolor(red) msize(0.5pt)) || (scatter lat lot if price >=887000  & price < 1157200 , mcolor(orange) msize(0.5pt)) || (scatter lat lot if price >=1157200  & price < 1965000 , mcolor(yellow) msize(0.5pt)) || (scatter lat lot if price >= 1965000 , mcolor(green) msize(0.5pt)), aspect(1)
*** ==> The higher prices are concentrated in the north of the city. The top of 5% of highest prices are in the central and northeast of the city (green points)

graph twoway (scatter logprice dist_from_cent, msize(vtiny)) (lfit logprice dist_from_cent), ytitle("log of price") xtitle("the distance from the center of County") title("Scatter representation : the log-level transformation")
*** ==> The further away from the center, the lower the price and the smaller the price range (standard deviation)





                *****************************************
                         ***** III. BUILDING LINEAR REGRESSION MODEL
                 ***************************************** 

* Single linear regression model (between logprice and logsqft_living)
reg logprice logsqft_living
*** ==> All indicators show that logsqft_living is relevant and a good first step to build a reliable model


* Steps to build Multiple Linear Regression Model 

** Run Linear Regression, find VIF (Variance Inflation Factor)
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent
vif
*** ==> VIF > 5 indicates a high risk of multicollinearity ==> the choosen variables are suitable

** Check Multicollinearity
correlate logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent
*** ==> condition, age has non-significant correltion with logprice
test (age renovated condition) 
*** ==> keep them

** Multiple Linear Regression Model 
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent
*** ==> a better linear regression




                *****************************************
                         ***** IV. OUTLIERS DETECTION AND ELIMINATION
                 ***************************************** 

rvfplot, msize(small) yline(0)
predict residu, resid
gen outliers_resid= 0
replace outliers_resid = 1 if (residu > 1.1 | residu < -1.1) 
tab outliers_resid
*** ==> 0.05% of observations are located above this area
drop if (residu > 1.1 | residu < -1.1) 

lvr2plot, msize(small) yline(0.0085) 

*** ==> We can remove the points which are far away from the others based on the leverage axis and normalized residual squared axis. In this case, we see the number of these points are negligible compared to the sample size, so we keep it




                *****************************************
                         ***** V. GRAPHICAL ANALYSIS OF HETEROSCEDASTICITY
                 ***************************************** 


* Regression model for price
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent

* Predicted values and residuals 
predict yhat, xb
predict uhat, residual

* Graph of residuals against independent variable
graph twoway (scatter uhat logsqft_living) (lfit uhat logsqft_living)

* Graph of residuals against fitted values 
rvfplot, msize(small) yline(0)
*** ==> From the graph, there is a hint of heteroscedasticity, with the variance of residuals getting smaller as the fitted value increases.





                *****************************************
                         ***** VI. HETEROSCEDASTICITY TESTS
                 ***************************************** 


* Heteroscedasticity tests involve estimating the regression model, 
* regressing the squared residuals uhatsq on combination of independent variables
* and doing F-test 

* Regression model
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent

* Get residuals and predicted values, and square them
* predict uhat, residual
gen uhatsq = uhat^2
* predict yhat, xb
gen yhatsq = yhat^2

****** BREUSCH-PAGAN TEST *****

* Regression for Breusch-Pagan test
reg uhatsq bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent

* ====================== Another way ====================
estat hettest, rhs iid
*** ==> This default test generated a p-value of 0.0000 which, as it is less than my chosen significance value of 0.05, indicates a statistically significant Chi-square test. This result indicates the presence of heteroskedasticity in the dependent variable logprice.


***** WHITE TEST *****

* Regression for White test
reg uhatsq yhat yhatsq

* ====================== Another way ====================
ssc install whitetst
whitetst
estat imtest, white
*** ==> All tests show heteroskedasticity 




                *****************************************
                         ***** VII. HETEROSCEDASTICITY ROBUST STANDARD ERRORS
                 ***************************************** 

				 

* Robust standard errors correct for heteroscedasticity
* Robust standard errors are not needed for homoscedastic 

* Regression model 
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent

* Regression model with robust standard errors
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent, robust
*** ==> Same coefficients, but robust standard errors are different



                *****************************************
                         ***** VIII. FEASIBLE GLS (FGLS)
                 ***************************************** 


* When the heteroscedasticity form is not known, 
* var(u|x) = sigma^2*exp(delta0 + delta1*bathrooms + delta2*logsqft_living + delta3*floors + delta4*waterfront + delta5*view + delta6*condition + delta7*grade + delta8*age + delta9*renovated + delta10*logdist_from_cent)
* estimate hhat and use WLS with weight=1/hhat.

* Heteroscedasticity form, estimate hhat
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent
predict u, residual
gen g=ln(u*u)
reg g bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent
predict ghat, xb
gen hhat=exp(ghat)

* FGLS: estimate model using WLS with weight=1/hhat
reg logprice bathrooms logsqft_living floors waterfront view1 condition grade age renovated dist_from_cent [aweight=1/hhat]

* ====================== Another way ====================
* Multiply all variables and the constant by 1/sqrt(hhat)
gen logpricestar = logprice/sqrt(hhat) 
gen bathroomsstar = bathrooms/sqrt(hhat) 
gen logsqft_livingstar = logsqft_living/sqrt(hhat) 
gen floorsstar = floors/sqrt(hhat) 
gen waterfrontstar = waterfront/sqrt(hhat) 
gen viewstar = view/sqrt(hhat) 
gen conditionstar = condition/sqrt(hhat)
gen gradestar = grade/sqrt(hhat) 
gen agestar = age/sqrt(hhat) 
gen renovatedstar = renovated/sqrt(hhat) 
gen dist_from_centstar = dist_from_cent/sqrt(hhat)  
gen constantstar = 1/sqrt(hhat) 

* FGLS: estimate model with transformed variables by OLS
reg logpricestar bathroomsstar logsqft_livingstar floorsstar waterfrontstar viewstar conditionstar gradestar agestar renovatedstar dist_from_centstar constantstar, noconstant
*** ==> R-squared is really better





