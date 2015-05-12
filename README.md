# Lager Kafka Backend

This is a backend for the Lager Erlang logging framework.

[https://github.com/basho/lager](https://github.com/basho/lager)

### dependencies
- [ekaf](https://github.com/helpshift/ekaf)

### Usage

Include this backend into your project using rebar:

    {lager_kafka_backend, ".*", {git, "https://github.com/snaiper80/lager_kafka_backend.git", "master"}}

### Configuration

You can pass the backend the following configuration:

    {lager, [
      {handlers, [
        {lager_kafka_backend, [
            {level,                      info},
            {topic,                      <<"test">>},
            {broker,                     {"localhost", 9092}},
            {send_method,                async},

            % ekaf option
            {ekaf_partition_strategy,    random},
            {ekaf_per_partition_workers, 5}
        ]}
      ]}
    ]}

### License

Apache 2.0