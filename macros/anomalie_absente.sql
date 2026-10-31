{% test anomalie_absente(model, column_name) %}

    -- renvoie les bilans signalés : le test alerte s'il y en a au moins un
    select *
    from {{ model }}
    where {{ column_name }} is true

{% endtest %}