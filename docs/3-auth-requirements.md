
## Assumptions

- anyone can be a data owners
- only some can be data users
- only some can be admin users

Given these assumptions, `pg-need-to-know` does not provide any authentication mechanisms. It is up to applications to integrate with other identity providers and authentication servers to establish the authenticity of persons, and to determine whether the person is authorized to be a data user or a data owner. `pg-need-to-know` therefore assumes that identity management, and rights management associated with data users and admin users is handled by external systems. This also means that applications can perform authentication and authorization using any mechanism they want. `pg-need-to-know` does not force anything.

`pg-need-to-know` does, however, provide a token endpoint which issues JWT for the three role types: `data_owner`, `data_user`, and `admin_user`. The only checks that are performed when issuing tokens are whether the identities of the data owner and user for which tokens are being requested, exist. This is not for the purpose of authentication though, but merely to prevent subsequent requests from being made, because they will fail (owners and users must be registered first).

It is also possible for applications to implement token issuing themselves, instead of using `pg-need-to-know`'s endpoint.

## Tokens, roles and postgrest

`pg-need-to-know` was designed to be used with `postgrest` - an application server which creates a REST API from a PostgreSQL database. `postgrest` uses JWT to integrate with authentication systems. The following claims _must_ be present in the JWT:

```json
{
    "role": "some_role",
    "exp": 210849818
}
```

The `exp` field is the time when the token should expire. In practice, tokens should be short-lived. `pg-need-to-know` issues tokens which are valid for 30 minutes.

The `role` claim plays a very specific role in `postgrest`: before the SQL query implied by the HTTP request is executed, `postgrest` switches into the role provided in the claim. In `pg-need-to-know`, `postgrest` is intended to connect to the DB with a role called the `authenticator`. This is a special role which has not other rights in the DB, other than the ability to connect to it, and to switch to other roles. By switching to the role provided in the JWT claim before executing the SQL query implied by the HTTP request, postgrest ensures that the DB system enforces security policies associated with that role.

## Integration

The process can be represented as follows:

```txt
# 1. Generic user authentication
User (credentials) -> app -> IdP + Auth Server
                          <- ID
                      app -> POST /rpc/token {ID}
                          <- JWT {exp:exp, role:role}

# 2. An authenticated request
HTTP + JWT -> postgrest (authenticator) -> DB (role) -> SQL (security context)
```

Firstly, apps must authenticate end-users, and determine their rights: whether they are data owners, data users, or admin users. Presumably, the IdP and Authentication Server will return some form of user ID, if the authentication is successful. The app can then POST this ID to `/rpc/token` provided by `pg-need-to-know`. If a token for a data user or data owner is being requested `pg-need-to-know` will check if the person has registered. If an admin token is requested, no check will be done. This emphasises the importance of managing rights in another system.

The app will then receive a JWT with an expiry, and a role which is compatible with `pg-need-to-know`'s requirements. The app can then include the JWT in the Authorization header in the following HTTP request. `postgrest` will then switch into the provided role, executing the implied SQL in the role's security context, thereby enforcing authorization.

## Own implementation

If, you wanted to implement your own token generation endpoint, you must therefore conform to the above requirements. And if you wanted to implement your own REST API, consuming `pg-need-to-know`'s SQL API, then you need to also perform DB connection and SQL queries in a similar way to `postgrest`.
