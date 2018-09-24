
## Assumptions

- anyone can be a data owners
- only some can be data users
- only some can be admin users

Given these assumptions, `pg-need-to-know` does not provide any authentication mechanisms. It is up to applications to integrate with other identity providers and authentication servers to establish the authenticity of persons, and to determine whether the person is authorized to be a data user or a data owner. `pg-need-to-know` therefore assumes that identity management, and rights management associated with data users and admin users is handled by external systems. This also means that applications can perform authentication and authorization using any mechanism they want. `pg-need-to-know` does not force anything.

`pg-need-to-know` does, however, provide a token endpoint which issues JWT for the three role types: `data_owner`, `data_user`, and `admin_user`. The only checks that are performed when issuing tokens are whether the identities of the data owner and user for which tokens are being requested, exist. This is not for the purpose of authentication though, but merely to prevent subsequent requests from being made, because they will fail (owners and users must be registered first).

It is also possible for applications to implement token issuing themselves, instead of using `pg-need-to-know`'s endpoint.

## Tokens, roles and postgrest

