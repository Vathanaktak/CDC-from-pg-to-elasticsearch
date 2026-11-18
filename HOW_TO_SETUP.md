# CDC Pipeline: PostgreSQL to Elasticsearch Setup Guide

This guide is structured slide-by-slide so you can directly copy/paste sections into PowerPoint, Google Slides, or Markdown slide tools (Marp / Slidev).

---

## Slide 1: Overview & Objective

### Real-Time CDC Pipeline (PostgreSQL → Elasticsearch)
* **What is CDC (Change Data Capture)?**
  * Automatically captures row-level changes (INSERT, UPDATE, DELETE) in PostgreSQL transaction logs and streams them to Elasticsearch with near-zero latency.
* **Why use it?**
  * Offloads heavy search and analytics queries from the relational database (PostgreSQL) to an optimized search engine (Elasticsearch) without dual-writing from application code.
* **Core Technologies:**
  * **Source Database:** PostgreSQL 16 (Logical Replication / WAL)
  * **Event Streaming:** Apache Kafka & Apache ZooKeeper
  * **CDC Engine:** Debezium Connect 2.7
  * **Sink Connector:** Confluent Elasticsearch Sink Connector v14
  * **Search Engine:** Elasticsearch 7.17

---

## Slide 2: Architecture & Data Flow

```
+---------------+     WAL Logs     +-------------------+     Topic: pg.public.customers     +-------------------+     Sync Documents    +---------------+
|  PostgreSQL   | ---------------> | Debezium Postgres | ---------------------------------> |  Elasticsearch    | --------------------> | Elasticsearch |
| (Source Table)|                  | Source Connector  |                                    |   Sink Connector  |                       |  (Port 9200)  |
+---------------+                  +-------------------+                                    +-------------------+                       +---------------+
                                             ^                                                        ^
                                             |                                                        |
                                             +------------------ Kafka Connect -----------------------+
                                                                  (Port 8083)
```

### Key Components:
1. **PostgreSQL**: `wal_level=logical` enabled; captures database transactions.
2. **Debezium Source Connector**: Tails PostgreSQL Write-Ahead Log (WAL) and publishes change events to Kafka topic `pg.public.customers`.
3. **Kafka & ZooKeeper**: High-throughput distributed log buffering CDC events.
4. **Elasticsearch Sink Connector**: Unwraps Debezium JSON envelope, maps primary key `id` to `_id`, and indexes/deletes documents in Elasticsearch.

---

## Slide 3: Prerequisites & Port Allocation

### Prerequisites:
* **Docker & Docker Compose** installed
* **Minimum System Resources:** ~4 GB available RAM
* **Command Line Tool:** Bash (Linux/macOS/Git Bash/WSL) or Windows PowerShell
* **HTTP Client:** `curl` or Postman

### Port Allocations (Ensure these are free):
| Service | Port | Description |
| :--- | :--- | :--- |
| **PostgreSQL** | `5432` | Source database |
| **Kafka** | `9092` | Message broker |
| **ZooKeeper** | `2181` | Kafka cluster coordinator |
| **Kafka Connect** | `8083` | REST API for connectors |
| **Elasticsearch** | `9200` | REST API for search & indexing |

> *Note: Stop any existing databases or containers using ports 5432, 9092, or 8083 before starting.*

---

## Slide 4: Step 1 - Build & Start the Services

### Command:
```bash
docker compose up -d --build
```

### What happens in this step:
1. Docker builds a custom Kafka Connect image (`./connect/Dockerfile`) containing:
   * Base image: `quay.io/debezium/connect:2.7`
   * Confluent Elasticsearch Sink plugin (`confluentinc-kafka-connect-elasticsearch:14.0.12`)
2. Launches 5 containers in the background:
   * `postgres` (preloaded with `init.sql`: table `customers` + sample rows)
   * `zookeeper`
   * `kafka`
   * `elasticsearch`
   * `connect`

---

## Slide 5: Step 2 - Wait for Services to be Ready

Wait 10–20 seconds for Elasticsearch and Kafka Connect to initialize.

### Verification Commands:
**1. Check Elasticsearch Health:**
```bash
curl -s http://localhost:9200/_cluster/health
```
*(Expected: JSON output with `"status": "green"` or `"yellow"`)*

**2. Check Kafka Connect Plugins:**
```bash
curl -s http://localhost:8083/connector-plugins
```
*(Verify both `PostgresConnector` and `ElasticsearchSinkConnector` are in the list)*

---

## Slide 6: Step 3 - Register PostgreSQL Source Connector

Registers Debezium to read change logs from the `public.customers` table.

### Linux / Git Bash / macOS:
```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connectors/pg-source.json
```

### Windows PowerShell:
```powershell
Invoke-RestMethod -Uri "http://localhost:8083/connectors" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -InFile "connectors/pg-source.json"
```

### Connector Highlights (`pg-source.json`):
* `connector.class`: `io.debezium.connector.postgresql.PostgresConnector`
* `plugin.name`: `pgoutput` (PostgreSQL native decoder)
* `topic.prefix`: `pg` (topic created will be `pg.public.customers`)
* `table.include.list`: `public.customers`

---

## Slide 7: Step 4 - Register Elasticsearch Sink Connector

Registers Kafka Connect to stream events from `pg.public.customers` into Elasticsearch.

### Linux / Git Bash / macOS:
```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connectors/es-sink.json
```

### Windows PowerShell:
```powershell
Invoke-RestMethod -Uri "http://localhost:8083/connectors" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -InFile "connectors/es-sink.json"
```

### Connector Highlights (`es-sink.json`):
* `transforms`: `unwrap,key`
  * `unwrap` (`ExtractNewRecordState`): Extracts the actual data row out of Debezium's CDC metadata wrapper.
  * `key` (`ExtractField$Key`): Uses PostgreSQL primary key `id` as Elasticsearch `_id`.
* `behavior.on.null.values`: `delete` (deletes document when a tombstone event occurs).

---

## Slide 8: Step 5 - Verify Connector Status

Ensure both connectors and their worker tasks are in the `RUNNING` state.

### Command:
```bash
curl -s "http://localhost:8083/connectors?expand=status"
```

### Windows PowerShell:
```powershell
(Invoke-RestMethod -Uri "http://localhost:8083/connectors?expand=status") | ConvertTo-Json -Depth 4
```

### Expected Output:
```json
{
  "pg-source": {
    "status": { "state": "RUNNING", "worker_id": "connect:8083" },
    "tasks": [{ "id": 0, "state": "RUNNING" }]
  },
  "es-sink": {
    "status": { "state": "RUNNING", "worker_id": "connect:8083" },
    "tasks": [{ "id": 0, "state": "RUNNING" }]
  }
}
```

---

## Slide 9: Quick Setup (Automated Alternative)

Instead of running steps 1–5 manually, you can run the provided bash script:

```bash
./scripts/setup.sh
```

### What `setup.sh` does:
1. Executes `docker compose up -d --build`
2. Polls `http://localhost:9200/_cluster/health` until Elasticsearch is ready
3. Polls `http://localhost:8083/connectors` until Kafka Connect is ready
4. Automatically registers `pg-source` and `es-sink`
5. Prints the status of all connectors

---

## Slide 10: Live Demo & Testing the Pipeline

### 1. Check Initial Initial Data (Snapshot Sync):
```bash
curl "http://localhost:9200/pg.public.customers/_search?pretty"
```
*Initial customers from `init.sql` (Sokha, Dara) are already synced!*

### 2. Test INSERT in PostgreSQL:
```bash
docker compose exec postgres psql -U postgres -d demo -c \
  "INSERT INTO customers(name,email,city) VALUES ('Lyjing','lyjing@example.com','Battambang');"
```
*Verify in Elasticsearch immediately:*
```bash
curl "http://localhost:9200/pg.public.customers/_search?q=name:Lyjing&pretty"
```

---

## Slide 11: Testing UPDATE & DELETE

### 3. Test UPDATE in PostgreSQL:
```bash
docker compose exec postgres psql -U postgres -d demo -c \
  "UPDATE customers SET city='Kampot' WHERE name='Lyjing';"
```
*Verify updated city in Elasticsearch:*
```bash
curl "http://localhost:9200/pg.public.customers/_search?q=city:Kampot&pretty"
```

### 4. Test DELETE in PostgreSQL:
```bash
docker compose exec postgres psql -U postgres -d demo -c \
  "DELETE FROM customers WHERE name='Lyjing';"
```
*Verify deletion:*
```bash
curl "http://localhost:9200/pg.public.customers/_search?q=name:Lyjing&pretty"
```
*(Document with name Lyjing is removed from Elasticsearch!)*

*(Or simply run `./scripts/demo.sh` to run the entire demo sequence automatically!)*

---

## Slide 12: How the Sink Works (Under the Hood)

### 1. Debezium Envelope vs Unwrapped Document:
* Raw Debezium payload contains metadata (`before`, `after`, `op`, `ts_ms`).
* `ExtractNewRecordState` (`unwrap`) strips metadata, leaving only the clean record payload for Elasticsearch.

### 2. ID Mapping:
* `ExtractField$Key` pulls the primary key (`id`) from Kafka key and sets it as `_id` in Elasticsearch.
* Guarantees updates overwrite the exact same document without creating duplicates.

### 3. Tombstone Deletions:
* When a row is deleted in PostgreSQL, Debezium emits a record with `value=null` (tombstone).
* `behavior.on.null.values=delete` detects this and executes an Elasticsearch `DELETE /_doc/{id}`.

---

## Slide 13: Useful Troubleshooting & Monitoring Commands

| Action | Command |
| :--- | :--- |
| **Check Kafka Connect Logs** | `docker compose logs -f connect` |
| **Check Elasticsearch Indices** | `curl "http://localhost:9200/_cat/indices?v"` |
| **Inspect Kafka Topics** | `docker compose exec kafka /kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list` |
| **Check PostgreSQL Table** | `docker compose exec postgres psql -U postgres -d demo -c "SELECT * FROM customers;"` |
| **Check Specific Connector Status**| `curl "http://localhost:8083/connectors/es-sink/status"` |

---

## Slide 14: Teardown & Cleanup

When the presentation or demo is finished, stop and clean up all containers and persistent volumes:

```bash
docker compose down -v
```
*(Or run `./scripts/cleanup.sh`)*

* Removes containers, network, and temporary database volumes.
* Frees up ports 5432, 9092, 8083, 9200, and 2181.
