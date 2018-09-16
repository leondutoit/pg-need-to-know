
# Mandatory Access Control model

## Terminology

- Data owner:
- Data user:
- Administrator:
- Anonymous user:

## Motivation

The Mandatory Access Control model enforced by `pg-need-to-know` provides the ability to manage data access based on:

1. Data owners
2. Data subsets
3. Data owners and data subsets

In addition it provides:

- security by default: specifying access control rules are mandatory - there is no data access otherwise
- audit logs for admins and data owners (who, about whom, when)
- true data ownership (data owners can revoke access and delete their own data at any time)
- integration points for managing consent

The rest of this document explains the model, and it's functioning, by addressing three different access control use cases. These also cover most needs.

## Access based on data owners

## Access based on data subsets

## Access based on data owners and subsets

## Summary
