
-- Proof of Concept

-- login as the superuser
-- construct a membership view, grant access to it
create role authenticator;
grant authenticator to tsd_backend_utv_user;
\du

create or replace view group_memberships as
select _group, _role from
    (select * from
        (select rolname as _group, oid from pg_authid)a join
        (select roleid, member from pg_auth_members)b on a.oid = b.member)c
    join (select rolname as _role, oid from pg_authid)d on c.roleid = d.oid;
-- give the db owner ownership of this view
alter view group_memberships owner to authenticator;
grant select on pg_authid to authenticator, tsd_backend_utv_user;
grant select on group_memberships to authenticator, tsd_backend_utv_user;
\d

set role tsd_backend_utv_user;

create or replace function roles_have_common_group(_current_role text, _current_row_owner text)
    returns boolean as $$
    declare _res boolean;
    begin
    select (
        select count(_group) from (
            select _group from group_memberships where _role = _current_role
            intersect
            select _group from group_memberships where _role = _current_row_owner)a
        where _group != 'authenticator')
    != 0 into _res;
    return _res;
    end;
$$ language plpgsql;
\df

-- a table where row owners can see their own data
-- and delete or update their own data
-- and non-owners can see the data when they are in
-- the same group as the row_owner
drop table if exists t1;
create table t1(row_owner text default current_user, x int);
alter table t1 owner to authenticator;
alter table t1 enable row level security;
grant insert, select, update, delete on t1 to public; -- constrained by RLS

-- policies (https://www.postgresql.org/docs/9.6/static/sql-createpolicy.html)
-- USING: existing rows (select, delete)
-- CHECK: new rows (insert, update)
create policy row_ownership_insert_policy on t1 for insert with check (true);
create policy row_ownership_select_policy on t1 for select using (row_owner = current_user);
create policy row_ownership_delete_policy on t1 for delete using (row_owner = current_user);
create policy row_ownership_select_group_policy on t1 for select using (roles_have_common_group(current_user::text, row_owner));
create policy row_owbership_update_policy on t1 for update using (row_owner = current_user) with check (row_owner = current_user);

\d+ t1

-- need to create the roles before inserting data
-- add a register request /rpc/user_register -> hash(id, salt), create role
create role role1;
grant role1 to authenticator;
grant select on group_memberships to role1;
grant execute on function roles_have_common_group(text, text) to role1;

create role role2;
grant role2 to authenticator;
grant select on group_memberships to role2;
grant execute on function roles_have_common_group(text, text) to role2;

create role role3;
grant role3 to authenticator;
grant select on group_memberships to role2;
grant execute on function roles_have_common_group(text, text) to role2;

-- simulate API-based inserts
set role role1;
insert into t1 (x) values (1);
set role authenticator;

set role role2;
insert into t1 (x) values (2);
set role authenticator;

set role role3;
insert into t1 (x) values (3);
set role authenticator;

-- only owners can operate on their own tables
set role authenticator;
table t1;

set role role1;
table t1;

-- reset
set role authenticator;
set role tsd_backend_utv_user;

-- testing groups
create role group1;
create role group2;

-- use a function
grant role3 to group2;
grant role1 to group1;
grant role2 to group1;

set role authenticator;
set role role1;
table t1;

-- test remaining policies
update t1 set x = 0;
table t1;

delete from t1;
table t1;

-- logout, login as superuser
-- cleanup
drop table t1;
drop view group_memberships;
revoke select on pg_authid from authenticator ;

drop role group1;
drop role group2;

drop role role1;
drop role role2;
drop role role3;

revoke authenticator from tsd_backend_utv_user;
drop role authenticator;
