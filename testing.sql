
-- `/rpc/table_create`
select table_create('{"table_name": "people", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}'::json, 'mac');
\d+ people

-- `/rpc/user_create`
select user_create('gustav');
select user_create('hannah');
select user_create('faye');
\du

-- `/rpc/group_create`
select group_create('project_members');
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
-- limit to admin_user, should fail for others
select group_add_members('{"memberships": [{"user":"gustav", "group":"project_members"}, {"user":"hannah", "group":"project_members"}]}'::json);
\du

set role gustav;
select name, age from people; -- can see hannah's data
set role authenticator;

set role hannah;
select name, age from people; -- can see gustav's data
set role authenticator;

set role faye;
select name, age from people; -- can only see own data
set role authenticator;

-- `/rpc/group_list`
set role admin_user;
select group_list();
set role authenticator;

-- `/rpc/group_list_members`
set role admin_user;
select group_list_members('project_members');
set role authenticator;

-- `/rpc/group_remove_members`
select group_remove_members('{"memberships": [{"user":"gustav", "group":"project_members"}]}'::json);

set role gustav;
select name, age from people; -- can now only see own data
set role authenticator;

set role hannah;
select name, age from people; -- can only see own data, only hannah left in group
set role authenticator;

-- `/rpc/user_delete_data`
set role gustav;
select user_delete_data(); -- TODO: create another table so can see delete from many tables
select name, age from people;
set role authenticator;
table user_data_deletion_requests;

-- `/rpc/user_delete`

-- `/rpc/group_delete`
