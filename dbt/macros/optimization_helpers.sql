-- Macro to apply common ClickHouse optimizations
{% macro optimize_table() %}
    {% if execute %}
        {% set query %}
            OPTIMIZE TABLE {{ this }} FINAL DEDUPLICATE
        {% endset %}
        
        {% do run_query(query) %}
        {{ log("Optimized table: " ~ this, info=True) }}
    {% endif %}
{% endmacro %}

-- Macro to enable query cache for marts
{% macro enable_query_cache() %}
    SET use_query_cache = true;
    SET query_cache_ttl = {{ var('query_cache_ttl', 300) }};
    SET query_cache_min_query_runs = 2;
{% endmacro %}

-- Macro to get anchor token status using dictionary
{% macro is_anchor_token(mint_column) %}
    dictGetOrDefault('solana_analytics.anchor_tokens_dict', 'is_anchor', {{ mint_column }}, 0)
{% endmacro %}

-- Macro for efficient sampling
{% macro sample_for_testing(sample_rate=0.01) %}
    {% if var('is_test_run', false) %}
        SAMPLE {{ sample_rate }}
    {% endif %}
{% endmacro %}

-- Macro to add standard indexes
{% macro add_standard_indexes() %}
    {% if execute %}
        {% set indexes = [
            ('trader', 'bloom_filter(0.01)', 1),
            ('market', 'bloom_filter(0.01)', 1),
            ('mint', 'bloom_filter(0.01)', 1),
            ('block_timestamp', 'minmax', 4)
        ] %}
        
        {% for column, type, granularity in indexes %}
            {% set query %}
                ALTER TABLE {{ this }} 
                ADD INDEX IF NOT EXISTS idx_{{ column }} {{ column }} 
                TYPE {{ type }} 
                GRANULARITY {{ granularity }}
            {% endset %}
            {% do run_query(query) %}
        {% endfor %}
    {% endif %}
{% endmacro %}

-- Macro for monitoring model performance
{% macro log_model_performance() %}
    {% if execute %}
        INSERT INTO solana_analytics.model_run_stats
        SELECT 
            '{{ this.name }}' AS model_name,
            now() - INTERVAL 1 MINUTE AS run_started,
            now() AS run_completed,
            count() AS rows_processed,
            'success' AS status,
            NULL AS error_message
        FROM {{ this }}
    {% endif %}
{% endmacro %}