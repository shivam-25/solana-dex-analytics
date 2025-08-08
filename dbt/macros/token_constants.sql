{% macro wsol() %}
    'So11111111111111111111111111111111111111112'
{% endmacro %}

{% macro usdc() %}
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'
{% endmacro %}

{% macro usdt() %}
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB'
{% endmacro %}

{% macro anchor_tokens() %}
    ({{ wsol() }}, {{ usdc() }}, {{ usdt() }})
{% endmacro %}

{% macro is_anchor_token(column_name) %}
    {{ column_name }} IN {{ anchor_tokens() }}
{% endmacro %}

{% macro not_anchor_token(column_name) %}
    {{ column_name }} NOT IN {{ anchor_tokens() }}
{% endmacro %}