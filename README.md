# CDC Demo: PostgreSQL → Elasticsearch (Debezium)

Pipeline: PostgreSQL → Debezium source → Kafka → Elasticsearch sink → Elasticsearch

## Requirements
Docker + Docker Compose (about 4 GB RAM free), curl, python3 (Git Bash/WSL on Windows).
Stop any other CDC demo first (ports 5432, 9092, 8083 are shared).

## Run
```bash
./scripts/setup.sh     # start stack + register both connectors
./scripts/demo.sh      # INSERT / UPDATE / search / DELETE
./scripts/cleanup.sh   # tear down
```

## Manual demo
```bash
docker compose exec postgres psql -U postgres -d demo
  INSERT INTO customers(name,email,city) VALUES ('Lyjing','l@example.com','Kampot');
  UPDATE customers SET city='Siem Reap' WHERE name='Lyjing';
  DELETE FROM customers WHERE name='Lyjing';

curl "localhost:9200/pg.public.customers/_search?pretty"
curl "localhost:9200/pg.public.customers/_search?q=city:Kampot&pretty"
```

## Useful checks
- Connector status: `curl localhost:8083/connectors/es-sink/status`
- Logs: `docker compose logs -f connect`
- Indices: `curl localhost:9200/_cat/indices?v`

## How the sink works
- `unwrap` (ExtractNewRecordState) turns the Debezium envelope into a flat row.
- `key` (ExtractField$Key) uses the primary key `id` as the Elasticsearch document `_id`.
- Deletes arrive as tombstones; `behavior.on.null.values=delete` removes the document.
- Elasticsearch 7.17 is used for best compatibility with the connector.
