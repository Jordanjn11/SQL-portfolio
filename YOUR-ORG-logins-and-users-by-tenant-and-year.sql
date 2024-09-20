--run in Snowflake Worksheets
use database ft_db
;

use schema YOUR_API_SCHEMA
;

with user_logins as (
    select count(*) as total_login_events
         , count(distinct user_id) as unique_users
         , date_trunc('year', login_attempted_at) as login_year
         , lt.tenant_id
      from login_trackings lt
      join users u
        on lt.user_id = u.id
     where login_attempted_at >= '2019-01-01'
       and login_attempted_at < '2022-01-01'
    --exclude internal users  
       and u.email not like '%@A.com%' 
       and u.email NOT iLIKE '%@B.com%' -- CONVERSION OPS DOMAIN
       and user_id not in (select user_id from user_roles)
     group by date_trunc('year', login_attempted_at), lt.tenant_id
)
, new_users as (
    select count(*) as total_new_users
         , date_trunc('year', created_at) as user_added_year
         , tenant_id
      from users
     where created_at >= '2019-01-01'
       and created_at < '2022-01-01'
    --exclude internal users      
       and u.email not like '%@A.com%' 
       and u.email NOT iLIKE '%@B.com%' -- CONVERSION OPS DOMAIN
       and id not in (select user_id from user_roles)
     group by date_trunc('year', created_at), tenant_id
)
select total_login_events
     , unique_users as unique_users_with_logins
     , total_new_users
     , t.name as tenant_name
     , t.id as tenant_id
     , to_char(login_year, 'YYYY') as "year"
  from user_logins ul
  join new_users nu
    on ul.login_year = nu.user_added_year
   and ul.tenant_id = nu.tenant_id
  join tenants t
    on nu.tenant_id = t.id
  order by "year", t.name
;
