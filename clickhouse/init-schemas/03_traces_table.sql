CREATE TABLE IF NOT EXISTS otel.traces_local ON CLUSTER obs_cluster
(
    Timestamp       DateTime64(9) CODEC(Delta, ZSTD(1)),
    TraceId         String CODEC(ZSTD(1)),
    SpanId          String CODEC(ZSTD(1)),
    ParentSpanId    String CODEC(ZSTD(1)),
    SpanName        LowCardinality(String),
    ServiceName     LowCardinality(String),
    Duration        UInt64 CODEC(ZSTD(1)),  -- nanoseconds
    StatusCode      LowCardinality(String),
    Host            LowCardinality(String),
    Environment     LowCardinality(String),
    SpanAttributes  Map(LowCardinality(String), String) CODEC(ZSTD(1)),

    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_duration Duration TYPE minmax GRANULARITY 4
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/traces_local', '{replica}')
PARTITION BY toDate(Timestamp)
ORDER BY (ServiceName, SpanName, Timestamp)
TTL toDateTime(Timestamp) + INTERVAL 14 DAY DELETE  -- trace_retention_days
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS otel.traces ON CLUSTER obs_cluster
AS otel.traces_local
ENGINE = Distributed(obs_cluster, otel, traces_local, cityHash64(TraceId));
