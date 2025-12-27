@EndUserText.label: 'company code and user configuration'
@AccessControl.authorizationCheck: #MANDATORY
define view entity ZI_CompanyCodeAndUserC
  as select from ZFI_COMPCODE_MAP
  association to parent ZI_CompanyCodeAndUserC_S as _CompanyCodeAndUsAll on $projection.SingletonID = _CompanyCodeAndUsAll.SingletonID
{
  key COMPANYCODE as Companycode,
  key USERID as Userid,
  CREATEDON as Createdon,
  1 as SingletonID,
  _CompanyCodeAndUsAll
}
