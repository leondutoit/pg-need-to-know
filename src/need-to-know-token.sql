
-- as the superuser
create extension pgcrypto;
create schema if not exists jwt;
grant usage on schema jwt to anon;

/*

The following code is from: https://github.com/michelp/pgjwt/blob/master/pgjwt--0.0.1.sql
which has the MIT license: https://github.com/michelp/pgjwt/blob/master/LICENSE
It is included here with slight modifications, placing functions
in different schemas, and lower-casing all SQL - since colour in editors
is a thing now. It is used to generate JWT.

*/

create or replace function jwt.url_encode(data bytea)
    returns text language sql as $$
    select translate(encode(data, 'base64'), E'+/=\n', '-_');
$$;


create or replace function jwt.url_decode(data text) returns bytea language sql as $$
WITH t as (select translate(data, '-_', '+/') as trans),
     rem as (select length(t.trans) % 4 as remainder from t) -- compute padding size
    select decode(
        t.trans ||
        case when rem.remainder > 0
           then repeat('=', (4 - rem.remainder))
           else '' end,
    'base64') from t, rem;
$$;


create or replace function jwt.algorithm_sign(signables text, secret text, algorithm text)
returns text language sql as $$
WITH
  alg as (
    select case
      when algorithm = 'HS256' then 'sha256'
      when algorithm = 'HS384' then 'sha384'
      when algorithm = 'HS512' then 'sha512'
      else '' end as id)  -- hmac throws error
select jwt.url_encode(hmac(signables, secret, alg.id)) from alg;
$$;


create or replace function jwt.sign(payload json, secret text, algorithm text default 'HS256')
returns text language sql as $$
with
  header as (
    select jwt.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) as data
    ),
  payload as (
    select jwt.url_encode(convert_to(payload::text, 'utf8')) as data
    ),
  signables as (
    select header.data || '.' || payload.data as data from header, payload
    )
select
    signables.data || '.' ||
    jwt.algorithm_sign(signables.data, secret, algorithm) from signables;
$$;


create or replace function jwt.verify(token text, secret text, algorithm text default 'HS256')
returns table(header json, payload json, valid boolean) language sql as $$
  select
    convert_from(jwt.url_decode(r[1]), 'utf8')::json as header,
    convert_from(jwt.url_decode(r[2]), 'utf8')::json as payload,
    r[3] = jwt.algorithm_sign(r[1] || '.' || r[2], secret, algorithm) as valid
  from regexp_split_to_array(token, '\.') r;
$$;

/* ------------------------------------------------------------------------- */

-- Now follows the /rpc/token endpoint for pg-need-to-know
-- using the temaple: http://postgrest.org/en/v5.1/auth.html#jwt-from-sql

create table if not exists jwt.secret_store(secret text);
grant select on jwt.secret_store to anon;


drop function if exists token(text, text);
create or replace function token(id text default null, token_type text default null)
    returns json as $$
    declare _secret text;
    declare _token text;
    declare _role text;
    declare _exp int;
    declare _claims text;
    declare _user_name text;
    declare _exists_count int;
    declare _out json;
    begin
        assert token_type in ('owner', 'user', 'admin'),
            'token type not recognised';
        if token_type = 'admin' then
            _role := 'admin_user';
        elsif token_type in ('owner', 'user') then
            if token_type = 'owner' then
                _user_name := 'owner_' || id;
            elsif token_type = 'user' then
                _user_name := 'user_' || id;
            end if;
            set role authenticator;
            set role admin_user;
            execute format('select count(1) from user_registrations
                            where user_name = $1') using _user_name
                    into _exists_count;
            set role authenticator;
            set role anon;
            assert (_exists_count = 1), 'user not registered';
            if token_type = 'owner' then
                _role := 'data_owner';
            elsif token_type = 'user' then
                _role := 'data_user';
            end if;
        end if;
        select extract(epoch from now())::integer + 1800 into _exp;
        select secret from jwt.secret_store into _secret;
        -- add id to token as user claim
        select '{"exp": ' || _exp || ', "role": "' || _role || '", "user": "'|| _user_name ||'"}' into _claims;
        select jwt.sign(_claims::json, _secret) into _token;
        select '{"token": "'|| _token || '"}' into _out;
        return _out;
    end;
$$ language plpgsql;
grant execute on function token(text, text) to anon;
