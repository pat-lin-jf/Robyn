# Copyright (c) Facebook, Inc. and its affiliates.

# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#############################################################################################
####################         Facebook MMM Open Source - Robyn 3.0.0    ######################
####################                    Quick guide                   #######################
#############################################################################################

################################################################
#### Step 0: setup environment

## Install and load libraries
library(Robyn) # remotes::install_github("facebookexperimental/Robyn/R")
set.seed(123)

## force multicore when using RStudio
Sys.setenv(R_FUTURE_FORK_ENABLE="true")
options(future.fork.enable = TRUE)

## Must install the python library Nevergrad once
## please see here for more info about installing Python packages via reticulate
## https://rstudio.github.io/reticulate/articles/python_packages.html

## Option 1: nevergrad installation via PIP
# virtualenv_create("r-reticulate")
# py_install("nevergrad", pip = TRUE)
# use_virtualenv("r-reticulate", required = TRUE)

## Option 2: nevergrad installation via conda
# conda_create("r-reticulate") # must run this line once
# conda_install("r-reticulate", "nevergrad", pip=TRUE)
# use_condaenv("r-reticulate")

## In case nevergrad still can't be imported after installation,
## please locate your python file and run this line with your path:
# use_python("~/Library/r-miniconda/envs/r-reticulate/bin/python3.9")


################################################################
#### Step 1: load data

## Check simulated dataset or load your own dataset
data("dt_simulated_weekly")
head(dt_simulated_weekly)

## Check holidays from Prophet
# 59 countries included. If your country is not included, please manually add it.
# Tipp: any events can be added into this table, school break, events etc.
data("dt_prophet_holidays")
head(dt_prophet_holidays)

## Set robyn_object. It must have extension .RDS. The object name can be different than Robyn:
robyn_object <- "~/Desktop/MyRobyn.RDS"

################################################################
#### Step 2a: For first time user: Model specification in 4 steps

#### 2a-1: First, specify input data & model parameters

# Run ?robyn_inputs to check parameter definition
InputCollect <- robyn_inputs(
  dt_input = dt_simulated_weekly
  ,dt_holidays = dt_prophet_holidays

  ### set variables

  ,date_var = "DATE" # date format must be "2020-01-01"
  ,dep_var = "revenue" # there should be only one dependent variable
  ,dep_var_type = "revenue" # "revenue" or "conversion"

  ,prophet_vars = c("trend", "season", "holiday") # "trend","season", "weekday", "holiday"
  # are provided and case-sensitive. Recommended to at least keep Trend & Holidays
  ,prophet_signs = c("default","default", "default") # c("default", "positive", and "negative").
  # Recommend as default.Must be same length as prophet_vars
  ,prophet_country = "DE"# only one country allowed once. Including national holidays
  # for 59 countries, whose list can be found on our githut guide

  ,context_vars = c("competitor_sales_B", "events") # typically competitors, price &
  # promotion, temperature, unemployment rate etc
  ,context_signs = c("default", "default") # c("default", " positive", and "negative"),
  # control the signs of coefficients for baseline variables

  ,paid_media_vars = c("tv_S", "ooh_S"	,	"print_S"	,"facebook_I" ,"search_clicks_P")
  # c("tv_S"	,"ooh_S",	"print_S"	,"facebook_I", "facebook_S","search_clicks_P"	,"search_S")
  # we recommend to use media exposure metrics like impressions, GRP etc for the model.
  # If not applicable, use spend instead
  ,paid_media_signs = c("positive", "positive","positive", "positive", "positive")
  # c("default", "positive", and "negative"). must have same length as paid_media_vars.
  # Controls the signs of coefficients for media variables
  ,paid_media_spends = c("tv_S","ooh_S",	"print_S"	,"facebook_S", "search_S")
  # spends must have same order and same length as paid_media_vars

  ,organic_vars = c("newsletter")
  ,organic_signs = c("positive") # must have same length as organic_vars

  ,factor_vars = c("events") # specify which variables in context_vars and
  # organic_vars are factorial

  ### set model parameters

  ## set cores for parallel computing
  ,cores = 6 # I am using 6 cores from 8 on my local machine. Use future::availableCores() to find out cores

  ## set rolling window start
  ,window_start = "2016-11-23"
  ,window_end = "2018-08-22"

  ## set model core features
  ,adstock = "geometric" # geometric or weibull. weibull is more flexible, yet has one more
  # parameter and thus takes longer
  ,iterations = 2000  # number of allowed iterations per trial. 2000 is recommended

  ,nevergrad_algo = "TwoPointsDE" # recommended algorithm for Nevergrad, the gradient-free
  # optimisation library https://facebookresearch.github.io/nevergrad/index.html
  ,trials = 5 # number of allowed iterations per trial. 5 is recommended without calibration,
  # 10 with calibration.

  # Time estimation: with geometric adstock, 2000 iterations * 5 trials
  # and 6 cores, it takes less than 1 hour. Weibull takes at least twice as much time.
)


#### 2a-2: Second, define and add hyperparameters

## Guide to setup hyperparameters

## 1. get correct hyperparameter names:
# All variables in paid_media_vars or organic_vars require hyperprameter and will be
# transformed by adstock & saturation.
# Difference between paid_media_vars and organic_vars is that paid_media_vars has spend that
# needs to be specified in paid_media_spends specifically.
# Run hyper_names() to get correct hyperparameter names. all names in hyperparameters must
# equal names from hyper_names(), case sensitive.

## 2. get guidance for setting hyperparameter bounds:
# For geometric adstock, use theta, alpha & gamma. For weibull adstock,
# use shape, scale, alpha, gamma.
# Theta: In geometric adstock, theta is decay rate. guideline for usual media genre:
# TV c(0.3, 0.8), OOH/Print/Radio c(0.1, 0.4), digital c(0, 0.3)
# Shape: In weibull adstock, shape controls the decay shape. Recommended c(0.0001, 2).
# The larger, the more S-shape. The smaller, the more L-shape. Channel-type specific
# values still to be investigated
# Scale: In weibull adstock, scale controls the decay inflexion point. Very conservative
# recommended bounce c(0, 0.1), becausee scale can increase adstocking half-life greaetly.
# Channel-type specific values still to be investigated
# Alpha: In s-curve transformation with hill function, alpha controls the shape between
# exponential and s-shape. Recommended c(0.5, 3). The larger the alpha, the more S-shape.
# The smaller, the more C-shape
# Gamma: In s-curve transformation with hill function, gamma controls the inflexion point.
# Recommended bounce c(0.3, 1). The larger the gamma, the later the inflection point
# in the response curve

# helper plots: set plot to TRUE for transformation examples
plot_adstock(FALSE) # adstock transformation example plot,
# helping you understand geometric/theta and weibull/shape/scale transformation
plot_saturation(FALSE) # s-curve transformation example plot,
# helping you understand hill/alpha/gamma transformatio


## 3. set each hyperparameter bounds. They either contains two values e.g. c(0, 0.5),
# or only one value (in which case you've "fixed" that hyperparameter)

# Run ?hyper_names to check parameter definition
hyper_names(adstock = InputCollect$adstock, all_media = InputCollect$all_media)

hyperparameters <- list(
  facebook_I_alphas = c(0.5, 3) # example bounds for alpha
  ,facebook_I_gammas = c(0.3, 1) # example bounds for gamma
  ,facebook_I_thetas = c(0, 0.3) # example bounds for theta
  #,facebook_I_shapes = c(0.0001, 2) # example bounds for shape
  #,facebook_I_scales = c(0, 0.1) # example bounds for scale

  ,print_S_alphas = c(0.5, 3)
  ,print_S_gammas = c(0.3, 1)
  ,print_S_thetas = c(0.1, 0.4)
  #,print_S_shapes = c(0.0001, 2)
  #,print_S_scales = c(0, 0.1)

  ,tv_S_alphas = c(0.5, 3)
  ,tv_S_gammas = c(0.3, 1)
  ,tv_S_thetas = c(0.3, 0.8)
  #,tv_S_shapes = c(0.0001, 2)
  #,tv_S_scales= c(0, 0.1)

  ,search_clicks_P_alphas = c(0.5, 3)
  ,search_clicks_P_gammas = c(0.3, 1)
  ,search_clicks_P_thetas = c(0, 0.3)
  #,search_clicks_P_shapes = c(0.0001, 2)
  #,search_clicks_P_scales = c(0, 0.1)

  ,ooh_S_alphas = c(0.5, 3)
  ,ooh_S_gammas = c(0.3, 1)
  ,ooh_S_thetas = c(0.1, 0.4)
  #,ooh_S_shapes = c(0.0001, 2)
  #,ooh_S_scales = c(0, 0.1)

  ,newsletter_alphas = c(0.5, 3)
  ,newsletter_gammas = c(0.3, 1)
  ,newsletter_thetas = c(0.1, 0.4)
  #,newsletter_shapes = c(0.0001, 2)
  #,newsletter_scales = c(0, 0.1)
)


#### 2a-3: Third, add hyperparameters into robyn_inputs()

InputCollect <- robyn_inputs(InputCollect = InputCollect, hyperparameters = hyperparameters)

#### 2a-4: Fourth (optional), model calibration / add experimental input

## Guide for calibration source

# 1. We strongly recommend to use experimental and causal results that are considered
# ground truth to calibrate MMM. Usual experiment types are people-based (e.g. Facebook
# conversion lift) and geo-based (e.g. Facebook GeoLift).
# 2. Currently, Robyn only accepts point-estimate as calibration input. For example, if
# 10k$ spend is tested against a hold-out for channel A, then input the incremental
# return as point-estimate as the example below.
# 3. The point-estimate has to always match the spend in the variable. For example, if
# channel A usually has 100k$ weekly spend and the experimental HO is 70%, input the
# point-estimate for the 30k$, not the 70k$.

# dt_calibration <- data.frame(
#   channel = c("facebook_I",  "tv_S", "facebook_I")
#   # channel name must in paid_media_vars
#   , liftStartDate = as.Date(c("2018-05-01", "2017-11-27", "2018-07-01"))
#   # liftStartDate must be within input data range
#   , liftEndDate = as.Date(c("2018-06-10", "2017-12-03", "2018-07-20"))
#   # liftEndDate must be within input data range
#   , liftAbs = c(400000, 300000, 200000) # Provided value must be
#   # tested on same campaign level in model and same metric as dep_var_type
# )
#
# InputCollect <- robyn_inputs(InputCollect = InputCollect
#                              , calibration_input = dt_calibration)


################################################################
#### Step 2b: For known model specification, setup in one single step

## Specify hyperparameters as in 2a-2 and optionally calibration as in 2a-4 and provide them directly in robyn_inputs()

# InputCollect <- robyn_inputs(
#   dt_input = dt_simulated_weekly
#   ,dt_holidays = dt_prophet_holidays
#   ,date_var = "DATE"
#   ,dep_var = "revenue"
#   ,dep_var_type = "revenue"
#   ,prophet_vars = c("trend", "season", "holiday")
#   ,prophet_signs = c("default","default", "default")
#   ,prophet_country = "DE"
#   ,context_vars = c("competitor_sales_B", "events")
#   ,context_signs = c("default", "default")
#   ,paid_media_vars = c("tv_S", "ooh_S", 	"print_S", "facebook_I", "search_clicks_P")
#   ,paid_media_signs = c("positive", "positive", "positive", "positive", "positive")
#   ,paid_media_spends = c("tv_S", "ooh_S",	"print_S", "facebook_S", "search_S")
#   ,organic_vars = c("newsletter")
#   ,organic_signs = c("positive")
#   ,factor_vars = c("events")
#   ,cores = 6
#   ,window_start = "2016-11-23"
#   ,window_end = "2018-08-22"
#   ,adstock = "geometric"
#   ,iterations = 2000
#   ,trials = 5
#   ,hyperparameters = hyperparameters # as in 2a-2 above
#   #,calibration_input = dt_calibration # as in 2a-4 above
# )

################################################################
#### Step 3: Build initial model

# Run ?robyn_run to check parameter definition
OutputCollect <- robyn_run(
  InputCollect = InputCollect # feed in all model specification
  , plot_folder = robyn_object # plots will be saved in the same folder as robyn_object
  , pareto_fronts = 3
  , plot_pareto = TRUE
  )

## Besides one-pager plots: there are 4 csv output saved in the folder for further usage
# pareto_hyperparameters.csv, hyperparameters per Pareto output model
# pareto_aggregated.csv, aggregated decomposition per independent variable of all Pareto output
# pareto_media_transform_matrix.csv, all media transformation vectors
# pareto_alldecomp_matrix.csv, all decomposition vectors of independent variables


################################################################
#### Step 4: Select and save the initial model

## Compare all model onepagers in the plot folder and select one that mostly represents
## your business reality

OutputCollect$allSolutions # get all model IDs in result
select_model <- "2_8_1" # select one from above
robyn_save(robyn_object = robyn_object # model object location and name
           , select_model = select_model # selected model ID
           , InputCollect = InputCollect # all model input
           , OutputCollect = OutputCollect # all model output
)


################################################################
#### Step 5: Get budget allocation based on the selected model above

## Budget allocator result requires further validation. Please use this result with caution.
## Don't interpret budget allocation result if selected result doesn't meet business expectation

# Check media summary for selected model
OutputCollect$xDecompAgg[solID == select_model & !is.na(mean_spend)
                         , .(rn, coef,mean_spend, mean_response, roi_mean
                             , total_spend, total_response=xDecompAgg, roi_total, solID)]

# Run ?robyn_allocator to check parameter definition
# Run the "max_historical_response" scenario: "What's the revenue lift potential with the
# same historical spend level and what is the spend mix?"
AllocatorCollect <- robyn_allocator(
  InputCollect = InputCollect
  , OutputCollect = OutputCollect
  , select_model = select_model
  , scenario = "max_historical_response"
  , channel_constr_low = c(0.7, 0.7, 0.7, 0.7, 0.7)
  , channel_constr_up = c(1.2, 1.5, 1.5, 1.5, 1.5)
)

# View allocator result. Last column "optmResponseUnitTotalLift" is the total response lift.
AllocatorCollect$dt_optimOut

# Run the "max_response_expected_spend" scenario: "What's the maximum response for a given
# total spend based on historical saturation and what is the spend mix?" "optmSpendShareUnit"
# is the optimum spend share.
AllocatorCollect <- robyn_allocator(
  InputCollect = InputCollect
  , OutputCollect = OutputCollect
  , select_model = select_model
  , scenario = "max_response_expected_spend"
  , channel_constr_low = c(0.7, 0.7, 0.7, 0.7, 0.7)
  , channel_constr_up = c(1.2, 1.5, 1.5, 1.5, 1.5)
  , expected_spend = 1000000 # Total spend to be simulated
  , expected_spend_days = 7 # Duration of expected_spend in days
)

# View allocator result. Column "optmResponseUnitTotal" is the maximum unit (weekly with
# simulated dataset) response. "optmSpendShareUnit" is the optimum spend share.
AllocatorCollect$dt_optimOut

## QA optimal response
# select_media <- "search_clicks_P"
# optimal_spend <- AllocatorCollect$dt_optimOut[channels== select_media, optmSpendUnit]
# optimal_response_allocator <- AllocatorCollect$dt_optimOut[channels== select_media
#                                                            , optmResponseUnit]
# optimal_response <- robyn_response(robyn_object = robyn_object
#                                    , select_build = 0
#                                    , paid_media_var = select_media
#                                    , spend = optimal_spend)
# round(optimal_response_allocator) == round(optimal_response)
# optimal_response_allocator; optimal_response


################################################################
#### Step 6: Model refresh based on selected model and saved Robyn.RDS object - Alpha

## NOTE: must run robyn_save to select and save an initial model first, before refreshing below
## The robyn_refresh() function is suitable for updating within "reasonable periods"
## Two situations are considered better to rebuild model:
## 1, most data is new. If initial model has 100 weeks and 80 weeks new data is added in refresh,
## it might be better to rebuild the model
## 2, new variables are added

# Run ?robyn_refresh to check parameter definition
Robyn <- robyn_refresh(
  robyn_object = robyn_object
  , dt_input = dt_simulated_weekly
  , dt_holidays = dt_prophet_holidays
  , refresh_steps = 13
  , refresh_mode = "auto"
  , refresh_iters = 1000 # Iteration for refresh. 600 is rough estimation. We'll still
  # figuring out what's the ideal number.
  , refresh_trials = 3
)

## Besides plots: there're 4 csv output saved in the folder for further usage
# report_hyperparameters.csv, hyperparameters of all selected model for reporting
# report_aggregated.csv, aggregated decomposition per independent variable
# report_media_transform_matrix.csv, all media transformation vectors
# report_alldecomp_matrix.csv,all decomposition vectors of independent variables


################################################################
#### Step 7: Get budget allocation recommendation based on selected refresh runs

# Run ?robyn_allocator to check parameter definition
AllocatorCollect <- robyn_allocator(
  robyn_object = robyn_object
  , select_build = 3 # Use third refresh model
  , scenario = "max_response_expected_spend"
  , channel_constr_low = c(0.7, 0.7, 0.7, 0.7, 0.7)
  , channel_constr_up = c(1.2, 1.5, 1.5, 1.5, 1.5)
  , expected_spend = 2000000 # Total spend to be simulated
  , expected_spend_days = 14 # Duration of expected_spend in days
)

AllocatorCollect$dt_optimOut

################################################################
#### Step 8: get marginal returns

## Example of how to get marginal ROI of next 1000$ from the 80k spend level for search channel

# Run ?robyn_response to check parameter definition

# Get response for 80k
Spend1 <- 80000
Response1 <- robyn_response(
  robyn_object = robyn_object
  #, select_build = 1 # 2 means the second refresh model. 0 means the initial model
  , paid_media_var = "search_clicks_P"
  , spend = Spend1)
Response1/Spend1 # ROI for search 80k

# Get response for 81k
Spend2 <- Spend1+1000
Response2 <- robyn_response(
  robyn_object = robyn_object
  #, select_build = 1
  , paid_media_var = "search_clicks_P"
  , spend = Spend2)
Response2/Spend2 # ROI for search 81k

# Marginal ROI of next 1000$ from 80k spend level for search
(Response2-Response1)/(Spend2-Spend1)


################################################################
#### Optional: get old model results

# Get old hyperparameters and select model
dt_hyper_fixed <- fread("~/Desktop/2021-07-29 00.56 init/pareto_hyperparameters.csv")
select_model <- "1_24_5"
dt_hyper_fixed <- dt_hyper_fixed[solID == select_model]

OutputCollectFixed <- robyn_run(
  # InputCollect must be provided by robyn_inputs with same dataset and parameters as before
  InputCollect = InputCollect
  , plot_folder = robyn_object
  , dt_hyper_fixed = dt_hyper_fixed)

# Save Robyn object for further refresh
robyn_save(robyn_object = robyn_object
           , select_model = select_model
           , InputCollect = InputCollect
           , OutputCollect = OutputCollectFixed)
