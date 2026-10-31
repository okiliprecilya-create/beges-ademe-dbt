{% macro oui_non_to_bool(colonne) %}
    case lower(trim({{ colonne }}))
        when 'oui' then true
        when 'non' then false
    end
{% endmacro %}