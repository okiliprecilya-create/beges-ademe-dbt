{{ config(materialized='view') }}

{% set postes = ['p1_1','p1_2','p1_3','p1_4','p1_5','p2_1','p2_2','p3_1','p3_2','p3_3','p3_4','p3_5','p4_1','p4_2','p4_3','p4_4','p4_5','p5_1','p5_2','p5_3','p5_4','p6_1'] %}

with bilans as (

    select * from {{ ref('stg_beges__bilans') }}

),

indicateurs as (

    select
        bilan_id,
        annee_reporting,
        type_structure,
        naf_division,
        libelle_naf,

        -- 1. plan d'action renseigné (0 ou 1)
        cast(actions_moyens is not null as int64) as ind_plan_action,

        -- 2. au moins un objectif de réduction à 2030 ou 2050 (0 ou 1)
        cast(
            objectif_reduction_2030 is not null
            or objectif_reduction_2050 is not null
            as int64
        ) as ind_objectif_reduction,

        -- 3. transparence méthodologique : part des 3 éléments renseignés (0 à 1)
        (
            cast(facteurs_emission_prg is not null as int64)
            + cast(incertitudes is not null as int64)
            + cast(sources is not null as int64)
        ) / 3 as ind_transparence_methodo,

        -- 4. cohérence de la référence (0 ou 1), vide si aucune année de référence n'est déclarée
        case
            when a_annee_reference then cast(
                coalesce(annee_reference <= annee_reporting, false)
                and (
                    {% for poste in postes -%}
                    emissions_reference_{{ poste }} is not null{% if not loop.last %} or{% endif %}
                    {% endfor %}
                )
                as int64
            )
        end as ind_coherence_reference,

        -- 5. exhaustivité : part des 22 postes d'émissions renseignés (0 à 1)
        (
            {% for poste in postes -%}
            cast(emissions_publication_{{ poste }} is not null as int64){% if not loop.last %} +{% endif %}
            {% endfor %}
        ) / 22 as ind_exhaustivite_postes

    from bilans

)

select
    *,
    -- score global de 0 à 100 : moyenne des indicateurs applicables
    round(
        100 * (
            ind_plan_action
            + ind_objectif_reduction
            + ind_transparence_methodo
            + ind_exhaustivite_postes
            + coalesce(ind_coherence_reference, 0)
        ) / (4 + if(ind_coherence_reference is null, 0, 1)),
        1
    ) as score_qualite

from indicateurs