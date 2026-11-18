#!/usr/bin/env bash
cd "$(dirname "$0")/.."
PSQL="docker compose exec -T postgres psql -U postgres -d demo -c"
IDX="http://localhost:9200/pg.public.customers"
show() { curl -s "$IDX/_refresh" >/dev/null; curl -s "$IDX/_search?pretty&size=20&filter_path=hits.total,hits.hits._id,hits.hits._source"; }
step() { echo; echo "=== $1 ==="; }

step "1. Initial snapshot in Elasticsearch"; sleep 3; show
step "2. INSERT in PostgreSQL"; $PSQL "INSERT INTO customers(name,email,city) VALUES ('Lyjing','lyjing@example.com','Battambang');"; sleep 4; show
step "3. UPDATE in PostgreSQL"; $PSQL "UPDATE customers SET city='Kampot' WHERE name='Lyjing';"; sleep 4; show
step "4. Full-text search: city = Kampot"; curl -s "$IDX/_search?q=city:Kampot&pretty&filter_path=hits.hits._source"
step "5. DELETE in PostgreSQL"; $PSQL "DELETE FROM customers WHERE name='Lyjing';"; sleep 4; show
