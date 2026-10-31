{{ config(materialized='table') }}

with bilans as (

    select
        q.*,
        a.exclure_des_analyses_emissions
    from {{ ref('int_beges__qualite_bilans') }} as q
    left join {{ ref('int_beges__anomalies') }} as a using (bilan_id)

),

par_secteur as (

    select
        'secteur_naf' as dimension,
        bilans.naf_division as groupe,
        coalesce(naf.libelle_division, bilans.naf_division) as libelle_groupe,
        naf.libelle_section as libelle_section,
        count(*) as nb_bilans,
        round(100 * avg(ind_plan_action), 1) as pct_plan_action,
        round(100 * avg(ind_objectif_reduction), 1) as pct_objectif_reduction,
        round(100 * avg(ind_transparence_methodo), 1) as pct_transparence_methodo,
        round(100 * avg(ind_coherence_reference), 1) as pct_coherence_reference,
        round(100 * avg(ind_exhaustivite_postes), 1) as pct_exhaustivite_postes,
        round(avg(score_qualite), 1) as score_qualite_moyen,
        round(100 * avg(cast(exclure_des_analyses_emissions as int64)), 1) as pct_bilans_anomalie_bloquante
    from bilans
    left join {{ ref('ref_naf_divisions') }} as naf
        on naf.naf_division = bilans.naf_division
    where bilans.naf_division is not null
    group by bilans.naf_division, naf.libelle_division, naf.libelle_section
    having count(*) >= {{ var('min_bilans_par_secteur', 30) }}

),

par_type_structure as (

    select
        'type_structure' as dimension,
        type_structure as groupe,
        type_structure as libelle_groupe,
        cast(null as string) as libelle_section,
        count(*) as nb_bilans,
        round(100 * avg(ind_plan_action), 1) as pct_plan_action,
        round(100 * avg(ind_objectif_reduction), 1) as pct_objectif_reduction,
        round(100 * avg(ind_transparence_methodo), 1) as pct_transparence_methodo,
        round(100 * avg(ind_coherence_reference), 1) as pct_coherence_reference,
        round(100 * avg(ind_exhaustivite_postes), 1) as pct_exhaustivite_postes,
        round(avg(score_qualite), 1) as score_qualite_moyen,
        round(100 * avg(cast(exclure_des_analyses_emissions as int64)), 1) as pct_bilans_anomalie_bloquante
    from bilans
    where type_structure is not null
    group by type_structure

)

select * from par_secteur
union all
select * from par_type_structure