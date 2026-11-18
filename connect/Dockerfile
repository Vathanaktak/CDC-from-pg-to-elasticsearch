# Stage 1: download the Confluent Elasticsearch sink connector
FROM alpine:3.19 AS dl
RUN apk add --no-cache curl unzip
RUN curl -fsSL -o /es.zip \
    https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-elasticsearch/versions/14.0.12/confluentinc-kafka-connect-elasticsearch-14.0.12.zip \
 && unzip -q /es.zip -d /plugin

# Stage 2: Debezium Connect + plugin
FROM quay.io/debezium/connect:2.7
COPY --from=dl --chown=kafka:kafka /plugin/ /kafka/connect/
