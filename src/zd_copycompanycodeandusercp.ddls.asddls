@EndUserText.label: 'Copy company code and user configuration'
define abstract entity ZD_CopyCompanyCodeAndUserCP
{
  @EndUserText.label: 'New Company Code'
  @UI.defaultValue: #( 'ELEMENT_OF_REFERENCED_ENTITY: Companycode' )
  Companycode : BUKRS;
  @EndUserText.label: 'New User Name'
  @UI.defaultValue: #( 'ELEMENT_OF_REFERENCED_ENTITY: Userid' )
  Userid : SYUNAME;
}
