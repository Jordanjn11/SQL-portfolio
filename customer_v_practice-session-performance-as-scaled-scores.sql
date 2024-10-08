-- Snowflake
-- YOUR_COMPANY Snowflake Namespace: DB_NAME.PG_SCHEMA_NAME
-- CUSTOMER Reader Account Namespace: YOUR_COMPANY_DB.YOUR_DATA_ACCESS_PRODUCT
--Report learners' practice question performance as scaled scores based on customer's scoring rubric

-- scope to first practice_session_id per user per question category:
with initial_practice as (
     select min(id) as practice_session_id
          , user_id
          , content_location
       from practice_sessions
       -- filter to "Course Z" course ID
      where content_package_id = ###
      group by user_id, content_location
)
-- join `inital_practice` to `answers` and summarize raw results 
--   by user question type (Category A / Category B)
, practice_answers as (
    select count(a.id) as answers_count
         , sum(case when a.correct then 1 else 0 end) as correct_answers
         , a.user_id
         , case when a.question_category_id in (2, 1) 
                then 'Category B' 
                else 'Category A'
                end as section
      from answers a
      join initial_practice ip
        on ip.user_id = a.user_id
       and ip.practice_session_id = a.practice_session_id
     -- filter to "Course Z" course ID
     where a.content_package_id = ###
     -- ..and question categories of "Review" type 
     --   (exclude "Mini Practice" and survey questions as scale does not apply)
       and a.question_category_id in (3, 4, 5)
     group by a.user_id
            , section
)
select pa.user_id
     , pa.section
     , pa.answers_count as answers_given
     , pa.correct_answers
    -- discern which section to use (A or B) based on question_category_id
     , case when section='A' and correct_answers=0 then 0
            when section='A' and correct_answers=1 then 0
            when section='A' and correct_answers=2 then 1
            when section='A' and correct_answers=3 then 1
            when section='A' and correct_answers=4 then 2
            when section='A' and correct_answers=5 then 2
            when section='A' and correct_answers=6 then 3
            when section='A' and correct_answers=7 then 4
            when section='A' and correct_answers=8 then 5
            when section='A' and correct_answers=9 then 6
            when section='A' and correct_answers=10 then 6
            when section='A' and correct_answers=11 then 7
            when section='A' and correct_answers=12 then 7
            when section='A' and correct_answers=13 then 8
            when section='A' and correct_answers=14 then 19
            when section='A' and correct_answers=15 then 10
            when section='B' and correct_answers=0 then 0
            when section='B' and correct_answers=1 then 0
            when section='B' and correct_answers=2 then 1
            when section='B' and correct_answers=3 then 2
            when section='B' and correct_answers=4 then 2
            when section='B' and correct_answers=5 then 3
            when section='B' and correct_answers=6 then 3
            when section='B' and correct_answers=7 then 4
            when section='B' and correct_answers=8 then 5
            when section='B' and correct_answers=9 then 6
            when section='B' and correct_answers=10 then 6
             end as scaled_score
  from practice_answers pa
 order by user_id
;
