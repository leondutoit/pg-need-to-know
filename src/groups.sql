
-- testing session variable approach

drop table if exists testing;
create table if not exists testing(
    row_owner text not null default current_setting('request.jwt.claim.user'),
    x int
);

set session "request.jwt.claim.user" = 'leon';
insert into testing (x) values (1);
select * from testing;

set session "request.jwt.claim.user" = 'gustav';
insert into testing (x) values (2);
select * from testing;

-- low level group operations

create schema groups;
grant usage on schema groups to admin_user;


drop table if exists groups.group_memberships;
create table if not exists groups.group_memberships(
    group_name text not null,
    user_name text not null, -- fk to registered users
    unique (group_name, user_name)
);


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

select groups.create('g1');
select groups.create('g2');
select groups.create('g3');
select groups.grant('g1', 'r1');
select groups.grant('g2', 'r1');
select groups.grant('g1', 'r2');
select groups.grant('g3', 'r3');
table groups.group_memberships;
\du
select groups.have_common_group('r1', 'r2'); -- expect true
select groups.have_common_group('r1', 'r3'); -- expect false
select groups.revoke('g1', 'r1');
select groups.revoke('g1', 'r2');
select groups.revoke('g2', 'r1');
select groups.revoke('g3', 'r3');
table groups.group_memberships;
select groups.drop('g1');
select groups.drop('g2');
select groups.drop('g3');
\du
