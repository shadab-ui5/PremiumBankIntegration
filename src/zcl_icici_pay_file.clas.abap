CLASS zcl_icici_pay_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "List of strings used to hold lines
    TYPES:
      ty_string_table TYPE STANDARD TABLE OF string WITH EMPTY KEY,
      ty_status       TYPE i,
      ty_status_msg   TYPE string.

    "Build flat file data (H/P/I/A/T) as one big string
    CLASS-METHODS build_file
      IMPORTING
                iv_paymentrunid   TYPE string
                iv_paymentrundate TYPE zfi_paymentrundate
                iv_count          TYPE string
      RETURNING VALUE(rv_data)    TYPE string.

    "Send JSON body to CPI + write/update ZFI_PAY_STATUS
    CLASS-METHODS send_to_cpi
      IMPORTING
        iv_body           TYPE string   " JSON: { "filename": "...", "data": "..." }
        iv_paymentrunid   TYPE string
        iv_paymentrundate TYPE zfi_paymentrundate
        iv_bankname       TYPE char5
      EXPORTING
        ev_status         TYPE ty_status
        ev_message        TYPE ty_status_msg .

    CLASS-METHODS build_header_line
      IMPORTING
                iv_paymentrundate TYPE zfi_paymentrundate
                iv_count          TYPE string
      RETURNING VALUE(rv_line)    TYPE string.

    CLASS-METHODS build_payment_header_line
      IMPORTING
        it_lines          TYPE ty_string_table
        iv_paymentrundate TYPE zfi_paymentrundate
      RETURNING
        VALUE(rv_line)    TYPE string.

    CLASS-METHODS build_trailer_line
      IMPORTING
                it_lines          TYPE ty_string_table
                iv_paymentrundate TYPE zfi_paymentrundate
      RETURNING VALUE(rv_line)    TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_ICICI_PAY_FILE IMPLEMENTATION.


  METHOD build_file.

    TYPES: BEGIN OF ty_pp_join,
             paymentrundate                 TYPE i_paymentproposalitem-paymentrundate,
             paymentrunid                   TYPE i_paymentproposalitem-paymentrunid,
             paymentrunisproposal           TYPE i_paymentproposalitem-paymentrunisproposal,
             paymentdocument                TYPE i_paymentproposalitem-paymentdocument,
             accountingdocument             TYPE i_paymentproposalitem-accountingdocument,
             accountingdocexternalreference TYPE i_paymentproposalitem-accountingdocexternalreference,
             documentdate                   TYPE i_paymentproposalitem-documentdate,
             amountintransactioncurrency    TYPE i_paymentproposalitem-amountintransactioncurrency,
             documentreferenceid            TYPE i_paymentproposalitem-documentreferenceid,
             postingdate                    TYPE i_paymentproposalitem-postingdate,
             documentitemtext               TYPE i_paymentproposalitem-documentitemtext,
             withholdingtaxamount           TYPE i_operationalacctgdocitem-withholdingtaxamount,
           END OF ty_pp_join.

    DATA: lt_i             TYPE TABLE OF zi_pmtrunreport,
          lt_a             TYPE TABLE OF ty_pp_join,
          lt_lines         TYPE ty_string_table,
          lv_line          TYPE string,
          lv_amount_abs    TYPE string,
          lv_amount_a      TYPE string,
          lv_amount_w      TYPE string,
          lv_reduction_amt TYPE i_paymentproposalitem-amountintransactioncurrency,
          lv_reduction_abs TYPE i_paymentproposalitem-amountintransactioncurrency,
          lv_amount_r      TYPE string,
          lv_amount_r_abs  TYPE string.

    "1) I records: use your ZI_PmtRunReport
    SELECT *
      FROM zi_pmtrunreport
      WHERE paymentrunid   = @iv_paymentrunid
        AND paymentrundate = @iv_paymentrundate
      INTO TABLE @lt_i.

    "2) A records: items from I_PAYMENTPROPOSALITEM
    SELECT   a~paymentrundate,
             a~paymentrunid,
             a~paymentrunisproposal,
             a~paymentdocument,
             a~accountingdocument,
             a~accountingdocexternalreference,
             a~documentdate,
             a~amountintransactioncurrency,
             a~documentreferenceid,
             a~postingdate,
             a~documentitemtext,
             b~withholdingtaxamount
      FROM i_paymentproposalitem AS a
      LEFT OUTER JOIN i_operationalacctgdocitem AS b
            ON  a~accountingdocument = b~accountingdocument
            AND a~fiscalyear         = b~fiscalyear
            AND a~companycode        = b~companycode
            AND b~financialaccounttype = 'K'

      WHERE paymentrunid   = @iv_paymentrunid
        AND paymentrundate = @iv_paymentrundate
        AND paymentrunisproposal <> 'X'
        INTO TABLE @lt_a.


    "3) H line
    APPEND build_header_line( iv_paymentrundate = iv_paymentrundate
                              iv_count = iv_count ) TO lt_lines.

    "4) I and A lines
    LOOP AT lt_i ASSIGNING FIELD-SYMBOL(<ls_i>).

      DATA(lv_payment_method) = <ls_i>-r1_paymentmethod.
      IF lv_payment_method = 'T'.
        lv_payment_method = 'N'. " Replace SAP T with N
      ENDIF.

      "Handle amount (minus indicator etc.)
      DATA(lv_amount) = <ls_i>-r5_amountinlocalcurrency.
      "If you need absolute value:
      lv_amount = abs( lv_amount ).
      lv_amount_abs = lv_amount.

      SELECT SINGLE email FROM zvendor_mail_cds
        WHERE ltrim( supplier, '0' ) = ltrim( @<ls_i>-r3_accountnumberofvendor, '0' )
        INTO @DATA(lv_emailid).

      CLEAR lv_line.
      CONCATENATE
        'I'                                  "1 Record Identifier
        lv_payment_method                    "2 Payment Method (T -> N)
        <ls_i>-r2_accountingdocumentnumber   "3 Accounting Document Number
        <ls_i>-r3_accountnumberofvendor      "4 Vendor/Creditor
        <ls_i>-r4_payeename1                 "5 Payee name
        lv_amount_abs                        "6 Amount in Local Currency
        <ls_i>-r6_probablepaymentdate        "7 Probable Payment Date
        <ls_i>-r9_recipientbankaccountnumber "8 Recipient Bank account
        <ls_i>-r8_companybankaccountnumber   "9 Company Bank account
        <ls_i>-r10_bankkeys                  "10 Bank Keys
        <ls_i>-r11_nameofbank                "11 Name of bank
        <ls_i>-r12_payeename2                "12 Payee name 2
        <ls_i>-r13_payeename3                "13 Payee name 3
        <ls_i>-r14_payeename4                "14 Payee name 4
        <ls_i>-r15_city                      "15 City
        <ls_i>-r16_postalcode                "16 Postal code
        <ls_i>-r17_fiscalyear                "17 Fiscal Year
        <ls_i>-r18_companycodeduplicate      "18 Company Code
        lv_emailid                           "19 Vendor E-Mail
        <ls_i>-r20_vendoracctgroup           "20 Vendor account group
        <ls_i>-r21_cityofpayee               "21 City of payee
        <ls_i>-r22_bankcity                  "22 Bank City
      INTO lv_line SEPARATED BY '|'.

      lv_line = lv_line && '|'.

      APPEND lv_line TO lt_lines.

      "A lines for this accounting document
      LOOP AT lt_a ASSIGNING FIELD-SYMBOL(<ls_a>)
           WHERE paymentdocument = <ls_i>-r2_accountingdocumentnumber.

        lv_amount_a = |{ <ls_a>-amountintransactioncurrency SIGN = LEFT DECIMALS = 2 }|.
        lv_amount_w = |{ <ls_a>-withholdingtaxamount SIGN = LEFT DECIMALS = 2 }|.
        lv_reduction_amt = <ls_a>-amountintransactioncurrency - <ls_a>-withholdingtaxamount.
        lv_amount_r = |{ lv_reduction_amt SIGN = LEFT DECIMALS = 2 }|. "Concatenation need field in string form
        lv_reduction_abs = abs( lv_reduction_amt ).
        lv_amount_r_abs = lv_reduction_abs. "Concatenation need field in string form


        CLEAR lv_line.
        CONCATENATE
          'A'                                     "1 Record Identifier
          <ls_a>-accountingdocument               "2 Accounting Document Number
          <ls_a>-accountingdocexternalreference   "3 Document External Reference ID
          <ls_a>-documentdate                     "4 Document Date
          lv_amount_a                             "5 Amount in document currency
          lv_amount_w                             "6 Withholding Tax Amount
          lv_amount_r                             "7 Original Reduction Amount
          ''                                      "8 Short Text for Special G/L Indicator
          <ls_a>-documentreferenceid              "9 Reference Document Number
          <ls_a>-postingdate                      "10 Posting Date
          <ls_a>-documentitemtext                 "11 Item Text
          lv_amount_r_abs                         "12 Abs value for Original Reduction Amount
          ''                                      "13 Tax Amount in local currency (no source)
        INTO lv_line SEPARATED BY '|'.

        lv_line = lv_line && '|'.
        APPEND lv_line TO lt_lines.
        CLEAR lv_line.

      ENDLOOP.

    ENDLOOP.

    "5) P line
    DATA(lv_p) = build_payment_header_line(
                   it_lines          = lt_lines
                   iv_paymentrundate = iv_paymentrundate ).
    INSERT lv_p INTO lt_lines INDEX 2.

    "6) T line
    DATA(lv_t) = build_trailer_line(
                   it_lines          = lt_lines
                   iv_paymentrundate = iv_paymentrundate ).
    APPEND lv_t TO lt_lines.

    rv_data = concat_lines_of(
                 table = lt_lines
                 sep   = cl_abap_char_utilities=>newline ).

  ENDMETHOD.


  METHOD send_to_cpi.

    CONSTANTS:
      lc_cpi_url_icici     TYPE string
        VALUE 'https://sapptldev.it-cpi021-rt.cfapps.in30.hana.ondemand.com/http/ICICIBank1',
      lc_cpi_url_icici_prd TYPE string
        VALUE 'https://sapptlprd-fujg3dfz.it-cpi021-rt.cfapps.in30.hana.ondemand.com/http/ICICIBank',
      lc_cpi_url_kotak     TYPE string
        VALUE 'https://sapptldev.it-cpi021-rt.cfapps.in30.hana.ondemand.com/http/KotakBank1',
       lc_cpi_url_kotak_prd     TYPE string
        VALUE 'https://sapptlprd-fujg3dfz.it-cpi021-rt.cfapps.in30.hana.ondemand.com/http/KotakBank'.

    DATA: lo_http_client   TYPE REF TO if_web_http_client,
          lo_request       TYPE REF TO if_web_http_request,
          lo_response      TYPE REF TO if_web_http_response,
          lv_response_text TYPE string,
          lv_status_code   TYPE i,
          lv_status_reason TYPE string.

    DATA: ls_status TYPE zfi_pay_status.

    " Insert NEW entry in status table
    ls_status-client         = sy-mandt.
    ls_status-paymentrunid   = iv_paymentrunid.
    ls_status-paymentrundate = iv_paymentrundate.
    ls_status-status         = 'NEW'.
    ls_status-message        = ''.
    IF iv_bankname = 'ICICI'.
      ls_status-bankname        = 'ICICI'.
    ELSE.
      ls_status-bankname        = 'KOTAK'.
    ENDIF.
    ls_status-createdby      = cl_abap_context_info=>get_user_technical_name( ).
    ls_status-createdon      = cl_abap_context_info=>get_system_date( ).
    ls_status-createdat      = cl_abap_context_info=>get_system_time( ).

    TRY.
        INSERT zfi_pay_status FROM @ls_status.
      CATCH cx_sy_open_sql_db.
        "Ignore duplicates
    ENDTRY.

    TRY.

        IF iv_bankname = 'ICICI'.
          " Create HTTP client with direct CPI URL
          lo_http_client = cl_web_http_client_manager=>create_by_http_destination(
            cl_http_destination_provider=>create_by_url( i_url = SWITCH #( sy-sysid
                                                                            when 'D70' THEN lc_cpi_url_icici_prd
                                                                            ELSE lc_cpi_url_icici ) )
          ).
        ELSE.
          " Create HTTP client with direct CPI URL
          lo_http_client = cl_web_http_client_manager=>create_by_http_destination(
            cl_http_destination_provider=>create_by_url( i_url = lc_cpi_url_kotak )
            ).
        ENDIF.


        " Get HTTP request object
        lo_request = lo_http_client->get_http_request( ).

        " Set Basic Authentication header
        lo_request->set_authorization_basic(
          i_username = 'shadab.hussain@techorbitgroup.com'
          i_password = 'Abap4Ever'
        ).

        " Set content type header
        lo_request->set_header_field(
          i_name  = 'Content-Type'
          i_value = 'application/json'
        ).

        " Set accept header
        lo_request->set_header_field(
          i_name  = 'Accept'
          i_value = 'application/json'
        ).

        " Set request body
        lo_request->set_text( i_text = iv_body ).

        " Execute POST request to CPI
        lo_response = lo_http_client->execute( i_method = if_web_http_client=>post ).


        DATA: lv_status TYPE if_web_http_response=>http_status,
              lv_body   TYPE string.

        lv_status = lo_response->get_status( ).
        lv_body   = lo_response->get_text( ).


        " Update final status
        ls_status-changedby = cl_abap_context_info=>get_user_technical_name( ).
        ls_status-changedon = cl_abap_context_info=>get_system_date( ).
        ls_status-changedat = cl_abap_context_info=>get_system_time( ).

        IF lv_status-code BETWEEN 200 AND 299.
          ls_status-status  = 'Success'.
          ls_status-message = lv_body.
        ELSE.
          ls_status-status  = 'Error'.
          ls_status-message = |HTTP { lv_status-code }: { lv_body }|.
        ENDIF.

        UPDATE zfi_pay_status
          SET status    = @ls_status-status,
              message   = @ls_status-message,
              changedby = @ls_status-changedby,
              changedon = @ls_status-changedon,
              changedat = @ls_status-changedat
          WHERE paymentrunid   = @ls_status-paymentrunid
            AND paymentrundate = @ls_status-paymentrundate.

        IF sy-subrc <> 0.
          INSERT zfi_pay_status FROM @ls_status.
        ENDIF.

        ev_status  = lv_status-code.
        ev_message = ls_status-message.

      CATCH cx_root INTO DATA(lx).

        ls_status-status  = 'Error'.
        ls_status-message = lx->get_text( ).
        ls_status-changedby = cl_abap_context_info=>get_user_technical_name( ).
        ls_status-changedon = cl_abap_context_info=>get_system_date( ).
        ls_status-changedat = cl_abap_context_info=>get_system_time( ).

        UPDATE zfi_pay_status
          SET status    = @ls_status-status,
              message   = @ls_status-message,
              changedby = @ls_status-changedby,
              changedon = @ls_status-changedon,
              changedat = @ls_status-changedat
          WHERE paymentrunid   = @ls_status-paymentrunid
            AND paymentrundate = @ls_status-paymentrundate.

        IF sy-subrc <> 0.
          INSERT zfi_pay_status FROM @ls_status.
        ENDIF.

        ev_status  = lv_status-code.
        ev_message = ls_status-message.

    ENDTRY.

  ENDMETHOD.


  METHOD build_header_line.

    DATA: lv_date_txt TYPE string.

    "iv_paymentrundate is YYYYMMDD (DATS)
    lv_date_txt = |{ iv_paymentrundate+6(2) }{ iv_paymentrundate+4(2) }{ iv_paymentrundate(4) }|. "DDMMYYYY

    DATA(lv_str_5) =  'PREMIUM_PREMIUMUPLD_' && lv_date_txt && '_' && iv_count.

    CONCATENATE
      'H'                                         "1 Record Identifier
      'PREMIUM_PREMIUMUPLD'                       "2 Client Code
      lv_date_txt                                 "3 Date
      iv_count                                    "4 Number - Incremental number from run on date
      lv_str_5                                    "5 2_3_4 concatenated
    INTO rv_line SEPARATED BY '|'.

    rv_line = rv_line && '|'.

  ENDMETHOD.


  METHOD build_payment_header_line.

    DATA: lv_cnt     TYPE i VALUE 0,
          lv_total   TYPE p DECIMALS 2 VALUE '0',
          lv_date    TYPE string,
          lv_cnt_s   TYPE string,
          lv_total_s TYPE string,
          lt_parts   TYPE STANDARD TABLE OF string,
          lv_amount  TYPE string.

    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<lv>).

      IF <lv>(1) = 'I'.

        SPLIT <lv> AT '|' INTO TABLE lt_parts.

        TRY.
            lv_amount = lt_parts[ 6 ].
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.

        IF lv_amount IS NOT INITIAL.
          "Explicit conversion required (string → number)
          lv_total = lv_total + lv_amount.
        ENDIF.

        lv_cnt = lv_cnt + 1.

      ENDIF.

    ENDLOOP.

    "Mandatory type conversion for concatenation
    lv_cnt_s   = |{ lv_cnt }|.
    lv_total_s = |{ lv_total }|.

    lv_date = |{ iv_paymentrundate+6(2) }{ iv_paymentrundate+4(2) }{ iv_paymentrundate(4) }|.

    CONCATENATE
      'P'
      lv_date
      lv_cnt_s
      lv_total_s
      ''
    INTO rv_line SEPARATED BY '|'.

  ENDMETHOD.


  METHOD build_trailer_line.

    DATA: lv_cnt     TYPE i VALUE 0,
          lv_total   TYPE p DECIMALS 2 VALUE '0',
          lv_date    TYPE string,
          lv_cnt_s   TYPE string,
          lv_total_s TYPE string,
          lt_parts   TYPE STANDARD TABLE OF string,
          lv_amount  TYPE string.

    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<lv>).

      IF <lv>(1) = 'I'.

        SPLIT <lv> AT '|' INTO TABLE lt_parts.

        TRY.
            lv_amount = lt_parts[ 6 ].
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.

        IF lv_amount IS NOT INITIAL.
          lv_total = lv_total + lv_amount.   "Explicit conversion
        ENDIF.

        lv_cnt = lv_cnt + 1.

      ENDIF.

    ENDLOOP.

    lv_cnt_s   = |{ lv_cnt }|.
    lv_total_s = |{ lv_total }|.

    lv_date = |{ iv_paymentrundate+6(2) }{ iv_paymentrundate+4(2) }{ iv_paymentrundate(4) }|.

    CONCATENATE
      'T'
      lv_date
      lv_cnt_s
      lv_total_s
      ''                          "trailing |
    INTO rv_line SEPARATED BY '|'.

  ENDMETHOD.
ENDCLASS.
