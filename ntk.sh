#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Missing arguments, exiting"
    echo "For help do: ./ntk.sh --guide"
    exit 1
fi

_guide="\

    ntk - need to know
    ------------------

    To set up the DB schema do the following:

    export SUPERUSER=db-super-user-name
    export DBOWNER=db-owner-user-name
    export DBNAME=db-name
    export DBHOST=db-host-name
    export JWT_SECRET=mysecret

    Create a .pgpass file so you can connect to the DB.

    ./ntk.sh OPTIONS

    Options
    -------
    --setup     Create the DB schema.
    --test      Run SQL tests to ensure the DB schema works.
    --guide     Print this guide

"

setup() {
    psql -h $DBHOST -U $SUPERUSER -d $DBNAME -f ./src/need-to-know.sql
    psql -h $DBHOST -U $SUPERUSER -d $DBNAME -f ./src/groups.sql
    psql -h $DBHOST -U $SUPERUSER -d $DBNAME -f ./src/need-to-know-token.sql
    psql -h $DBHOST -U $SUPERUSER -d $DBNAME -c "insert into jwt.secret_store values ('$JWT_SECRET');"
    echo 'pg-need-to-know setup complete, make sure to clear the JWT_SECRET environment variable :)'
}

sqltest() {
    psql -U $SUPERUSER -d $DBNAME -1 -f ./src/testing.sql
}

while (( "$#" )); do
    case $1 in
        --setup)           shift; setup; exit 0 ;;
        --test)            shift; sqltest; exit 0 ;;
        --guide)           printf "%s\n" "$_guide"; exit 0 ;;
        *) break ;;
    esac
done
