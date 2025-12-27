CLASS zcl_kotak_pay_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      ty_string_table TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CLASS-METHODS build_file
      IMPORTING
        iv_paymentrunid   TYPE string
        iv_paymentrundate TYPE zfi_paymentrundate
        iv_seq_no         TYPE string OPTIONAL
      RETURNING
        VALUE(rv_data)    TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      gc_sep          TYPE c VALUE '~',   " field separator
      gc_rec_header   TYPE c VALUE 'H',   " header row
      gc_rec_batch    TYPE c VALUE 'B',   " batch row
      gc_rec_detail   TYPE c VALUE 'D',   " detail row
      gc_rec_advice   TYPE c VALUE 'E',   " advice row
      gc_rec_trailer  TYPE c VALUE 'T',   " trailer row
      gc_product_code TYPE string VALUE 'VENPAY'.  " Batch Product_Code

    TYPES: tt_paymeent_proposal TYPE STANDARD TABLE OF i_paymentproposalpayment.

    "--- helper / hook methods -------------------------------------------

    CLASS-METHODS build_header_line
      IMPORTING
        iv_paymentrunid   TYPE string
        iv_paymentrundate TYPE zfi_paymentrundate
        iv_seq_no         TYPE string OPTIONAL
      RETURNING
        VALUE(rv_line)    TYPE string.

    CLASS-METHODS build_batch_line
      IMPORTING
        it_payments       TYPE tt_paymeent_proposal
        iv_paymentrunid   TYPE string
        iv_paymentrundate TYPE zfi_paymentrundate
      RETURNING
        VALUE(rv_line)    TYPE string.

    CLASS-METHODS build_detail_and_advice_lines
      IMPORTING
        it_payments     TYPE tt_paymeent_proposal
      RETURNING
        VALUE(rt_lines) TYPE ty_string_table.

    CLASS-METHODS build_trailer_line
      IMPORTING
        it_payments    TYPE tt_paymeent_proposal
      RETURNING
        VALUE(rv_line) TYPE string.

    "---- formatting helpers / hooks

    CLASS-METHODS get_client_code
      RETURNING VALUE(rv_client_code) TYPE string.

    CLASS-METHODS get_file_name
      IMPORTING
        iv_paymentrunid    TYPE string
        iv_paymentrundate  TYPE zfi_paymentrundate
        iv_seq_no          TYPE string OPTIONAL
      RETURNING
        VALUE(rv_filename) TYPE string.

    CLASS-METHODS format_date_ddmmyyyy
      IMPORTING
        iv_date        TYPE zfi_paymentrundate
      RETURNING
        VALUE(rv_date) TYPE string.

    CLASS-METHODS format_date_dd_mm_yyyy
      IMPORTING
        iv_date        TYPE zfi_paymentrundate
      RETURNING
        VALUE(rv_date) TYPE string.

    CLASS-METHODS format_amount_15_2
      IMPORTING
        iv_amount        TYPE i_paymentproposalpayment-paymentamountinpaytcurrency "paytamountincocodecurrency
      RETURNING
        VALUE(rv_amount) TYPE string.

    CLASS-METHODS determine_payment_type
      IMPORTING
        is_payment     TYPE i_paymentproposalpayment
      RETURNING
        VALUE(rv_type) TYPE string.

    CLASS-METHODS get_payment_ref_no
      IMPORTING
        is_payment      TYPE i_paymentproposalpayment
      RETURNING
        VALUE(rv_refno) TYPE string.

    CLASS-METHODS build_advice_line
      IMPORTING
        is_payment     TYPE i_paymentproposalpayment
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_kotak_pay_file IMPLEMENTATION.


  METHOD build_file.

    DATA: lt_payments TYPE TABLE OF i_paymentproposalpayment,
          lt_lines    TYPE ty_string_table,
          lv_line     TYPE string.

    "Read payment header data
    SELECT *
      FROM i_paymentproposalpayment
      WHERE paymentrunid   = @iv_paymentrunid
        AND paymentrundate = @iv_paymentrundate
        AND paymentrunisproposal <> 'X'
      INTO TABLE @lt_payments.

    IF lt_payments IS INITIAL.
      rv_data = ''.
      RETURN.
    ENDIF.

    "Header row (H)
    APPEND build_header_line(
             iv_paymentrunid   = iv_paymentrunid
             iv_paymentrundate = iv_paymentrundate
             iv_seq_no         = iv_seq_no ) TO lt_lines.

    "Batch row (B) – one batch per file
    APPEND build_batch_line(
             it_payments       = lt_payments
             iv_paymentrunid   = iv_paymentrunid
             iv_paymentrundate = iv_paymentrundate ) TO lt_lines.

    "Detail (D) + Advice (E) rows
    lt_lines = VALUE #(
                 BASE lt_lines
                 ( LINES OF build_detail_and_advice_lines( it_payments = lt_payments ) ) ).

    "Trailer row (T)
    APPEND build_trailer_line( it_payments = lt_payments ) TO lt_lines.

    "Join all lines into one string, newline-separated
    rv_data = concat_lines_of(
               table = lt_lines
               sep   = cl_abap_char_utilities=>newline ).

  ENDMETHOD.


  METHOD build_header_line.

    DATA(lv_client_code) = get_client_code( ).
    DATA(lv_file_name)   = get_file_name(
                             iv_paymentrunid   = iv_paymentrunid
                             iv_paymentrundate = iv_paymentrundate
                             iv_seq_no         = iv_seq_no ).

    DATA(lv_col3) = ''.
    DATA(lv_col4) = ''.
    DATA(lv_col5) = ''.
    DATA(lv_col7) = ''.  " extra filler to match last '~'

    CONCATENATE
      gc_rec_header        "1  H
      lv_client_code       "2  PMPL12
      lv_col3              "3  blank
      lv_col4              "4  blank
      lv_col5              "5  blank
      lv_file_name         "6  141125001.TXT
      lv_col7              "7  blank (gives trailing ~)
    INTO rv_line SEPARATED BY gc_sep.


  ENDMETHOD.


  METHOD build_batch_line.

    DATA: lv_cnt        TYPE i VALUE 0,
          lv_total      TYPE i_paymentproposalitem-amountintransactioncurrency VALUE '0',
          lv_cnt_s      TYPE string,
          lv_total_s    TYPE string,
          lv_batch_date TYPE string,
          lv_batch_ref  TYPE string.

    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      lv_cnt   = lv_cnt + 1.
      lv_total = lv_total + abs( <ls_pay>-paytamountincocodecurrency ).
    ENDLOOP.

    lv_cnt_s      = |{ lv_cnt }|.
    lv_total_s    = format_amount_15_2( iv_amount = lv_total ).
    lv_batch_date = format_date_dd_mm_yyyy( iv_date = iv_paymentrundate ).

    lv_batch_ref = |{ iv_paymentrundate }_{ iv_paymentrunid }|. "YYYYMMDD_RunID

    CONCATENATE
      gc_rec_batch        "1 B
      lv_cnt_s            "2 Tot_Instruments
      lv_total_s          "3 Tot_Amount
      lv_batch_ref        "4 20251114_JB023 - Batch Ref. No.
      lv_batch_date       "5 Batch Date
      gc_product_code     "6 Product_Code
    INTO rv_line SEPARATED BY gc_sep.

    rv_line = rv_line && gc_sep.

  ENDMETHOD.


  METHOD build_detail_and_advice_lines.

    rt_lines = VALUE #( ).

    TYPES: BEGIN OF ty_kotak_a,
             paymentdocument             TYPE i_paymentproposalitem-paymentdocument,
             accountingdocument          TYPE i_paymentproposalitem-accountingdocument,
             documentdate                TYPE i_paymentproposalitem-documentdate,
             amountintransactioncurrency TYPE i_paymentproposalitem-amountintransactioncurrency,
             documentreferenceid         TYPE i_paymentproposalitem-documentreferenceid,
             postingdate                 TYPE i_paymentproposalitem-postingdate,
             documentitemtext            TYPE i_paymentproposalitem-documentitemtext,
             withholdingtaxamount        TYPE i_operationalacctgdocitem-withholdingtaxamount,
           END OF ty_kotak_a.

    DATA: lt_a TYPE STANDARD TABLE OF ty_kotak_a.

    DATA: lr_docs TYPE RANGE OF i_paymentproposalpayment-paymentdocument.

    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_p>).

      IF <ls_p>-paymentdocument IS NOT INITIAL.

        APPEND VALUE #(
          sign   = 'I'
          option = 'EQ'
          low    = <ls_p>-paymentdocument
        ) TO lr_docs.

      ENDIF.

    ENDLOOP.


    SORT lr_docs.
    DELETE ADJACENT DUPLICATES FROM lr_docs COMPARING low.

    IF lr_docs IS NOT INITIAL.
      SELECT a~paymentdocument,
             a~accountingdocument,
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
        WHERE a~paymentdocument IN @lr_docs
        INTO TABLE @lt_a.

    ENDIF.

    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_pay>).

      " --- D row fields -----------------------------

      DATA(lv_refno)      = get_payment_ref_no( <ls_pay> ).
      DATA(lv_pay_type)   = determine_payment_type( <ls_pay> ).
      DATA(lv_amount_s)   = format_amount_15_2( abs( <ls_pay>-paytamountincocodecurrency ) ).
      DATA(lv_pay_date)   = format_date_dd_mm_yyyy( <ls_pay>-paymentrundate ).
      DATA(lv_instr_date) = lv_pay_date.  " for cheques, replace with posting date

      DATA(lv_instr_no)   = ''.                        " not used in sample for NEFT/RTGS
      DATA(lv_dr_ac_no)   = <ls_pay>-bankaccount.      " debit account

      DATA(lv_dr_desc)    = ''.                        " optional
      DATA(lv_dr_ref_no)  = ''.
      DATA(lv_cr_ref_no)  = ''.
      DATA(lv_benficiary_code) = ''.
      DATA(lv_benficiary_bank) = ''.

      DATA(lv_bank_code_ind) = 'M'.                    " M / I

      DATA(lv_ben_name)      = <ls_pay>-organizationbpname1.
      DATA(lv_ben_branch)    = <ls_pay>-payeebankkey.       " IFSC
      DATA(lv_ben_ac_no)     = <ls_pay>-payeebankaccount.   " beneficiary account

      DATA(lv_ben_bank)     = ''.    " left blank in sample
      DATA(lv_ben_blank)    = ''.
      DATA(lv_ben_code)     = <ls_pay>-supplier.      " vendor code
      DATA(lv_ben_code1)     = |Vendor Code - { <ls_pay>-supplier }|.     " vendor code
      CONDENSE lv_ben_code NO-GAPS.

      DATA lv_location      TYPE string.
      DATA lv_print_loc     TYPE string.

      DATA lv_addr1         TYPE string.
      DATA lv_addr2         TYPE string.
      DATA lv_addr3         TYPE string.

      DATA(lv_city)         = <ls_pay>-payeecityname.
      DATA lv_zip           TYPE string.
      DATA lv_state         TYPE string.
      DATA lv_email         TYPE string.
      DATA lv_mobile        TYPE string.

      "Fetch supplier email (same CDS as ICICI)
      CLEAR lv_email.

      SELECT SINGLE postalcode,
                    phonenumber1,
                    email
        FROM zvendor_mail_cds
        WHERE ltrim( supplier, '0' ) = ltrim( @lv_ben_code, '0' )
        INTO @DATA(ls_comm_details).

      lv_email = ls_comm_details-email.
      lv_mobile = ls_comm_details-phonenumber1.
      lv_zip = ls_comm_details-postalcode.

      CONDENSE lv_email NO-GAPS.

      DATA lv_pay_det1      TYPE string.
      DATA lv_pay_det2      TYPE string.
      DATA lv_pay_det3      TYPE string.
      DATA lv_pay_det4      TYPE string.

      DATA(lv_delivery_mode) = sy-uname.                 " user ID

      " --- D row CONCATENATE -----------------------

      DATA(lv_d_line) = VALUE string( ).

      CONCATENATE
        gc_rec_detail      "1  D
        lv_refno           "2  Payment Ref No
        lv_pay_type        "3  Payment Type
        lv_amount_s        "4  Amount
        lv_pay_date        "5  Payment Date
        lv_instr_date      "6  Instrument Date
        lv_instr_no        "7  Instrument Number
        lv_dr_ac_no        "8  Dr Ac No
        lv_dr_desc         "9  Dr Description
        lv_dr_ref_no       "10 Dr Ref No
        lv_cr_ref_no       "11 Cr Ref No
        lv_bank_code_ind   "12 Bank Code Indicator M/I
        lv_benficiary_code "13 Benficiary Code -- as suggested by bank on 22/12
        lv_ben_name        "14 Beneficiary Name
        lv_benficiary_bank "15 Benificiary Bank -- as suggested by bank on 22/12
        lv_ben_branch      "16 Beneficiary Branch / IFSC
        lv_ben_ac_no       "17 Beneficiary Acc No
        lv_ben_bank        "18 Beneficiary Bank
        lv_ben_blank       "19 Blank Field -- as suggested by bank on 22/12
        lv_ben_code1       "20 Beneficiary Code
        lv_location        "18 Location
*        lv_print_loc       "19 Print Location - commented on 22/12
        lv_addr1           "20 Beneficiary Addr1
        lv_addr2           "21 Beneficiary Addr2
        lv_addr3           "22 Beneficiary Addr3
        lv_city            "23 City
        lv_zip             "24 Zip
        lv_state           "25 State
        lv_email           "26 Email
        lv_mobile          "27 Mobile
        lv_pay_det1        "28 Payment Details 1
        lv_pay_det2        "29 Payment Details 2
*        lv_pay_det3        "30 Payment Details 3
*        lv_pay_det4        "31 Payment Details 4
        lv_delivery_mode   "32 User / Delivery Mode
        lv_pay_det3        "30 Payment Details 3 -- as suggested by bank on 22/12
      INTO lv_d_line SEPARATED BY gc_sep.

      lv_d_line = lv_d_line && gc_sep.

      APPEND lv_d_line TO rt_lines.

      "---- MULTIPLE E per D
      DATA: lv_seq         TYPE i,
            lv_seq_c       TYPE string,
            lv_amt_a       TYPE string,
            lv_amt_w       TYPE string,
            lv_amt_r       TYPE p DECIMALS 2,
            lv_amt_r_s     TYPE string,
            lv_amt_r_abs   TYPE p DECIMALS 2,
            lv_amt_r_abs_s TYPE string.

      DATA lv_e_line TYPE string.

      LOOP AT lt_a ASSIGNING FIELD-SYMBOL(<ls_a>)
           WHERE paymentdocument = <ls_pay>-paymentdocument.

        lv_seq = lv_seq + 1.

*        lv_amt_a = |{ <ls_a>-amountintransactioncurrency SIGN = LEFT DECIMALS = 2 }|.
        lv_amt_a = |{ abs( <ls_a>-amountintransactioncurrency ) SIGN = LEFT DECIMALS = 2 }|.
*        lv_amt_w = |{ <ls_a>-withholdingtaxamount SIGN = LEFT DECIMALS = 2 }|.
        lv_amt_w = |{ abs( <ls_a>-withholdingtaxamount ) SIGN = LEFT DECIMALS = 2 }|.

        lv_amt_r = <ls_a>-amountintransactioncurrency - <ls_a>-withholdingtaxamount.
        lv_amt_r_s = |{ lv_amt_r SIGN = LEFT DECIMALS = 2 }|.

*        lv_amt_r_abs = |{ abs( lv_amt_r ) }|.
*        lv_amt_r_abs_s = lv_amt_r_abs.

        " Gross = Net + WHT
        DATA lv_gross TYPE p DECIMALS 2.
        lv_gross = abs( <ls_a>-amountintransactioncurrency )
                   + abs( <ls_a>-withholdingtaxamount ).

        lv_amt_r_abs_s = |{ lv_gross DECIMALS = 2 }|.
        CONDENSE lv_amt_r_abs_s NO-GAPS.

        lv_seq_c = |{ lv_seq }|.

        CONDENSE lv_seq_c NO-GAPS.
        CONDENSE lv_amt_a NO-GAPS.
        CONDENSE lv_amt_w NO-GAPS.
        CONDENSE lv_amt_r_s NO-GAPS.
        CONDENSE lv_amt_r_abs_s NO-GAPS.

        CLEAR lv_e_line.

        CONCATENATE
          gc_rec_advice                    " E
          lv_seq_c                         " 1 Serial No
          <ls_a>-paymentdocument           " 2 Payment Document
          'NA'                             " 3 Filler
          <ls_a>-documentdate              " 4 Invoice / Document Date
          <ls_a>-documentreferenceid       " 5 Reference No (Invoice)
          lv_amt_r_abs_s                   " 6 Gross Amount
          '0.00'                           " 7 Advance
          lv_amt_w                         " 8 Withholding Tax
          lv_amt_a                         " 9 Net Amount
          'NA'                             " 10 Enrichment 7
          'NA'                             " 11 Enrichment 8
        INTO lv_e_line SEPARATED BY gc_sep.

        CONDENSE lv_e_line NO-GAPS.

*        CONCATENATE
*          gc_rec_advice                    " E
*          lv_seq_c                         " 1 Sequence
*          <ls_a>-accountingdocument        " 2 Journal Entry No
*          <ls_a>-documentreferenceid       " 3 Reference
*          <ls_a>-documentdate              " 4 Document Date
*          lv_amt_a                         " 5 Amount
*          lv_amt_w                         " 6 Withholding Tax
*          lv_amt_r_s                       " 7 Reduction
*          ''                               " 8 filler
*          <ls_a>-documentitemtext          " 9 Item Text
*          <ls_a>-postingdate               " 10 Posting Date
*          lv_amt_r_abs_s                   " 11 Abs Reduction
*          'NA'                             " 12 filler
*        INTO lv_e_line SEPARATED BY gc_sep.

        APPEND lv_e_line TO rt_lines.

      ENDLOOP.

      CLEAR lv_seq.
    ENDLOOP.


  ENDMETHOD.


  METHOD build_trailer_line.

    DATA: lv_total   TYPE i_paymentproposalitem-amountintransactioncurrency VALUE '0',
          lv_total_s TYPE string.

    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      lv_total = lv_total + abs( <ls_pay>-paytamountincocodecurrency ).
    ENDLOOP.

    lv_total_s = format_amount_15_2( iv_amount = lv_total ).

    DATA(lv_tot_batches) = 1.
    DATA(lv_tot_batches_s) = |{ lv_tot_batches }|.

    CONCATENATE
      gc_rec_trailer       "1
      lv_tot_batches_s     "2 Tot_Instruments (batches)
      lv_total_s           "3 Tot_Amount
    INTO rv_line SEPARATED BY gc_sep.

    rv_line = rv_line && gc_sep.

  ENDMETHOD.


  METHOD get_client_code.
    rv_client_code = 'PMPL12'.
  ENDMETHOD.


  METHOD get_file_name.

    " iv_paymentrundate is DATS YYYYMMDD
    DATA(lv_ddmmyy) = |{ iv_paymentrundate+6(2) }{ iv_paymentrundate+4(2) }{ iv_paymentrundate+2(2) }|.

    DATA(lv_seq) = iv_seq_no.
    IF lv_seq IS INITIAL.
      lv_seq = '001'.
    ENDIF.

    rv_filename = |{ lv_ddmmyy }{ lv_seq }.TXT|.

  ENDMETHOD.


  METHOD format_date_ddmmyyyy.

    rv_date = |{ iv_date+6(2) }{ iv_date+4(2) }{ iv_date(4) }|.

  ENDMETHOD.


  METHOD format_date_dd_mm_yyyy.

    rv_date = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date(4) }|.

  ENDMETHOD.


  METHOD format_amount_15_2.

    "format with 2 decimals; remove spaces
    rv_amount = |{ iv_amount DECIMALS = 2 SIGN = LEFT }|.

  ENDMETHOD.


  METHOD determine_payment_type.

    DATA(lv_amount) = is_payment-paytamountincocodecurrency.

    IF lv_amount < '200000'.
      rv_type = 'NEFT'.
    ELSE.
      rv_type = 'RTGS'.
    ENDIF.

    " Kotak to Kotak – IFSC starts with KKBK => IFT
    IF is_payment-payeebankkey CP 'KKBK*'.
      rv_type = 'IFT'.
    ENDIF.

  ENDMETHOD.


  METHOD get_payment_ref_no.

    rv_refno = |{ is_payment-paymentdocument }_{ is_payment-paymentrundate+0(4) }|.

*    rv_refno = |{ is_payment-paymentrunid }_{ is_payment-paymentrundate }|.

  ENDMETHOD.


  METHOD build_advice_line.

    DATA: lv_seq      TYPE char1 VALUE 1,
          lv_doc_no   TYPE string,
          lv_doc_date TYPE string,
          lv_ref_no   TYPE string,
          lv_orig_amt TYPE string,
          lv_wht_amt  TYPE string,
          lv_charges  TYPE string,
          lv_net_amt  TYPE string,
          lv_enrich7  TYPE string,
          lv_enrich8  TYPE string.

    lv_doc_no   = is_payment-paymentdocument.
    lv_doc_date = format_date_dd_mm_yyyy( iv_date = is_payment-paymentrundate ).
    lv_ref_no   = ''.

    lv_orig_amt = format_amount_15_2(
                    iv_amount = is_payment-paytamountincocodecurrency ).

    lv_wht_amt  = '0.00'.
    lv_charges  = '0.00'.
    lv_net_amt  = lv_orig_amt && ' +'.
    lv_enrich7  = 'NA'.
    lv_enrich8  = 'NA'.

    CONCATENATE
      gc_rec_advice      " E
      lv_seq             " 1  (sequence – if you loop items, increase this)
      lv_doc_no          " 2  Document Number
      'NA'               " 3  as per sample
      lv_doc_date        " 4  Document Date
      lv_ref_no          " 5  Reference No
      lv_orig_amt        " 6  Original Amount
      lv_wht_amt         " 7  Withholding Tax Amount
      lv_charges         " 8  Charges
      lv_net_amt         " 9  Net Amount + sign
      lv_enrich7         " 10 Enrichment 7
      lv_enrich8         " 11 Enrichment 8
      INTO rv_line
      SEPARATED BY gc_sep.

    rv_line = rv_line && gc_sep.

  ENDMETHOD.
ENDCLASS.
