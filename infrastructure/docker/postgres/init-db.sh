#!/bin/sh
set -e

# PostgreSQL initialization script
# Executed automatically on container creation when postgres data directory is empty.

echo "Initializing CineConnect database schema and extensions..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
EOSQL

echo "PostgreSQL initialization completed successfully."
