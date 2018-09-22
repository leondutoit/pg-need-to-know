
# Mandatory Access Control model

## Terminology

- Data owner: a person from whom data originates
- Data user: a person analysing the data
- Administrator: a person who manages access control, and is responsible for the ethical use of data
- Anonymous user: a person who is not yet identifiable by `pg-need-to-know`

## Motivation

The Mandatory Access Control model enforced by `pg-need-to-know` provides the ability to manage data access based on:

1. Data owners
2. Data subsets
3. Data owners and data subsets

In addition it provides:

- security by default: specifying access control rules are mandatory - there is no data access otherwise
- extensive event logging which can be used for audit and data management: data access, access control changes, user-initiated group revocations, user-initiated data deletions - all of this is logged and available to the administrator; data owners can see data access logs about themselves
- enforcement of true data ownership (data owners can revoke access and delete their own data at any time)
- integration points for external systems using extensible metadata

The rest of this document explains the model, and it's functioning, by addressing three different access control use cases. These also cover most needs.

## Access based on data owners

Assume the following setup:

```txt
data owners: A, B, C, D, E, F
tables: t1, t2, t3, each containing data from a different survey section
data users: W, X, Y, Z
```

Now further suppose an administrator wanted to set up the following access control rules:

```txt
data users X, and Y should only have access to data from owners A, B, C, D
data user Z should only have access to all data - from owners A, B, C, D, E, F
```

This is quite a common requirement: that a subset of analysts have access to a limited set of data, while a smaller group has access to everything. In this example, we suppose that access is based on the identity of the data owners. The owners E, and F might, for example, belong to an institution that did not consent to users X and Y analysing their data. How can the administrator use `pg-need-to-know` to solve this?

```txt
group1
    - members: (X, (Y, A, B, C, D))
    - table access grants: (t1, t2, t3)
group2
    - members: (t1, t2, t3)
    - table access grants: (Z, (A, B, C, D, E, F))
```

In words, the administrator would simply create two groups containing the data owners which should make their data usable to the respective data users. And since data belonging to everyone is contianed in all three tables, both groups would be granted access to all tables. `pg-need-to-know`'s security policies will ensure that data will be made available based on common group membership, regardless of which table it is stored in.


## Access based on data subsets

## Access based on data owners and subsets

## Granting all data users access to all data

## Summary
