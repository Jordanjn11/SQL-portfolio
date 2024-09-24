----------------------------------------------------
-- This file contains multiple queries for multiple platform usage KPIs: run each one separately - see comments
--Used for grant certification purposes/funding applications/credential issuance tied to total/avg time and activities users spend on a platform in a given year, week, and day
----------------------------------------------------

use schema schema_name;

----------------------------------------------------
--Query 1
-- calculate millions of hours of user platform activity in 2021
--using THREE application data tables: A, B, C 
----------------------------------------------------

-- get applicable usage unit time per year using table_a
with a_calc as (
  select 
         sum(timediff(seconds, a.start_time, a.end_time))/3600.0 as a_value -- convert seconds to hours
       , sum(computed_duration)/3600.0 as a_duration_value -- convert seconds to hours
       , to_char(date_trunc('year', a.start_time), 'yyyy') as applicable_year
    from table_a a
group by applicable_year
)
,

-- get applicable usage unit time per year using table_b
b_calc as (
  select 
         sum(b.duration)/3600000.0 as b_value -- convert miliseconds to hours
       , to_char(date_trunc('year', b.created_at), 'yyyy') as applicable_year
    from table_b b
   where b.eligible = 'true'
     and b.name not like 'idle_time'
group by applicable_year
)
,

-- get applicable usage unit time per year using TABLE_C
c_calc as (
  select sum(c.usage_unit_duration)/60.0 as c_value
       , to_char(date_trunc('year', c.usage_units_timestamp), 'yyyy') as applicable_year
    from table_c c
group by applicable_year
)

-- get millions of hours per year for each calculation method
  select 
         c.applicable_year
       , round(a.a_value/1000000.0, 3) as a_mhours -- convert hours to millions of hours
       , round(b.b_value/1000000.0, 3) as b_mhours -- convert hours to millions of hours
       , round(c.c_value/1000000.0, 3) as c_mhours -- convert hours to millions of hours
    from c_calc c
    join b_calc b 
      on c.applicable_year=b.applicable_year
    join a_calc a 
      on c.applicable_year=a.applicable_year
order by c.applicable_year;



----------------------------------------------------
--Query 2
-- calculate minutes/day among active users in 2021
-- note: this is calculated based only on the days that the user was active, not skipped days.
-- after feedback from CSM stakeholders on the total platform usage time KPIs (see 1st query), i only used the `a` table this time.
----------------------------------------------------

-- using a_table
with a_calc as (
select 
      timediff(seconds, a.start_time, a.end_time)/60.0 as a_minutes -- convert seconds to minutes
    , date_trunc('day', a.start_time) as applicable_day
    , a.user_id as user_id
 from a_table a
where to_char(date_trunc('year', a.start_time), 'yyyy')=2021

)
,

a_user_days as (
  select avg(a.usage_units_minutes) as avg_minutes
    from a_calc a
group by a.user_id, a.applicable_day
)

select round(avg(aud.avg_minutes)) as avg_active_minutes_per_day
from a_user_days aud;



----------------------------------------------------
--Query 3
-- calculate activities/week among active users in 2021
-- note: this is calculated based only on the weeks that the user was active at least once, not skipped weeks.
-- after feedback from CSM stakeholders on the total platform usage time KPIs (see 1st query), i only used the `a` table this time.
----------------------------------------------------

use schema SCHEMA_NAME;

with user_weekly_activities as (
select
         count(distinct a.id) as activities_count
       , a.user_id as user_id
       , date_trunc('week', a.created_at) as active_week
    from activities a
   where to_char(date_trunc('year', a.created_at), 'yyyy')=2021
group by active_week, a.user_id
)

select round(avg(activities_count)) as avg_weekly_activities
  from user_weekly_activities;


----------------------------------------------------
--Query 4
-- calculate total number of user activities 2021
----------------------------------------------------

select round(count(distinct a.id)/1000000.0,1) as million_activities
  from activities a
 where to_char(date_trunc('year', a.created_at), 'yyyy')=2021
