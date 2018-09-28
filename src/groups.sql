
-- low level group operations
-- run after need-to-know.sql

create schema groups;
grant usage on schema groups to admin_user;


drop table if exists groups.group_memberships;
create table if not exists groups.group_memberships(
    group_name text not null references ntk.user_defined_groups (group_name),
    user_name text not null references ntk.registered_users (_user_name),
    unique (group_name, user_name)
);
grant insert, select, delete on groups.group_memberships to admin_user;


create or replace function groups.create(group_name text)
    returns boolean as $$
    begin
        execute format('create role %I', group_name);
        return true;
    end;
$$ language plpgsql;


create or replace function groups.grant(group_name text, user_name text)
    returns boolean as $$
    begin
        execute format('insert into groups.group_memberships values
                        ($1, $2)') using group_name, user_name;
        return true;
    end;
$$ language plpgsql;


create or replace function groups.have_common_group(user1 text, user2 text)
    returns boolean as $$
    declare _num_common_groups int;
    begin
        execute format('select count(group_name) from (
                        select group_name from groups.group_memberships
                        where user_name = $1
                        intersect
                        select group_name from groups.group_memberships
                        where user_name = $2)a')
                into _num_common_groups
                using user1, user2;
        if _num_common_groups = 0 then
            return false;
        elsif _num_common_groups > 0 then
            return true;
        else
            return false;
        end if;
    end;
$$ language plpgsql;


create or replace function groups.revoke(group_name text, user_name text)
    returns boolean as $$
    begin
        execute format('delete from groups.group_memberships
                        where group_name = $1 and user_name = $2')
                using group_name, user_name;
        return true;
    end;
$$ language plpgsql;


create or replace function groups.drop(group_name text)
    returns boolean as $$
    begin
        execute format('drop role %I', group_name);
        return true;
    end;
$$ language plpgsql;


-- testing
set role anon;
select user_register('r1', 'data_owner', '{}'::json);
select user_register('r2', 'data_owner', '{}'::json);
select user_register('r3', 'data_owner', '{}'::json);
set role admin_user;
select group_create('g1', '{}'::json);
select group_create('g2', '{}'::json);
select group_create('g3', '{}'::json);
select groups.grant('g1', 'owner_r1');
select groups.grant('g2', 'owner_r1');
select groups.grant('g1', 'owner_r2');
select groups.grant('g3', 'owner_r3');
table groups.group_memberships;
\du
select groups.have_common_group('r1', 'owner_r2'); -- expect true
select groups.have_common_group('r1', 'owner_r3'); -- expect false
select groups.revoke('g1', 'owner_r1');
select groups.revoke('g1', 'owner_r2');
select groups.revoke('g2', 'owner_r1');
select groups.revoke('g3', 'owner_r3');
table groups.group_memberships;
select group_delete('g1');
select group_delete('g2');
select group_delete('g3');
select user_delete('owner_r1');
select user_delete('owner_r2');
select user_delete('owner_r3');
\du
