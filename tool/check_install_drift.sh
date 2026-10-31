#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$ROOT/database"
SUFFIX="$$"
MIG_DB="fore_mig_${SUFFIX}"
INS_DB="fore_ins_${SUFFIX}"
REB_DB="fore_reb_${SUFFIX}"
TMP="$(mktemp -d "$ROOT/.install-drift.XXXXXX")"
CREATED=()

cleanup() {
  for name in "${CREATED[@]}"; do dropdb --if-exists "$name" >/dev/null 2>&1 || true; done
  case "$TMP" in
    "$ROOT"/.install-drift.*) rm -rf -- "$TMP" ;;
    *) echo "Refusing to remove unexpected temporary path: $TMP" >&2 ;;
  esac
}
trap cleanup EXIT

for command in psql createdb dropdb diff; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 2; }
done

make_db() {
  local name="$1"
  createdb "$name"
  CREATED+=("$name")
  psql -X -v ON_ERROR_STOP=1 -d "$name" -f "$DB/tests/00_supabase_stub.sql" >/dev/null
}

apply() { psql -X -v ON_ERROR_STOP=1 -d "$1" -f "$2" >/dev/null; }

modules=(01_foundation.sql 02_operations_reconciliation.sql \
  03_read_apis.sql 04_membership_sessions.sql)

make_db "$MIG_DB"
for source in "${modules[@]}"; do
  apply "$MIG_DB" "$DB/$source"
done

make_db "$INS_DB"
for source in "${modules[@]}"; do
  apply "$INS_DB" "$DB/install/$source"
done

make_db "$REB_DB"
apply "$REB_DB" "$DB/dev/rebuild_test_database.sql"

query="select p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')|' || md5(pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' order by 1;"
psql -X -At -d "$MIG_DB" -c "$query" > "$TMP/migrations"
psql -X -At -d "$INS_DB" -c "$query" > "$TMP/install"
psql -X -At -d "$REB_DB" -c "$query" > "$TMP/rebuild"

diff -u "$TMP/migrations" "$TMP/install"
diff -u "$TMP/migrations" "$TMP/rebuild"
echo 'INSTALL DRIFT: PASS (public function definitions match across grouped SQL, install copies, and test rebuild)'
