{{ config(materialized='view') }}

{% set postes = ['p1_1','p1_2','p1_3','p1_4','p1_5','p2_1','p2_2','p3_1','p3_2','p3_3','p3_4','p3_5','p4_1','p4_2','p4_3','p4_4','p4_5','p5_1','p5_2','p5_3','p5_4','p6_1'] %}

with bilans as (

    select * from {{ ref('stg_beges__bilans') }}

),

totaux as (

    select
        bilan_id,
        siren_principal,
        annee_reporting,
        naf_division,
        a_annee_reference,
        annee_reference,

        -- nombre de postes renseignés et somme des postes de l'année publiée (tCO2e)
        (
            {% for poste in postes -%}
            cast(emissions_publication_{{ poste }} is not null as int64){% if not loop.last %} +{% endif %}
            {% endfor %}
        ) as nb_postes_publication,
        (
            {% for poste in postes -%}
            coalesce(emissions_publication_{{ poste }}, 0){% if not loop.last %} +{% endif %}
            {% endfor %}
        ) as somme_postes_publication,

        -- au moins une émission négative, en publication ou en référence
        coalesce(
            {% for poste in postes -%}
            emissions_publication_{{ poste }} < 0 or emissions_reference_{{ poste }} < 0{% if not loop.last %} or{% endif %}
            {% endfor %}
            , false
        ) as anomalie_emission_negative

    from bilans

),

avec_total as (

    select
        *,
        if(nb_postes_publication = 0, null, somme_postes_publication) as emissions_totales_publication
    from totaux

),

avec_mediane as (

    select
        *,
        percentile_cont(emissions_totales_publication, 0.5) over (partition by naf_division) as mediane_secteur
    from avec_total

),

anomalies as (

    select
        bilan_id,
        annee_reporting,
        naf_division,
        emissions_totales_publication,

        -- anomalies (à écarter des analyses d'émissions)
        anomalie_emission_negative,
        coalesce(emissions_totales_publication, 0) = 0 as anomalie_aucune_emission,
        coalesce(emissions_totales_publication > {{ var('seuil_emission_extreme', 500000000) }}, false) as anomalie_valeur_extreme,

        -- alertes (à surveiller, sans écarter le bilan)
        coalesce(a_annee_reference and annee_reference > annee_reporting, false) as anomalie_reference_posterieure,
        (siren_principal is not null and count(*) over (partition by siren_principal, annee_reporting) > 1) as alerte_doublon_siren_annee,
        coalesce(
            naf_division is not null
            and emissions_totales_publication > {{ var('ratio_ecart_secteur', 100) }} * mediane_secteur,
            false
        ) as alerte_ecart_secteur

    from avec_mediane

)

select
    *,
    (anomalie_emission_negative or anomalie_aucune_emission or anomalie_valeur_extreme) as exclure_des_analyses_emissions
from anomalies