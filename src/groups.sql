
-- low level group operations
-- run after need-to-know.sql

create schema groups;
grant usage on schema groups to admin_user, data_owners_group, data_users_group;


drop table if exists groups.group_memberships;
create table if not exists groups.group_memberships(
    group_name text not null references ntk.user_defined_groups (group_name),
    user_name text not null references ntk.registered_users (_user_name),
    unique (group_name, user_name)
);
grant insert, select, delete on groups.group_memberships to admin_user;
grant select on groups.group_memberships to data_owners_group, data_users_group;


create or replace function groups.create(group_name text)
    returns void
    language sql
    as $$
    create role group_name;
$$;
revoke all privileges on function groups.create(text) from public;
grant execute on function groups.create(text) to admin_user;


create or replace function groups.grant(group_name text, user_name text)
    returns void
    language sql
    as $$
    insert into groups.group_memberships
    values (group_name, user_name);
$$;
revoke all privileges on function groups.grant(text, text) from public;
grant execute on function groups.grant(text, text) to admin_user;


create or replace function groups.have_common_group(user1 text, user2 text)
    returns boolean
    language sql as $$
    select exists (
        select 1
        from groups.group_memberships
        where user_name in (user1, user2)
        group by group_name
        having count(*) > 1
    )
$$;
revoke all privileges on function groups.have_common_group(text, text) from public;
grant execute on function groups.have_common_group(text, text) to admin_user, data_owners_group, data_users_group;


create or replace function groups.revoke(group_name text, user_name text)
    returns void
    language sql
    as $$
    delete from groups.group_memberships
    where (group_name, user_name) = (group_name, user_name);
$$;
revoke all privileges on function groups.revoke(text, text) from public;
grant execute on function groups.revoke(text, text) to admin_user, data_owners_group;


create or replace function groups.drop(group_name text)
    returns void
    language sql
    as $$
        drop role group_name;
$$;
revoke all privileges on function groups.drop(text) from public;
grant execute on function groups.drop(text) to admin_user;
