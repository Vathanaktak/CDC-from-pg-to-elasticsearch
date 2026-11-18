#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
docker compose up -d --build
echo "Waiting for Elasticsearch..."
until curl -sf http://localhost:9200/_cluster/health >/dev/null; do sleep 3; done
echo "Waiting for Kafka Connect..."
until curl -sf http://localhost:8083/connectors >/dev/null; do sleep 3; done
for c in pg-source es-sink; do
  curl -s -X POST -H "Content-Type: application/json" \
       --data @connectors/$c.json http://localhost:8083/connectors >/dev/null
  echo "Registered $c"
done
sleep 8
curl -s "http://localhost:8083/connectors?expand=status" | python3 -m json.tool | grep -E '"(name|state)"' || true
