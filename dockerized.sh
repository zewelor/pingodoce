#!/usr/bin/env bash

docker_compose_run_or_exec() {
  local container=$1
  shift

  if docker compose ps --status running | grep -q "$container"; then
    docker compose exec "$container" "$@"
  else
    docker compose run --rm "$container" "$@"
  fi
}

for cmd in ruby bundle rake standardrb rubocop rspec lefthook; do
  eval "$cmd() { docker_compose_run_or_exec app $cmd \"\$@\"; }"
done

export LEFTHOOK_BIN="$(cd "$(dirname "$0")" && pwd)/dockerized.sh lefthook"
