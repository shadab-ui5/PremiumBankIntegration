@EndUserText.label: 'company code and user configuration Sing'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_CompanyCodeAndUserC_S
  as select from I_Language
    left outer join I_CstmBizConfignLastChgd on I_CstmBizConfignLastChgd.ViewEntityName = 'ZI_COMPANYCODEANDUSERC'
  association [0..*] to I_ABAPTransportRequestText as _ABAPTransportRequestText on $projection.TransportRequestID = _ABAPTransportRequestText.TransportRequestID
  composition [0..*] of ZI_CompanyCodeAndUserC as _CompanyCodeAndUserC
{
  key 1 as SingletonID,
  _CompanyCodeAndUserC,
  I_CstmBizConfignLastChgd.LastChangedDateTime as LastChangedAtMax,
  cast( '' as SXCO_TRANSPORT) as TransportRequestID,
  _ABAPTransportRequestText
}
where I_Language.Language = $session.system_language
