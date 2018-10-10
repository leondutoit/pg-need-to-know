
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

\set db_owner `echo "$DBOWNER"`

create role authenticator noinherit login password 'replaceme';
grant authenticator to :db_owner;
create role admin_user createrole;
grant admin_user to authenticator;
create role anon;
grant anon to authenticator;
create role data_owners_group;
create role data_owner;
grant data_owners_group to data_owner;
grant data_owner to authenticator;
create role data_users_group;
create role data_user;
grant data_users_group to data_user;
grant data_user to authenticator;


create schema if not exists ntk;
grant usage on schema ntk to public;
grant create on schema ntk to admin_user; -- so execute can be granted/revoked when users are created/deleted


drop function if exists ntk.is_row_owner(text) cascade;
create or replace function ntk.is_row_owner(_current_row_owner text)
    returns boolean as $$
    declare trusted_current_role text;
    declare trusted_current_row_owner text;
    begin
        trusted_current_role := current_setting('request.jwt.claim.user');
        trusted_current_row_owner := _current_row_owner;
        if trusted_current_role = trusted_current_row_owner then
            return true;
        else
            return false;
        end if;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.is_row_owner(text) from public;
alter function ntk.is_row_owner owner to admin_user;
grant execute on function ntk.is_row_owner(text) to data_owners_group, data_users_group;


drop function if exists ntk.is_row_originator(text) cascade;
create or replace function ntk.is_row_originator(_current_row_originator text)
    returns boolean as $$
    declare trusted_current_role text;
    declare trusted_current_row_originator text;
    begin
        trusted_current_role := current_setting('request.jwt.claim.user');
        trusted_current_row_originator := _current_row_originator;
        if trusted_current_role = trusted_current_row_owner then
            return true;
        else
            return false;
        end if;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.is_row_originator(text) from public;
alter function ntk.is_row_originator owner to admin_user;
grant execute on function ntk.is_row_originator(text) to data_owners_group, data_users_group;


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
grant delete on event_log_data_access to :db_owner;
create policy select_for_data_owners on event_log_data_access for select using (ntk.is_row_owner(data_owner));
create policy insert_policy_for_public on event_log_data_access for insert with check (true);


drop function if exists ntk.update_request_log(text, text) cascade;
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
grant execute on function ntk.update_request_log(text, text) to data_owners_group, data_users_group;


drop table if exists event_log_access_control cascade;
create table if not exists event_log_access_control(
    id serial,
    event_time timestamptz default current_timestamp,
    event_type text not null check
        (event_type in ('group_create', 'group_delete',
                        'group_member_add', 'group_member_remove',
                        'table_grant_add_select', 'table_grant_add_insert',
                        'table_grant_add_update', 'table_grant_revoke_select',
                        'table_grant_revoke_insert', 'table_grant_revoke_update')),
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


drop function if exists ntk.roles_have_common_group_and_is_data_user(text) cascade;
create or replace function ntk.roles_have_common_group_and_is_data_user(_current_row_owner text)
    returns boolean as $$
    declare trusted_current_role text;
    declare trusted_current_row_owner text;
    declare _type text;
    declare _log boolean;
    declare _res boolean;
    begin
        trusted_current_role := current_setting('request.jwt.claim.user');
        trusted_current_row_owner := _current_row_owner;
        execute format('select _user_type from ntk.registered_users where _user_name = $1')
            into _type using trusted_current_role;
        if _type != 'data_user'
            then return false;
        end if;
        execute format('select groups.have_common_group($1, $2)')
            into _res
            using trusted_current_role, trusted_current_row_owner;
        if _res = true then
            select ntk.update_request_log(trusted_current_role, trusted_current_row_owner) into _log;
        end if;
        return _res;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.roles_have_common_group_and_is_data_user(text) from public;
alter function ntk.roles_have_common_group_and_is_data_user owner to admin_user;
grant execute on function ntk.roles_have_common_group_and_is_data_user(text) to data_owners_group, data_users_group;


drop table if exists event_log_data_updates;
create table if not exists event_log_data_updates(
    updated_time timestamptz default current_timestamp,
    updated_by text,
    table_name text,
    row_id int,
    column_name text,
    old_data text,
    new_data text,
    query text
);
alter table event_log_data_updates owner to admin_user;
grant insert on event_log_data_updates to data_owners_group, data_users_group;


drop function if exists ntk.log_data_update() cascade;
create or replace function ntk.log_data_update()
    returns trigger as $$
    declare _old_data text;
    declare _new_data text;
    declare _colname text;
    declare _table_name text;
    declare _updator text;
    declare _row_id int;
    begin
        _table_name := TG_TABLE_NAME::text;
        _updator := current_setting('request.jwt.claim.user');
        for _colname in execute
            format('select c.column_name::text
                    from pg_catalog.pg_statio_all_tables as st
                    inner join information_schema.columns c
                    on c.table_schema = st.schemaname and c.table_name = st.relname
                    left join pg_catalog.pg_description pgd
                    on pgd.objoid=st.relid
                    and pgd.objsubid=c.ordinal_position
                    where st.relname = $1') using _table_name
        loop
            execute format('select ($1).%s::text', _colname) using OLD into _old_data;
            execute format('select ($1).%s::text', _colname) using NEW into _new_data;
            if _old_data != _new_data then
                insert into event_log_data_updates
                    (updated_by, table_name, row_id, column_name, old_data, new_data, query)
                values
                    (_updator, _table_name, OLD.row_id, _colname, _old_data, _new_data, current_query());
            end if;
        end loop;
        return new;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.log_data_update() from public;
grant execute on function ntk.log_data_update() to admin_user, data_owners_group, data_users_group;


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
    declare _curr_setting text;
    declare _seqname text;
    begin
        untrusted_definition := definition;
        untrusted_columns := untrusted_definition->'columns';
        trusted_table_name := quote_ident(untrusted_definition->>'table_name');
        trusted_comment := quote_nullable(untrusted_definition->>'description');
        _curr_setting := 'request.jwt.claim.user';
        _seqname := trusted_table_name || '_id_seq';
        begin
            execute format('create sequence %I', _seqname);
            execute format('grant usage, select, update on %I to public', _seqname);
        exception
            when duplicate_table then null;
        end;
        execute 'create table if not exists ' || trusted_table_name ||
                '(row_id int not null default nextval(' || quote_literal(_seqname) || '))';
        execute format('alter sequence %I owned by %I.row_id', _seqname, trusted_table_name);
        begin
            execute 'alter table ' || trusted_table_name ||
                    ' add column row_owner text not null default current_setting(' || quote_literal(_curr_setting) ||
                    ') references ntk.registered_users (_user_name)';
            execute 'alter table ' || trusted_table_name ||
                    ' add column row_originator text not null default current_setting(' || quote_literal(_curr_setting) ||
                    ') references ntk.registered_users (_user_name)';
        exception
            when duplicate_column then null;
        end;
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
                when duplicate_column then null;
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
        execute format('grant select, insert, update, delete on %I to data_owners_group', trusted_table_name);
        begin
            execute format('create policy row_ownership_insert_policy on %I for insert with check (true)', trusted_table_name);
            execute format('create policy row_ownership_select_policy on %I for select using (ntk.is_row_owner(row_owner))', trusted_table_name);
            execute format('create policy row_ownership_delete_policy on %I for delete using (ntk.is_row_owner(row_owner))', trusted_table_name);
            execute format('create policy row_ownership_select_group_policy on %I for select using (ntk.roles_have_common_group_and_is_data_user(row_owner))', trusted_table_name);
            execute format('create policy row_ownership_update_policy on %I for update using (ntk.is_row_owner(row_owner))', trusted_table_name);
            execute format('create policy row_originator_update_policy on %I for update using (ntk.is_row_originator(row_originator))', trusted_table_name);
            execute format('comment on table %I is %s', trusted_table_name, trusted_comment);
            execute format('create trigger update_trigger after update on %I for each row execute procedure ntk.log_data_update()', trusted_table_name);
        exception
            when duplicate_object then null;
        end;
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


drop function if exists table_group_access_grant(text, text, text);
create or replace function table_group_access_grant(table_name text,
                                                    group_name text,
                                                    grant_type text)
    returns text as $$
    declare trusted_table_name text;
    declare trusted_group_name text;
    declare grant_event text;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        assert (select ntk.is_user_defined_table(table_name) = true);
        assert grant_type in ('select', 'insert', 'update'),
            'unrecognised grant type - choose one: select, insert, update';
        trusted_table_name := quote_ident(table_name);
        trusted_group_name := quote_ident(group_name);
        if grant_type = 'select' then
            execute format('grant select on %I to %I', trusted_table_name, trusted_group_name);
            grant_event := 'table_grant_add_select';
        elsif grant_type = 'insert' then
            execute format('grant insert on %I to %I', trusted_table_name, trusted_group_name);
            grant_event := 'table_grant_add_insert';
        elsif grant_type = 'update' then
            execute format('grant select, update on %I to %I', trusted_table_name, trusted_group_name);
            grant_event := 'table_grant_add_update';
        end if;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using grant_event, trusted_group_name, trusted_table_name;
        return 'granted access to table';
    end;
$$ language plpgsql;
revoke all privileges on function table_group_access_grant(text, text) from public;
grant execute on function table_group_access_grant(text, text) to admin_user;


drop function if exists ntk.table_grant_status(text, text, text, text);
create or replace function ntk.table_grant_status(table_name text,
                                                  group_name text,
                                                  grant_event_name text,
                                                  revoke_event_name text)
    returns text as $$
    declare latest_event text;
    begin
        execute format('select event_type from
            (select id, event_type
                from event_log_access_control
                where group_name = $1
                and event_type in ($2,$3)
                and target = $4
                order by id desc
                limit 1)a')
            using group_name, grant_event_name, revoke_event_name, table_name
            into latest_event;
        return latest_event;
    end;
$$ language plpgsql;
revoke all privileges on function ntk.table_grant_status(text, text, text, text) from public;
grant execute on function ntk.table_grant_status(text, text, text, text) to admin_user;


drop function if exists table_group_access_revoke(text, text, text);
create or replace function table_group_access_revoke(table_name text,
                                                     group_name text,
                                                     grant_type text)
    returns text as $$
    declare trusted_table_name text;
    declare trusted_group_name text;
    declare revoke_event text;
    declare latest_event text;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        assert (select ntk.is_user_defined_table(table_name) = true);
        assert grant_type in ('select', 'insert', 'update'),
            'unrecognised grant type - choose one: select, insert, update';
        trusted_table_name := quote_ident(table_name);
        trusted_group_name := quote_ident(group_name);
        if grant_type = 'select' then
            execute format('revoke select on %I from %I', trusted_table_name, trusted_group_name);
            revoke_event := 'table_grant_revoke_select';
        elsif grant_type = 'insert' then
            execute format('revoke insert on %I from %I', trusted_table_name, trusted_group_name);
            revoke_event := 'table_grant_revoke_insert';
        elsif grant_type = 'update' then
            select ntk.table_grant_status(table_name, group_name, 'table_grant_add_select', 'table_grant_revoke_select')
                into latest_event;
            if latest_event = 'table_grant_revoke_select' then
                -- then there is not an existing select grant from a separate grant
                execute format('revoke select, update on %I from %I', trusted_table_name, trusted_group_name);
            else
                execute format('revoke update on %I from %I', trusted_table_name, trusted_group_name);
            end if;
            revoke_event := 'table_grant_revoke_update';
        end if;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using revoke_event, trusted_group_name, trusted_table_name;
        return 'revoked access to table';
    end;
$$ language plpgsql;
revoke all privileges on function table_group_access_revoke(text, text) from public;
grant execute on function table_group_access_revoke(text, text) to admin_user;


drop table if exists ntk.registered_users cascade;
create table if not exists ntk.registered_users(
    registration_date timestamptz default current_timestamp,
    user_id text not null,
    _user_name text not null unique,
    _user_type text not null check (_user_type in ('data_owner', 'data_user')),
    user_metadata json
);
alter table ntk.registered_users owner to admin_user;
grant select on ntk.registered_users to public;
create or replace view user_registrations as
    select registration_date, user_id, _user_name as user_name,
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
        if user_type = 'data_owner' then
            trusted_user_name := 'owner_' || user_id;
        elsif user_type = 'data_user' then
            trusted_user_name := 'user_' || user_id;
        end if;
        set role admin_user;
        select ntk.user_create(user_id, trusted_user_name, user_type, user_metadata) into _ans;
        set role authenticator;
        set role anon;
        return 'user created';
    end;
$$ language plpgsql;
revoke all privileges on function user_register(text, text, json) from public;
grant execute on function user_register(text, text, json) to anon;


drop function if exists ntk.user_create(text, text, text, json);
create or replace function ntk.user_create(user_id text, user_name text, user_type text, user_metadata json)
    returns text as $$
    declare trusted_user_name text;
    declare trusted_user_type text;
    begin
        assert (select bool_or(user_type like arr_element||'%')
                from unnest(ARRAY['data_owner','data_user']) x(arr_element)),
            'user_type must be one of "data_owner" or "data_user"';
        trusted_user_name := quote_ident(user_name);
        trusted_user_type := quote_literal(user_type);
        execute format('insert into ntk.registered_users (user_id, _user_name, _user_type, user_metadata) values ($1, $2, $3, $4)')
            using user_id, user_name, user_type, user_metadata;
        if user_type = 'data_owner' then
            execute format('insert into ntk.data_owners values ($1)') using user_name;
        end if;
        return 'user created';
    end;
$$ language plpgsql;
revoke all privileges on function ntk.user_create(text, text, text, json) from public;
grant execute on function ntk.user_create(text, text, text, json) to admin_user;


drop table if exists ntk.user_defined_groups cascade;
create table if not exists ntk.user_defined_groups (
    group_name text unique,
    group_metadata json not null
);
alter table ntk.user_defined_groups owner to admin_user;
grant select on ntk.user_defined_groups to public;
create view groups as select * from ntk.user_defined_groups;
alter view groups owner to admin_user;
grant select on groups to data_owners_group;


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
    declare _res boolean;
    begin
        trusted_group_name := quote_ident(group_name);
        execute format('select groups.create($1)') using trusted_group_name into _res;
        execute format('grant %I to data_user', trusted_group_name);
        execute format('insert into ntk.user_defined_groups values ($1, $2)')
            using group_name, group_metadata;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'group_create', trusted_group_name, null;
        return 'group created';
    end;
$$ language plpgsql;
revoke all privileges on function group_create(text, json) from public;
grant execute on function group_create(text, json) to admin_user;


create or replace view table_overview as
    select a.table_name, b.table_description, a.groups_with_access from
    (select table_name, array_agg(distinct grantee::text) groups_with_access
    from information_schema.table_privileges
        where privilege_type in ('SELECT', 'INSERT', 'UPDATE')
        and table_schema = 'public'
        and grantee not in ('PUBLIC')
        and grantee in (select group_name from ntk.user_defined_groups)
        or grantee = 'data_owners_group'
        and table_name not in ('user_registrations', 'groups', 'event_log_user_group_removals',
                               'event_log_user_data_deletions', 'event_log_data_access',
                               'event_log_data_updates')
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
    declare untrusted_owners json;
    declare untrusted_users json;
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
            untrusted_owners := members->'memberships'->'data_owners';
            untrusted_users := members->'memberships'->'data_users';
            for untrusted_i in select * from json_array_elements(untrusted_owners) loop
                trusted_user_name := 'owner_' || replace(untrusted_i, '"', '');
                execute format('select groups.grant($1, $2)')
                    using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            for untrusted_i in select * from json_array_elements(untrusted_users) loop
                trusted_user_name := 'user_' || replace(untrusted_i, '"', '');
                execute format('select groups.grant($1, $2)')
                    using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            return 'added members to groups';
        elsif metadata is not null then
            untrusted_key := quote_literal(metadata->>'key');
            untrusted_val := metadata->>'value';
            for trusted_user_name in execute
                format('select user_name from user_registrations where user_metadata->>%s = $1', untrusted_key)
                    using untrusted_val loop
                execute format('select groups.grant($1, $2)')
                    using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all = true then
            for trusted_user_name in select user_name from user_registrations loop
                execute format('select groups.grant($1, $2)') using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all_owners = true then
            for trusted_user_name in select user_name from user_registrations
                                     where user_type = 'data_owner' loop
                execute format('select groups.grant($1, $2)') using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
            end loop;
            return 'added members to groups';
        elsif add_all_users = true then
            for trusted_user_name in select user_name from user_registrations
                                     where user_type = 'data_user' loop
                execute format('select groups.grant($1, $2)') using trusted_group_name, trusted_user_name;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_add', trusted_group_name, trusted_user_name;
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
    returns table (user_id text) as $$
    begin
        return query execute
            format('select user_id from
                (select user_id, user_name from user_registrations)a
                join
                (select group_name, user_name from groups.group_memberships
                 where group_name = $1)b
                on a.user_name = b.user_name')
            using group_name;
    end;
$$ language plpgsql;
revoke all privileges on function group_list_members(text) from public;
grant execute on function group_list_members(text) to admin_user;


drop function if exists user_groups(text, text);
create or replace function user_groups(user_id text default null, user_type text default null)
    returns table (group_name text, group_metadata json) as $$
    declare user_name text;
    begin
        if user_id is null then
            user_name := current_setting('request.jwt.claim.user');
        elsif user_type = 'data_owner' then
            user_name := 'owner_' || user_id;
        elsif user_type = 'data_user' then
            user_name := 'user_' || user_id;
        end if;
        assert user_name in (select _user_name from ntk.registered_users),
            'access to role not allowed';
        return query execute format('select a.group_name as group_name, a.group_metadata as group_metadata
                                    from (select group_name, group_metadata from groups)a
                                    join
                                    (select distinct group_name from groups.group_memberships
                                     where user_name = $1)b
                                     on a.group_name = b.group_name') using user_name;
    end;
$$ language plpgsql;
revoke all privileges on function user_groups(text, text) from public;
alter function user_groups owner to admin_user;
grant execute on function user_groups(text, text) to data_owners_group;


drop function if exists user_group_remove(text);
create or replace function user_group_remove(group_name text)
    returns text as $$
    declare trusted_current_role text;
    declare trusted_group text;
    begin
        trusted_current_role := current_setting('request.jwt.claim.user');
        assert trusted_current_role in (select _user_name from ntk.registered_users),
            'access to role not allowed';
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'access to group not allowed';
        trusted_group := quote_ident(group_name);
        set role authenticator;
        set role admin_user;
        execute format('select groups.revoke($1, $2)') using trusted_group, trusted_current_role;
        execute format('insert into ntk.user_initiated_group_removals (user_name, group_name) values ($1, $2)')
                using trusted_current_role, group_name;
        set role authenticator;
        return 'removed user from group';
    end;
$$ language plpgsql;
revoke all privileges on function user_group_remove(text) from public;
alter function user_group_remove owner to admin_user;
grant execute on function user_group_remove(text) to data_owners_group;


drop function if exists group_remove_members(text, json, json, boolean);
create or replace function group_remove_members(group_name text,
                                                members json default null,
                                                metadata json default null,
                                                remove_all boolean default null)
    returns text as $$
    declare untrusted_owners json;
    declare untrusted_users json;
    declare untrusted_i text;
    declare trusted_user text;
    declare trusted_group_name text;
    declare untrusted_key text;
    declare untrusted_val text;
    begin
        trusted_group_name := quote_ident(group_name);
        assert trusted_group_name in (select udg.group_name from ntk.user_defined_groups udg),
                'access to group not allowed';
        assert (select count(1) from unnest(array[members::text,
                metadata::text, remove_all::text]) x where x is not null) = 1,
            'you can only remove group members by one method per call';
        if members is not null then
            untrusted_owners := members->'memberships'->'data_owners';
            untrusted_users := members->'memberships'->'data_users';
            for untrusted_i in select * from json_array_elements(untrusted_owners) loop
                trusted_user := 'owner_' || replace(untrusted_i, '"', '');
                execute format('select groups.revoke($1, $2)') using trusted_group_name, trusted_user;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            for untrusted_i in select * from json_array_elements(untrusted_users) loop
                trusted_user := 'user_' || replace(untrusted_i, '"', '');
                execute format('select groups.revoke($1, $2)') using trusted_group_name, trusted_user;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, replace(untrusted_i, '"', '');
            end loop;
            return 'removed members to groups';
        elsif metadata is not null then
            untrusted_key := quote_literal(metadata->>'key');
            untrusted_val := metadata->>'value';
            for trusted_user in execute
                format('select user_name from user_registrations where user_metadata->>%s = $1', untrusted_key)
                using untrusted_val loop
                execute format('select groups.revoke($1, $2)') using trusted_group_name, trusted_user;
                execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                    using 'group_member_remove', trusted_group_name, trusted_user;
            end loop;
            return 'removed members to groups';
        elsif remove_all = true then
            for trusted_user in execute format('select user_name from groups.group_memberships where group_name = $1')
                using trusted_group_name loop
                execute format('select groups.revoke($1, $2)') using trusted_group_name, trusted_user;
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
            if trusted_table in ('event_log_data_access', 'event_log_access_control')
                then continue;
            end if;
            begin
                execute format('delete from %I', trusted_table);
            exception
                when insufficient_privilege
                then raise notice 'cannot delete data from %, permission denied', trusted_table;
            end;
        end loop;
        insert into ntk.user_data_deletion_requests (user_name, request_date)
            values (current_setting('request.jwt.claim.user'), current_timestamp);
        return 'all data deleted';
    end;
$$ language plpgsql;
grant execute on function user_delete_data() to public;


drop function if exists user_delete(text, text);
create or replace function user_delete(user_id text, user_type text)
    returns text as $$
    declare user_name text;
    declare trusted_table text;
    declare trusted_user_name text;
    declare trusted_user_type text;
    declare trusted_numrows int;
    declare trusted_group text;
    begin
        if user_type = 'data_owner' then
            user_name := 'owner_' || user_id;
        elsif user_type = 'data_user' then
            user_name := 'user_' || user_id;
        end if;
        assert user_name in (select _user_name from ntk.registered_users),
            'deleting role not allowed';
        trusted_user_name := quote_ident(user_name);
        execute format('select _user_type from ntk.registered_users where _user_name = $1')
                    using user_name into trusted_user_type;
        if trusted_user_type = 'data_owner' then
            -- data users never have data, so we do not need this check for them
            execute 'set session "request.jwt.claim.user" =  ' || quote_literal(user_name);
            for trusted_table in select table_name from information_schema.tables
                                  where table_schema = 'public' and table_type != 'VIEW' loop
                begin
                    set role data_owner;
                    execute format('select count(1) from %I where row_owner = $1', trusted_table)
                            using user_name into trusted_numrows;
                    set role admin_user;
                    if trusted_numrows > 0 then
                        raise exception 'Cannot delete user, DB has data belonging to % in table %', user_name, trusted_table;
                    end if;
                exception
                    when undefined_column then null;
                end;
            end loop;
        end if;
        for trusted_group in execute
            format('select group_name from groups.group_memberships where user_name = $1')
            using user_name loop
            execute format('select groups.revoke($1, $2)') using trusted_group, trusted_user_name;
        end loop;
        -- this might not be necessary anymore - since the grants are now based on
        -- data_owners_group, and data_owner role, and since users do not exist as roles anymore
        for trusted_table in select table_name from information_schema.role_table_grants
                              where grantee = quote_literal(user_name) loop
            begin
                raise info 'revoking access for % on table %', user_name, trusted_table;
                execute format('revoke all privileges on %I from %I', trusted_table, user_name);
            end;
        end loop;
        set role authenticator;
        set role admin_user;
        execute format('delete from ntk.registered_users where _user_name = $1') using user_name;
        execute format('delete from ntk.data_owners where user_name = $1') using user_name;
        return 'user deleted';
    end;
$$ language plpgsql;
revoke all privileges on function user_delete(text, text) from public;
grant execute on function user_delete(text, text) to admin_user;


drop function if exists group_delete(text);
create or replace function group_delete(group_name text)
    returns text as $$
    declare trusted_group_name text;
    declare trusted_num_members int;
    declare trusted_num_table_select_grants int;
    declare _res boolean;
    begin
        assert group_name in (select udg.group_name from ntk.user_defined_groups udg),
            'permission denied to delete group';
        trusted_group_name := quote_ident(group_name);
        execute format('select count(1) from groups.group_memberships u where u.group_name = $1')
                using group_name into trusted_num_members;
        if trusted_num_members > 0 then
            raise exception 'Cannot delete group %, it has % members', group_name, trusted_num_members;
        end if;
        execute format('select count(1) from table_overview where groups_with_access @> array[$1]')
            using group_name into trusted_num_table_select_grants;
        if trusted_num_table_select_grants > 0 then
            raise exception 'Cannot delete group - still has select grants on existing tables: please check table_overview to see which tables and remove the grants';
        end if;
        execute format('select groups.drop($1)') using trusted_group_name into _res;
        execute format('delete from ntk.user_defined_groups where group_name = $1') using group_name;
        execute format('select ntk.update_event_log_access_control($1, $2, $3)')
                using 'group_delete', trusted_group_name, null;
        return 'group deleted';
    end;
$$ language plpgsql;
revoke all privileges on function group_delete(text) from public;
grant execute on function group_delete(text) to admin_user;
