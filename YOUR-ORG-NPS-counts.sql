--run in Snowflake Worksheets
SELECT
      t.id AS tenant_id
    , t.name AS tenant_name
    , to_char(e.nps_voted_at, 'YYYY') || ' - ' || to_char(e.nps_voted_at, 'MM') || ' - ' || to_char(e.nps_voted_at, 'MMMM')::text as
 month_year
    , sum(case when e.nps_course is not null then 1 else 0 end) as surveys_taken
    , sum(case when e.nps_course in (9,10) then 1 else 0 end) as promoter_count
    , sum(case when e.nps_course in (7,8) then 1 else 0 end) as passive_count
    , sum(case when e.nps_course in (0,1,2,3,4,5,6) then 1 else 0 end) as detractor_count
FROM enrollments e
	JOIN users u
		ON e.user_id = u.id
	JOIN content_packages cp
		ON e.content_package_id = cp.id
    JOIN tenants t
        ON cp.tenant_id = t.id
WHERE 
    --exclude internal users
    u.email not like '%@A.com%'	
    AND u.email NOT iLIKE '%@B.com%' -- CONVERSION OPS DOMAIN
    and user_id not in (select user_id from user_roles) --filter out internal custom roles (not real learners)
    --exclude older NPS
    AND e.nps_voted_at >= '2019-01-01 00:00:00.000'
--	AND e.nps_course is not null
GROUP BY 
	  tenant_name
    , t.id
	, month_year
HAVING
    month_year IS NOT NULL
ORDER BY
      month_year
    , t.id
;