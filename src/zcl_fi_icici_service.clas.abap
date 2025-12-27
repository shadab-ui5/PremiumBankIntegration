CLASS zcl_fi_icici_service DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_http_service_extension .
*    INTERFACES if_oo_adt_classrun .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_FI_ICICI_SERVICE IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.


    DATA: lv_body       TYPE string,
          ls_json       TYPE string,
          ls_input      TYPE string,
          ls_output     TYPE string,
          lv_runid      TYPE string,
          lv_rundate    TYPE zfi_paymentrundate,
          lv_bankname   TYPE char5,
          lv_filedata   TYPE string,
          lv_json       TYPE string,
          lv_status     TYPE i,
          lv_message    TYPE string,
          lv_today_date TYPE zfi_paymentrundate,
          lv_count      TYPE i.

    TRY.

        " CORS SUPPORT (allow UI5 to call this URL)
        response->set_header_field( i_name = 'Access-Control-Allow-Origin'   i_value = '*' ).
        response->set_header_field( i_name = 'Access-Control-Allow-Methods'  i_value = 'POST,OPTIONS' ).
        response->set_header_field( i_name = 'Access-Control-Allow-Headers'  i_value = 'Content-Type' ).
        response->set_header_field( i_name = 'Access-Control-Allow-Credentials' i_value = 'true' ).

        "Preflight request
        IF request->get_method( ) = 'OPTIONS'.
          response->set_status( i_code = 200 i_reason = 'OK' ).
          RETURN.
        ENDIF.

        " Read Request Body (JSON from UI5)
        lv_body = request->get_text( ).

        IF lv_body IS INITIAL.
          response->set_status( 400 ).
          response->set_text( '{"error":"Empty request body"}' ).
          RETURN.
        ENDIF.

        " Deserialize JSON → ABAP structure
        TYPES: BEGIN OF ty_input,
                 bankname       TYPE string,
                 paymentrunid   TYPE string,
                 paymentrundate TYPE zfi_paymentrundate,
               END OF ty_input.

        DATA(ls_input_data) = VALUE ty_input( ).

        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_body
          CHANGING  data = ls_input_data ).

        lv_runid   = ls_input_data-paymentrunid.
        lv_rundate = ls_input_data-paymentrundate.
        lv_bankname = ls_input_data-bankname.

        IF lv_runid IS INITIAL OR lv_rundate IS INITIAL.
          response->set_status( 400 ).
          response->set_text( '{"error":"Missing PaymentRunID or PaymentRunDate"}' ).
          RETURN.
        ENDIF.

        IF lv_bankname = 'ICICI'.

          " Get the record that says how many time in a day bank file is sent in lv_count
          lv_today_date = cl_abap_context_info=>get_system_date( ).

          SELECT COUNT( * )
            FROM zfi_pay_status
            WHERE bankname = 'ICICI'
            AND createdon = @lv_today_date
            INTO @lv_count.

          IF lv_count > 0.
            lv_count = lv_count + 1.
          ELSE.
            lv_count = 1.
          ENDIF.

          DATA lv_count_3 TYPE string.
          lv_count_3 = |{ lv_count WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.  " Count as 3 character with leading zeros

          " Build flat file
          lv_filedata = zcl_icici_pay_file=>build_file(
                           iv_paymentrunid   = lv_runid
                           iv_paymentrundate = lv_rundate
                           iv_count = lv_count_3 ).

          "iv_paymentrundate is YYYYMMDD (DATS)
          DATA(lv_date_txt) = |{ lv_rundate+6(2) }{ lv_rundate+4(2) }{ lv_rundate(4) }|. "DDMMYYYY

          DATA(lv_str_5) =  'PREMIUM_PREMIUMUPLD_' && lv_date_txt && '_' && lv_count_3.

        ELSEIF lv_bankname = 'KOTAK'.

          lv_today_date = cl_abap_context_info=>get_system_date( ).

          SELECT COUNT( * )
            FROM zfi_pay_status
            WHERE bankname = 'KOTAK'
              AND createdon = @lv_today_date
            INTO @lv_count.

          IF lv_count > 0.
            lv_count = lv_count + 1.
          ELSE.
            lv_count = 1.
          ENDIF.

          DATA(lv_count_3_kotak) = |{ lv_count WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.

          lv_filedata = zcl_kotak_pay_file=>build_file(
                           iv_paymentrunid   = lv_runid
                           iv_paymentrundate = lv_rundate
                           iv_seq_no         = lv_count_3_kotak ).

          " File name to send to CPI (SFTP target)
          " Example from sample: KOTAK_BK_PMPL12141125001.TXT
          DATA(lv_ddmmyy) = |{ lv_rundate+6(2) }{ lv_rundate+4(2) }{ lv_rundate+2(2) }|. "DDMMYY

          lv_str_5 = |KOTAK_BK_PMPL12{ lv_ddmmyy }{ lv_count_3_kotak }.TXT|.

        ENDIF.


        " Build JSON for CPI
        TYPES: BEGIN OF ty_cpi_payload,
                 filename TYPE string,
                 data     TYPE string,
               END OF ty_cpi_payload.

        DATA(ls_payload) = VALUE ty_cpi_payload(
                             filename = lv_str_5
                             data     = lv_filedata ).

        lv_json = /ui2/cl_json=>serialize( ls_payload ).


        " Send to CPI (with logging)
        zcl_icici_pay_file=>send_to_cpi(
          EXPORTING
            iv_body           = lv_json
            iv_paymentrunid   = lv_runid
            iv_paymentrundate = lv_rundate
            iv_bankname       = lv_bankname
          IMPORTING
            ev_status         = lv_status
            ev_message        = lv_message ).


        " Return response to UI5
        TYPES: BEGIN OF ty_ui_resp,
                 status  TYPE string,
                 message TYPE string,
               END OF ty_ui_resp.

        DATA(ls_resp) = VALUE ty_ui_resp(
                          status  = lv_status
                          message = lv_message ).

        DATA(ls_ui_response) = /ui2/cl_json=>serialize( ls_resp ).


        response->set_status( lv_status ).
        response->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
        response->set_text( ls_ui_response ).

      CATCH cx_root INTO DATA(lx).

        TYPES: BEGIN OF ty_err,
                 error TYPE string,
               END OF ty_err.

        DATA(ls_err) = VALUE ty_err( error = lx->get_text( ) ).
        DATA(lv_json_err) = /ui2/cl_json=>serialize( ls_err ).

        response->set_header_field(
          i_name  = 'Content-Type'
          i_value = 'application/json' ).

        response->set_text( lv_json_err ).
        response->set_status( 500 ).

    ENDTRY.

  ENDMETHOD.
ENDCLASS.
