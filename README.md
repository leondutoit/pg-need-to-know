# pg-need-to-know

A Mandatory Access Control setup for PostgreSQL which takes data ownership seriously, and allows data owners to make their data available to data users on a need to know basis.


## Features

- Any registered data owner can insert data (registation is needed to enforce ownership)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Read-only access can be granted to data users based on common group membership (data owner can never see the data of other data owners)
- All data access by data users is logged: which data owner successfully requested data about which data owner, when
- Data owners can delete all their data at any time


## Creating the DB schema

```bash
# run this as the DB superuser
psql -d yourdb -1 -f need-to-know.sql

# run sql tests
psql -d yourdb -1 -f testing.sql
```

## Usage

There are two ways to use pg-need-to-know: 1) as an HTTP API via `postgrest`, or 2) as an API to your DB, used from you own CRUD app.

Opting for #1 has the advantage that you do not need to write your own CRUD app, worry about JSON marshalling, request and response handling, SQL generation, query capabilities, or performance. It does, however, mean that you are tied to the design choices made by `postgrest`.

If that is too restrictive, then maybe it is better to write your own REST api, which consumes the SQL API directly. This still has the benefit of letting pg-need-to-know take care of all authorization, access control and SQL safety for you. The only constraint is that you must connect to the DB as the `authenticator` role, and execute your SQL as the role specified in the JWT.


## Create a REST API using postgrest

- Download and install [postgrest](http://postgrest.org/)
- Create a [config file](http://postgrest.org/en/v5.0/install.html#configuration)
- Run `postgrest your-config-file`
- Using this API pre-supposes that you have an Identity Provider and an Authentication Server which can issue JSON Web Tokens (read more about the requirements for this in the description of the MAC model)


## LICENSE

GPL.
