@EndUserText.label: 'Supplier Evaluation Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
@Metadata.allowExtensions: true 
define root view entity ZC_SupplierEval
  provider contract transactional_query
  as projection on ZI_SupplierEval
{
  @EndUserText.label: 'Supplier ID'
  key SupplierId,
  SupplierName,
  Industry,
  CountryCode,
  EvaluationDate,
  QualityScore,
  DeliveryScore,
  OverallScore,
  ScoreCriticality,
  EvalComments,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  
  // This field MUST be projected for the BDEF to use it as an ETag
  @EndUserText.label: 'Last Changed At'
  LastChangedAt 
}
