@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Supplier Evaluation Root View'
define root view entity ZI_SupplierEval 
  as select from zsupp_eval_db
{
  key supplier_id as SupplierId,
  supplier_name as SupplierName,
  industry as Industry,
  country_code as CountryCode,
  evaluation_date as EvaluationDate,
  quality_score as QualityScore,
  delivery_score as DeliveryScore,
  overall_score as OverallScore,
  
  // --- NEW: The calculation happens HERE at the base level ---
  case
    when overall_score >= 80 then 3
    when overall_score >= 50 then 2
    when overall_score > 0   then 1
    else 0
  end as ScoreCriticality,
  
  eval_comments as EvalComments,
  
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by as LastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  last_changed_at as LastChangedAt
}
