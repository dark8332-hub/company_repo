drop TEMPORARY table temp_solution_servers;
use maestro;
CREATE TEMPORARY TABLE temp_solution_servers (solution VARCHAR(255),
                                       id VaRCHAR(255)
                                      );


### 각 제품 상황에 어긋나는 데이터를 삭제한다.
#####
####
###  custom은 이쪽에서 솔루션 명만 정해서 사용하도록 한다.
####
#####

##contrabass all in one
insert into temp_solution_servers (solution, id)
select name, id from MSTR_SOLUTION_SERVER where name in
    ('admin-finops');
# ##viola paas
# select name, id from MSTR_SOLUTION where MSTR_SOLUTION.name in
#     ('cmp',
#      'viola',
#      'trombone');

select * from temp_solution_servers;

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


delete from MSTR_ENDPOINT_IN_AUTHORITY where endpoint_id in (select id from MSTR_ENDPOINT where solution_server_id in (select id from temp_solution_servers));

delete from MSTR_ENDPOINT where solution_server_id in (select id from temp_solution_servers);

delete from MSTR_SOLUTION_SERVER where id in (select id from temp_solution_servers);




