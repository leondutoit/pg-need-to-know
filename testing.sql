
\echo
\echo 'TESTING'
\echo

-- `/rpc/table_create`
set role authenticator;
set role admin_user;
select table_create('{"table_name": "people", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}'::json, 'mac');
\d+ people
set role authenticator;

-- `/rpc/user_create`
set role admin_user;
select user_create('gustav', 'data_owner');
select user_create('hannah', 'data_owner');
select user_create('faye', 'data_owner');
select user_create('project_user', 'data_user');
\du
table user_types;
set role authenticator;

-- `/rpc/group_create`
set role admin_user;
select group_create('project_group');
\du

set role gustav;
insert into people (name, age) values ('Gustav de la Croix', 1);
-- add test to ensure that row_owner cannot be selected
select name, age from people;
set role authenticator;

set role hannah;
insert into people (name, age) values ('Hannah le Roux', 29);
-- add test to ensure that row_owner cannot be selected
select name, age from people;
set role authenticator;

set role faye;
insert into people (name, age) values ('Faye Thompson', 58);
set role authenticator;

-- `/rpc/group_add_members`
set role admin_user;
select group_add_members('{"memberships": [{"user":"gustav", "group":"project_group"}, {"user":"hannah", "group":"project_group"}, {"user":"project_user", "group":"project_group"}]}'::json);
set role authenticator;
table user_defined_groups;
table user_defined_groups_memberships;
\du

set role gustav;
select name, age from people; -- can only see own data
set role authenticator;

set role hannah;
select name, age from people; -- can only see own data
set role authenticator;

set role project_user;
select name, age from people; -- can only see gustav and hannah's data
set role authenticator;

\echo 'check table owner access rights'
set role admin_user;
select * from people;
set role authenticator;

-- `/rpc/group_list`
set role admin_user;
select group_list();
set role authenticator;

-- `/rpc/group_list_members`
set role admin_user;
select group_list_members('project_group');
set role authenticator;

-- `/rpc/group_remove_members`
set role admin_user;
select group_remove_members('{"memberships": [{"user":"gustav", "group":"project_group"}]}'::json);
set role authenticator;

set role project_user;
select name, age from people; -- can only see hannah's data
set role authenticator;

-- `/rpc/user_delete_data`
-- create another table first to check multiple table deletes
set role authenticator;
set role admin_user;
select table_create('{"table_name": "people2", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}'::json, 'mac');
set role authenticator;

-- insert some data
set role gustav;
insert into people2 (name, age) values ('Gustav de la Croix', 10);
select name, age from people2;

-- delete
select user_delete_data();
select name, age from people;
select name, age from people2;
set role authenticator;
table user_data_deletion_requests;

-- `/rpc/user_delete`
set role hannah;
select name, age from people;
set role authenticator;
set role admin_user;
\echo 'deleting hannah as admin user - should not work'
select user_delete('hannah'); -- should fail, because data still present
set role authenticator;
set role hannah;
select user_delete_data();
set role authenticator;
set role admin_user;
select user_delete('hannah');

-- `/rpc/group_delete`

-- cleanup state
set role authenticator;
set role admin_user;
select user_delete('gustav');
set role authenticator;

set role faye;
select user_delete_data();
set role authenticator;

set role admin_user;
select user_delete('faye');
select user_delete('project_user');
set role authenticator;

set role admin_user;
select group_delete('project_group');
set role authenticator;

set role admin_user;
drop table people;
drop table people2;

\echo
\echo 'DB state after cleanup'
\echo '======================'
\d
\du

