-- Raw metrics: fine-grained, short retention. A materialized view rolls these up
-- into an hourly aggregate table with much longer retention (see below) -
-- this is the standard "raw + downsampled" pattern for cost-controlled long-term metrics.
CREATE TABLE IF NOT EXISTS otel.metrics_raw_local ON CLUSTER obs_cluster
(
    Timestamp    DateTime64(3) CODEC(Delta, ZSTD(1)),
    MetricName   LowCardinality(String),
    ServiceName  LowCardinality(String),
    Host         LowCardinality(String),
    Environment  LowCardinality(String),
    Value        Float64 CODEC(ZSTD(1)),
    Labels       Map(LowCardinality(String), String) CODEC(ZSTD(1))
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/metrics_raw_local', '{replica}')
PARTITION BY toDate(Timestamp)
ORDER BY (MetricName, ServiceName, Host, Timestamp)
TTL toDateTime(Timestamp) + INTERVAL 15 DAY DELETE  -- metrics_raw_retention_days
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS otel.metrics_raw ON CLUSTER obs_cluster
AS otel.metrics_raw_local
ENGINE = Distributed(obs_cluster, otel, metrics_raw_local, cityHash64(Host));

CREATE TABLE IF NOT EXISTS otel.metrics_hourly_local ON CLUSTER obs_cluster
(
    Hour         DateTime CODEC(Delta, ZSTD(1)),
    MetricName   LowCardinality(String),
    ServiceName  LowCardinality(String),
    Host         LowCardinality(String),
    AvgValue     AggregateFunction(avg, Float64),
    MaxValue     AggregateFunction(max, Float64),
    MinValue     AggregateFunction(min, Float64)
)
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/metrics_hourly_local', '{replica}')
PARTITION BY toYYYYMM(Hour)
ORDER BY (MetricName, ServiceName, Host, Hour)
TTL Hour + INTERVAL 400 DAY DELETE  -- metrics_downsampled_retention_days
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW IF NOT EXISTS otel.metrics_hourly_mv ON CLUSTER obs_cluster
TO otel.metrics_hourly_local
AS SELECT
    toStartOfHour(Timestamp) AS Hour,
    MetricName,
    ServiceName,
    Host,
    avgState(Value) AS AvgValue,
    maxState(Value) AS MaxValue,
    minState(Value) AS MinValue
FROM otel.metrics_raw_local
GROUP BY Hour, MetricName, ServiceName, Host;
