
## Create a REST API using postgrest

- Download and install [postgrest](http://postgrest.org/)
- Create a [config file](http://postgrest.org/en/v5.0/install.html#configuration); you should connect to the DB as the `authenticator` and set `db-anon-role` to `anon`
- Run `postgrest your-config-file`
- Set up nginx or apache for TLS, IP-level access control, URL rewriting, rate limiting and other needs
