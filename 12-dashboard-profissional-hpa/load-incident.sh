#!/usr/bin/env sh
set -eu

BASE="http://sre-demo.sre-lab.svc.cluster.local"

echo "Starting mixed SRE incident load..."

# CPU-bound traffic
for w in 1 2 3 4 5 6 7 8; do
  (
    i=0
    while [ "$i" -lt 30 ]; do
      curl -s "$BASE/cpu" >/dev/null
      i=$((i+1))
    done
  ) &
done

# Slow traffic
for w in 1 2 3 4; do
  (
    i=0
    while [ "$i" -lt 20 ]; do
      curl -s "$BASE/slow" >/dev/null
      i=$((i+1))
    done
  ) &
done

# Normal traffic
for w in 1 2 3 4; do
  (
    i=0
    while [ "$i" -lt 50 ]; do
      curl -s "$BASE/" >/dev/null
      i=$((i+1))
    done
  ) &
done

# 5xx
(
  i=0
  while [ "$i" -lt 20 ]; do
    curl -s "$BASE/error" >/dev/null
    i=$((i+1))
  done
) &

wait
echo "Incident load finished"
