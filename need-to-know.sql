
/*

Conventions
-----------
For plpgsql functions the following conventions for code are adopted
- all parameters are re-assigned to internal variables
- all these variable state explicitly whether the source of the input
  is trusted or untrusted - this _should_ make it easier to reason
  about the security of the function; an example of trusted input
  is the built-in current_user variable, while end-user input is untrusted
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
        trusted_current_role := $1;
        trusted_current_row_owner := $2;
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
    begin
        case
            -- even though redundant this prevent SQL injection
            when _type = 'int' then return 'int';
            when _type = 'text' then return 'text';
            when _type = 'json' then return 'json';
            when _type = 'real' then return 'real';
            when _type = 'text[]' then return 'text[]';
            when _type = 'date' then return 'date';
            when _type = 'timestamp' then return 'timestamp';
            when _type = 'timestamptz' then return 'timestamptz';
            when _type = 'int[]' then return 'int[]';
            when _type = 'boolean' then return 'boolean';
            when _type = 'cidr' then return 'cidr';
            when _type = 'inet' then return 'inet';
            when _type = 'jsonb' then return 'jsonb';
            when _type = 'interval' then return 'interval';
            when _type = 'macaddr' then return 'macaddr';
            when _type = 'decimal' then return 'decimal';
            when _type = 'serial' then return 'serial';
            when _type = 'time' then return 'time';
            when _type = 'timetz' then return 'timetz';
            when _type = 'xml' then return 'xml';
            when _type = 'uuid' then return 'uuid';
            when _type = 'bytea' then return 'bytea';
            else raise exception using message = 'Unrecognised data type';
        end case;
    end;
$$ language plpgsql;
grant execute on function sql_type_from_generic_type(text) to admin_user;


drop function if exists table_create(json, text, int);
create or replace function table_create(definition json, type text, form_id int default 0)
    returns text as $$
    declare _res text;
    begin
        if type = 'mac' then
            select parse_mac_table_def(definition) into _res;
            return _res;
        elsif type = 'generic' then
            select parse_generic_table_def(definition) into _res;
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
    declare _table_name text;
    declare _columns json;
    declare _colname text;
    declare _dtype text;
    declare _i json;
    declare _pk boolean;
    declare _nn boolean;
    begin
        _columns := definition->'columns';
        _table_name := definition->>'table_name';
        execute 'create table if not exists ' || _table_name || '(row_owner text default current_user)';
        for _i in select * from json_array_elements(_columns) loop
            select sql_type_from_generic_type(_i->>'type') into _dtype;
            select _i->>'name' into _colname;
            begin
                execute 'alter table ' || _table_name || ' add column ' || _colname || ' ' || _dtype;
            exception
                when duplicate_column then raise notice 'column % already exists', _colname;
            end;
            begin
                select _i->'constraints'->'primary_key' into _pk;
                if _pk is not null then
                    begin
                        execute 'alter table ' || _table_name || ' add primary key ' || '(' || _colname || ')';
                    exception
                        when invalid_table_definition then raise notice 'primary key already exists';
                    end;
                end if;
            end;
            begin
                select _i->'constraints'->'not_null' into _nn;
                if _nn is not null then
                    execute 'alter table ' || _table_name || ' alter column ' || _colname || ' set not null';
                end if;
            end;
        end loop;
        execute 'alter table ' || _table_name || ' enable row level security';
        execute 'alter table ' || _table_name || ' force row level security';
        -- TODO: eventually move the select grant up and grant it on all user defined rows only
        execute 'grant insert, select, update, delete on ' || _table_name || ' to public';
        execute 'create policy row_ownership_insert_policy on ' || _table_name || ' for insert with check (true)';
        execute 'create policy row_ownership_select_policy on ' || _table_name || ' for select using (row_owner = current_user)';
        execute 'create policy row_ownership_delete_policy on ' || _table_name || ' for delete using (row_owner = current_user)';
        execute 'create policy row_ownership_select_group_policy on ' || _table_name || ' for select using (roles_have_common_group_and_is_data_user(current_user::text, row_owner))';
        execute 'create policy row_owbership_update_policy on ' || _table_name || ' for update using (row_owner = current_user) with check (row_owner = current_user)';
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
    begin
        execute 'create role ' || user_name;
        execute 'grant ' || user_name || ' to authenticator';
        execute 'grant select on group_memberships to ' || user_name;
        execute 'grant execute on function roles_have_common_group_and_is_data_user(text, text) to ' || user_name;
        execute 'grant insert on user_data_deletion_requests to ' || user_name;
        insert into user_types (_user_name, _user_type) values (user_name, user_type);
        return 'created user ' || user_name;
    end;
$$ language plpgsql;
grant execute on function user_create(text, text) to admin_user;


drop table if exists user_defined_groups cascade;
create table if not exists user_defined_groups(group_name text unique);
grant insert, select, delete on user_defined_groups to public; --eventually admin


drop function if exists group_create(text);
create or replace function group_create(group_name text)
    returns text as $$
    begin
        execute 'create role ' || group_name;
        insert into user_defined_groups values (group_name);
        return 'created group ' || group_name;
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
    declare _i json;
    declare _user text;
    declare _group text;
    begin
        for _i in select * from json_array_elements(members->'memberships') loop
            select _i->>'user' into _user;
            select _i->>'group' into _group;
            execute 'grant ' || _user || ' to ' || _group;
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
    declare _group text;
    begin
        _group := $1;
        raise notice '%', _group;
        return query execute 'select u.member::text from user_defined_groups_memberships u
                     where u.group_name = ' || quote_literal(_group);
    end;
$$ language plpgsql;
grant execute on function group_list_members(text) to admin_user;


drop function if exists group_remove_members(json);
create or replace function group_remove_members(members json)
    returns text as $$
    declare _i json;
    declare _user text;
    declare _group text;
    begin
        for _i in select * from json_array_elements(members->'memberships') loop
            select _i->>'user' into _user;
            select _i->>'group' into _group;
            execute 'revoke ' || _user || ' from ' || _group;
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
    declare _table text;
    begin
        for _table in select table_name from information_schema.tables where table_schema = 'public' and table_type != 'VIEW' loop
            begin
                if _table in ('user_defined_groups', 'user_types', 'user_data_deletion_requests') then
                    raise notice 'deleting data from % is not allowed', _table;
                    continue;
                end if;
                execute 'delete from '||  _table;
            exception
                when insufficient_privilege then raise notice 'cannot delete data from %, permission denied', _table;
            end;
        end loop;
        insert into user_data_deletion_requests (user_name, request_date) values (current_user, current_timestamp);
        return 'all data deleted';
    end;
$$ language plpgsql;
grant execute on function user_delete_data() to public;


drop function if exists user_delete(text);
create or replace function user_delete(user_name text)
    returns text as $$
    declare _table text;
    declare _numrows int;
    declare _g text;
    begin
        -- TODO check that user_name is user defined and not an internal role
        for _table in select table_name from information_schema.tables where table_schema = 'public' and table_type != 'VIEW' loop
            begin
                -- checked by the role we are going to delete, table owner has no access to data
                set role authenticator;
                execute 'set role ' || user_name;
                raise notice '1. --> current role: %', current_user::text;
                execute 'select count(1) from ' || _table || ' where row_owner = ' || quote_literal(user_name) into _numrows;
                set role authenticator;
                set role admin_user;
                raise notice '2. --> current role: %', current_user::text;
                if _numrows > 0 then
                    raise exception 'Cannot delete user, DB has data belonging to % in table %', user_name, _table;
                end if;
            exception
                when undefined_column then raise notice '% has no user data', _table;
            end;
        end loop;
        for _g in select _group from group_memberships where _role = user_name loop
            execute 'revoke ' || user_name || ' from ' || _g;
        end loop;
        for _table in select table_name from information_schema.role_table_grants where grantee = quote_literal(user_name) loop
            begin
                execute 'revoke all privileges on ' || _table ' from ' || user_name;
            end;
        end loop;
        -- ensure correct role
        set role authenticator;
        set role admin_user;
        execute 'revoke all privileges on group_memberships from ' || user_name;
        execute 'revoke all privileges on user_data_deletion_requests from ' || user_name;
        execute 'revoke execute on function roles_have_common_group_and_is_data_user(text, text) from ' || user_name;
        execute 'delete from user_types where _user_name = ' || quote_literal(user_name);
        execute 'drop role ' || user_name;
        return 'user deleted';
    end;
$$ language plpgsql;
grant execute on function user_delete(text) to public; -- eventually only admin_user


drop function if exists group_delete(text);
create or replace function group_delete(group_name text)
    returns text as $$
    declare _num_members int;
    begin
        -- ensure group has no members
        execute 'select count(1) from user_defined_groups_memberships u where u.group_name = ' || quote_literal(group_name) into _num_members;
        if _num_members > 0 then
            raise exception 'Cannot delete group %, it has % members', group_name, _num_members;
        end if;
        execute 'drop role ' || group_name;
        execute 'delete from user_defined_groups where group_name = ' || group_name;
        return 'group deleted';
    end;
$$ language plpgsql;
