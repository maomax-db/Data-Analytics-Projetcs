--THE Objective To be Achieved is Identifying the Most Strategically Valuable AI Talent Markets for Global Hiring

---- First Objective: Where to hire — Which countries offer strong AI talent (high skill demand, high AI maturity) 
--at a salary that doesn't break the budget when adjusted for cost of living


--First Lets Get to know the Exact Number of Each of the Country Talent
SELECT country, Count(country) as Frequency
FROM global_ai_jobs
Group By country

-- to begin with we need to know the best countries to hire from overall, based na lot of metrics that we be evalating and comparing oe after the other
-- So first were goin to see the countries with the highest Average Skill Demnand Score
SELECt country, AVG(CAST (skill_demand_score AS float) ) as skillDemandScore
From global_ai_jobs
group by country




-- KR1: Identify countries where salary_usd is in the *bottom 40th percentile* globally, while skill_demand_score is *above 60/100*
----
  ----
    ----

GO


WITH Percentile_Line AS(
SELECT DISTINCT PERCENTILE_CONT(0.40) WITHIN GROUP(ORDER BY salary_usd) OVER () as p_40_Salary
FROM global_ai_jobs
)

SELECT g.country, g.job_role, AVG(g.skill_demand_score) AS avg_skill_demand, AVG(g.salary_usd) AS avg_salary_usd, p.p_40_Salary AS globl40thPercentile
FROM global_ai_jobs g
CROSS JOIN Percentile_Line p
WHERE g.skill_demand_score >= 60
GROUP BY g.country, g.job_role, p.p_40_Salary
HAVING AVG(g.salary_usd) <= p.p_40_Salary
ORDER BY g.job_role, avg_salary_usd




    ----
  ----
----











--KR1 second prt: To know Countries with cost_of_living_index adjusted salary stil leaves a >=20% budget advantage vs the USA baseline
--First lets get the adjusted salary 
--cost of living adjusted salary means: Scaling the salary by how far it actually goes in that country. The formula is essentially

----
  ----
    ----

GO

WITH Percentile_Line AS (
    SELECT DISTINCT PERCENTILE_CONT(0.40) WITHIN GROUP(ORDER BY salary_usd) OVER () AS p_40_Salary
    FROM global_ai_jobs
),
Part1_Countries AS (
    -- Recreate Part 1 output as a CTE to filter from
    SELECT g.country, g.job_role, AVG(g.skill_demand_score) AS avg_skill_demand, AVG(g.salary_usd) AS avg_salary_usd, p.p_40_Salary AS global40thPercentile
    FROM global_ai_jobs g
    CROSS JOIN Percentile_Line p
    WHERE g.skill_demand_score >= 60
    GROUP BY g.country, g.job_role, p.p_40_Salary
    HAVING AVG(g.salary_usd) <= p.p_40_Salary
),
USA_Baseline AS (
    -- Calculate USA average cost_of_living_adjusted salary per job role
    SELECT
        job_role,
        AVG(CAST(salary_usd AS FLOAT) / NULLIF(cost_of_living_index, 0)) AS usa_cola_salary
    FROM global_ai_jobs
    WHERE country = 'USA'
    GROUP BY job_role
)

SELECT
    p.country,
    p.job_role,
    p.avg_salary_usd,
    ROUND(AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)), 2) AS avg_cola_salary,
    ROUND(u.usa_cola_salary, 2) AS usa_cola_baseline,
    ROUND((1 - AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)) / u.usa_cola_salary) * 100, 2) AS budget_advantage_pct
FROM Part1_Countries p
JOIN global_ai_jobs g ON p.country = g.country AND p.job_role = g.job_role
JOIN USA_Baseline u ON p.job_role = u.job_role
GROUP BY p.country, p.job_role, p.avg_salary_usd, u.usa_cola_salary
HAVING (1 - AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)) / u.usa_cola_salary) * 100 >= 20
ORDER BY budget_advantage_pct DESC, p.job_role;

--**The 3 CTEs explained:**
--- **`Percentile_Line`** — same as Part 1, calculates the global 40th percentile salary
--- **`Part1_Countries`** — exact same logic as Part 1, acting as the **starting pool** for Part 2
--- **`USA_Baseline`** — calculates the average cost-of-living adjusted salary per job role for USA only

--**The budget advantage calculation:**
--```
--(1 - country_cola_salary / usa_cola_salary) * 100




    ----
  ----
----










--K2:Pinpoint roles with the strongest longevity
--Part 1: Flag roles where automation_risk is below 40 AND ai_adoption_score is above 70


----
  ----
    ----

SELECT 
    g.country,
    g.job_role,
    AVG(g.automation_risk) AS avg_automation_risk,
    AVG(g.ai_adoption_score) AS avg_ai_adoption_score,
    COUNT(*) AS qualifying_records
FROM global_ai_jobs g
WHERE g.ai_adoption_score > 70
  AND g.automation_risk <= 40
GROUP BY g.country, g.job_role
ORDER BY g.job_role, avg_automation_risk ASC;


    ----
  ----
----




--Identify the top 5 ai_specialization categories that meet both thresholds across at least *3 different countries*




----
  ----
    ----

GO

WITH filtered AS (
    SELECT *
    FROM global_ai_jobs
    WHERE ai_adoption_score > 70
      AND automation_risk <= 40
),
normalized AS (
    SELECT
        country,
        ai_specialization,
        (CAST(ai_adoption_score AS FLOAT) - MIN(ai_adoption_score) OVER()) / 
            NULLIF(MAX(ai_adoption_score) OVER() - MIN(ai_adoption_score) OVER(), 0) AS norm_ai_adoption,

        (MAX(automation_risk) OVER() - CAST(automation_risk AS FLOAT)) / 
            NULLIF(MAX(automation_risk) OVER() - MIN(automation_risk) OVER(), 0) AS norm_automation_risk_inv,

        (CAST(job_openings AS FLOAT) - MIN(job_openings) OVER()) / 
            NULLIF(MAX(job_openings) OVER() - MIN(job_openings) OVER(), 0) AS norm_job_openings,

        (CAST(skill_demand_score AS FLOAT) - MIN(skill_demand_score) OVER()) / 
            NULLIF(MAX(skill_demand_score) OVER() - MIN(skill_demand_score) OVER(), 0) AS norm_skill_demand,

        (MAX(salary_usd / NULLIF(cost_of_living_index, 0)) OVER() - 
            CAST(salary_usd AS FLOAT) / NULLIF(cost_of_living_index, 0)) /
            NULLIF(MAX(salary_usd / NULLIF(cost_of_living_index, 0)) OVER() - 
            MIN(salary_usd / NULLIF(cost_of_living_index, 0)) OVER(), 0) AS norm_affordability
    FROM filtered
),
scored AS (
    SELECT
        country,
        ai_specialization,
        ROUND((
            (norm_ai_adoption + norm_automation_risk_inv) / 2.0 +
            (norm_job_openings + norm_skill_demand) / 2.0 +
            norm_affordability
        ) / 3.0, 4) AS composite_score
    FROM normalized
),
avg_by_country AS (
    -- Average composite score per country per specialization
    SELECT
        country,
        ai_specialization,
        AVG(composite_score) AS avg_composite_score
    FROM scored
    GROUP BY country, ai_specialization
),
ranked_by_country AS (
    -- Rank specializations within each country
    SELECT
        country,
        ai_specialization,
        avg_composite_score,
        DENSE_RANK() OVER (PARTITION BY country ORDER BY avg_composite_score DESC) AS country_rank
    FROM avg_by_country
),
country_qualified AS (
    -- Only keep specializations that ranked top 5 in at least 3 countries
    SELECT
        ai_specialization,
        COUNT(DISTINCT country) AS countries_in_top5
    FROM ranked_by_country
    WHERE country_rank <= 5
    GROUP BY ai_specialization
    HAVING COUNT(DISTINCT country) >= 3
),
global_scored AS (
    -- Global average composite score per specialization
    SELECT
        ai_specialization,
        AVG(composite_score) AS avg_composite_score
    FROM scored
    GROUP BY ai_specialization
)

SELECT TOP 5
    g.ai_specialization,
    ROUND(g.avg_composite_score, 4) AS avg_composite_score,
    c.countries_in_top5
FROM global_scored g
JOIN country_qualified c ON g.ai_specialization = c.ai_specialization
ORDER BY g.avg_composite_score DESC;
    ----
  ----
----


--KR3: Define a competitive compensation benchmark per market*
--For each shortlisted country, produce a salary_usd + bonus_usd range broken down by experience_level (Entry / Mid / Senior)
--Benchmark must sit between the *40th–70th percentile* to stay competitive without overpaying





----
  ----
    ----

GO

WITH Percentile_Line AS (
    SELECT DISTINCT PERCENTILE_CONT(0.40) WITHIN GROUP(ORDER BY salary_usd) OVER () AS p_40_Salary
    FROM global_ai_jobs
),
Part1_Countries AS (
    SELECT g.country, g.job_role, AVG(g.skill_demand_score) AS avg_skill_demand, AVG(g.salary_usd) AS avg_salary_usd, p.p_40_Salary AS global40thPercentile
    FROM global_ai_jobs g
    CROSS JOIN Percentile_Line p
    WHERE g.skill_demand_score >= 60
    GROUP BY g.country, g.job_role, p.p_40_Salary
    HAVING AVG(g.salary_usd) <= p.p_40_Salary
),
USA_Baseline AS (
    SELECT
        job_role,
        AVG(CAST(salary_usd AS FLOAT) / NULLIF(cost_of_living_index, 0)) AS usa_cola_salary
    FROM global_ai_jobs
    WHERE country = 'USA'
    GROUP BY job_role
),
Part2_Countries AS (
    SELECT
        p.country,
        p.job_role
    FROM Part1_Countries p
    JOIN global_ai_jobs g ON p.country = g.country AND p.job_role = g.job_role
    JOIN USA_Baseline u ON p.job_role = u.job_role
    GROUP BY p.country, p.job_role, u.usa_cola_salary
    HAVING (1 - AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)) / u.usa_cola_salary) * 100 >= 20
),
Compensation_Percentiles AS (
    -- Calculate 40th and 70th percentile of total compensation
    -- within each country/experience_level group
    SELECT DISTINCT
        g.country,
        g.experience_level,
        PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY g.salary_usd + g.bonus_usd)
            OVER (PARTITION BY g.country, g.experience_level) AS p40_compensation,
        PERCENTILE_CONT(0.70) WITHIN GROUP (ORDER BY g.salary_usd + g.bonus_usd)
            OVER (PARTITION BY g.country, g.experience_level) AS p70_compensation
    FROM global_ai_jobs g
    WHERE EXISTS (
        SELECT 1 FROM Part2_Countries p2
        WHERE p2.country = g.country
    )
)

SELECT
    c.country,
    c.experience_level,
    ROUND(c.p40_compensation, 2) AS p40_total_compensation,
    ROUND(c.p70_compensation, 2) AS p70_total_compensation
FROM Compensation_Percentiles c
ORDER BY c.country, 
         CASE c.experience_level 
            WHEN 'Entry' THEN 1 
            WHEN 'Mid' THEN 2 
            WHEN 'Senior' THEN 3 
         END;




    ----
  ----
----













--*KR4: Rank markets by retention strength*
-- Score each country using a composite of employee_satisfaction, job_security_score, work_life_balance_score, and inverse of layoff_risk
-- Retain only markets that score *above 65/100* on this composite


----
  ----
    ----


GO

WITH Percentile_Line AS (
    SELECT DISTINCT PERCENTILE_CONT(0.40) WITHIN GROUP(ORDER BY salary_usd) OVER () AS p_40_Salary
    FROM global_ai_jobs
),
Part1_Countries AS (
    SELECT g.country, g.job_role, AVG(g.skill_demand_score) AS avg_skill_demand, AVG(g.salary_usd) AS avg_salary_usd, p.p_40_Salary AS global40thPercentile
    FROM global_ai_jobs g
    CROSS JOIN Percentile_Line p
    WHERE g.skill_demand_score >= 60
    GROUP BY g.country, g.job_role, p.p_40_Salary
    HAVING AVG(g.salary_usd) <= p.p_40_Salary
),
USA_Baseline AS (
    SELECT
        job_role,
        AVG(CAST(salary_usd AS FLOAT) / NULLIF(cost_of_living_index, 0)) AS usa_cola_salary
    FROM global_ai_jobs
    WHERE country = 'USA'
    GROUP BY job_role
),
Part2_Countries AS (
    SELECT DISTINCT p.country
    FROM Part1_Countries p
    JOIN global_ai_jobs g ON p.country = g.country AND p.job_role = g.job_role
    JOIN USA_Baseline u ON p.job_role = u.job_role
    GROUP BY p.country, p.job_role, u.usa_cola_salary
    HAVING (1 - AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)) / u.usa_cola_salary) * 100 >= 20
),
Country_Avgs AS (
    -- Average all 4 retention metrics per country, only for Part2 shortlisted countries
    SELECT
        g.country,
        AVG(CAST(g.employee_satisfaction AS FLOAT))   AS avg_satisfaction,
        AVG(CAST(g.job_security_score AS FLOAT))       AS avg_job_security,
        AVG(CAST(g.work_life_balance_score AS FLOAT))  AS avg_work_life_balance,
        AVG(CAST(g.layoff_risk AS FLOAT))              AS avg_layoff_risk
    FROM global_ai_jobs g
    WHERE EXISTS (
        SELECT 1 FROM Part2_Countries p2
        WHERE p2.country = g.country
    )
    GROUP BY g.country
),
Normalized AS (
    -- Normalize each metric to 0-1, invert layoff_risk
    SELECT
        country,
        (avg_satisfaction - MIN(avg_satisfaction) OVER()) /
            NULLIF(MAX(avg_satisfaction) OVER() - MIN(avg_satisfaction) OVER(), 0) AS norm_satisfaction,

        (avg_job_security - MIN(avg_job_security) OVER()) /
            NULLIF(MAX(avg_job_security) OVER() - MIN(avg_job_security) OVER(), 0) AS norm_job_security,

        (avg_work_life_balance - MIN(avg_work_life_balance) OVER()) /
            NULLIF(MAX(avg_work_life_balance) OVER() - MIN(avg_work_life_balance) OVER(), 0) AS norm_work_life_balance,

        (MAX(avg_layoff_risk) OVER() - avg_layoff_risk) /
            NULLIF(MAX(avg_layoff_risk) OVER() - MIN(avg_layoff_risk) OVER(), 0) AS norm_layoff_risk_inv
    FROM Country_Avgs
),
Composite AS (
    -- Combine into 0-100 composite score, equal weights
    SELECT
        country,
        ROUND((
            norm_satisfaction +
            norm_job_security +
            norm_work_life_balance +
            norm_layoff_risk_inv
        ) / 4.0 * 100, 2) AS retention_score
    FROM Normalized
)

SELECT
    country,
    retention_score,
    DENSE_RANK() OVER (ORDER BY retention_score DESC) AS market_rank
FROM Composite
WHERE retention_score > 65
ORDER BY retention_score DESC;

    ----
  ----
----




----KR5

GO
WITH Percentile_Line AS (
    SELECT DISTINCT PERCENTILE_CONT(0.40) WITHIN GROUP(ORDER BY salary_usd) OVER () AS p_40_Salary
    FROM global_ai_jobs
),
Part1_Countries AS (
    SELECT g.country, g.job_role, AVG(g.skill_demand_score) AS avg_skill_demand, AVG(g.salary_usd) AS avg_salary_usd, p.p_40_Salary AS global40thPercentile
    FROM global_ai_jobs g
    CROSS JOIN Percentile_Line p
    WHERE g.skill_demand_score >= 60
    GROUP BY g.country, g.job_role, p.p_40_Salary
    HAVING AVG(g.salary_usd) <= p.p_40_Salary
),
USA_Baseline AS (
    SELECT
        job_role,
        AVG(CAST(salary_usd AS FLOAT) / NULLIF(cost_of_living_index, 0)) AS usa_cola_salary
    FROM global_ai_jobs
    WHERE country = 'USA'
    GROUP BY job_role
),
Part2_Countries AS (
    SELECT DISTINCT p.country
    FROM Part1_Countries p
    JOIN global_ai_jobs g ON p.country = g.country AND p.job_role = g.job_role
    JOIN USA_Baseline u ON p.job_role = u.job_role
    GROUP BY p.country, p.job_role, u.usa_cola_salary
    HAVING (1 - AVG(CAST(g.salary_usd AS FLOAT) / NULLIF(g.cost_of_living_index, 0)) / u.usa_cola_salary) * 100 >= 20
),
Country_Avgs AS (
    SELECT
        g.country,
        AVG(CAST(g.employee_satisfaction AS FLOAT))   AS avg_satisfaction,
        AVG(CAST(g.job_security_score AS FLOAT))       AS avg_job_security,
        AVG(CAST(g.work_life_balance_score AS FLOAT))  AS avg_work_life_balance,
        AVG(CAST(g.layoff_risk AS FLOAT))              AS avg_layoff_risk
    FROM global_ai_jobs g
    WHERE EXISTS (SELECT 1 FROM Part2_Countries p2 WHERE p2.country = g.country)
    GROUP BY g.country
),
Normalized AS (
    SELECT
        country,
        (avg_satisfaction - MIN(avg_satisfaction) OVER()) /
            NULLIF(MAX(avg_satisfaction) OVER() - MIN(avg_satisfaction) OVER(), 0) AS norm_satisfaction,
        (avg_job_security - MIN(avg_job_security) OVER()) /
            NULLIF(MAX(avg_job_security) OVER() - MIN(avg_job_security) OVER(), 0) AS norm_job_security,
        (avg_work_life_balance - MIN(avg_work_life_balance) OVER()) /
            NULLIF(MAX(avg_work_life_balance) OVER() - MIN(avg_work_life_balance) OVER(), 0) AS norm_work_life_balance,
        (MAX(avg_layoff_risk) OVER() - avg_layoff_risk) /
            NULLIF(MAX(avg_layoff_risk) OVER() - MIN(avg_layoff_risk) OVER(), 0) AS norm_layoff_risk_inv
    FROM Country_Avgs
),
KR4_Countries AS (
    -- Final 3 countries that passed KR4
    SELECT
        country,
        ROUND((
            norm_satisfaction +
            norm_job_security +
            norm_work_life_balance +
            norm_layoff_risk_inv
        ) / 4.0 * 100, 2) AS retention_score
    FROM Normalized
    WHERE ROUND((
            norm_satisfaction +
            norm_job_security +
            norm_work_life_balance +
            norm_layoff_risk_inv
        ) / 4.0 * 100, 2) > 65
),
KR5_Metrics AS (
    -- Aggregate hiring metrics per country per job_role for KR4 countries
    SELECT
        g.country,
        g.job_role,
        AVG(CAST(g.offer_acceptance_rate AS FLOAT))    AS avg_offer_acceptance_rate,
        AVG(CAST(g.hiring_difficulty_score AS FLOAT))  AS avg_hiring_difficulty,
        AVG(CAST(g.job_openings AS FLOAT))             AS avg_job_openings
    FROM global_ai_jobs g
    WHERE EXISTS (SELECT 1 FROM KR4_Countries k WHERE k.country = g.country)
    GROUP BY g.country, g.job_role
    HAVING AVG(CAST(g.offer_acceptance_rate AS FLOAT)) > 55
       AND AVG(CAST(g.hiring_difficulty_score AS FLOAT)) < 60
       AND AVG(CAST(g.job_openings AS FLOAT)) >= 15
),
Country_Hiring_Score AS (
    -- Aggregate to country level and build a hiring ease composite
    SELECT
        k.country,
        k.retention_score,
        ROUND(AVG(m.avg_offer_acceptance_rate), 2)   AS avg_acceptance_rate,
        ROUND(AVG(m.avg_hiring_difficulty), 2)        AS avg_hiring_difficulty,
        ROUND(AVG(m.avg_job_openings), 2)             AS avg_job_openings,
        -- Hiring ease score: high acceptance + low difficulty + high openings
        ROUND((
            AVG(m.avg_offer_acceptance_rate) / 100.0 +
            (100 - AVG(m.avg_hiring_difficulty)) / 100.0 +
            AVG(m.avg_job_openings) / NULLIF(MAX(AVG(m.avg_job_openings)) OVER(), 0)
        ) / 3.0 * 100, 2) AS hiring_ease_score
    FROM KR4_Countries k
    JOIN KR5_Metrics m ON k.country = m.country
    GROUP BY k.country, k.retention_score
)

SELECT
    country,
    retention_score,
    avg_acceptance_rate,
    avg_hiring_difficulty,
    avg_job_openings,
    hiring_ease_score,
    DENSE_RANK() OVER (ORDER BY hiring_ease_score DESC) AS hiring_ease_rank
FROM Country_Hiring_Score
ORDER BY hiring_ease_rank;




