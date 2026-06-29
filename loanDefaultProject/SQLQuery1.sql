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

SELECT
    IsDefault,
    AVG(Age_Days / 365.25) AS avg_age,
    AVG(Credit_Amount) AS avg_loan_amount,
    AVG(Credit_Amount / Loan_Annuity) AS avg_tenure,
	AVG(CAST(Client_Income as int)) as AvgIncome,
    COUNT(*) AS total
FROM loan_default_main
GROUP BY IsDefault;







