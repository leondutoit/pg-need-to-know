
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
-- limit to admin_user
select group_add_members('{"memberships": [{"user":"gustav", "group":"project_members"}, {"user":"hannah", "group":"project_members"}, {"user":"faye", "group":"project_members"}]}'::json);
\du

set role gustav;
select name, age from people;
set role authenticator;

set role hannah;
select name, age from people;
set role authenticator;

-- `/rpc/group_list_members`


-- `/rpc/group_remove_members`
select group_remove_members('{"memberships": [{"user":"gustav", "group":"project_members"}]}'::json);

set role gustav;
select name, age from people;
set role authenticator;

set role hannah;
select name, age from people;
set role authenticator;


-- `/rpc/user_delete_data`

-- `/rpc/user_delete`

-- `/rpc/group_delete`
