
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
    returns boolean as $$
    begin
        execute format('create role %I', group_name);
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function groups.create(text) from public;
grant execute on function groups.create(text) to admin_user;


create or replace function groups.grant(group_name text, user_name text)
    returns boolean as $$
    begin
        execute format('insert into groups.group_memberships values
                        ($1, $2)') using group_name, user_name;
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function groups.grant(text, text) from public;
grant execute on function groups.grant(text, text) to admin_user;


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
revoke all privileges on function groups.have_common_group(text, text) from public;
grant execute on function groups.have_common_group(text, text) to admin_user, data_owners_group, data_users_group;


create or replace function groups.revoke(group_name text, user_name text)
    returns boolean as $$
    begin
        execute format('delete from groups.group_memberships
                        where group_name = $1 and user_name = $2')
                using group_name, user_name;
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function groups.revoke(text, text) from public;
grant execute on function groups.revoke(text, text) to admin_user, data_owners_group;


create or replace function groups.drop(group_name text)
    returns boolean as $$
    begin
        execute format('drop role %I', group_name);
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function groups.drop(text) from public;
grant execute on function groups.drop(text) to admin_user;
