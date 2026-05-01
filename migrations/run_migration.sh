#!/bin/bash
# Run this once to create the database and apply schema
# Usage: bash migrations/run_migration.sh

set -e

DB_HOST="localhost"
DB_PORT="5433"
DB_USER="kimtvh"
DB_NAME="shopho_db"

echo ">>> Creating database '$DB_NAME' if not exists..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" \
  | grep -q 1 || psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "CREATE DATABASE $DB_NAME;"

echo ">>> Running schema migration..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$(dirname "$0")/001_initial_schema.sql"

echo ">>> Done! Database '$DB_NAME' is ready."
