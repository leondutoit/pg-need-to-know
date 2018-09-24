
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
