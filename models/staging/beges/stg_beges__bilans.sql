{{ config(materialized='view') }}

{% set postes = ['p1_1','p1_2','p1_3','p1_4','p1_5','p2_1','p2_2','p3_1','p3_2','p3_3','p3_4','p3_5','p4_1','p4_2','p4_3','p4_4','p4_5','p5_1','p5_2','p5_3','p5_4','p6_1'] %}

with source as (

    select * from {{ source('beges_ademe', 'raw_beges') }}

),

dedoublonne as (

    -- 14 lignes sont des copies exactes : on garde une seule ligne par bilan
    select
        *,
        row_number() over (partition by id order by date_publication) as rang
    from source

),

bilans as (

    select * except (rang)
    from dedoublonne
    where rang = 1

)

select
    -- identité du bilan
    trim(id) as bilan_id,
    methode_beges,
    safe.parse_date('%d/%m/%Y', date_publication) as date_publication,
    safe_cast(annee_reporting as int64) as annee_reporting,

    -- organisation
    type_structure,
    nullif(trim(type_collectivite), '') as type_collectivite,
    raison_sociale,
    lpad(trim(siren_principal), 9, '0') as siren_principal,
    nullif(trim(code_naf), '') as code_naf,
    left(nullif(trim(code_naf), ''), 2) as naf_division,
    nullif(trim(libelle_naf), '') as libelle_naf,
    nullif(trim(nb_salaries_agents), '') as effectif,
    safe_cast(nb_salaries_agents as int64) as effectif_exact,
    safe_cast(population as int64) as population,
    region,
    code_departement,
    departement,

    -- périmètre et obligations
    mode_consolidation,
    {{ oui_non_to_bool('structure_obligee') }} as est_structure_obligee,
    {{ oui_non_to_bool('assujetti_dpef_pcaet') }} as est_assujetti_dpef_pcaet,
    {{ oui_non_to_bool('assujetti_csrd') }} as est_assujetti_csrd,
    {{ oui_non_to_bool('aide_diag_decarbonaction') }} as a_aide_diag_decarbonaction,
    safe_cast(seuil_importance_pct as float64) as seuil_importance_pct,
    {{ oui_non_to_bool('niveau_influence') }} as a_niveau_influence,
    {{ oui_non_to_bool('importance_strategique_vulnerabilites') }} as a_importance_strategique,
    {{ oui_non_to_bool('lignes_directrices_sectorielles') }} as a_lignes_directrices_sectorielles,
    {{ oui_non_to_bool('sous_traitance') }} as a_sous_traitance,
    {{ oui_non_to_bool('engagement_personnel') }} as a_engagement_personnel,
    nullif(trim(justification_postes_ecartes), '') as justification_postes_ecartes,

    -- émissions de l'année publiée, par poste
    {% for poste in postes -%}
    safe_cast(emissions_publication_{{ poste }} as float64) as emissions_publication_{{ poste }},
    {% endfor %}

    -- année de référence et émissions de référence, par poste
    {{ oui_non_to_bool('annee_reference_calculee') }} as a_annee_reference,
    safe_cast(annee_reference as int64) as annee_reference,
    {% for poste in postes -%}
    safe_cast(emissions_reference_{{ poste }} as float64) as emissions_reference_{{ poste }},
    {% endfor %}

    -- plan d'action et qualité de la documentation
    safe_cast(reduction_attendue_emissions_directes as float64) as reduction_attendue_emissions_directes,
    safe_cast(reduction_attendue_emissions_indirectes as float64) as reduction_attendue_emissions_indirectes,
    nullif(trim(objectif_reduction_2030), '') as objectif_reduction_2030,
    nullif(trim(objectif_reduction_2050), '') as objectif_reduction_2050,
    nullif(trim(objectif_reduction_autres_horizons), '') as objectif_reduction_autres_horizons,
    nullif(trim(presentation_organisation), '') as presentation_organisation,
    nullif(trim(politique_developpement_durable), '') as politique_developpement_durable,
    nullif(trim(actions_moyens), '') as actions_moyens,
    nullif(trim(analyse_resultats_depuis_dernier_bilan), '') as analyse_resultats_depuis_dernier_bilan,
    nullif(trim(facteurs_emission_prg), '') as facteurs_emission_prg,
    nullif(trim(incertitudes), '') as incertitudes,
    nullif(trim(sources), '') as sources,
    nullif(trim(recalcul_annee_reference), '') as recalcul_annee_reference,
    nullif(trim(comparaison_bilan_reference), '') as comparaison_bilan_reference,
    safe_cast(part_energie_renouvelable as float64) as part_energie_renouvelable,
    nullif(trim(lien_rapport_beges), '') as lien_rapport_beges

from bilans