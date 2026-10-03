-- Justified macro: this exact cleanup is reused across multiple staging models.
-- (Rule of three — see /docs. Don't abstract a one-off.)
{% macro clean_string(col) %}
    nullif(trim(lower({{ col }})), '')
{% endmacro %}
