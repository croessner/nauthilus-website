#!/usr/bin/env bash
# Runs every Lua Cookbook recipe: start the stack, run its test.sh, remove the stack.
#
#   ./run-all.sh                                   # the released image named in the compose files
#   NAUTHILUS_IMAGE=nauthilus:dev ./run-all.sh     # a local build
#   NAUTHILUS_LUA_JIT=false ./run-all.sh           # Lua interpreter instead of the JIT (Nauthilus 4.2 and later)
#   ./run-all.sh admin-toolkit login-journal       # only some recipes
#
# Exit code 0 means every check of every recipe passed. Known issues are reported but do not fail the run.
cd "$(dirname "$0")" || exit 1

RECIPES=("$@")

if [ ${#RECIPES[@]} -eq 0 ]; then
    RECIPES=(flatfile-users sql-users admin-toolkit account-rules login-journal geo-regions reputation policy-api)
fi

failed=()

for recipe in "${RECIPES[@]}"; do
    printf '\n=== %s (image %s, jit %s)\n' "$recipe" "${NAUTHILUS_IMAGE:-default}" "${NAUTHILUS_LUA_JIT:-true}"

    (
        cd "$recipe" || exit 1
        [ -x setup.sh ] && ./setup.sh >/dev/null

        if ! docker compose up -d --wait >/dev/null 2>&1; then
            echo "  FAIL  the stack did not become healthy"
            docker compose logs nauthilus 2>&1 | tail -20
            docker compose down -v >/dev/null 2>&1
            exit 1
        fi

        ./test.sh
        result=$?

        docker compose down -v >/dev/null 2>&1
        exit $result
    ) || failed+=("$recipe")
done

printf '\n'

if [ ${#failed[@]} -gt 0 ]; then
    echo "FAILED: ${failed[*]}"
    exit 1
fi

echo "All recipes passed."
