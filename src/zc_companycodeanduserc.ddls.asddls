@EndUserText.label: 'Maintain company code and user configura'
@AccessControl.authorizationCheck: #MANDATORY
@Metadata.allowExtensions: true
define view entity ZC_CompanyCodeAndUserC
  as projection on ZI_CompanyCodeAndUserC
{
  key Companycode,
  key Userid,
  Createdon,
  @Consumption.hidden: true
  SingletonID,
  _CompanyCodeAndUsAll : redirected to parent ZC_CompanyCodeAndUserC_S
}
