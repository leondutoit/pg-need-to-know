# pg-need-to-know

Mandatory Access Control for PostgreSQL - designed to be used as a REST API in conjunction with [postgrest](http://postgrest.org/en/v5.1/).

## Motivation

File systems provide simple mechanisms for managing access control using rights, users and groups which can be applied to files and folders. These simple tools can be used to cover many important access control needs.

Relational databases, also have the necessary functionality for implementing access control, at a coarse and fine-grained level, but often lack high-level interfaces to these tools.

`pg-need-to-know` provides such high level interfaces in the form of users, groups, and table grants. This allows data administrators to implement and manage their access control requirements with ease. Application developers have a rich API at their disposal to create use-case specific apps, while delegating all access control decisions to `pg-need-to-know`.

Lastly, `pg-need-to-know` differs from most file systems in making access control policies mandatory - without them, there is no access.

## Features

For administrators:
- manage access control for data analysis based on group membership, and table access grants (select, insert, update)
- security and integrity by default: without explicit policies, only data owners can see or operate on their data
- extensive audit logging: data access, data updates and deletions, access control changes

For data owners:
- true data ownership: retain the right to revoke access and delete their data
- transparent insight into how their data is being used

For data users:
- extensible metadata support for describing users, groups, tables, and columns
- possibility to publish data, and make it available to specific individuals only

For application developers:
- rich HTTP and SQL API for application development
- authorization is a solved problem
- a [reference client](https://github.com/leondutoit/py-need-to-know) to see how the API can be used

## Setup

```bash
./ntk.sh --guide
./ntk.sh --setup
./ntk.sh --test
```

## Docs

To use `pg-need-to-know` read through `/docs`, and refer to `/api`.

## LICENSE

GPL.
