@EndUserText.label: 'Payment Run Report (Interface)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define view entity ZI_PmtRunReport
  as select from    I_PaymentProposalPayment as Pay

  /* Bank name / city via PayeeBankKey */
    left outer join I_Bank_2                 as Bank      on Bank.BankInternalID = Pay.PayeeBankKey

  /* Fiscal year via accounting document + company code */
    left outer join I_JournalEntry           as JE        on  JE.AccountingDocument = Pay.PaymentDocument
                                                          and JE.CompanyCode        = Pay.PayingCompanyCode

    left outer join I_Supplier               as Sup       on Sup.Supplier = Pay.Supplier

    left outer join zfi_pay_status           as paystatus on  paystatus.paymentrunid   = Pay.PaymentRunID
                                                          and paystatus.paymentrundate = Pay.PaymentRunDate                                                          

{
      /* Header / filter fields */
  key Pay.PayingCompanyCode          as CompanyCode,
      @Consumption.filter: { selectionType: #SINGLE }
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PmtRunReport', element: 'PaymentRunID' } }]
  key Pay.PaymentRunID               as PaymentRunID,
  key Pay.PaymentRunDate             as PaymentRunDate,

      Pay.HouseBank                  as HouseBank,
      Pay.HouseBankAccount           as HouseBankAccount,
      Pay.PaymentMethod              as PaymentMethod,

      /* Report columns — Record Type I */
      Pay.PaymentMethod              as R1_PaymentMethod,
      Pay.PaymentDocument            as R2_AccountingDocumentNumber,
      Pay.Supplier                   as R3_AccountNumberOfVendor,
      Pay.OrganizationBPName1        as R4_PayeeName1,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      Pay.PaytAmountInCoCodeCurrency as R5_AmountInLocalCurrency,
      Pay.CompanyCodeCurrency, // keep this in the projection!

      Pay.PaymentDueDate             as R6_ProbablePaymentDate,
      Pay.DirectDebitType            as R7_CheckNumber,
      Pay.BankAccount                as R8_CompanyBankAccountNumber,
      Pay.PayeeBankAccount           as R9_RecipientBankAccountNumber,
      Pay.PayeeBankKey               as R10_BankKeys,
      Bank.BankName                  as R11_NameOfBank,
      Pay.OrganizationBPName2        as R12_PayeeName2,
      Pay.OrganizationBPName3        as R13_PayeeName3,
      Pay.OrganizationBPName4        as R14_PayeeName4,

      Sup.CityName                   as R15_City,
      Sup.PostalCode                 as R16_PostalCode,

      JE.FiscalYear                  as R17_FiscalYear,
      Pay.PayingCompanyCode          as R18_CompanyCodeDuplicate,

      /* R19 Vendor E-Mail Address (needs BP email)          as R19_VendorEmail,     */
      Sup.SupplierAccountGroup       as R20_VendorAcctGroup,

      Pay.PayeeCityName              as R21_CityOfPayee,
      Bank.CityName                  as R22_BankCity,

      case paystatus.status
             when 'Success' then 'Sent Successfully'
             when 'Error' then 'Error in Sending'
             else 'Not Sent'
           end                       as R23_Status,
      paystatus.message              as R24_Message,
      paystatus.createdby            as R25_Createdby,
      paystatus.createdon            as R26_Createdon,
      paystatus.createdat            as R27_Createdat,
      paystatus.changedby            as R28_Changedby,
      paystatus.changedon            as R29_Changedon,
      paystatus.changedat            as R30_Changedat

}
where
  Pay.PaymentRunIsProposal = '' // fetch only posted payments (proposal flag blank)
;
