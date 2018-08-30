
\echo
\echo 'TESTING'
\echo

\echo 'testing: table_create'

create or replace function test_table_create()
    returns boolean as $$
    declare _ans text;
    begin
        set role authenticator;
        set role admin_user;
        select table_create('{"table_name": "people", "columns": [ {"name": "name", "type": "text"}, {"name": "age", "type": "int"} ]}'::json, 'mac') into _ans;
        assert (select count(1) from people) = 0, 'problem with table creation';
        set role authenticator;
        return true;
    end;
$$ language plpgsql;
select test_table_create();

\echo 'overview of new people table and its RLS policies'
\d+ people

\echo 'testing: user_create'

create or replace function test_user_create()
    returns boolean as $$
    declare _ans text;
    begin
        set role admin_user;
        select user_create('gustav', 'data_owner') into _ans;
        assert (select _user_type from user_types where _user_name = 'gustav') = 'data_owner',
            'problem with user creation';
        select user_create('hannah', 'data_owner') into _ans;
        assert (select _user_type from user_types where _user_name = 'hannah') = 'data_owner',
            'problem with user creation';
        select user_create('faye', 'data_owner') into _ans;
        assert (select _user_type from user_types where _user_name = 'faye') = 'data_owner',
            'problem with user creation';
        select user_create('project_user', 'data_user') into _ans;
        assert (select _user_type from user_types where _user_name = 'project_user') = 'data_user',
            'problem with user creation';
        assert (select count(1) from user_types) = 4,
            'not all newly created users are recorded in the user_types table';
        -- test that the rolse actually exist
        set role gustav;
        set role authenticator;
        set role hannah;
        set role authenticator;
        set role faye;
        set role authenticator;
        set role project_user;
        set role authenticator;
        return true;
    end;
$$ language plpgsql;
select test_user_create();

\echo 'overview of roles after user creation'
\du

\echo 'testing: group_create'

create or replace function test_group_create()
    returns boolean as $$
    declare _ans text;
    begin
        set role admin_user;
        select group_create('project_group') into _ans;
        assert (select count(*) from user_defined_groups) = 1,
            'problem recording user defined group creation in accounting table';
        -- check role exists
        set role authenticator;
        set role tsd_backend_utv_user; -- db owner
        set role project_group;
        set role authenticator;
        return true;
    end;
$$ language plpgsql;
select test_group_create();

\echo 'overview of roles after group creation'
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

