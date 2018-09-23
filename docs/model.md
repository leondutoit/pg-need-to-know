
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
tables: t1, t2, t3, each containing data from all data owners
data users: X, Y, Z
```

Now further suppose an administrator wanted to set up the following access control rules:

```txt
data users X, and Y should only have access to data from owners A, B, C, D
data user Z should have access to all data - i.e. from owners A, B, C, D, E, F
```

This is quite a common requirement: that a subset of analysts have access to a limited set of data, while a smaller group has access to everything. In this example, we suppose that access is based on the identity of the data owners. The owners E, and F might, for example, belong to an institution that did not consent to users X and Y analysing their data. How can the administrator use `pg-need-to-know` to solve this?

```txt
group1
    - members: ((X, Y), (A, B, C, D))
    - table access grants: (t1, t2, t3)
group2
    - members: ((Z), (A, B, C, D, E, F))
    - table access grants: (t1, t2, t3)
```

In words, the administrator would simply create two groups containing the respective data owners and data users. Since data belonging to everyone is contianed in all three tables, both groups would be granted access to all tables. `pg-need-to-know`'s security policies will ensure that data will be made available based on common group membership, regardless of which table it is stored in. Common group membership will ensure that data users can see the data of their group's data owners, but data owners can only ever see their own data.

## Access based on data subsets

Assume a similar setup than before in terms of owers, data, and users:

```txt
data owners: A, B, C, D, E, F
tables: t1, t2, t3, each containing data from all data owners, but different categories
data users: X, Y, Z
```

Now further suppose an administrator wanted to set up the following access control rules, this time based on data subsets, rather then individual owners:

```txt
data users X, and Y should only have access to data contained in tables t1, and t2
data user Z should have access to all data - i.e. tables t1, t2, and t3
```

In contrast to the previous example, data might be categorised into different levels of sensitivity, and stored in different tables. In this case everyone needs access to data from all owners, just not all of their data. It is then firstly up to the administrator to ensure that data is collected and partitioned into different tables based on their categorisation. After that the following `pg-need-to-know` setup will ensure that the requirements are met:

```txt
group1
    - members: ((X, Y), (A, B, C, D, E, F))
    - table access grants: (t1, t2)
group2
    - members: ((Z), (A, B, C, D, E, F))
    - table access grants: (t1, t2, t3)
```

This time both groups contain all data owners. However, only `group2`, which contains data user `Z`, has been granted access to table `t3`.

## Access based on data owners and subsets

This is a combination of the previous two cases:

```txt
data owners: A, B, C, D, E, F
tables: t1, t2, t3, t4 each containing data from all data owners, with t4 containing data belonging to a different category
data users: X, Y, Z
```

Suppose the following access control rules needed to be in place:

```txt
data users X, and Y should only have access to data contained in tables t1, and t2
data user Z should have access to all data - i.e. tables t1, t2, t3, and t4
```

The following groups memberships and table grant will ensure the above access control rules are enforced:

```txt
group1
    - members: ((X, Y), (A, B, C, D))
    - table access grants: (t1, t2, t3)
group2
    - members: ((Z), (A, B, C, D, E, F))
    - table access grants: (t1, t2, t3, t4)
```

Notice that only data user `Z` has access to table `t4`.

## Granting all data users access to all data

This is mentioned for the sake of completion, but is should be obvious that this is accomplished by creating one group, with everyone as a member, and granting access to all tables.

## Summary

The data management and access control requirements placed on administrators by regulatory bodies are becoming increasingly complex and the consequences of not being compliant more severe. This puts pressure on researchers to work with data in a way that ensures only the necessary access is given, and that all access, and the management thereof, is logged for audit purposes. This is a difficult task, especially as it is often not primary to the scientific task.

`pg-need-to-know` gives administrators the tools they need to fulfill these requirements in an easy way. Application developers can interact with the API to create user-friendly interfaces, which also interoperate easily with other data management and storage systems.
