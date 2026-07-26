-- Local table per shard (ReplicatedMergeTree), plus a Distributed table for cluster-wide queries.
CREATE TABLE IF NOT EXISTS otel.logs_local ON CLUSTER obs_cluster
(
    Timestamp        DateTime64(9) CODEC(Delta, ZSTD(1)),
    TraceId          String CODEC(ZSTD(1)),
    SpanId           String CODEC(ZSTD(1)),
    SeverityText     LowCardinality(String),
    SeverityNumber   UInt8,
    ServiceName      LowCardinality(String),
    Host             LowCardinality(String),
    Environment      LowCardinality(String),
    Region           LowCardinality(String),
    Body             String CODEC(ZSTD(3)),
    LogAttributes    Map(LowCardinality(String), String) CODEC(ZSTD(1)),

    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_body Body TYPE tokenbf_v1(30720, 3, 0) GRANULARITY 1
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/logs_local', '{replica}')
PARTITION BY toDate(Timestamp)
ORDER BY (ServiceName, Host, Timestamp)
TTL toDateTime(Timestamp) + INTERVAL 30 DAY DELETE  -- log_retention_days, keep in sync with group_vars/all.yml
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS otel.logs ON CLUSTER obs_cluster
AS otel.logs_local
ENGINE = Distributed(obs_cluster, otel, logs_local, cityHash64(Host));
