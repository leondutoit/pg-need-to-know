
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
- function, table and view ownership is granted to the admin_user when
  the admin_user needs to grant usage on those objects to other roles,
  otherwise the admin_user only has the minimum privileges necessary

*/

-- as the superuser

create role authenticator noinherit login password 'replaceme';
grant authenticator to tsd_backend_utv_user; -- TODO remove
create role admin_user createrole;
grant admin_user to authenticator;
create role anon;
grant anon to authenticator;
create role data_owners_group;


-- internal schema
create schema if not exists ntk;
grant usage on schema ntk to public;
grant create on schema ntk to admin_user; -- so execute can be granted/revoked when users are created/deleted


create or replace view ntk.group_memberships as
select _group, _role from
    (select * from
        (select rolname as _role, oid from pg_authid)a join
        (select roleid, member from pg_auth_members)b on a.oid = b.member)c
    join (select rolname as _group, oid from pg_authid)d on c.roleid = d.oid;
alter view ntk.group_memberships owner to admin_user;
grant select on pg_authid to tsd_backend_utv_user, admin_user;
grant select on ntk.group_memberships to tsd_backend_utv_user, admin_user;


drop table if exists event_log_data_access;
create table event_log_data_access(
    request_time timestamptz default current_timestamp,
    data_user text,
    data_owner text
);
grant insert, select on event_log_data_access to public;
alter table event_log_data_access enable row level security;
alter table event_log_data_access owner to admin_user;
revoke delete on event_log_data_access from admin_user;
grant delete on event_log_data_access to tsd_backend_utv_user;
create policy select_for_data_owners on event_log_data_access for select using (data_owner = current_user);
create policy insert_policy_for_public on event_log_data_access for insert with check (true);


drop function if exists ntk.update_request_log(text, text);
create or replace function ntk.update_request_log(_current_role text, _current_row_owner text)
    returns boolean as $$
    declare trusted_current_role text;
    declare trusted_current_row_owner text;
    begin
        trusted_current_role := _current_role;
        trusted_current_row_owner := _current_row_owner;
        execute format('insert into event_log_data_access (data_user, data_owner) values ($1, $2)')
                using trusted_current_role, trusted_current_row_owner;
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.update_request_log(text, text) from public;
alter function ntk.update_request_log owner to admin_user;


drop table if exists event_log_access_control cascade;
create table if not exists event_log_access_control(
    event_time timestamptz default current_timestamp,
    event_type text not null check
        (event_type in ('group_create', 'group_delete',
                        'group_member_add', 'group_member_remove',
                        'table_grant_add', 'table_grant_revoke')),
    group_name text not null,
    target text
);
alter table event_log_access_control owner to admin_user;
revoke delete, update on event_log_access_control from admin_user;


drop function if exists ntk.update_event_log_access_control(text, text, text);
create or replace function ntk.update_event_log_access_control(event_type text, group_name text, target text)
    returns void as $$
    begin
        execute format('insert into event_log_access_control
                       (event_type, group_name, target)
                       values ($1, $2, $3)')
            using event_type, group_name, target;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.update_event_log_access_control(text, text, json) from public;
grant execute on function ntk.update_event_log_access_control(text, text, json) to admin_user;


drop function if exists ntk.roles_have_common_group_and_is_data_user(text, text);
create or replace function ntk.roles_have_common_group_and_is_data_user(_current_role text, _current_row_owner text)
    returns boolean as $$
    -- param vars
    declare trusted_current_role text;
    declare trusted_current_row_owner text;
    -- func vars
    declare _type text;
    declare _log boolean;
    declare _res boolean;
    begin
        trusted_current_role := _current_role;
        trusted_current_row_owner := _current_row_owner;
        execute format('select _user_type from ntk.registered_users where _user_name = $1')
            into _type using trusted_current_role;
        if _type != 'data_user'
            then return false;
        end if;
        execute format('select (
            select count(_group) from (
                select _group from ntk.group_memberships where _role = $1
                intersect
                select _group from ntk.group_memberships where _role = $2)a
            where _group != $3)
        != 0') into _res using trusted_current_role, trusted_current_row_owner, 'authenticator';
        if _res = true then
            select ntk.update_request_log(trusted_current_role, trusted_current_row_owner) into _log;
        end if;
        return _res;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.roles_have_common_group_and_is_data_user(text, text) from public;
alter function ntk.roles_have_common_group_and_is_data_user owner to admin_user;


drop function if exists ntk.sql_type_from_generic_type(text);
create or replace function ntk.sql_type_from_generic_type(_type text)
    returns text as $$
    declare untrusted_type text;
    begin
        untrusted_type := _type;
        case
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
revoke all privileges on function ntk.sql_type_from_generic_type(text) from public;
grant execute on function ntk.sql_type_from_generic_type(text) to admin_user;


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
            select ntk.parse_mac_table_def(untrusted_definition) into _res;
            return _res;
        elsif untrusted_type = 'generic' then
            select ntk.parse_generic_table_def(untrusted_definition) into _res;
            return _res;
        else
            raise exception using message = 'Unrecognised table definition type.';
        end if;
    end;
$$ language plpgsql;
revoke all privileges on function table_create(json, text, int) from public;
grant execute on function table_create(json, text, int) to admin_user;


drop function if exists ntk.parse_mac_table_def(json);
create or replace function ntk.parse_mac_table_def(definition json)
    returns text as $$
    declare untrusted_definition json;
    declare trusted_table_name text;
    declare untrusted_columns json;
    declare trusted_colname text;
    declare trusted_dtype text;
    declare untrusted_i json;
    declare untrusted_pk boolean;
    declare untrusted_nn boolean;
    declare trusted_comment text;
    declare trusted_column_description text;
    begin
        untrusted_definition := definition;
        untrusted_columns := untrusted_definition->'columns';
        trusted_table_name := quote_ident(untrusted_definition->>'table_name');
        trusted_comment := quote_nullable(untrusted_definition->>'description');
        execute format('create table if not exists %I (row_owner text default current_user references ntk.data_owners (user_name))', trusted_table_name);
        for untrusted_i in select * from json_array_elements(untrusted_columns) loop
            select ntk.sql_type_from_generic_type(untrusted_i->>'type') into trusted_dtype;
            select quote_ident(untrusted_i->>'name') into trusted_colname;
            select quote_nullable(untrusted_i->>'description') into trusted_column_description;
            begin
                execute format('alter table %I add column %I %s',
                    trusted_table_name, trusted_colname, trusted_dtype);
                execute format('comment on column %I.%I is %s',
                    trusted_table_name, trusted_colname, trusted_column_description);
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
        execute format('grant select on %I to data_owners_group', trusted_table_name);
        execute format('grant insert, update, delete on %I to public', trusted_table_name);
        execute format('create policy row_ownership_insert_policy on %I for insert with check (true)', trusted_table_name);
        execute format('create policy row_ownership_select_policy on %I for select using (row_owner = current_user)', trusted_table_name);
        execute format('create policy row_ownership_delete_policy on %I for delete using (row_owner = current_user)', trusted_table_name);
        execute format('create policy row_ownership_select_group_policy on %I for select using (ntk.roles_have_common_group_and_is_data_user(current_user::text, row_owner))', trusted_table_name);
        execute format('create policy row_ownership_update_policy on %I for update using (row_owner = current_user) with check (row_owner = current_user)', trusted_table_name);
        execute format('comment on table %I is %s', trusted_table_name, trusted_comment);
        return 'Success';
    end;
$$ language plpgsql;
revoke all privileges on function ntk.parse_mac_table_def(json) from public;
grant execute on function ntk.parse_mac_table_def(json) to admin_user;


drop function if exists ntk.is_user_defined_table(text);
create or replace function ntk.is_user_defined_table(table_name text)
    returns boolean as $$
    begin
        assert $1 in (select info.table_name from information_schema.tables info
                        where info.table_schema = 'public'
                        and info.table_type != 'VIEW'
                        and info.table_name not in
                        ('user_registrations', 'groups', 'event_log_user_group_removals',
                         'event_log_user_data_deletions', 'event_log_data_access')), 'access denied to table';
        return true;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.is_user_defined_table(text) from public;
grant execute on function ntk.is_user_defined_table(text) to admin_user;


drop function if exists table_describe(text, text);
create or replace function table_describe(table_name text, table_description text)
    returns text as $$
    declare trusted_table_name text;
    declare trusted_table_description text;
    begin
        assert (select ntk.is_user_defined_table(table_name) = true);
        trusted_table_name := quote_ident(table_name);
        trusted_table_description := quote_literal(table_description);
        execute format('comment on table %I is %s', trusted_table_name, trusted_table_description);
        return 'table description set';
    end;
$$ language plpgsql;
revoke all privileges on function table_describe(text, text) from public;
grant execute on function table_describe(text, text) to admin_user;


drop function if exists table_describe_columns(text, json);
create or replace function table_describe_columns(table_name text, column_descriptions json)
    returns text as $$
    declare trusted_table_name text;
    declare untrusted_i json;
    declare trusted_column_name text;
    declare trusted_column_description text;
    begin
        assert (select ntk.is_user_defined_table(table_name) = true);
        trusted_table_name := quote_ident(table_name);
        for untrusted_i in select * from json_array_elements(column_descriptions) loop
            select quote_ident(untrusted_i->>'name') into trusted_column_name;
            select quote_nullable(untrusted_i->>'description') into trusted_column_description;
            execute format('comment on column %I.%I is %s',
                trusted_table_name, trusted_column_name, trusted_column_description);
        end loop;
        return 'column description set';
    end;
$$ language plpgsql;
revoke all privileges on function table_describe_columns(text, json) from public;
grant execute on function table_describe_columns(text, json) to admin_user;


drop table if exists ntk.tm cascade;
create table if not exists ntk.tm(column_name text, column_description text);


drop function if exists table_metadata(text);
create or replace function table_metadata(table_name text)
    returns setof ntk.tm as $$
    begin
        assert (select ntk.is_user_defined_table(table_name) = true);
        return query execute format('
            select c.column_name::text, pgd.description::text
                from pg_catalog.pg_statio_all_tables as st
            inner join information_schema.columns c
                on c.table_schema = st.schemaname and c.table_name = st.relname
            left join pg_catalog.pg_description pgd
                on pgd.objoid=st.relid
                and pgd.objsubid=c.ordinal_position
                where st.relname = $1') using $1;
    end;
$$ language plpgsql;
revoke all privileges on function table_metadata from public;
grant execute on function table_metadata to admin_user;


drop function if exists ntk.parse_generic_table_def(json);
create or replace function ntk.parse_generic_table_def(definition json)
    returns text as $$
    begin
        return 'Not implemented - did nothing.';
    end;
$$ language plpgsql;
revoke all privileges on function ntk.parse_generic_table_def(json) from public;


drop function if exists table_group_access_grant(text, text);
create or replace function table_group_access_grant(table_name text, group_name text)
    returns text as $$
    declare trusted_table_name text;
    declare trusted_group_name text;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        assert (select ntk.is_user_defined_table(table_name) = true);
        trusted_table_name := quote_ident(table_name);
        trusted_group_name := quote_ident(group_name);
        execute format('grant select on %I to %I', trusted_table_name, trusted_group_name);
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'table_grant_add', trusted_group_name, trusted_table_name;
        return 'granted access to table';
    end;
$$ language plpgsql;
revoke all privileges on function table_group_access_grant(text, text) from public;
grant execute on function table_group_access_grant(text, text) to admin_user;


drop function if exists table_group_access_revoke(text, text);
create or replace function table_group_access_revoke(table_name text, group_name text)
    returns text as $$
    declare trusted_table_name text;
    declare trusted_group_name text;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        assert (select ntk.is_user_defined_table(table_name) = true);
        trusted_table_name := quote_ident(table_name);
        trusted_group_name := quote_ident(group_name);
        execute format('revoke select on %I from %I', trusted_table_name, trusted_group_name);
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'table_grant_revoke', trusted_group_name, trusted_table_name;
        return 'revoked access to table';
    end;
$$ language plpgsql;
revoke all privileges on function table_group_access_revoke(text, text) from public;
grant execute on function table_group_access_revoke(text, text) to admin_user;


drop table if exists ntk.registered_users cascade;
create table if not exists ntk.registered_users(
    registration_date timestamptz default current_timestamp,
    _user_name text not null unique,
    _user_type text not null check (_user_type in ('data_owner', 'data_user')),
    user_metadata json
);
alter table ntk.registered_users owner to admin_user;
grant select on ntk.registered_users to public;
create or replace view user_registrations as
    select registration_date, _user_name as user_name,
           _user_type as user_type, user_metadata
    from ntk.registered_users;
alter view user_registrations owner to admin_user;


drop table if exists ntk.data_owners;
create table if not exists ntk.data_owners(user_name text not null unique);
alter table ntk.data_owners owner to admin_user;
grant insert on ntk.data_owners to public;


drop function if exists user_register(text, text, json);
create or replace function user_register(user_id text, user_type text, user_metadata json)
    returns text as $$
    declare _ans text;
    declare trusted_user_name text;
    begin
        assert (select length(user_id) <= 57),
            'the maximum allowed user name length is 57 characters';
        assert (select bool_or(user_type ilike arr_element||'%')
                from unnest(ARRAY['data_owner','data_user']) x(arr_element)),
            'user_type must be either "data_owner" or "data_user"';
        if user_type = 'data_owner' then
            trusted_user_name := 'owner_' || user_id;
        elsif user_type = 'data_user' then
            trusted_user_name := 'user_' || user_id;
        end if;
        set role admin_user;
        select ntk.user_create(trusted_user_name, user_type, user_metadata) into _ans;
        set role authenticator;
        set role anon;
        return 'user created';
    end;
$$ language plpgsql;
revoke all privileges on function user_register(text, text, json) from public;
grant execute on function user_register(text, text, json) to anon;


drop function if exists ntk.user_create(text, text, json);
create or replace function ntk.user_create(user_name text, user_type text, user_metadata json)
    returns text as $$
    declare trusted_user_name text;
    declare trusted_user_type text;
    begin
        assert (select bool_or(user_name like arr_element||'%')
                from unnest(ARRAY['owner_','user_']) x(arr_element)),
            'user name must start with either "owner_" or "user_"';
        trusted_user_name := quote_ident(user_name);
        trusted_user_type := quote_literal(user_type);
        execute format('create role %I', trusted_user_name);
        execute format('grant %I to authenticator', trusted_user_name);
        execute format('grant select on ntk.group_memberships to %I', trusted_user_name);
        execute format('grant execute on function ntk.roles_have_common_group_and_is_data_user(text, text) to %I', trusted_user_name);
        execute format('grant execute on function ntk.update_request_log(text, text) to %I', trusted_user_name);
        execute format('grant execute on function user_groups(text) to %I', trusted_user_name);
        execute format('grant execute on function user_group_remove(text) to %I', trusted_user_name);
        execute format('insert into ntk.registered_users (_user_name, _user_type, user_metadata) values ($1, $2, $3)')
            using user_name, user_type, user_metadata;
        if user_type = 'data_owner' then
            execute format('insert into ntk.data_owners values ($1)') using user_name;
            execute format('grant data_owners_group to %I', trusted_user_name);
        end if;
        return 'user created';
    end;
$$ language plpgsql;
revoke all privileges on function ntk.user_create(text, text, json) from public;
grant execute on function ntk.user_create(text, text, json) to admin_user;


drop table if exists ntk.user_defined_groups cascade;
create table if not exists ntk.user_defined_groups (
    group_name text unique,
    group_metadata json not null
);
alter table ntk.user_defined_groups owner to admin_user;
grant select on ntk.user_defined_groups to public;
create view groups as select * from ntk.user_defined_groups;
alter view groups owner to admin_user;


drop table if exists ntk.user_initiated_group_removals cascade;
create table ntk.user_initiated_group_removals(
    removal_date timestamptz default current_timestamp,
    user_name text not null,
    group_name text not null
);
alter table ntk.user_initiated_group_removals owner to admin_user;
grant insert on ntk.user_initiated_group_removals to public;
create or replace view event_log_user_group_removals as
    select * from ntk.user_initiated_group_removals;
alter view event_log_user_group_removals owner to admin_user;


drop function if exists group_create(text, json);
create or replace function group_create(group_name text, group_metadata json)
    returns text as $$
    declare trusted_group_name text;
    begin
        trusted_group_name := quote_ident(group_name);
        execute format('create role %I', trusted_group_name);
        execute format('insert into ntk.user_defined_groups values ($1, $2)')
            using group_name, group_metadata;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'group_create', trusted_group_name, null;
        return 'group created';
    end;
$$ language plpgsql;
revoke all privileges on function group_create(text, json) from public;
grant execute on function group_create(text, json) to admin_user;


drop view if exists ntk.user_defined_groups_memberships cascade;
create or replace view ntk.user_defined_groups_memberships as
    select group_name, _role member from
        (select group_name from ntk.user_defined_groups)a
        join
        (select _group, _role from ntk.group_memberships)b
        on a.group_name = b._group;
alter view ntk.user_defined_groups_memberships owner to admin_user;
grant select on ntk.user_defined_groups_memberships to public;


create or replace view table_overview as
    select a.table_name, b.table_description, a.groups_with_access from
    (select table_name, array_agg(grantee::text) groups_with_access
    from information_schema.table_privileges
        where privilege_type = 'SELECT'
        and table_schema = 'public'
        and grantee not in ('PUBLIC')
        and grantee in (select group_name from ntk.user_defined_groups)
        or grantee = 'data_owners_group'
        and table_name not in ('user_registrations', 'groups', 'event_log_user_group_removals',
                               'event_log_user_data_deletions', 'event_log_data_access')
        group by table_name)a
    join
    (select relname, obj_description(oid) table_description
    from pg_class where relkind = 'r')b
    on a.table_name = b.relname;
alter view table_overview owner to admin_user;


drop function if exists group_add_members(text, json, json, boolean, boolean, boolean);
create or replace function group_add_members(group_name text,
                                             members json default null,
                                             metadata json default null,
                                             add_all boolean default null,
                                             add_all_owners boolean default null,
                                             add_all_users boolean default null)
    returns text as $$
    declare trusted_num_params int;
    declare untrusted_members json;
    declare untrusted_i text;
    declare trusted_user text;
    declare trusted_group text;
    declare untrusted_key text;
    declare untrusted_val text;
    declare trusted_user_name text;
    declare trusted_group_name text;
    begin
        trusted_group_name := quote_ident(group_name);
        assert trusted_group_name in (select udg.group_name from ntk.user_defined_groups udg),
                'access to group not allowed';
        assert (select count(1) from unnest(array[members::text,
                                                  metadata::text,
                                                  add_all::text,
                                                  add_all_owners::text,
                                                  add_all_users::text]) x where x is not null) = 1,
            'only one parameter is allowed to be used in the function signature - you can only add group members by one method per call';
        if members is not null then
            untrusted_members := members;
            for untrusted_i in select * from json_array_elements(untrusted_members->'memberships') loop
                execute format('grant %I to %s', trusted_group_name, untrusted_i);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            return 'added members to groups';
        elsif metadata is not null then
            untrusted_key := quote_literal(metadata->>'key');
            untrusted_val := metadata->>'value';
            for trusted_user_name in execute format('select user_name from user_registrations where user_metadata->>%s = $1', untrusted_key)
                using untrusted_val loop
                execute format('grant %I to %I', trusted_group_name, trusted_user_name);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all = true then
            for trusted_user_name in select user_name from user_registrations loop
                execute format('grant %I to %I', trusted_group_name, trusted_user_name);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
                raise notice 'added %', trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all_owners = true then
            for trusted_user_name in select user_name from user_registrations
                                     where user_type = 'data_owner' loop
                execute format('grant %I to %I', trusted_group_name, trusted_user_name);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
                raise notice 'added %', trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all_users = true then
            for trusted_user_name in select user_name from user_registrations
                                     where user_type = 'data_user' loop
                execute format('grant %I to %I', trusted_group_name, trusted_user_name);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
                raise notice 'added %', trusted_user_name;
            end loop;
            return 'added members to groups';
        else
            return 'members NOT added to groups';
        end if;
    end;
$$ language plpgsql;
revoke all privileges on function group_add_members(json, json, boolean) from public;
grant execute on function group_add_members(json, json, boolean) to admin_user;


drop function if exists group_list_members(text);
create or replace function group_list_members(group_name text)
    returns table (member text) as $$
    begin
        return query execute format('select u.member::text from ntk.user_defined_groups_memberships u
                     where u.group_name = $1') using group_name;
    end;
$$ language plpgsql;
revoke all privileges on function group_list_members(text) from public;
grant execute on function group_list_members(text) to admin_user;


drop function if exists user_groups(text);
create or replace function user_groups(user_name text default current_user::text)
    returns table (group_name text, group_metadata json) as $$
    begin
        assert user_name in (select _user_name from ntk.registered_users), 'access to role not allowed';
        return query execute format('select a.group_name, b.group_metadata from
                                        (select _group::text group_name from ntk.group_memberships where _role = $1)a
                                         join
                                        (select udg.group_name, udg.group_metadata from ntk.user_defined_groups udg)b
                                    on a.group_name = b.group_name') using user_name;
    end;
$$ language plpgsql;
revoke all privileges on function user_groups(text) from public;
alter function user_groups owner to admin_user;


drop function if exists user_group_remove(text);
create or replace function user_group_remove(group_name text)
    returns text as $$
    declare trusted_current_role text;
    declare trusted_group text;
    begin
        assert current_user::text in (select _user_name from ntk.registered_users),
            'access to role not allowed';
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        trusted_current_role := current_user::text;
        trusted_group := quote_ident(group_name);
        set role authenticator;
        set role admin_user;
        execute format('revoke %I from %I', trusted_group, trusted_current_role);
        execute format('insert into ntk.user_initiated_group_removals (user_name, group_name) values ($1, $2)')
                using trusted_current_role, group_name;
        set role authenticator;
        return 'removed user from group';
    end;
$$ language plpgsql;
revoke all privileges on function user_group_remove(text) from public;
alter function user_group_remove owner to admin_user;


drop function if exists group_remove_members(text, json, json, boolean);
create or replace function group_remove_members(group_name text,
                                                members json default null,
                                                metadata json default null,
                                                remove_all boolean default null)
    returns text as $$
    declare untrusted_members json;
    declare untrusted_i text;
    declare trusted_user text;
    declare trusted_group_name text;
    declare untrusted_key text;
    declare untrusted_val text;
    begin
        trusted_group_name := quote_ident(group_name);
        assert trusted_group_name in (select udg.group_name from ntk.user_defined_groups udg),
                'access to group not allowed';
        assert (select count(1) from unnest(array[members::text, metadata::text, remove_all::text]) x where x is not null) = 1,
            'only one parameter is allowed to be used in the function signature - you can only remove group members by one method per call';
        if members is not null then
            untrusted_members := members;
            for untrusted_i in select * from json_array_elements(untrusted_members->'memberships') loop
                execute format('revoke %I from %s', trusted_group_name, untrusted_i);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            return 'removed members to groups';
        elsif metadata is not null then
            untrusted_key := quote_literal(metadata->>'key');
            untrusted_val := metadata->>'value';
            for trusted_user in execute format('select user_name from user_registrations where user_metadata->>%s = $1', untrusted_key)
                using untrusted_val loop
                execute format('revoke %I from %s', trusted_group_name, trusted_user);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, trusted_user;
            end loop;
            return 'removed members to groups';
        elsif remove_all = true then
            for trusted_user in execute format('select _role from ntk.group_memberships where _group = $1')
                using trusted_group_name loop
                execute format('revoke %I from %I', trusted_group_name, trusted_user);
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, trusted_user;
            end loop;
            return 'removed members to groups';
        end if;
    end;
$$ language plpgsql;
revoke all privileges on function group_remove_members(json, json, boolean) from public;
grant execute on function group_remove_members(json, json, boolean) to admin_user;


drop table if exists ntk.user_data_deletion_requests cascade;
create table if not exists ntk.user_data_deletion_requests(
    user_name text not null,
    request_date timestamptz not null
);
alter table ntk.user_data_deletion_requests owner to admin_user;
grant insert on ntk.user_data_deletion_requests to public;
create or replace view event_log_user_data_deletions as
    select * from ntk.user_data_deletion_requests;
alter view event_log_user_data_deletions owner to admin_user;


drop function if exists user_delete_data();
create or replace function user_delete_data()
    returns text as $$
    declare trusted_table text;
    begin
        for trusted_table in select table_name from information_schema.tables
                      where table_schema = 'public' and table_type != 'VIEW' loop
            if trusted_table = 'event_log_data_access' then continue; end if;
            begin
                execute format('delete from %I', trusted_table);
            exception
                when insufficient_privilege
                then raise notice 'cannot delete data from %, permission denied', trusted_table;
            end;
        end loop;
        insert into ntk.user_data_deletion_requests (user_name, request_date)
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
    declare trusted_user_type text;
    declare trusted_numrows int;
    declare trusted_group text;
    begin
        assert user_name in (select _user_name from ntk.registered_users), 'deleting role not allowed';
        trusted_user_name := quote_ident(user_name);
        execute format('select _user_type from ntk.registered_users where _user_name = $1')
                    using user_name into trusted_user_type;
        if trusted_user_type = 'data_owner' then
            -- data users never have data, so we do not need this check for them
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
        end if;
        for trusted_group in select _group from ntk.group_memberships where _role = user_name loop
            -- this removes data_owners from the data_owners_group
            execute format('revoke %I from %I',  trusted_group, trusted_user_name);
        end loop;
        for trusted_table in select table_name from information_schema.role_table_grants
                              where grantee = quote_literal(user_name) loop
            begin
                execute format('revoke all privileges on %I from %I', trusted_table, user_name);
            end;
        end loop;
        set role authenticator;
        set role admin_user;
        execute format('revoke all privileges on ntk.group_memberships from %I', trusted_user_name);
        execute format('revoke execute on function ntk.update_request_log(text, text) from %I', trusted_user_name);
        execute format('revoke execute on function ntk.roles_have_common_group_and_is_data_user(text, text) from %I', trusted_user_name);
        execute format('revoke execute on function user_groups(text) from %I', trusted_user_name);
        execute format('revoke execute on function user_group_remove(text) from %I', trusted_user_name);
        execute format('delete from ntk.registered_users where _user_name = $1') using user_name;
        execute format('delete from ntk.data_owners where user_name = $1') using user_name;
        execute format('drop role %I', trusted_user_name);
        return 'user deleted';
    end;
$$ language plpgsql;
revoke all privileges on function user_delete(text) from public;
grant execute on function user_delete(text) to admin_user;


drop function if exists group_delete(text);
create or replace function group_delete(group_name text)
    returns text as $$
    declare trusted_group_name text;
    declare trusted_num_members int;
    declare trusted_num_table_select_grants int;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg), 'permission denied to delete group';
        trusted_group_name := quote_ident(group_name);
        execute format('select count(1) from ntk.user_defined_groups_memberships u where u.group_name = $1')
                using group_name into trusted_num_members;
        if trusted_num_members > 0 then
            raise exception 'Cannot delete group %, it has % members', group_name, trusted_num_members;
        end if;
        execute format('select count(1) from table_overview where groups_with_access @> array[$1]')
            using group_name into trusted_num_table_select_grants;
        if trusted_num_table_select_grants > 0 then
            raise exception 'Cannot delete group - still has select grants on existing tables: please check table_overview to see which tables and remove the grants';
        end if;
        execute format('drop role %I', trusted_group_name);
        execute format('delete from ntk.user_defined_groups where group_name = $1') using group_name;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'group_delete', trusted_group_name, null;
        return 'group deleted';
    end;
$$ language plpgsql;
revoke all privileges on function group_delete(text) from public;
grant execute on function group_delete(text) to admin_user;
