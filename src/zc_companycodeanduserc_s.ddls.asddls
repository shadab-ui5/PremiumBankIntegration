@EndUserText.label: 'Maintain company code and user configura'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@UI: {
  headerInfo: {
    typeName: 'CompanyCodeAndUsAll'
  }
}
@ObjectModel.semanticKey: [ 'SingletonID' ]
define root view entity ZC_CompanyCodeAndUserC_S
  provider contract TRANSACTIONAL_QUERY
  as projection on ZI_CompanyCodeAndUserC_S
{
  @UI.facet: [ {
    id: 'ZI_CompanyCodeAndUserC', 
    purpose: #STANDARD, 
    type: #LINEITEM_REFERENCE, 
    label: 'company code and user configuration', 
    position: 1 , 
    targetElement: '_CompanyCodeAndUserC'
  } ]
  @UI.lineItem: [ {
    position: 1 
  } ]
  key SingletonID,
  @UI.hidden: true
  LastChangedAtMax,
  @ObjectModel.text.element: [ 'TransportRequestDescription' ]
  @UI.identification: [ {
    position: 1 , 
    type: #WITH_INTENT_BASED_NAVIGATION, 
    semanticObjectAction: 'manage'
  } ]
  @Consumption.semanticObject: 'CustomizingTransport'
  TransportRequestID,
  @UI.hidden: true
  _ABAPTransportRequestText.TransportRequestDescription : localized,
  _CompanyCodeAndUserC : redirected to composition child ZC_CompanyCodeAndUserC
}
