-- total records: 121856
--records with actual loans borrowed: 
WITH train_data as
(
	SELECT *
	from dbo.Train_Dataset$
	where Credit_Amount IS NOT NULL
), loan_annuity_present as 
(
	Select *
	from train_data
	where Loan_Annuity IS NOT NULL
	--records with actual loans borrowed: 
), job_info as 
(
	select *
	from loan_annuity_present
	where Client_Occupation is not null 
		AND Type_Organization is not null
), company as 
(
	select *
	from job_info
	where Social_Circle_Default is not null
), dup_indc as
(
	select *, ROW_NUMBER() over (partition by ID order by ID) dup_flag
	from company
)
select *
into loan_default_main
from dup_indc
where dup_flag = 1

-- Total Number of records in the clean dataset = 35,696

select *
from loan_default_main



-- Begin cohort analysis
-- to create a cohort analysis the following data points or labels are required:unique identifier(ID)









SELECT 
  COUNT(*) AS total_loans,
  SUM(CASE WHEN IsDefault = 1 THEN Credit_Amount ELSE 0 END) AS total_loan_amount_defaulted,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate
FROM Train_Dataset$;





SELECT 
  COUNT(*) AS total_loans,
  SUM(Credit_Amount) AS total_loan_amount,
  SUM(CASE WHEN IsDefault = 1 THEN Credit_Amount ELSE 0 END) AS total_loan_amount_defaulted,
  SUM(IsDefault) AS total_defaults,
  ROUND(
    SUM(CASE WHEN IsDefault = 1 THEN Credit_Amount ELSE 0 END) * 100.0 / SUM(Credit_Amount), 
    2
  ) AS pct_amount_defaulted
FROM Train_Dataset$;





-- Non_Perfoming Loan (NPL) gives The rate of defaulters per different  segments
-- Its Data we can then use in Risk Profiling
SELECT 
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate
FROM loan_default_main;


-- The Dafulters rate by Age Group
SELECT Cast(Age_Days/ 365 as int) as Age,
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate
FROM loan_default_main
where Age_Days is not null
group by Cast(Age_Days/ 365 as int)
order by Age Asc


-- The Dafulters rate by client income
SELECT
CASE
    WHEN Client_Income < 50000 THEN 'Under 50k'
    WHEN Client_Income < 100000 THEN '50k - 100k'
    WHEN Client_Income < 200000 THEN '100k - 200k'
    ELSE '200k+'
END AS Income_Band,
COUNT(*) AS total_loans,
SUM(IsDefault) AS total_defaults,
ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate
FROM loan_default_main
GROUP BY
CASE
    WHEN Client_Income < 50000 THEN 'Under 50k'
    WHEN Client_Income < 100000 THEN '50k - 100k'
    WHEN Client_Income < 200000 THEN '100k - 200k'
    ELSE '200k+'
END
ORDER BY MIN(Client_Income);


---- The Dafulters rate by Loan Type
SELECT 
  Loan_Contract_Type ,COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate
FROM loan_default_main
where Loan_Contract_Type is not null
group by Loan_Contract_Type
order by npl_rate desc


-- The Defaulters rate by Employment Type
SELECT
  Type_Organization,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate,
  COUNT(*) AS total
FROM loan_default_main
GROUP BY Type_Organization
ORDER BY npl_rate DESC;


-- The Defaulters rate by Marital Status
SELECT
  Client_Marital_Status,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS npl_rate,
  COUNT(*) AS total
FROM loan_default_main
where Client_Marital_Status is not null
GROUP BY Client_Marital_Status
ORDER BY npl_rate DESC;
--

--------


--Now to run a Default Anlysis to know How/when/under what conditions do defaults happen?


--Angle 1 — Single Variable Patterns


SELECT
  IsDefault,
  COUNT(*) AS total_borrowers,
  AVG(Client_Income) AS avg_income,
  AVG(Credit_Amount) AS avg_loan_amount,
  AVG(Loan_Annuity) AS avg_monthly_repayment,
  AVG(Age_Days / 365.0) AS avg_age_years,
  AVG(Employed_Days / 365.0) AS avg_years_employed,
  AVG(Child_Count) AS avg_children,
  AVG(Client_Family_Members) AS avg_family_size,
  AVG(Score_Source_1) AS avg_credit_score_1,
  AVG(Score_Source_2) AS avg_credit_score_2,
  AVG(Score_Source_3) AS avg_credit_score_3,
  AVG(Social_Circle_Default) AS avg_social_circle_defaults,
  AVG(Credit_Bureau) AS avg_credit_bureau_enquiries
FROM loan_default_main
GROUP BY IsDefault;





--Angle 2 — Combination Patterns

SELECT
  Client_Income_Type,
  Client_Education,
  Client_Marital_Status,
  Loan_Contract_Type,
  COUNT(*) AS total,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS default_rate
FROM loan_default_main
GROUP BY 
  Client_Income_Type,
  Client_Education,
  Client_Marital_Status,
  Loan_Contract_Type
ORDER BY default_rate DESC;





--Angle 3 — Frequency Patterns

-- Default rate by day of week
SELECT
  CASE Application_Process_Day
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END AS application_day,
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS default_rate
FROM loan_default_main
GROUP BY Application_Process_Day
ORDER BY Application_Process_Day;

-- Default rate by application hour
SELECT
  Application_Process_Hour,
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS default_rate
FROM loan_default_main
GROUP BY Application_Process_Hour
ORDER BY Application_Process_Hour;

-- Default rate by loan amount bracket
SELECT
  CASE
    WHEN Credit_Amount < 200000 THEN 'Small (< 200K)'
    WHEN Credit_Amount BETWEEN 200000 AND 500000 THEN 'Medium (200K - 500K)'
    WHEN Credit_Amount BETWEEN 500001 AND 1000000 THEN 'Large (500K - 1M)'
    ELSE 'Very Large (> 1M)'
  END AS loan_bracket,
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(SUM(IsDefault) * 100.0 / COUNT(*), 2) AS default_rate
FROM loan_default_main
GROUP BY
  CASE
    WHEN Credit_Amount < 200000 THEN 'Small (< 200K)'
    WHEN Credit_Amount BETWEEN 200000 AND 500000 THEN 'Medium (200K - 500K)'
    WHEN Credit_Amount BETWEEN 500001 AND 1000000 THEN 'Large (500K - 1M)'
    ELSE 'Very Large (> 1M)'
  END
ORDER BY default_rate DESC;
