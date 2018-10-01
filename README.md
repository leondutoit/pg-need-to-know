# pg-need-to-know

Mandatory Access Control for PostgreSQL - designed to be used as a REST API in conjunction with [postgrest](http://postgrest.org/en/v5.1/).

## Design

`pg-need-to-know` divides the data collection and analysis life-cycle into actions performed by three different roles: `data owners`, `administrators`, and `data users`. Data owners are people who give their data to researchers, e.g. survey respondents. Administrators are people who are responsible for ethical usage of this data, and by implication responsible for managing access control, and audit logs. Data users are people who analyse the data - they typically only need read access to the original data.

`pg-need-to-know` provides Mandatory Access Control mechanisms to ensure that data owners always retain control over who has access to their data, and insight into who has made use of their data. In addition to forcing administrators to explicitly grant access to any data, `pg-need-to-know` provides tools to manage access control based on group membership and group-level table grants. Data users never have more access than that granted by an administrator.

## Features

- Tables, users, and groups can be created with user-defined metadata
- Administrators can set up access control for data analysis based on group membership, and explicit group-level table access grants (all access control management is logged)
- Only registered data owners can insert data (registation is needed to enforce ownership)
- Data owners are the only ones who can operate on their data by default (select, update, delete)
- Access can be granted to data users based on common group membership and group level table access grants
- Data users can be granted insert and update rights to tables; this allows data publication by setting ownership to the intended person
- Data owners can never see the data of other data owners
- Data owners can remove themselves from groups, revoking access to their data at any time - these removals are logged
- Data owners can delete all their data at any time - these deletions are logged
- All data access by data users is logged: which data user successfully requested data about which data owner, and when - data owners can request these logs about themselves, while administrators can see all data access logs

## Setup

```bash
./ntk.sh --guide
./ntk.sh --setup
./ntk.sh --sqltest
```

## Docs

To use `pg-need-to-know` read through `/docs`, and refer to `/api`.

## LICENSE

GPL.
