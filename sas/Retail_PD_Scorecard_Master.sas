/********************************************************************************
 PROGRAM NAME : Retail_PD_Scorecard_Master.sas
 PROJECT      : Retail Banking Probability of Default (PD) Scorecard
 DESCRIPTION  : End-to-end 21-module SAS scorecard workflow
 DATA         : UCI Credit Card Default dataset
 AUTHOR       : Credit Risk Modeling & Analytics
********************************************************************************/

/*==============================================================================
  GLOBAL SETTINGS
==============================================================================*/

/* Keep the log readable. */
options mprint;
ods graphics on;

/*------------------------------------------------------------------------------
  Project paths for the current SAS Studio environment
------------------------------------------------------------------------------*/
%let PROJ_ROOT=/home/u64582537/sasuser.v94;
%let INPUT_FILE=&PROJ_ROOT./UCI_Credit_Card.csv;
%let RAW_PATH=&PROJ_ROOT./raw;
%let MODEL_PATH=&PROJ_ROOT./model;
%let OUTPUT_PATH=&PROJ_ROOT./output;
%let REPORT_PATH=&PROJ_ROOT./Retail_PD_Scorecard_Final_Report.pdf;

/*------------------------------------------------------------------------------
  Create the project folders through LIBNAME assignment.
  DLCREATEDIR tells SAS to create the final directory when needed.
------------------------------------------------------------------------------*/
options dlcreatedir;

libname raw "&RAW_PATH.";
libname model "&MODEL_PATH.";
libname output "&OUTPUT_PATH.";

/* Clean WORK so old datasets from earlier SAS Studio runs cannot interfere. */
proc datasets library=work kill nolist;
quit;

/* Target */
%let TARGET=default_payment_next_month;


/*==============================================================================
  MODULE 01: DATA IMPORT & BASE DATASET
==============================================================================*/

proc import datafile="&INPUT_FILE."
    out=work.credit_raw
    dbms=csv
    replace;
    getnames=yes;
run;

data raw.credit_data;
    set work.credit_raw;

    label
        ID = "Customer Unique Identification Number"
        LIMIT_BAL = "Credit Line Amount"
        SEX = "Gender"
        EDUCATION = "Education Level"
        MARRIAGE = "Marital Status"
        AGE = "Age"
        PAY_0 = "Repayment Status Sept 2005"
        PAY_2 = "Repayment Status Aug 2005"
        PAY_3 = "Repayment Status Jul 2005"
        PAY_4 = "Repayment Status Jun 2005"
        PAY_5 = "Repayment Status May 2005"
        PAY_6 = "Repayment Status Apr 2005"
        &TARGET. = "Target: Default Next Month";

    format
        LIMIT_BAL
        BILL_AMT1-BILL_AMT6
        PAY_AMT1-PAY_AMT6
        comma16.2;
run;


/*==============================================================================
  MODULE 02: DATA QUALITY & CLEANING
==============================================================================*/

proc sort data=raw.credit_data
          out=work.credit_nodup
          nodupkey
          dupout=work.duplicate_records;
    by ID;
run;

data raw.cleaned_data;
    set work.credit_nodup;

    /* Education: invalid/missing -> Others */
    if EDUCATION in (0,5,6) or missing(EDUCATION) then
        EDUCATION=4;

    /* Marriage: invalid/missing -> Others */
    if MARRIAGE=0 or missing(MARRIAGE) then
        MARRIAGE=3;

    /* Repayment statuses: negative codes -> 0 */
    array pay_status[*] PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6;

    do i=1 to dim(pay_status);
        if pay_status[i] < 0 then
            pay_status[i]=0;
    end;

    drop i;
run;


/*==============================================================================
  MODULE 03: EXPLORATORY DATA ANALYSIS (EDA)
==============================================================================*/

proc freq data=raw.cleaned_data;
    tables &TARGET.;
run;

proc summary data=raw.cleaned_data
             n nmiss mean std min q1 median q3 max;
    class &TARGET.;
    var LIMIT_BAL AGE BILL_AMT1 PAY_AMT1;
    output out=work.eda_numeric_summary;
run;

proc freq data=raw.cleaned_data;
    tables
        SEX*&TARGET.
        EDUCATION*&TARGET.
        MARRIAGE*&TARGET.
        PAY_0*&TARGET.
        / chisq crosslist;
run;

/* Clean PAY_0 default-rate table */
proc sql;
    create table work.pay0_default_analysis as
    select
        PAY_0,
        count(*) as Total_Customers,
        sum(&TARGET.) as Default_Customers,
        calculated Default_Customers /
        calculated Total_Customers as Default_Rate format=percent8.2
    from raw.cleaned_data
    group by PAY_0
    order by PAY_0;
quit;


/*==============================================================================
  MODULE 04: MISSING VALUE TREATMENT
==============================================================================*/

proc means data=raw.cleaned_data n nmiss;
    var
        LIMIT_BAL AGE
        BILL_AMT1-BILL_AMT6
        PAY_AMT1-PAY_AMT6
        PAY_0 PAY_2-PAY_6
        SEX EDUCATION MARRIAGE;
run;

/* Current dataset has no missing values in checked fields.
   Keep a dedicated analytical copy for downstream modules. */
data raw.imputed_data;
    set raw.cleaned_data;
run;


/*==============================================================================
  MODULE 05: OUTLIER TREATMENT - 1st / 99th PERCENTILE WINSORIZATION
==============================================================================*/

/* Explicit percentile extraction for robust SAS compatibility */
proc univariate data=raw.imputed_data noprint;
    var LIMIT_BAL;
    output out=work.p_limit_bal
        p1=LB_P1
        p99=LB_P99;
run;

proc univariate data=raw.imputed_data noprint;
    var BILL_AMT1-BILL_AMT6;
    output out=work.p_bill
        p1=B1_P1 B2_P1 B3_P1 B4_P1 B5_P1 B6_P1
        p99=B1_P99 B2_P99 B3_P99 B4_P99 B5_P99 B6_P99;
run;

proc univariate data=raw.imputed_data noprint;
    var PAY_AMT1-PAY_AMT6;
    output out=work.p_pay
        p1=P1_P1 P2_P1 P3_P1 P4_P1 P5_P1 P6_P1
        p99=P1_P99 P2_P99 P3_P99 P4_P99 P5_P99 P6_P99;
run;

data raw.treated_data;
    if _n_=1 then do;
        set work.p_limit_bal;
        set work.p_bill;
        set work.p_pay;
    end;

    set raw.imputed_data;

    /* 1st percentile floor and 99th percentile cap */
    if LIMIT_BAL < LB_P1 then LIMIT_BAL=LB_P1;
    else if LIMIT_BAL > LB_P99 then LIMIT_BAL=LB_P99;

    if BILL_AMT1 < B1_P1 then BILL_AMT1=B1_P1;
    else if BILL_AMT1 > B1_P99 then BILL_AMT1=B1_P99;

    if BILL_AMT2 < B2_P1 then BILL_AMT2=B2_P1;
    else if BILL_AMT2 > B2_P99 then BILL_AMT2=B2_P99;

    if BILL_AMT3 < B3_P1 then BILL_AMT3=B3_P1;
    else if BILL_AMT3 > B3_P99 then BILL_AMT3=B3_P99;

    if BILL_AMT4 < B4_P1 then BILL_AMT4=B4_P1;
    else if BILL_AMT4 > B4_P99 then BILL_AMT4=B4_P99;

    if BILL_AMT5 < B5_P1 then BILL_AMT5=B5_P1;
    else if BILL_AMT5 > B5_P99 then BILL_AMT5=B5_P99;

    if BILL_AMT6 < B6_P1 then BILL_AMT6=B6_P1;
    else if BILL_AMT6 > B6_P99 then BILL_AMT6=B6_P99;

    if PAY_AMT1 < P1_P1 then PAY_AMT1=P1_P1;
    else if PAY_AMT1 > P1_P99 then PAY_AMT1=P1_P99;

    if PAY_AMT2 < P2_P1 then PAY_AMT2=P2_P1;
    else if PAY_AMT2 > P2_P99 then PAY_AMT2=P2_P99;

    if PAY_AMT3 < P3_P1 then PAY_AMT3=P3_P1;
    else if PAY_AMT3 > P3_P99 then PAY_AMT3=P3_P99;

    if PAY_AMT4 < P4_P1 then PAY_AMT4=P4_P1;
    else if PAY_AMT4 > P4_P99 then PAY_AMT4=P4_P99;

    if PAY_AMT5 < P5_P1 then PAY_AMT5=P5_P1;
    else if PAY_AMT5 > P5_P99 then PAY_AMT5=P5_P99;

    if PAY_AMT6 < P6_P1 then PAY_AMT6=P6_P1;
    else if PAY_AMT6 > P6_P99 then PAY_AMT6=P6_P99;

    drop
        LB_P1 LB_P99
        B1_P1 B1_P99 B2_P1 B2_P99 B3_P1 B3_P99
        B4_P1 B4_P99 B5_P1 B5_P99 B6_P1 B6_P99
        P1_P1 P1_P99 P2_P1 P2_P99 P3_P1 P3_P99
        P4_P1 P4_P99 P5_P1 P5_P99 P6_P1 P6_P99;
run;

/*==============================================================================
  MODULE 06: STRATIFIED TRAIN / TEST SPLIT
==============================================================================*/

proc sort data=raw.treated_data
          out=work.treated_sorted;
    by &TARGET.;
run;

proc surveyselect data=work.treated_sorted
    samprate=0.70
    method=srs
    out=work.split_sample
    outall
    seed=98765432;
    strata &TARGET.;
run;

data raw.train raw.test;
    set work.split_sample;
    if Selected=1 then output raw.train;
    else output raw.test;
run;


/*==============================================================================
  MODULE 07: SCORECARD BINNING
==============================================================================*/

%macro create_bins(indata=,outdata=);

data &outdata.;
    set &indata.;

    length
        BIN_PAY_0 $30
        BIN_AGE $30
        BIN_LIMIT_BAL $30;

    if PAY_0=0 then
        BIN_PAY_0="01: Duly Paid/No Delay";
    else if PAY_0=1 then
        BIN_PAY_0="02: 1 Month Delay";
    else if PAY_0=2 then
        BIN_PAY_0="03: 2 Months Delay";
    else if PAY_0>=3 then
        BIN_PAY_0="04: 3+ Months Delay";

    if AGE<25 then
        BIN_AGE="01: <25";
    else if AGE<35 then
        BIN_AGE="02: 25-34";
    else if AGE<45 then
        BIN_AGE="03: 35-44";
    else if AGE<55 then
        BIN_AGE="04: 45-54";
    else
        BIN_AGE="05: 55+";

    if LIMIT_BAL<=50000 then
        BIN_LIMIT_BAL="01: <= 50k";
    else if LIMIT_BAL<=100000 then
        BIN_LIMIT_BAL="02: 50k-100k";
    else if LIMIT_BAL<=200000 then
        BIN_LIMIT_BAL="03: 100k-200k";
    else
        BIN_LIMIT_BAL="04: > 200k";
run;

%mend;

%create_bins(indata=raw.train,outdata=raw.binned_train);

proc freq data=raw.binned_train;
    tables BIN_PAY_0 BIN_AGE BIN_LIMIT_BAL;
run;


/*==============================================================================
  MODULE 08: WOE & INFORMATION VALUE
==============================================================================*/

%macro calc_woe_iv(indata=,var=,target=,outdata=);

    proc sql noprint;
        select
            sum(&target.),
            count(*)-sum(&target.)
        into
            :total_bads,
            :total_goods
        from &indata.;
    quit;

    proc sql;
        create table &outdata. as
        select
            "&var." as Variable length=32,
            &var. as Bin_Value length=50,
            count(*) as Total_Cnt,
            sum(&target.) as Bad_Cnt,
            count(*)-sum(&target.) as Good_Cnt,
            calculated Good_Cnt/&total_goods. as Prop_Good,
            calculated Bad_Cnt/&total_bads. as Prop_Bad,

            log(
                (calculated Good_Cnt/&total_goods.) /
                ((calculated Bad_Cnt/&total_bads.)+0.00001)
            ) as WOE,

            (
                (calculated Good_Cnt/&total_goods.) -
                (calculated Bad_Cnt/&total_bads.)
            ) *
            calculated WOE as IV_Weight

        from &indata.
        group by &var.;
    quit;

%mend;

%calc_woe_iv(
    indata=raw.binned_train,
    var=BIN_PAY_0,
    target=&TARGET.,
    outdata=work.woe_pay0
);

%calc_woe_iv(
    indata=raw.binned_train,
    var=BIN_AGE,
    target=&TARGET.,
    outdata=work.woe_age
);

%calc_woe_iv(
    indata=raw.binned_train,
    var=BIN_LIMIT_BAL,
    target=&TARGET.,
    outdata=work.woe_limit
);

proc sql;
    create table output.iv_summary as
    select
        "PAY_0" as Variable length=20,
        sum(IV_Weight) as Total_IV
    from work.woe_pay0
    union all
    select
        "AGE",
        sum(IV_Weight)
    from work.woe_age
    union all
    select
        "LIMIT_BAL",
        sum(IV_Weight)
    from work.woe_limit;
quit;

data output.iv_summary;
    set output.iv_summary;
    length Predictive_Power $30;

    if Total_IV<0.02 then
        Predictive_Power="Weak (<0.02)";
    else if Total_IV<=0.10 then
        Predictive_Power="Low (0.02-0.1)";
    else if Total_IV<=0.30 then
        Predictive_Power="Medium (0.1-0.3)";
    else if Total_IV<=0.50 then
        Predictive_Power="Strong (0.3-0.5)";
    else
        Predictive_Power="Suspiciously High (>0.5)";
run;


/*==============================================================================
  MODULE 09: WOE TRANSFORMATION
==============================================================================*/

proc sql;
    create table raw.modeling_train as
    select
        a.*,
        b.WOE as WOE_PAY_0,
        c.WOE as WOE_AGE,
        d.WOE as WOE_LIMIT_BAL
    from raw.binned_train as a
    left join work.woe_pay0 as b
        on a.BIN_PAY_0=b.Bin_Value
    left join work.woe_age as c
        on a.BIN_AGE=c.Bin_Value
    left join work.woe_limit as d
        on a.BIN_LIMIT_BAL=d.Bin_Value;
quit;


/*==============================================================================
  MODULE 10: VIF / MULTICOLLINEARITY
==============================================================================*/

ods graphics off;

proc reg data=raw.modeling_train;
    model &TARGET.=
        WOE_PAY_0
        WOE_AGE
        WOE_LIMIT_BAL
        / vif tol;
    ods output
        ParameterEstimates=output.vif_report;
run;
quit;

ods graphics on;

proc corr data=raw.modeling_train
          out=output.correlation_matrix
          noprint;
    var WOE_PAY_0 WOE_AGE WOE_LIMIT_BAL;
run;


/*==============================================================================
  MODULE 11: LOGISTIC REGRESSION / PD MODEL
==============================================================================*/

ods select none;

proc logistic data=raw.modeling_train descending
              outmodel=model.logistic_pd_model;

    model &TARGET.=
        WOE_PAY_0
        WOE_AGE
        WOE_LIMIT_BAL;

    output out=work.train_scored_raw
        p=PD_HAT;

    ods output
        ParameterEstimates=output.logistic_coefficients
        FitStatistics=output.logistic_fit_statistics
        Association=output.logistic_association;

run;

ods select all;


/* Keep only required coefficient fields */
data work.logit_parameters;
    set output.logistic_coefficients;
run;


/* Extract coefficients dynamically */
proc sql noprint;

    select Estimate into :BETA_INTERCEPT trimmed
    from work.logit_parameters
    where upcase(Variable)="INTERCEPT";

    select Estimate into :BETA_PAY0 trimmed
    from work.logit_parameters
    where upcase(Variable)="WOE_PAY_0";

    select Estimate into :BETA_AGE trimmed
    from work.logit_parameters
    where upcase(Variable)="WOE_AGE";

    select Estimate into :BETA_LIMIT trimmed
    from work.logit_parameters
    where upcase(Variable)="WOE_LIMIT_BAL";

quit;


/*==============================================================================
  MODULE 12: HOSMER-LEMESHOW GOODNESS OF FIT
==============================================================================*/

ods select none;

proc logistic data=raw.modeling_train;
    model &TARGET.(event='1')=
        WOE_PAY_0
        WOE_AGE
        WOE_LIMIT_BAL
        / lackfit;

    ods output
        LackFitPartition=output.hosmer_lemeshow;
run;

ods select all;


/*==============================================================================
  MODULE 13: AUC + GINI + KS
==============================================================================*/

/* Extract AUC from association table */
data work.auc_gini;
    set output.logistic_association;
    where lowcase(Label2)="c";

    AUC=nValue2;
    Gini=(2*AUC-1)*100;

    keep AUC Gini;
run;


/* Train scored probabilities */
data raw.scored_train;
    set work.train_scored_raw;
run;


/* KS */
proc sort data=raw.scored_train
          out=work.train_scored_sorted;
    by descending PD_HAT;
run;

data work.ks_calculation;
    set work.train_scored_sorted;

    retain Cum_Bads 0 Cum_Goods 0;

    if &TARGET.=1 then
        Cum_Bads+1;
    else
        Cum_Goods+1;
run;

proc sql noprint;
    select
        sum(&TARGET.),
        count(*)-sum(&TARGET.)
    into
        :TOTAL_BADS,
        :TOTAL_GOODS
    from work.ks_calculation;
quit;

data work.ks_summary;
    set work.ks_calculation;

    PCT_CUM_BADS=
        Cum_Bads/&TOTAL_BADS.;

    PCT_CUM_GOODS=
        Cum_Goods/&TOTAL_GOODS.;

    KS_STAT=
        abs(PCT_CUM_BADS-PCT_CUM_GOODS)*100;
run;

proc sql;
    create table output.ks_summary as
    select *
    from work.ks_summary;

    create table output.max_ks_metric as
    select
        max(KS_STAT) as Max_KS_Statistic format=8.2,
        (select AUC from work.auc_gini) as Model_AUC format=8.4,
        (select Gini from work.auc_gini) as Estimated_Gini format=8.2
    from work.ks_summary;
quit;


/*==============================================================================
  MODULE 14: SCORECARD POINTS ALLOCATION
==============================================================================*/

/* Score scaling */
data work.score_scaling;
    Base_Score=600;
    Base_Odds=50;
    PDO=20;

    Factor=PDO/log(2);
    Offset=Base_Score-(Factor*log(Base_Odds));
run;

proc sql noprint;
    select Factor, Offset
        into :FACTOR_VAL, :OFFSET_VAL
    from work.score_scaling;
quit;


/* Base points allocated across three predictors */
%let BASE_POINTS_PER_VARIABLE=%sysevalf((&OFFSET_VAL.)/3);


/* PAY_0 points */
data work.points_pay0;
    set work.woe_pay0;

    length Variable $20 Bin_Name $50;

    Variable="PAY_0";
    Bin_Name=Bin_Value;

    Points=round(
        &BASE_POINTS_PER_VARIABLE.
        -
        (&FACTOR_VAL.*&BETA_PAY0.*WOE)
    );

    keep Variable Bin_Name WOE Points;
run;


/* AGE points */
data work.points_age;
    set work.woe_age;

    length Variable $20 Bin_Name $50;

    Variable="AGE";
    Bin_Name=Bin_Value;

    Points=round(
        &BASE_POINTS_PER_VARIABLE.
        -
        (&FACTOR_VAL.*&BETA_AGE.*WOE)
    );

    keep Variable Bin_Name WOE Points;
run;


/* LIMIT_BAL points */
data work.points_limit;
    set work.woe_limit;

    length Variable $20 Bin_Name $50;

    Variable="LIMIT_BAL";
    Bin_Name=Bin_Value;

    Points=round(
        &BASE_POINTS_PER_VARIABLE.
        -
        (&FACTOR_VAL.*&BETA_LIMIT.*WOE)
    );

    keep Variable Bin_Name WOE Points;
run;


/* Final scorecard table */
data output.scorecard_points_table;
    set
        work.points_pay0
        work.points_age
        work.points_limit;
run;


/*==============================================================================
  MODULE 15: SCORE SCALING
==============================================================================*/

data raw.scored_train;
    set raw.scored_train;

    if PD_HAT>0 and PD_HAT<1 then do;
        Logit=log(PD_HAT/(1-PD_HAT));

        Credit_Score=
            round(
                &OFFSET_VAL. -
                (&FACTOR_VAL.*Logit)
            );
    end;

    if Credit_Score<300 then Credit_Score=300;
    if Credit_Score>850 then Credit_Score=850;
run;


/*==============================================================================
  MODULE 16: DECILE / RANK-ORDERING VALIDATION
==============================================================================*/

proc rank data=raw.scored_train
          out=work.decile_ranked
          groups=10
          descending;
    var Credit_Score;
    ranks Decile;
run;

proc sql;
    create table output.decile_analysis as
    select
        Decile+1 as Score_Decile,
        min(Credit_Score) as Min_Score,
        max(Credit_Score) as Max_Score,
        count(*) as Total_Accounts,
        sum(&TARGET.) as Bad_Accounts,
        count(*)-sum(&TARGET.) as Good_Accounts,
        sum(&TARGET.)/count(*) as Bad_Rate format=percent8.2,
        mean(PD_HAT) as Avg_Predicted_PD format=percent8.2
    from work.decile_ranked
    group by Decile
    order by Score_Decile;
quit;


/*==============================================================================
  MODULE 17: RISK-ORDERED LIFT / GAINS
==============================================================================*/

proc sort data=raw.scored_train
          out=work.risk_sorted;
    by Credit_Score;
run;

proc rank data=work.risk_sorted
          out=work.risk_deciles
          groups=10;
    var Credit_Score;
    ranks Risk_Decile;
run;

data work.risk_deciles;
    set work.risk_deciles;
    Risk_Decile=Risk_Decile+1;
run;

proc sql;
    create table work.risk_decile_summary as
    select
        Risk_Decile,
        min(Credit_Score) as Min_Score,
        max(Credit_Score) as Max_Score,
        count(*) as Total_Accounts,
        sum(&TARGET.) as Bad_Accounts,
        count(*)-sum(&TARGET.) as Good_Accounts,
        sum(&TARGET.)/count(*) as Bad_Rate format=percent8.2
    from work.risk_deciles
    group by Risk_Decile
    order by Risk_Decile;
quit;

proc sql noprint;
    select
        sum(Total_Accounts),
        sum(Bad_Accounts)
    into
        :RISK_TOTAL_ACCOUNTS,
        :RISK_TOTAL_BADS
    from work.risk_decile_summary;
quit;

data output.risk_lift_gains;
    set work.risk_decile_summary;

    retain
        Cumulative_Accounts 0
        Cumulative_Bads 0;

    Cumulative_Accounts=
        Cumulative_Accounts+Total_Accounts;

    Cumulative_Bads=
        Cumulative_Bads+Bad_Accounts;

    Cumulative_Population=
        (Cumulative_Accounts/&RISK_TOTAL_ACCOUNTS.)*100;

    Cumulative_Gains=
        (Cumulative_Bads/&RISK_TOTAL_BADS.)*100;

    Lift=
        Cumulative_Gains/Cumulative_Population;

    format
        Cumulative_Population
        Cumulative_Gains
        Lift 8.2;
run;


/*==============================================================================
  MODULE 18: POPULATION STABILITY INDEX (PSI)
==============================================================================*/

/* Create TEST bins using the exact same development rules */
%create_bins(indata=raw.test,outdata=raw.binned_test);


/* Attach TRAIN WOE mappings to TEST */
proc sql;
    create table work.woe_test as
    select
        a.*,
        b.WOE as WOE_PAY_0,
        c.WOE as WOE_AGE,
        d.WOE as WOE_LIMIT_BAL
    from raw.binned_test as a
    left join work.woe_pay0 as b
        on a.BIN_PAY_0=b.Bin_Value
    left join work.woe_age as c
        on a.BIN_AGE=c.Bin_Value
    left join work.woe_limit as d
        on a.BIN_LIMIT_BAL=d.Bin_Value;
quit;


/* Score TEST dynamically from fitted coefficients */
data raw.scored_test;
    set work.woe_test;

    Logit=
        &BETA_INTERCEPT.
        + (&BETA_PAY0.*WOE_PAY_0)
        + (&BETA_AGE.*WOE_AGE)
        + (&BETA_LIMIT.*WOE_LIMIT_BAL);

    PD_HAT=
        1/(1+exp(-Logit));

    Credit_Score=
        round(
            &OFFSET_VAL. -
            (&FACTOR_VAL.*Logit)
        );

    if Credit_Score<300 then Credit_Score=300;
    if Credit_Score>850 then Credit_Score=850;
run;


/* Score bands */
%macro create_score_band(indata=,outdata=);
data &outdata.;
    set &indata.;

    length Score_Band $20;

    if Credit_Score<480 then
        Score_Band="01: <480";
    else if Credit_Score<=510 then
        Score_Band="02: 480-510";
    else if Credit_Score<=530 then
        Score_Band="03: 511-530";
    else if Credit_Score<=540 then
        Score_Band="04: 531-540";
    else
        Score_Band="05: 541+";
run;
%mend;

%create_score_band(
    indata=raw.scored_train,
    outdata=work.train_psi
);

%create_score_band(
    indata=raw.scored_test,
    outdata=work.test_psi
);


/* Distribution */
proc sql;
    create table work.train_dist as
    select
        Score_Band,
        count(*) as Train_Count,
        calculated Train_Count/
        (select count(*) from work.train_psi) as Train_Prop
    from work.train_psi
    group by Score_Band;

    create table work.test_dist as
    select
        Score_Band,
        count(*) as Test_Count,
        calculated Test_Count/
        (select count(*) from work.test_psi) as Test_Prop
    from work.test_psi
    group by Score_Band;
quit;


/* PSI */
proc sql;
    create table output.psi_summary as
    select
        coalesce(a.Score_Band,b.Score_Band) as Score_Band,

        coalesce(a.Train_Count,0) as Train_Count,
        coalesce(b.Test_Count,0) as Test_Count,

        coalesce(a.Train_Prop,0) as Train_Prop,
        coalesce(b.Test_Prop,0) as Test_Prop,

        (
            coalesce(a.Train_Prop,0)
            -
            coalesce(b.Test_Prop,0)
        )
        *
        log(
            max(coalesce(a.Train_Prop,0.000001),0.000001)
            /
            max(coalesce(b.Test_Prop,0.000001),0.000001)
        ) as PSI_Contribution

    from work.train_dist as a
    full join work.test_dist as b
        on a.Score_Band=b.Score_Band;
quit;

proc sql;
    create table output.psi_total as
    select
        sum(PSI_Contribution) as Total_PSI
    from output.psi_summary;
quit;


/*==============================================================================
  MODULE 19: CHARACTERISTIC ANALYSIS
==============================================================================*/

proc sql;
    create table output.characteristic_analysis_pay0 as
    select
        BIN_PAY_0,
        count(*) as Total_Accounts,
        sum(&TARGET.) as Bad_Accounts,
        sum(&TARGET.)/count(*) as Observed_Default_Rate format=percent8.2,
        mean(PD_HAT) as Average_Predicted_PD format=percent8.2,
        mean(Credit_Score) as Average_Credit_Score format=8.2,
        min(Credit_Score) as Minimum_Credit_Score,
        max(Credit_Score) as Maximum_Credit_Score
    from raw.scored_train
    group by BIN_PAY_0
    order by BIN_PAY_0;

    create table output.characteristic_analysis_age as
    select
        BIN_AGE,
        count(*) as Total_Accounts,
        sum(&TARGET.) as Bad_Accounts,
        sum(&TARGET.)/count(*) as Observed_Default_Rate format=percent8.2,
        mean(PD_HAT) as Average_Predicted_PD format=percent8.2,
        mean(Credit_Score) as Average_Credit_Score format=8.2
    from raw.scored_train
    group by BIN_AGE
    order by BIN_AGE;

    create table output.characteristic_analysis_limit as
    select
        BIN_LIMIT_BAL,
        count(*) as Total_Accounts,
        sum(&TARGET.) as Bad_Accounts,
        sum(&TARGET.)/count(*) as Observed_Default_Rate format=percent8.2,
        mean(PD_HAT) as Average_Predicted_PD format=percent8.2,
        mean(Credit_Score) as Average_Credit_Score format=8.2
    from raw.scored_train
    group by BIN_LIMIT_BAL
    order by BIN_LIMIT_BAL;
quit;


/*==============================================================================
  MODULE 20: PRODUCTION SCORING BATCH PIPELINE
==============================================================================*/

%macro production_score_batch(input_dataset=,output_dataset=);

    /* Create production bins */
    %create_bins(
        indata=&input_dataset.,
        outdata=work.prod_binned
    );

    /* Attach trained WOE */
    proc sql;
        create table work.prod_woe as
        select
            a.*,
            b.WOE as WOE_PAY_0,
            c.WOE as WOE_AGE,
            d.WOE as WOE_LIMIT_BAL
        from work.prod_binned as a
        left join work.woe_pay0 as b
            on a.BIN_PAY_0=b.Bin_Value
        left join work.woe_age as c
            on a.BIN_AGE=c.Bin_Value
        left join work.woe_limit as d
            on a.BIN_LIMIT_BAL=d.Bin_Value;
    quit;

    /* Calculate production PD and score */
    data &output_dataset.;
        set work.prod_woe;

        Logit=
            &BETA_INTERCEPT.
            + (&BETA_PAY0.*WOE_PAY_0)
            + (&BETA_AGE.*WOE_AGE)
            + (&BETA_LIMIT.*WOE_LIMIT_BAL);

        PD_Production=
            1/(1+exp(-Logit));

        Score_Production=
            round(
                &OFFSET_VAL. -
                (&FACTOR_VAL.*Logit)
            );

        if Score_Production<300 then
            Score_Production=300;

        if Score_Production>850 then
            Score_Production=850;
    run;

%mend;


/* Use TEST as a demonstration production portfolio */
data work.production_input;
    set raw.test;
run;

%production_score_batch(
    input_dataset=work.production_input,
    output_dataset=output.production_scored_portfolio
);


/*==============================================================================
  MODULE 21: FINAL EXECUTIVE REPORT
==============================================================================*/

ods _all_ close;

ods pdf file="&REPORT_PATH."
    style=Pearl
    pdftoc=1;

title1 "RETAIL BANKING PROBABILITY OF DEFAULT";
title2 "PD SCORECARD - EXECUTIVE MODEL RISK REPORT";


/* 1. Dataset and sample */
title3 "1. Dataset and Sample Summary";

proc sql;
    select count(*) as Total_Records
    from raw.credit_data;

    select count(*) as Training_Records
    from raw.train;

    select count(*) as Test_Records
    from raw.test;
quit;


/* 2. IV */
title3 "2. Information Value Summary";

proc print data=output.iv_summary noobs;
    format Total_IV 8.4;
run;


/* 3. Logistic coefficients */
title3 "3. Logistic Regression Coefficients";

proc print data=output.logistic_coefficients noobs;
    var
        Variable
        Estimate
        StdErr
        WaldChiSq
        ProbChiSq;
run;


/* 4. Performance */
title3 "4. Model Discriminatory Power";

proc print data=output.max_ks_metric noobs;
run;


/* 5. Hosmer-Lemeshow */
title3 "5. Model Goodness of Fit";

proc print data=output.hosmer_lemeshow noobs;
run;


/* 6. Scorecard */
title3 "6. Scorecard Points Allocation";

proc print data=output.scorecard_points_table noobs;
    var Variable Bin_Name WOE Points;
run;


/* 7. Decile */
title3 "7. Scorecard Decile Rank Ordering";

proc print data=output.decile_analysis noobs;
run;


/* 8. Lift / Gains */
title3 "8. Risk Ordered Cumulative Gains and Lift";

proc print data=output.risk_lift_gains noobs;
    var
        Risk_Decile
        Min_Score
        Max_Score
        Total_Accounts
        Bad_Accounts
        Cumulative_Population
        Cumulative_Gains
        Lift;
run;


/* 9. PSI */
title3 "9. Population Stability Index";

proc print data=output.psi_summary noobs;
    format
        Train_Prop
        Test_Prop
        PSI_Contribution
        percent8.2;
run;

proc print data=output.psi_total noobs;
    title4 "Total PSI";
run;


/* 10. Production scoring summary */
title3 "10. Production Scoring Summary";

proc means data=output.production_scored_portfolio
           n min mean median max;
    var
        PD_Production
        Score_Production;
run;


title;
ods pdf close;


/*==============================================================================
  FINAL VALIDATION CHECKS
==============================================================================*/

/* Record counts */
proc sql;
    create table output.final_validation as
    select "RAW" as Dataset length=20, count(*) as Records
    from raw.credit_data
    union all
    select "TRAIN", count(*) from raw.train
    union all
    select "TEST", count(*) from raw.test
    union all
    select "PRODUCTION", count(*) from output.production_scored_portfolio;
quit;

proc print data=output.final_validation noobs;
    title "Final Project Validation - Record Counts";
run;


/* Final console summary */
%put ================================================================;
%put RETAIL PD SCORECARD MASTER PROGRAM COMPLETED;
%put Report: &REPORT_PATH.;
%put Factor: &FACTOR_VAL.;
%put Offset: &OFFSET_VAL.;
%put AUC/Gini/KS table: OUTPUT.MAX_KS_METRIC;
%put IV table: OUTPUT.IV_SUMMARY;
%put Scorecard table: OUTPUT.SCORECARD_POINTS_TABLE;
%put PSI table: OUTPUT.PSI_SUMMARY;
%put Production scoring: OUTPUT.PRODUCTION_SCORED_PORTFOLIO;
%put ================================================================;
