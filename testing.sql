
----------------
-- Use the model
----------------

-- need to create the roles before inserting data
-- add a register request /rpc/user_register -> hash(id, salt), create role
create role role1;
grant role1 to authenticator;
grant select on group_memberships to role1;

create role role2;
grant role2 to authenticator;
grant select on group_memberships to role2;

create role role3;
grant role3 to authenticator;
grant select on group_memberships to role2;

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
