
/*

Conventions
-----------
For plpgsql functions the following conventions for code are adopted
- all parameters are re-assigned to internal variables
- all these variable state explicitly whether the source of the input
  is trusted or untrusted
- this _should_ make it easier to reason about the security of the function
- trusted input is either derived from the db system itself or end-user
  input that has been validated by internal functions
- untrusted variable are never used for dynamic sql statement generation
- declarations for variables that are used to store parameters are
  distinguished from variables used to store internal state by comments

*/

-- as the superuser

create role authenticator createrole; -- add noinheret?
grant authenticator to tsd_backend_utv_user;
create role admin_user createrole; -- project admins
grant admin_user to authenticator;
create role app_user;
grant app_user to authenticator;

create or replace view group_memberships as
select _group, _role from
    (select * from
        (select rolname as _group, oid from pg_authid)a join
        (select roleid, member from pg_auth_members)b on a.oid = b.member)c
    join (select rolname as _role, oid from pg_authid)d on c.roleid = d.oid;
alter view group_memberships owner to admin_user;
grant select on pg_authid to authenticator, tsd_backend_utv_user, admin_user;
grant select on group_memberships to authenticator, tsd_backend_utv_user, admin_user;


set role tsd_backend_utv_user; --dbowner

drop function if exists roles_have_common_group_and_is_data_user(text, text);
create or replace function roles_have_common_group_and_is_data_user(_current_role text, _current_row_owner text)
    returns boolean as $$
    -- param vars
    declare trusted_current_role text;
    declare trusted_current_row_owner text;
    -- func vars
    declare _type text;
    declare _res boolean;
    begin
        trusted_current_role := _current_role;
        trusted_current_row_owner := _current_row_owner;
        execute format('select _user_type from user_types where _user_name = $1')
            into _type using trusted_current_role;
        if _type != 'data_user'
            then return false;
        end if;
        execute format('select (
            select count(_group) from (
                select _group from group_memberships where _role = $1
                intersect
                select _group from group_memberships where _role = $2)a
            where _group != $3)
        != 0') into _res using trusted_current_role, trusted_current_row_owner, 'authenticator';
        return _res;
    end;
$$ language plpgsql;
alter function roles_have_common_group_and_is_data_user owner to admin_user;
grant execute on function roles_have_common_group_and_is_data_user(text, text) to public;


drop function if exists sql_type_from_generic_type(text);
create or replace function sql_type_from_generic_type(_type text)
    returns text as $$
    declare untrusted_type text;
    begin
        untrusted_type := _type;
        case
            -- even though redundant this prevent SQL injection
            when untrusted_type = 'int' then return 'int';
            when untrusted_type = 'text' then return 'text';
            when untrusted_type = 'json' then return 'json';
            when untrusted_type = 'real' then return 'real';
            when untrusted_type = 'text[]' then return 'text[]';
            when untrusted_type = 'date' then return 'date';
            when untrusted_type = 'timestamp' then return 'timestamp';
            when untrusted_type = 'timestamptz' then return 'timestamptz';
            when untrusted_type = 'int[]' then return 'int[]';
            when untrusted_type = 'boolean' then return 'boolean';
            when untrusted_type = 'cidr' then return 'cidr';
            when untrusted_type = 'inet' then return 'inet';
            when untrusted_type = 'jsonb' then return 'jsonb';
            when untrusted_type = 'interval' then return 'interval';
            when untrusted_type = 'macaddr' then return 'macaddr';
            when untrusted_type = 'decimal' then return 'decimal';
            when untrusted_type = 'serial' then return 'serial';
            when untrusted_type = 'time' then return 'time';
            when untrusted_type = 'timetz' then return 'timetz';
            when untrusted_type = 'xml' then return 'xml';
            when untrusted_type = 'uuid' then return 'uuid';
            when untrusted_type = 'bytea' then return 'bytea';
            else raise exception using message = 'Unrecognised data type';
        end case;
    end;
$$ language plpgsql;
grant execute on function sql_type_from_generic_type(text) to admin_user;


drop function if exists table_create(json, text, int);
create or replace function table_create(definition json, type text, form_id int default 0)
    returns text as $$
    declare untrusted_definition json;
    declare untrusted_type text;
    declare untrusted_form_id int;
    declare _res text;
    begin
        untrusted_definition := definition;
        untrusted_type := type;
        untrusted_form_id := form_id;
        if untrusted_type = 'mac' then
            select parse_mac_table_def(untrusted_definition) into _res;
            return _res;
        elsif untrusted_type = 'generic' then
            select parse_generic_table_def(untrusted_definition) into _res;
            return _res;
        else
            raise exception using message = 'Unrecognised table definition type.';
        end if;
    end;
$$ language plpgsql;
grant execute on function table_create(json, text, int) to admin_user;


drop function if exists parse_mac_table_def(json);
create or replace function parse_mac_table_def(definition json)
    returns text as $$
    -- param vars
    declare untrusted_definition json;
    -- func vars
    declare trusted_table_name text;
    declare untrusted_columns json;
    declare trusted_colname text;
    declare trusted_dtype text;
    declare untrusted_i json;
    declare untrusted_pk boolean;
    declare untrusted_nn boolean;
    begin
        untrusted_definition := definition;
        untrusted_columns := untrusted_definition->'columns';
        trusted_table_name := quote_ident(untrusted_definition->>'table_name');
        execute format('create table if not exists %I (row_owner text default current_user)', trusted_table_name);
        for untrusted_i in select * from json_array_elements(untrusted_columns) loop
            select sql_type_from_generic_type(untrusted_i->>'type') into trusted_dtype;
            select quote_ident(untrusted_i->>'name') into trusted_colname;
            begin
                execute format('alter table %I add column %I %s', trusted_table_name, trusted_colname, trusted_dtype);
            exception
                when duplicate_column then raise notice 'column % already exists', trusted_colname;
            end;
            begin
                select untrusted_i->'constraints'->'primary_key' into untrusted_pk;
                if untrusted_pk is not null then
                    begin
                        execute format('alter table %I add primary key (%s)', trusted_table_name, trusted_colname);
                    exception
                        when invalid_table_definition then raise notice 'primary key already exists';
                    end;
                end if;
            end;
            begin
                select untrusted_i->'constraints'->'not_null' into untrusted_nn;
                if untrusted_nn is not null then
                    execute format('alter table %I alter column %I set not null', trusted_table_name, trusted_colname);
                end if;
            end;
        end loop;
        execute format('alter table %I enable row level security', trusted_table_name);
        execute format('alter table %I force row level security', trusted_table_name);
        -- TODO: perhaps move the select grant up and grant it on all user defined rows only
        execute format('grant insert, select, update, delete on %I to public', trusted_table_name);
        execute format('create policy row_ownership_insert_policy on %I for insert with check (true)', trusted_table_name);
        execute format('create policy row_ownership_select_policy on %I for select using (row_owner = current_user)', trusted_table_name);
        execute format('create policy row_ownership_delete_policy on %I for delete using (row_owner = current_user)', trusted_table_name);
        execute format('create policy row_ownership_select_group_policy on %I for select using (roles_have_common_group_and_is_data_user(current_user::text, row_owner))', trusted_table_name);
        execute format('create policy row_owbership_update_policy on %I for update using (row_owner = current_user) with check (row_owner = current_user)', trusted_table_name);
        return 'Success';
    end;
$$ language plpgsql;


drop function if exists parse_generic_table_def(json);
create or replace function parse_generic_table_def(definition json)
    returns text as $$
    begin
        return 'Not implemented - did nothing.';
    end;
$$ language plpgsql;


drop table if exists user_types;
create table if not exists user_types(
    _user_name text not null,
    _user_type text not null check (_user_type in ('data_owner', 'data_user')));
alter table user_types owner to authenticator;
grant insert, select, delete on user_types to public; -- eventually only app_user, admin_user


drop function if exists user_create(text, text);
create or replace function user_create(user_name text, user_type text)
    returns text as $$
    declare trusted_user_name text;
    declare trusted_user_type text;
    begin
        trusted_user_name := quote_ident(user_name);
        trusted_user_type := quote_literal(user_type);
        execute format('create role %I', trusted_user_name);
        execute format('grant %I to authenticator', trusted_user_name);
        execute format('grant select on group_memberships to %I', trusted_user_name);
        execute format('grant execute on function roles_have_common_group_and_is_data_user(text, text) to %I', trusted_user_name);
        execute format('grant insert on user_data_deletion_requests to %I', trusted_user_name);
        -- the table also has a check constraint on it for values of _user_type
        execute format('insert into user_types (_user_name, _user_type) values ($1, $2)')
            using user_name, user_type; -- this is alright, since they are _values_ not SQL identifiers
        return 'user created';
    end;
$$ language plpgsql;
grant execute on function user_create(text, text) to admin_user;


drop table if exists user_defined_groups cascade;
create table if not exists user_defined_groups(group_name text unique);
grant insert, select, delete on user_defined_groups to public; --eventually admin


drop function if exists group_create(text);
create or replace function group_create(group_name text)
    returns text as $$
    declare trusted_group_name text;
    begin
        trusted_group_name := quote_ident(group_name);
        execute format('create role %I', trusted_group_name);
        execute format('insert into user_defined_groups values ($1)') using group_name;
        return 'group created';
    end;
$$ language plpgsql;
grant execute on function group_create(text) to admin_user;


drop view if exists user_defined_groups_memberships cascade;
create or replace view user_defined_groups_memberships as
    select group_name, _role member from
        (select group_name from user_defined_groups)a
        join
        (select _group, _role from group_memberships)b
        on a.group_name = b._group;
grant select on user_defined_groups_memberships to public;


drop function if exists group_add_members(json);
create or replace function group_add_members(members json)
    returns text as $$
    declare untrusted_members json;
    declare untrusted_i json;
    declare trusted_user text;
    declare trusted_group text;
    begin
        untrusted_members := members;
        for untrusted_i in select * from json_array_elements(untrusted_members->'memberships') loop
            select quote_ident(untrusted_i->>'user') into trusted_user;
            select quote_ident(untrusted_i->>'group') into trusted_group;
            execute format('grant %I to %I', trusted_user, trusted_group);
        end loop;
    return 'added members to groups';
    end;
$$ language plpgsql;
grant execute on function group_add_members(json) to admin_user;


drop function if exists group_list();
create or replace function group_list()
    returns setof user_defined_groups as $$
    begin
        return query select group_name from user_defined_groups;
    end;
$$ language plpgsql;
grant execute on function group_list() to admin_user;


drop function if exists group_list_members(text);
create or replace function group_list_members(group_name text)
    returns table (member text) as $$
    begin
        return query execute format('select u.member::text from user_defined_groups_memberships u
                     where u.group_name = $1') using group_name;
    end;
$$ language plpgsql;
grant execute on function group_list_members(text) to admin_user;


drop function if exists group_remove_members(json);
create or replace function group_remove_members(members json)
    returns text as $$
    declare untrusted_members json;
    declare untrusted_i json;
    declare trusted_user text;
    declare trusted_group text;
    begin
        untrusted_members := members;
        for untrusted_i in select * from json_array_elements(untrusted_members->'memberships') loop
            select quote_ident(untrusted_i->>'user') into trusted_user;
            select quote_ident(untrusted_i->>'group') into trusted_group;
            execute format('revoke %I from %I', trusted_user, trusted_group);
        end loop;
    return 'removed members from groups';
    end;
$$ language plpgsql;
grant execute on function group_remove_members(json) to admin_user;


drop table if exists user_data_deletion_requests;
create table if not exists user_data_deletion_requests(
    user_name text not null,
    request_date timestamptz not null
);
alter table user_data_deletion_requests owner to admin_user;
grant insert on user_data_deletion_requests to public;


drop function if exists user_delete_data();
create or replace function user_delete_data()
    returns text as $$
    declare trusted_table text;
    begin
        for trusted_table in select table_name from information_schema.tables
                      where table_schema = 'public' and table_type != 'VIEW' loop
            begin
                if trusted_table in ('user_defined_groups', 'user_types', 'user_data_deletion_requests') then null;
                    continue;
                end if;
                execute format('delete from %I', trusted_table);
            exception
                when insufficient_privilege
                then raise notice 'cannot delete data from %, permission denied', trusted_table;
            end;
        end loop;
        insert into user_data_deletion_requests (user_name, request_date)
            values (current_user, current_timestamp);
        return 'all data deleted';
    end;
$$ language plpgsql;
grant execute on function user_delete_data() to public;


drop function if exists user_delete(text);
create or replace function user_delete(user_name text)
    returns text as $$
    declare trusted_table text;
    declare trusted_user_name text;
    declare trusted_numrows int;
    declare trusted_group text;
    begin
        assert user_name in (select _user_name from user_types), 'deleting role not allowed';
        trusted_user_name := quote_ident(user_name);
        for trusted_table in select table_name from information_schema.tables
                              where table_schema = 'public' and table_type != 'VIEW' loop
            begin
                set role authenticator;
                execute format('set role %I', trusted_user_name);
                execute format('select count(1) from %I where row_owner = $1', trusted_table)
                        using user_name into trusted_numrows;
                set role authenticator;
                set role admin_user;
                if trusted_numrows > 0 then
                    raise exception 'Cannot delete user, DB has data belonging to % in table %', user_name, trusted_table;
                end if;
            exception
                when undefined_column then null;
            end;
        end loop;
        for trusted_group in select _group from group_memberships where _role = user_name loop
            execute format('revoke %I from %I', trusted_user_name, trusted_group);
        end loop;
        for trusted_table in select table_name from information_schema.role_table_grants
                              where grantee = quote_literal(user_name) loop
            begin
                execute format('revoke all privileges on %I from %I', trusted_table, user_name);
            end;
        end loop;
        set role authenticator;
        set role admin_user;
        execute format('revoke all privileges on group_memberships from %I', trusted_user_name);
        execute format('revoke all privileges on user_data_deletion_requests from %I', trusted_user_name);
        execute format('revoke execute on function roles_have_common_group_and_is_data_user(text, text) from %I', trusted_user_name);
        execute format('delete from user_types where _user_name = $1') using user_name;
        execute format('drop role %I', trusted_user_name);
        return 'user deleted';
    end;
$$ language plpgsql;
grant execute on function user_delete(text) to public; -- eventually only admin_user


drop function if exists group_delete(text);
create or replace function group_delete(group_name text)
    returns text as $$
    declare trusted_group_name text;
    declare trusted_num_members int;
    begin
        assert group_name in (select udg.group_name from user_defined_groups udg), 'permission denied to delete group';
        trusted_group_name := quote_ident(group_name);
        execute format('select count(1) from user_defined_groups_memberships u where u.group_name = $1')
                using group_name into trusted_num_members;
        if trusted_num_members > 0 then
            raise exception 'Cannot delete group %, it has % members', group_name, trusted_num_members;
        end if;
        execute format('drop role %I', trusted_group_name);
        execute format('delete from user_defined_groups where group_name = $1') using group_name;
        return 'group deleted';
    end;
$$ language plpgsql;
