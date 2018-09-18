# pg-need-to-know

Mandatory Access Control for PostgreSQL - designed to be used as a REST API.


## Features

- Administrators can set up access control for data analysis based on group membership, and explicit group-level table access grants
- Only registered data owners can insert data (registation is needed to enforce ownership)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Read-only access can be granted to data users based on common group membership and group level table access grants
- Data owners can never see the data of other data owners
- Data owners can remove themselves from groups, revoking access to their data at any time
- Data owners can delete all their data at any time
- All data access by data users is logged: which data user successfully requested data about which data owner, and when - data owners can request these logs about themselves, while administrators can see all data access logs

## Creating the DB schema

```bash
# run this as the DB superuser
psql -d yourdb -1 -f need-to-know.sql

# run sql tests
psql -d yourdb -1 -f testing.sql
```

## Usage

There are two ways to use `pg-need-to-know`:

1) as an HTTP API via `postgrest` (for which it was designed)
2) as an API to your DB, used from your own app

Opting for #1 have the advantages that you do not need to write your own REST API, worry about JSON marshalling, request and response handling, SQL generation, query capabilities, or performance. It does, however, mean that you are tied to the design choices made by `postgrest`.

If that is too restrictive, then maybe it is better to write your own REST api, which consumes the SQL API directly. This still has the benefit of letting `pg-need-to-know` take care of all authorization, access control and SQL safety. Doing this requires that your app adopts a similar connection and SQL execution strategy than `postgrest`.


## Create a REST API using postgrest

- Download and install [postgrest](http://postgrest.org/)
- Create a [config file](http://postgrest.org/en/v5.0/install.html#configuration)
- Run `postgrest your-config-file`
- Using this API pre-supposes that you have an Identity Provider and an Authentication Server which can issue JSON Web Tokens according to the specifications of `pg-need-to-know` (read more about these in `auth-requirements.md`)


## LICENSE

GPL.
