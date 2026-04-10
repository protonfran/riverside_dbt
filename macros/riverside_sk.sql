{#
  Thin wrapper around dbt_utils.generate_surrogate_key.
  Usage: {{ riverside_sk(['user_id']) }}
  Returns a SHA-256 hex string consistent with the original
  SHA2(col, 256) values already in the warehouse.
#}

{% macro riverside_sk(column_names) %}
    {{ dbt_utils.generate_surrogate_key(column_names) }}
{% endmacro %}
