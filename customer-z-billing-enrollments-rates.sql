WITH enrollment_info AS(
SELECT DISTINCT e.id AS i_enrollment_id
, e.user_id AS e_user_id
, e.created_at AS enrollment_date
, e.content_package_id as e_cp_id
, e.auxiliary_enrollment_data  
, p.initial_duration AS plan_duration 
, p.initial_duration_unit AS plan_duration_unit
, ltil.user_id AS ltil_user_id
, ltil.content_package_id AS ltil_cp_id
, cp.title AS course_name
, li.plan_id AS li_plan_id
, li.institution_contract_id AS li_inst_contr_id
, p_inv.audience AS plan_aud_type
, p_inv.title as plan_name
, p_inv.bench_prep_plan_url AS plan_url
FROM enrollments e
JOIN content_packages cp
  ON e.content_package_id = cp.id
JOIN users u
  ON e.user_id = u.id
FULL OUTER JOIN licenses li
  ON e.license_id = li.id
FULL OUTER JOIN plans p
ON li.plan_id = p.id
FULL OUTER JOIN "DATABASE"."SCHEMA"."REF_TABLE" AS p_inv
  ON p.id = TRY_TO_NUMBER(p_inv.plan_id, '99999', 38, 0)
FULL OUTER JOIN lti_launches ltil
  ON e.user_id = ltil.user_id
--CUSTOMER Z ID
  WHERE cp.tenant_id = 9709
  --non-internal users
     AND u.email NOT LIKE '%A%'
	   AND u.email NOT LIKE '%B%'
	   AND u.email NOT LIKE '%C%'
	   AND u.email NOT LIKE '%D%'
     AND u.email NOT LIKE '%E%'
  --exclude enrollments associated to an internal plan ID
     AND  li_plan_id != 6593
)
,

--classify trial enrollments
trial_enrollments AS(
SELECT 
i_enrollment_id AS t_enrollment_id
--identify short trial enrollments
, CASE WHEN (plan_duration <= 1 AND plan_duration_unit = 'month') 
    OR (plan_duration <= 31 AND plan_duration_unit = 'day') 
    OR (plan_duration <= 4 AND plan_duration_unit = 'week') THEN 'short_trial'
--identify long trial enrollments
    WHEN (plan_duration > 1 AND plan_duration_unit = 'month') 
    OR (plan_duration > 31 AND plan_duration_unit = 'day') 
    OR (plan_duration > 4 AND plan_duration_unit = 'week') 
    OR (plan_duration_unit = 'year') THEN 'long_trial'
    ELSE 'non_trial' END AS is_trial
FROM enrollment_info
ORDER BY is_trial DESC
)
,

--classify non-short-trial enrollments
enrollments_classified AS(
SELECT
i_enrollment_id AS ec_enrollment_id
, e_user_id AS user_id
--pull in short trial enrollments
, CASE WHEN is_trial = 'short_trial' THEN 'short_trial'
  
--identify CE (course name or plan name)
WHEN is_trial != 'short_trial' 
  AND (course_name LIKE '%CE%' OR plan_name LIKE '%CE%') 
  THEN 'CE'

--identify ebook (course name)                              
 WHEN is_trial != 'short_trial' AND (course_name LIKE '%Instructor Guide%' OR course_name LIKE '%Student Guide%') THEN 'ebook'

--extract plan ID from bench_prep_plan_url in COURSE INVENTORY (reference Gsheet), match to plan ID from LICENSES, and use COURSE_INVENTORY.audience --> enrollment_type
WHEN is_trial != 'short_trial' AND SUBSTR(plan_url,35,10) = li_plan_id THEN plan_aud_type

--LTI launches Plan A --> B2B enrollment type  
WHEN is_trial != 'short_trial' 
  AND (e_user_id = ltil_user_id
  AND e_cp_id = ltil_cp_id) THEN 'B2B'

--LTI launches Plan B --> B2B enrollment type  
WHEN is_trial != 'short_trial'
  AND is_null_value(AUXILIARY_ENROLLMENT_DATA:audience) 
  AND (li_plan_id IS NULL AND li_inst_contr_id IS NULL) THEN 'B2B'
  
--if enrollment tied to a contract --> B2B
WHEN is_trial != 'short_trial' 
  AND li_inst_contr_id IS NOT NULL THEN 'B2B'                     
                          
--if enrollment tied to a plan + plan B2B --> B2B (from plan_inventory Gsheet)
WHEN is_trial != 'short_trial' 
  AND plan_aud_type iLIKE 'B2B' THEN 'B2B'                        
                          
--if enrollment tied to a plan + plan B2C --> B2C (from plan_inventory Gsheet)
WHEN is_trial != 'short_trial' 
  AND plan_aud_type iLIKE 'B2C' THEN 'B2C'          

--identify enrollments where auxiliary_enrollment_data column has any value --> B2C
WHEN is_trial != 'short_trial'
  AND NOT is_null_value(AUXILIARY_ENROLLMENT_DATA:audience) THEN 'B2C' --per CSM, we're classifying ANY aux_enroll_data value as B2C
-- query QC: check for unclassified enrollment types (those w/ this billing rate)
ELSE 'Needs Review' END AS enrollment_type
FROM enrollment_info
JOIN trial_enrollments
    ON enrollment_info.i_enrollment_id = trial_enrollments.t_enrollment_id
)

--select final columns and perform final calculations (including billing rate for each enrollment)
SELECT 
DISTINCT ec_enrollment_id AS enrollment_id
, enrollment_date
, e_user_id AS user_id
, enrollment_type
, CASE WHEN enrollment_type = 'CE' THEN 1000
    WHEN enrollment_type = 'ebook' THEN 5000
    WHEN enrollment_type = 'B2B' THEN 7000
    WHEN enrollment_type = 'B2C' THEN 38000
    WHEN enrollment_type = 'short_trial' THEN 0
    ELSE 666 END AS billing_rate -- query QC: check for unclassified enrollment types (those w/ this billign rate)
FROM enrollments_classified
JOIN enrollment_info
    ON enrollments_classified.ec_enrollment_id = enrollment_info.i_enrollment_id
--WHERE enrollment_type = 'Needs Review' --QC
--WHERE billing_rate = 666 --QC
ORDER BY enrollment_id;
