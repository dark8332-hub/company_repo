drop TEMPORARY table temp_solutions;
use maestro;
CREATE TEMPORARY TABLE temp_solutions (solution VARCHAR(255),
                                       id VaRCHAR(255)
                                      );


### 각 제품 상황에 어긋나는 데이터를 삭제한다.
#####
####
###  custom은 이쪽에서 솔루션 명만 정해서 사용하도록 한다.
####
#####

##contrabass all in one
insert into temp_solutions (solution, id)
select name, id from MSTR_SOLUTION where MSTR_SOLUTION.name in
    ('cmp',
     'contrabass');
# ##viola paas
# select name, id from MSTR_SOLUTION where MSTR_SOLUTION.name in
#     ('cmp',
#      'viola',
#      'trombone');

# ##shinhan
# select name, id from MSTR_SOLUTION where MSTR_SOLUTION.name in
#     ('cmp',
#      'viola',
#      'aws',
#      'doublebass');


select * from temp_solutions;

set foreign_key_checks = 0;

/*
   해당 솔루션 목록에 포함되지 않는 것들을 모두 지운다.
   제거 대상
   endpoint
   endpoint_in_authority
   authority_in_role
   menu_authority
   global_menu_authority
   authority
 */

delete from MSTR_ENDPOINT_IN_AUTHORITY where endpoint_id in (select id from MSTR_ENDPOINT where solution not in (select solution from temp_solutions));

delete from MSTR_ENDPOINT where solution not in (select solution from temp_solutions);

delete from MSTR_AUTHORITY_IN_ROLE where authority_id in (select id from MSTR_AUTHORITY where solution not in (select solution from temp_solutions));

delete from MSTR_MENU_AUTHORITY where authority_id in (select id from MSTR_AUTHORITY where solution not in (select solution from temp_solutions));

delete from MSTR_GLOBAL_MENU_AUTHORITY where authority_id in (select id from MSTR_AUTHORITY where solution not in (select solution from temp_solutions));

delete from MSTR_AUTHORITY where solution not in (select solution from temp_solutions);



delete from MSTR_MENU where global_menu_id in (select id from MSTR_GLOBAL_MENU where solution_id not in (select id from temp_solutions));

delete from MSTR_GLOBAL_MENU where solution_id not in (select id from temp_solutions);

delete from MSTR_SOLUTION_SERVER where solution_id not in (select id from temp_solutions);

# 솔루션, 플랫폼은 상황에 따라 사용될 수 있으므로 일단 내버려둔다.
# delete from MSTR_PLATFORM where solution_id not in (select id from temp_solutions);
# delete from MSTR_SOLUTION where name not in (select solution from temp_solutions);




