" ----------------------------------------------------------------------
" 1. BUFFER CLASS: Holds data in memory during the LUW
" ----------------------------------------------------------------------
CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    TYPES: mt_zsupp_eval TYPE STANDARD TABLE OF zsupp_eval_db WITH EMPTY KEY.
    CLASS-DATA: mt_create TYPE mt_zsupp_eval,
                mt_update TYPE mt_zsupp_eval,
                mt_delete TYPE mt_zsupp_eval.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.

" ----------------------------------------------------------------------
" 2. SAVER CLASS: The only place where DB COMMIT happens
" ----------------------------------------------------------------------
CLASS lcl_saver DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
ENDCLASS.

CLASS lcl_saver IMPLEMENTATION.
  METHOD finalize.          ENDMETHOD.
  METHOD check_before_save. ENDMETHOD.

  METHOD save.
    " Insert with safety net for duplicate keys
    IF lcl_buffer=>mt_create IS NOT INITIAL.
      INSERT zsupp_eval_db FROM TABLE @lcl_buffer=>mt_create ACCEPTING DUPLICATE KEYS.
    ENDIF.

    IF lcl_buffer=>mt_update IS NOT INITIAL.
      UPDATE zsupp_eval_db FROM TABLE @lcl_buffer=>mt_update.
    ENDIF.

    IF lcl_buffer=>mt_delete IS NOT INITIAL.
      DELETE zsupp_eval_db FROM TABLE @lcl_buffer=>mt_delete.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    CLEAR: lcl_buffer=>mt_create, lcl_buffer=>mt_update, lcl_buffer=>mt_delete.
  ENDMETHOD.
ENDCLASS.

" ----------------------------------------------------------------------
" 3. HANDLER DEFINITION
" ----------------------------------------------------------------------
CLASS lhc_SupplierEval DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      create FOR MODIFY
        IMPORTING entities FOR CREATE SupplierEval,
      update FOR MODIFY
        IMPORTING entities FOR UPDATE SupplierEval,
      delete FOR MODIFY
        IMPORTING keys FOR DELETE SupplierEval,
      read FOR READ
        IMPORTING keys FOR READ SupplierEval RESULT result,
      lock FOR LOCK
        IMPORTING keys FOR LOCK SupplierEval,
      SetPerfectScore FOR MODIFY
        IMPORTING keys FOR ACTION SupplierEval~SetPerfectScore RESULT result,
      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR SupplierEval RESULT result.
ENDCLASS.

" ----------------------------------------------------------------------
" 4. HANDLER IMPLEMENTATION
" ----------------------------------------------------------------------
CLASS lhc_SupplierEval IMPLEMENTATION.

  METHOD create.
    GET TIME STAMP FIELD DATA(lv_ts).

    LOOP AT entities INTO DATA(ls_entity).
      " Check for Duplicate ID to catch it before it even reaches the Saver
      SELECT SINGLE supplier_id FROM zsupp_eval_db
        WHERE supplier_id = @ls_entity-SupplierId
        INTO @DATA(lv_check).

      IF sy-subrc = 0.
        APPEND VALUE #( %cid = ls_entity-%cid SupplierId = ls_entity-SupplierId ) TO failed-suppliereval.
        CONTINUE.
      ENDIF.

      DATA: lv_q TYPE i, lv_d TYPE i.
      lv_q = ls_entity-QualityScore.
      lv_d = ls_entity-DeliveryScore.
      DATA(lv_overall) = ( lv_q + lv_d ) / 2.

      DATA(ls_db) = VALUE zsupp_eval_db(
        client          = sy-mandt
        supplier_id     = ls_entity-SupplierId
        supplier_name   = ls_entity-SupplierName
        industry        = ls_entity-Industry
        country_code    = ls_entity-CountryCode
        evaluation_date = ls_entity-EvaluationDate
        quality_score   = ls_entity-QualityScore
        delivery_score  = ls_entity-DeliveryScore
        overall_score   = lv_overall
        eval_comments   = ls_entity-EvalComments
        created_by      = sy-uname
        created_at      = lv_ts
      ).

      APPEND ls_db TO lcl_buffer=>mt_create.
      APPEND VALUE #( %cid = ls_entity-%cid SupplierId = ls_entity-SupplierId ) TO mapped-suppliereval.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    GET TIME STAMP FIELD DATA(lv_ts).

    LOOP AT entities INTO DATA(ls_entity).
      SELECT SINGLE * FROM zsupp_eval_db
        WHERE supplier_id = @ls_entity-SupplierId
        INTO @DATA(ls_db).

      IF sy-subrc = 0.
        IF ls_entity-%control-SupplierName = if_abap_behv=>mk-on. ls_db-supplier_name = ls_entity-SupplierName. ENDIF.
        IF ls_entity-%control-Industry     = if_abap_behv=>mk-on. ls_db-industry      = ls_entity-Industry.     ENDIF.
        IF ls_entity-%control-QualityScore  = if_abap_behv=>mk-on. ls_db-quality_score   = ls_entity-QualityScore.  ENDIF.
        IF ls_entity-%control-DeliveryScore = if_abap_behv=>mk-on. ls_db-delivery_score  = ls_entity-DeliveryScore. ENDIF.
        IF ls_entity-%control-EvalComments  = if_abap_behv=>mk-on. ls_db-eval_comments   = ls_entity-EvalComments.  ENDIF.

        ls_db-overall_score = ( ls_db-quality_score + ls_db-delivery_score ) / 2.
        ls_db-last_changed_by = sy-uname.
        ls_db-last_changed_at = lv_ts.

        APPEND ls_db TO lcl_buffer=>mt_update.
      ELSE.
        APPEND VALUE #( %tky = ls_entity-%tky ) TO failed-suppliereval.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( supplier_id = ls_key-SupplierId ) TO lcl_buffer=>mt_delete.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    SELECT * FROM zsupp_eval_db
      FOR ALL ENTRIES IN @keys
      WHERE supplier_id = @keys-SupplierId
      INTO TABLE @DATA(lt_db).

    result = VALUE #( FOR ls_db IN lt_db (
                         SupplierId      = ls_db-supplier_id
                         SupplierName    = ls_db-supplier_name
                         Industry        = ls_db-industry
                         CountryCode     = ls_db-country_code
                         EvaluationDate  = ls_db-evaluation_date
                         QualityScore    = ls_db-quality_score
                         DeliveryScore   = ls_db-delivery_score
                         OverallScore    = ls_db-overall_score
                         EvalComments    = ls_db-eval_comments
                         CreatedBy       = ls_db-created_by
                         CreatedAt       = ls_db-created_at
                         LastChangedBy   = ls_db-last_changed_by
                         LastChangedAt   = ls_db-last_changed_at
                      ) ).
  ENDMETHOD.

  METHOD lock.
    " Logic for locking unmanaged resources goes here
  ENDMETHOD.

  METHOD SetPerfectScore.
    READ ENTITIES OF zi_suppliereval IN LOCAL MODE
      ENTITY SupplierEval ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_eval).

    MODIFY ENTITIES OF zi_suppliereval IN LOCAL MODE
      ENTITY SupplierEval
        UPDATE FIELDS ( QualityScore DeliveryScore OverallScore EvalComments )
        WITH VALUE #( FOR ls_eval IN lt_eval ( %tky = ls_eval-%tky
                                               QualityScore  = 100
                                               DeliveryScore = 100
                                               OverallScore  = 100
                                               EvalComments  = 'Action: Perfect Score!' ) ).

    READ ENTITIES OF zi_suppliereval IN LOCAL MODE
      ENTITY SupplierEval ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated).

    result = VALUE #( FOR ls_upd IN lt_updated ( %tky = ls_upd-%tky %param = ls_upd ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_suppliereval IN LOCAL MODE
      ENTITY SupplierEval FIELDS ( OverallScore ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_eval).

    result = VALUE #( FOR ls_eval IN lt_eval ( %tky = ls_eval-%tky
                        %action-SetPerfectScore = COND #( WHEN ls_eval-OverallScore = 100
                                                          THEN if_abap_behv=>fc-o-disabled
                                                          ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

ENDCLASS.
