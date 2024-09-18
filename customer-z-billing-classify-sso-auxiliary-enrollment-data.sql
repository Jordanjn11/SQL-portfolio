--Customer Z Billing Data Update to classify SSO users as B2B or B2C
-- Based on Revenue not user count | unique enrollments
SELECT cast(e.user_id as varchar(11)) as user_id
	,u.name as user_name
	,u.email as user_email
	,at.token
    ,case when at.token ilike '%ILT' then 'B2B' 
              WHEN (at.token IS NULL AND cast(e.auxiliary_enrollment_data as text) iLIKE '%{"audience":"B2C"%') THEN 'B2C'
               WHEN (at.token IS NULL AND cast(e.auxiliary_enrollment_data as text) iLIKE '%{"audience":"B2B"%') THEN 'B2B'
               WHEN (at.token IS NULL AND cast(e.auxiliary_enrollment_data as text) iLIKE '%{"audience": ""%') THEN 'B2C'
		else 'B2C'  
		end as token_category
	,cast(p.id as varchar(6)) as plan_id
	,p.name as plan_name
	,CONCAT(initial_duration,
	  case when p.initial_duration is null then '' else ' ' end, 
	  initial_duration_unit, 
	  case when p.initial_duration = 1 or p.initial_duration is null then '' else 's' end)
	  as plan_duration
	,e.content_package_id as course_id
	,cp.title as course_title
	,l.activated_at::date as license_date
	,l.state as license_state
FROM enrollments e
	LEFT JOIN licenses l
		ON e.license_id = l.id
	LEFT JOIN plans p
		ON l.plan_id = p.id
	LEFT JOIN subscriptions s
		ON l.id = s.license_id
	LEFT JOIN access_tokens at
		ON s.access_token_id = at.id
	LEFT JOIN users u
		ON e.user_id = u.id
	LEFT JOIN content_packages cp
		ON e.content_package_id = cp.id
WHERE cp.tenant_id = 9709
  --non-internal users
     AND u.email NOT LIKE '%A%'
	   AND u.email NOT LIKE '%B%'
	   AND u.email NOT LIKE '%C%'
	   AND u.email NOT LIKE '%D%'
     AND u.email NOT LIKE '%E%'
;