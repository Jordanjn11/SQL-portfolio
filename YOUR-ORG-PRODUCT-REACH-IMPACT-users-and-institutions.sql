use schema schema_name;

----------------------------------------------------
-- calculate students and educators served to date
-- note: i used case statements so the conditions are readable
--Used for grant certification purposes/funding applications/credential issuance tied to total/avg time and activities users spend on a platform in a given year, week, and day
----------------------------------------------------
-- KPIs:
--        total students served
--        total educators served
----------------------------------------------------

with user_counts as (
select
    count(distinct (case 
    when ug.member_type is null then u.id 
    when ug.member_type not like 'instructor' then u.id 
    else null
    end)) as students_served
    , count(distinct (case 
    when ug.member_type like 'instructor' then u.id 
    else null 
    end)) as educators_served
     from users u
left join user_groups ug
       on u.id = ug.user_id
    where u.email not ilike '%A%'
      and u.email not ilike '%B%'
      and u.email not ilike '%C%'
)
,

----------------------------------------------------
-- calculate schools served, higher ed institutions, & employers served to date

--KPIs:
--        total schools served
---       total higher ed inst. served
--        total employers served
----------------------------------------------------

institution_counts as (
    select
    count(distinct (case
    when i.name ilike '%school%' then i.id
    when i.name ilike '%academy%' then i.id
    when i.name ilike '%college prep%' then i.id
    when i.institution_type in('SC-HS', 'SC-MS', 'HS', 'Secondary') then i.id
    else null
    end)) as schools_served
    , count(distinct (case
    when i.name ilike '%university%' then i.id
    when (i.name ilike '%college%' and i.name not ilike '%college prep%') then i.id
    when i.institution_type in('Post Secondary', 'SC-TC', 'SC-CTE') then i.id
    else null
    end)) as higher_eds_served
    , count(distinct (case
    when (i.name not ilike '%university%'
    and i.name not ilike '%college%'
    and i.name not ilike '%school%'
    and i.name not ilike '%academy%'
    and i.name not ilike '%education%'
    and (i.institution_type is null or i.institution_type = '')
    ) then i.id
    else null
    end)) as employers_served
    from institutions i

)

select * from institution_counts
, lateral (select * from user_counts uc)
