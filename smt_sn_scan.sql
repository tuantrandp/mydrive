CREATE OR REPLACE PROCEDURE MES1.SMT_SN_SCAN (
    IN_EVENT    IN     VARCHAR2,
    IN_DATA     IN     CLOB,
    RES            OUT VARCHAR2,
    RES_TABLE      OUT SYS_REFCURSOR)
IS
    ------------------Created by Tuan Tran 2025/08/27-------------------------
    T_IN_DATA         JSON;
    T_COUNT           NUMBER;
    T_INPUT_QTY       NUMBER;
    T_QTY             NUMBER;
    T_TARGET_QTY      NUMBER;
    T_WORK_FLAG       VARCHAR2 (1);
    T_LINE_NAME       VARCHAR2 (20);
    T_FLAG            VARCHAR2 (20);
    T_WO              VARCHAR2 (20);
    T_WO_WIP          VARCHAR2 (20);
    T_MO_NUMBER       VARCHAR2 (20);
    T_EMP_NO          VARCHAR2 (20);
    T_SPECIAL_ROUTE   VARCHAR2 (20);
    T_IP_CLIENT       VARCHAR2 (50);
    T_STATION_NAME    VARCHAR2 (100);
    T_MODEL_TYPE      VARCHAR2 (100);
    T_KP_NO           VARCHAR2 (100);
    T_STATION_NO      VARCHAR2 (100);
    T_STATION_TEMP    VARCHAR2 (100);
    T_WIP_GROUP       VARCHAR2 (100);
    T_STATION         VARCHAR2 (100);
    T_WO_INPUT        VARCHAR2 (100);
    T_START_TIME      VARCHAR2 (100);
    T_SN              VARCHAR2 (200);
    T_TR_CODE         VARCHAR2 (200);
    T_MODEL_NAME      VARCHAR2 (200);
    T_GROUP_NEXT      VARCHAR2 (200);
    T_P_NO            VARCHAR2 (200);
    T_NEXT_STEP       VARCHAR2 (1000);
    T_DATA_SCAN       VARCHAR2 (3000);
    T_EXIT            EXCEPTION;
BEGIN
    RES := 'NG';
    T_IN_DATA := JSON (IN_DATA);

    OPEN RES_TABLE FOR SELECT 'NO TABLE RETURN' MESSAGE FROM DUAL;

    ---------------- BEGIN: CONFIG LINE ----------------
    IF IN_EVENT = 'GET_LINE_STATION'
    THEN
        T_IP_CLIENT := JSON_EXT.GET_STRING (T_IN_DATA, 'IP_CLIENT');

        DELETE MES4.R_PTH_QTY_TEMP
         WHERE EDIT_TIME < SYSDATE - 31;

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_MES_LOG
         WHERE PRG_NAME = 'SMT_SN_SCAN' AND IP_CLIENT = T_IP_CLIENT;

        IF T_COUNT = 0
        THEN
            OPEN RES_TABLE FOR
                SELECT 'NOT_CONFIG;NOT_CONFIG' AS LINE_STATION FROM DUAL;
        ELSE
            OPEN RES_TABLE FOR
                SELECT ACTION_DESC     AS LINE_STATION
                  FROM MES4.R_MES_LOG
                 WHERE     PRG_NAME = 'SMT_SN_SCAN'
                       AND IP_CLIENT = T_IP_CLIENT
                       AND TIME IN
                               (SELECT MAX (TIME)
                                  FROM MES4.R_MES_LOG
                                 WHERE     PRG_NAME = 'SMT_SN_SCAN'
                                       AND IP_CLIENT = T_IP_CLIENT)
                       AND ROWNUM = 1;
        END IF;
    ELSIF IN_EVENT = 'GET_CMB_LINE'
    THEN
        OPEN RES_TABLE FOR   SELECT DISTINCT LINE_NAME, LINE_SECTION
                               FROM MES1.C_LINE_STATION
                           ORDER BY LINE_NAME;
    ELSIF IN_EVENT = 'GET_CMB_STATION'
    THEN
        T_LINE_NAME := JSON_EXT.GET_STRING (T_IN_DATA, 'LINE_NAME');

        OPEN RES_TABLE FOR   SELECT DISTINCT STATION_NAME
                               FROM MES1.C_LINE_STATION
                              WHERE LINE_NAME || LINE_SECTION = T_LINE_NAME
                           ORDER BY STATION_NAME;
    ELSIF IN_EVENT = 'CONFIG_LINE'
    THEN
        T_LINE_NAME := JSON_EXT.GET_STRING (T_IN_DATA, 'LINE_STATION');
        T_EMP_NO := JSON_EXT.GET_STRING (T_IN_DATA, 'LOGIN_EMP');
        T_IP_CLIENT := JSON_EXT.GET_STRING (T_IN_DATA, 'IP_CLIENT');

        INSERT INTO MES4.R_MES_LOG
             VALUES (T_EMP_NO,
                     'SMT_SN_SCAN',
                     T_IP_CLIENT,
                     'CONFIG_LINE',
                     T_LINE_NAME,
                     SYSDATE);
    ---------------- END: CONFIG LINE ----------------

    ---------------- BEGIN: MATERIAL SCAN ----------------
    ELSIF IN_EVENT = 'MATERIAL_SCAN'
    THEN
        T_DATA_SCAN := JSON_EXT.GET_STRING (T_IN_DATA, 'DATA_SCAN');
        T_STATION_NAME := JSON_EXT.GET_STRING (T_IN_DATA, 'STATION_NAME');

        IF T_DATA_SCAN = 'UNDO'
        THEN
            DELETE FROM MES4.R_AP_TEMP
                  WHERE     DATA1 = 'SCADA-GW28'
                        AND DATA2 = (SELECT STATION_NO
                                       FROM MES1.C_GW28_CONFIG
                                      WHERE STATION_NAME = T_STATION_NAME);

            RES := 'OK UNDO ==> INPUT EMP ?';
        ELSE
            SELECT COUNT (*)
              INTO T_COUNT
              FROM MES1.C_GW28_CONFIG
             WHERE STATION_NAME = T_STATION_NAME;

            IF T_COUNT = 0
            THEN
                RES :=
                    'STATION_NAME IS NOT CONFIGURED IN MES1.C_GW28_CONFIG. PLEASE CALL IT CHECK!';
                RAISE T_EXIT;
            END IF;

            SELECT STATION_NO
              INTO T_STATION_NO
              FROM MES1.C_GW28_CONFIG
             WHERE STATION_NAME = T_STATION_NAME AND ROWNUM = 1;

            SELECT COUNT (*)
              INTO T_COUNT
              FROM MES4.R_AP_TEMP
             WHERE     DATA1 = 'SCADA-GW28'
                   AND DATA2 = T_STATION_NO
                   AND DATA3 = '1';

            IF T_COUNT = 0
            THEN
                MES1.PUB_CHECK_EMP (T_DATA_SCAN, T_STATION_NO, RES);

                IF SUBSTR (RES, 1, 2) <> 'OK'
                THEN
                    RAISE T_EXIT;
                END IF;

                RES := 'OK EMP ==> INPUT: ACTION CODE ?';
            ELSE
                MES1.G_STATION_SP_WORKTYPE (T_DATA_SCAN, T_STATION_NO, RES);

                IF SUBSTR (RES, 1, 2) <> 'OK'
                THEN
                    RAISE T_EXIT;
                END IF;

                SELECT COUNT (*)
                  INTO T_COUNT
                  FROM MES4.R_AP_TEMP
                 WHERE     DATA1 = 'SCADA-GW28'
                       AND DATA2 = T_STATION_NO
                       AND DATA3 IN
                               (SELECT MAX (TO_NUMBER (DATA3))
                                  FROM MES4.R_AP_TEMP
                                 WHERE     DATA1 = 'SCADA-GW28'
                                       AND DATA2 = T_STATION_NO)
                       AND DATA6 IS NOT NULL;

                IF T_COUNT = 0
                THEN
                    RES :=
                        'DATA6 IN MES4.R_AP_TEMP IS NULL. PLEASE CALL IT CHECK!';
                    RAISE T_EXIT;
                END IF;

                SELECT DATA6
                  INTO T_NEXT_STEP
                  FROM MES4.R_AP_TEMP
                 WHERE     DATA1 = 'SCADA-GW28'
                       AND DATA2 = T_STATION_NO
                       AND DATA3 IN
                               (SELECT MAX (TO_NUMBER (DATA3))
                                  FROM MES4.R_AP_TEMP
                                 WHERE     DATA1 = 'SCADA-GW28'
                                       AND DATA2 = T_STATION_NO)
                       AND ROWNUM = 1;

                RES := 'OK ==> INPUT: ' || T_NEXT_STEP || ' ?';
            END IF;
        END IF;
    ELSIF IN_EVENT = 'GET_WO_DATA_NO_LOG'
    THEN
        T_WO := JSON_EXT.GET_STRING (T_IN_DATA, 'WO');
        T_STATION_NAME := JSON_EXT.GET_STRING (T_IN_DATA, 'STATION_NAME');

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_WO_BASE
         WHERE WO = T_WO;

        IF T_COUNT = 0
        THEN
            RES := T_WO || ' - WO DOES NOT EXIST ON SYSTEM.';
            RAISE T_EXIT;
        END IF;

        SELECT WO_QTY
          INTO T_TARGET_QTY
          FROM MES4.R_WO_BASE
         WHERE WO = T_WO AND ROWNUM = 1;

        SELECT COUNT (DISTINCT (P_SN))
          INTO T_INPUT_QTY
          FROM MES4.R_TR_PRODUCT_DETAIL
         WHERE     WO = T_WO
               AND TR_CODE LIKE '%' || SUBSTR (T_STATION_NAME, -3) || '%';

        OPEN RES_TABLE FOR
            SELECT ROWNUM     AS NO,
                   TR_SN,
                   KP_NO,
                   QTY,
                   STANDARD_QTY,
                   EXT_QTY,
                   DATE_CODE,
                   LOT_CODE,
                   BUFFER_QTY,
                   TRUE_EXT_QTY,
                   WO,
                   TARGET_QTY,
                   INPUT_QTY
              FROM (  SELECT DISTINCT
                             A.TR_SN,
                             A.KP_NO,
                             A.QTY,
                             B.STANDARD_QTY,
                             A.EXT_QTY,
                             A.DATE_CODE,
                             A.LOT_CODE,
                             C.BUFFER_QTY,
                             A.EXT_QTY - C.BUFFER_QTY     AS TRUE_EXT_QTY,
                             T_WO                         AS WO,
                             T_TARGET_QTY                 AS TARGET_QTY,
                             T_INPUT_QTY                  AS INPUT_QTY
                        FROM MES4.R_TR_SN_WIP  A,
                             MES4.R_STATION_WIP B,
                             MES1.C_STATION_KP C
                       WHERE     A.STATION = T_STATION_NAME
                             AND A.WO = T_WO
                             AND A.TR_SN = B.TR_SN
                             AND C.P_NO = B.P_NO
                             AND B.KP_NO = C.KP_NO
                    ORDER BY A.EXT_QTY);
    ---------------- END: MATERIAL SCAN ----------------

    ---------------- BEGIN: SN SCAN ----------------
    ELSIF IN_EVENT = 'SN_SCAN'
    THEN
        T_SN := JSON_EXT.GET_STRING (T_IN_DATA, 'SN');
        T_STATION_NAME := JSON_EXT.GET_STRING (T_IN_DATA, 'STATION_NAME');
        T_WO_INPUT := JSON_EXT.GET_STRING (T_IN_DATA, 'WO_INPUT');
        T_EMP_NO := JSON_EXT.GET_STRING (T_IN_DATA, 'EMP_NO');

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_TR_CODE_LIST
         WHERE STATION = T_STATION_NAME AND TR_CODE IS NOT NULL;

        IF T_COUNT = 0
        THEN
            RES := T_SN || ' - NO TR_CODE DATA (' || T_STATION_NAME || ')';
            RAISE T_EXIT;
        END IF;

        SELECT START_TIME, TR_CODE
          INTO T_START_TIME, T_TR_CODE
          FROM (  SELECT START_TIME, TR_CODE
                    FROM MES4.R_TR_CODE_LIST
                   WHERE STATION = T_STATION_NAME AND TR_CODE IS NOT NULL
                ORDER BY START_TIME DESC)
         WHERE ROWNUM = 1;

        T_STATION_TEMP := SUBSTR (T_TR_CODE, 1, 8);

        SELECT COUNT (*)
          INTO T_COUNT
          FROM SFISM4.R107@SFCODB
         WHERE SERIAL_NUMBER = T_SN;

        IF T_COUNT = 0
        THEN
            RES := T_SN || ' - THIS SN DOES NOT EXIST ON SYSTEM.';
            RAISE T_EXIT;
        END IF;

        SELECT SPECIAL_ROUTE,
               WIP_GROUP,
               MO_NUMBER,
               MODEL_NAME
          INTO T_SPECIAL_ROUTE,
               T_WIP_GROUP,
               T_MO_NUMBER,
               T_MODEL_NAME
          FROM SFISM4.R107@SFCODB
         WHERE SERIAL_NUMBER = T_SN AND ROWNUM = 1;

        ---- BEGIN: CHECK ROUTE ----

        SELECT COUNT (*)
          INTO T_COUNT
          FROM SFIS1.C_ROUTE_CONTROL_T@SFCODB
         WHERE ROUTE_CODE = T_SPECIAL_ROUTE AND STEP_SEQUENCE = '1';

        IF T_COUNT >= 1
        THEN
            SELECT GROUP_NEXT
              INTO T_GROUP_NEXT
              FROM SFIS1.C_ROUTE_CONTROL_T@SFCODB
             WHERE     ROUTE_CODE = T_SPECIAL_ROUTE
                   AND STEP_SEQUENCE = '1'
                   AND ROWNUM = 1;
        END IF;

        IF T_WIP_GROUP = T_GROUP_NEXT
        THEN
            RES := T_SN || ' - PLEASE CHECK THE ROUTE OF SN.';
            RAISE T_EXIT;
        END IF;

        ---- END: CHECK ROUTE ----

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_STATION_WIP
         WHERE STATION = T_STATION_NAME;

        IF T_COUNT = 0
        THEN
            RES := T_STATION_NAME || ' - THIS STATION IS NOT ONLINE.';
            RAISE T_EXIT;
        END IF;

        SELECT WO, P_NO, STATION
          INTO T_WO, T_P_NO, T_STATION
          FROM MES4.R_STATION_WIP
         WHERE STATION = T_STATION_NAME AND ROWNUM = 1;

        IF     '00' || T_MO_NUMBER <> T_WO
           AND '00' || T_MO_NUMBER <> '00' || T_WO
        THEN
            SELECT COUNT (*)
              INTO T_COUNT
              FROM SFIS1.C_MODEL_DESC_T@SFCODB
             WHERE MODEL_NAME = T_MODEL_NAME;

            IF T_COUNT > 0
            THEN
                SELECT MODEL_TYPE
                  INTO T_MODEL_TYPE
                  FROM SFIS1.C_MODEL_DESC_T@SFCODB
                 WHERE MODEL_NAME = T_MODEL_NAME AND ROWNUM = 1;

                IF INSTR (T_MODEL_TYPE, '200') > 0
                THEN
                    MES1.CHECK_ROUTE_CODE (T_SN, RES);

                    IF RES <> 'OK'
                    THEN
                        RAISE T_EXIT;
                    END IF;

                    SELECT COUNT (*)
                      INTO T_COUNT
                      FROM MES4.R_TR_PRODUCT_DETAIL
                     WHERE     P_SN = T_SN
                           AND (TR_CODE LIKE '%CT1%' OR TR_CODE LIKE '%BT1%');

                    IF T_COUNT <> 0
                    THEN
                        RES :=
                            T_SN || ' - THIS SN IS OK. PLEASE SCAN OTHER SN.';
                        RAISE T_EXIT;
                    END IF;

                    INSERT INTO MES4.R_TR_PRODUCT_DETAIL (WO,
                                                          P_SN,
                                                          TR_CODE,
                                                          WORK_FLAG,
                                                          WORK_TIME)
                         VALUES ('00' || T_MO_NUMBER,
                                 T_SN,
                                 T_STATION_NAME,
                                 '0',
                                 SYSDATE);

                    COMMIT;
                    RES := 'OK SN, SCAN NEXT SN?';
                    RAISE T_EXIT;
                END IF;
            END IF;

            SELECT COUNT (*)
              INTO T_COUNT
              FROM SFISM4.R107@SFCODB  A
                   INNER JOIN MES4.R_STATION_WIP B ON A.MODEL_NAME = B.P_NO
             WHERE     A.MO_NUMBER = T_MO_NUMBER
                   AND B.WO = '00' || T_MO_NUMBER
                   AND A.SERIAL_NUMBER = T_SN
                   AND (B.STATION LIKE '%CT1%' OR B.STATION LIKE '%BT1%');

            IF T_COUNT = 0
            THEN
                RES := T_MO_NUMBER || ' - ME HAS NOT SETUP MATERIAL TABLE.';
                RAISE T_EXIT;
            ELSE
                RES :=
                       T_MO_NUMBER
                    || ' - THIS PRODUCT IS RUNNING ON OTHER LINE.';
                RAISE T_EXIT;
            END IF;
        END IF;

        ---- BEGIN: SSN SCAN ----

        SELECT COUNT (*)
          INTO T_COUNT
          FROM SFIS1.C_ROUTE_CONTROL_T@SFCODB
         WHERE ROUTE_CODE = T_SPECIAL_ROUTE AND GROUP_NEXT = 'SNSCAN';

        IF T_COUNT > 0
        THEN
            SELECT COUNT (*)
              INTO T_COUNT
              FROM MES4.R_TR_SN_WIP A, MES4.R_STATION_WIP B
             WHERE     A.STATION = T_STATION
                   AND A.WO = T_WO
                   AND A.TR_SN = B.TR_SN;

            IF T_COUNT = 0
            THEN
                RES := 'THE TRSN CHECK OUT TO WRONG WO.';
                RAISE T_EXIT;
            END IF;

            SELECT COUNT (*)
              INTO T_COUNT
              FROM MES4.R_TR_SN_WIP A, MES4.R_STATION_WIP B
             WHERE     A.STATION = T_STATION
                   AND A.WO = T_WO
                   AND A.TR_SN = B.TR_SN
                   AND (A.EXT_QTY = 0 OR A.EXT_QTY < 0);

            IF T_COUNT > 0
            THEN
                RES := 'PLEASE CHECKOUT MATERIAL FOR PRODUCTION LINE.';
                RAISE T_EXIT;
            END IF;

            SELECT COUNT (*)
              INTO T_COUNT
              FROM SFISM4.R107@SFCODB
             WHERE SERIAL_NUMBER = T_SN AND WIP_GROUP = 'SNSCAN';

            IF T_COUNT > 0
            THEN
                MES1.CHECK_ROUTE_CODE (T_SN, RES);

                IF RES = 'OK'
                THEN
                    RES := 'SN IS OK, PLEASE SCAN OTHER SN.';
                END IF;

                RAISE T_EXIT;
            ELSE
                RES := T_SN || ' - WIP_GROUP OF SN <> SNSCAN.';
                RAISE T_EXIT;
            END IF;
        ELSE
            SELECT COUNT (*)
              INTO T_COUNT
              FROM MES4.R_TR_PRODUCT_DETAIL
             WHERE     P_SN = T_SN
                   AND TR_CODE LIKE '%' || SUBSTR (T_STATION_NAME, -3) || '%';

            IF T_COUNT > 0
            THEN
                RES :=
                    'SN HAS SCAN 1 TIME!, PLEASE SCAN NEXT STATION OR CHECK ROUTE AGAIN!';
                RAISE T_EXIT;
            END IF;
        END IF;

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_STATION_WIP
         WHERE STATION = T_STATION_NAME AND WO = T_WO;

        IF T_COUNT = 0
        THEN
            SELECT COUNT (*)
              INTO T_COUNT
              FROM (SELECT WO, P_NO, P_VERSION
                      FROM MES4.R_STATION_WIP
                     WHERE STATION = T_STATION_NAME AND ROWNUM = 1) A,
                   (SELECT P_NO, P_VERSION
                      FROM MES4.R_WO_BASE
                     WHERE WO = T_WO) B
             WHERE A.P_NO = B.P_NO AND A.P_VERSION = B.P_VERSION;

            IF T_COUNT = 0
            THEN
                RES :=
                    'THE MATERIAL IS RUNNING OUT, PLEASE CHECKOUT FOR PRODUCTION LINE!';
                RAISE T_EXIT;
            END IF;

            SELECT A.WO
              INTO T_WO_WIP
              FROM (SELECT WO, P_NO, P_VERSION
                      FROM MES4.R_STATION_WIP
                     WHERE STATION = T_STATION_NAME AND ROWNUM = 1) A,
                   (SELECT P_NO, P_VERSION
                      FROM MES4.R_WO_BASE
                     WHERE WO = T_WO) B
             WHERE     A.P_NO = B.P_NO
                   AND A.P_VERSION = B.P_VERSION
                   AND ROWNUM = 1;
        ELSE
            SELECT WO
              INTO T_WO_WIP
              FROM MES4.R_STATION_WIP
             WHERE STATION = T_STATION_NAME AND WO = T_WO AND ROWNUM = 1;
        END IF;

        -- TARGET_QTY
        SELECT WO_QTY
          INTO T_TARGET_QTY
          FROM MES4.R_WO_BASE
         WHERE WO = T_WO AND ROWNUM = 1;

        -- INPUT_QTY
        SELECT COUNT (DISTINCT (P_SN))
          INTO T_INPUT_QTY
          FROM MES4.R_TR_PRODUCT_DETAIL
         WHERE     WO = T_WO
               AND TR_CODE LIKE '%' || SUBSTR (T_STATION_NAME, -3) || '%';

        T_QTY := 0;

        --------------- BEGIN: CHECK LAST STATION ---------------

        T_FLAG := MES1.IS_LAST_STATION (T_STATION_NAME, T_WO);

        IF T_FLAG = 'TRUE'
        THEN
            T_WORK_FLAG := '1';
        ELSE
            T_WORK_FLAG := '0';
        END IF;

        --------------- END: CHECK LAST STATION ---------------

        IF T_WO_INPUT IS NULL
        THEN
            T_WO_INPUT := T_WO;
        END IF;

        SELECT COUNT (*)
          INTO T_COUNT
          FROM MES4.R_STATION_WIP
         WHERE     WO = T_WO_WIP
               AND STATION = T_STATION_NAME
               AND TR_SN IS NULL
               AND SHORTAGE_FLAG = '0';

        IF T_COUNT > 0
        THEN
            SELECT KP_NO
              INTO T_KP_NO
              FROM MES4.R_STATION_WIP
             WHERE     WO = T_WO_WIP
                   AND STATION = T_STATION_NAME
                   AND TR_SN IS NULL
                   AND SHORTAGE_FLAG = '0'
                   AND ROWNUM = 1;

            RES :=
                   'KP_NO ('
                || T_KP_NO
                || ') IS NOT ONLINE, PLEASE ONLINE THIS KP_NO';
            RAISE T_EXIT;
        END IF;

        --------------- BEGIN: CHECK KP QTY ---------------

        T_FLAG := MES1.CHECK_KP_QTY (T_WO_WIP, T_STATION_NAME);

        IF T_FLAG = 'FALSE'
        THEN
            OPEN RES_TABLE FOR
                  SELECT DISTINCT (A.TR_SN),
                                  A.KP_NO,
                                  A.QTY,
                                  B.STANDARD_QTY,
                                  A.EXT_QTY,
                                  A.DATE_CODE,
                                  A.LOT_CODE,
                                  C.BUFFER_QTY,
                                  A.EXT_QTY - C.BUFFER_QTY     TRUE_EXT_QTY,
                                  T_WO                         AS WO,
                                  T_TARGET_QTY                 AS TARGET_QTY,
                                  T_INPUT_QTY                  AS INPUT_QTY
                    FROM MES4.R_TR_SN_WIP  A,
                         MES4.R_STATION_WIP B,
                         MES1.C_STATION_KP C
                   WHERE     A.STATION = T_STATION_NAME
                         AND A.WO = T_WO_WIP
                         AND A.TR_SN = B.TR_SN
                         AND C.P_NO = B.P_NO
                         AND B.KP_NO = C.KP_NO
                ORDER BY EXT_QTY;

            RES := 'THE MATERIAL IS RUNNING OUT, PLEASE CHECK OUT.';
            RAISE T_EXIT;
        END IF;

        --------------- END: CHECK KP QTY ---------------

        INSERT INTO MES4.R_TR_PRODUCT_DETAIL (WO,
                                              P_SN,
                                              TR_CODE,
                                              WORK_FLAG,
                                              WORK_TIME)
             VALUES (T_WO,
                     T_SN,
                     T_TR_CODE,
                     T_WORK_FLAG,
                     SYSDATE);

        COMMIT;

        --------------- BEGIN: CUT_KP_QTY ---------------

        MES1.CUT_KP_QTY (T_WO_WIP,
                         T_STATION_NAME,
                         T_EMP_NO,
                         RES);

        IF RES <> 'OK'
        THEN
            RES := 'ERROR IN MES1.CUT_KP_QTY.';
            RAISE T_EXIT;
        END IF;

        --------------- END: CUT_KP_QTY ---------------

        T_INPUT_QTY := T_INPUT_QTY + 1;
        T_QTY := T_QTY + 1;

        OPEN RES_TABLE FOR
              SELECT DISTINCT (A.TR_SN),
                              A.KP_NO,
                              A.QTY,
                              B.STANDARD_QTY,
                              A.EXT_QTY,
                              A.DATE_CODE,
                              A.LOT_CODE,
                              C.BUFFER_QTY,
                              A.EXT_QTY - C.BUFFER_QTY     TRUE_EXT_QTY,
                              T_WO                         AS WO,
                              T_TARGET_QTY                 AS TARGET_QTY,
                              T_INPUT_QTY                  AS INPUT_QTY
                FROM MES4.R_TR_SN_WIP  A,
                     MES4.R_STATION_WIP B,
                     MES1.C_STATION_KP C
               WHERE     A.STATION = T_STATION_NAME
                     AND A.WO = T_WO_WIP
                     AND A.TR_SN = B.TR_SN
                     AND C.P_NO = B.P_NO
                     AND B.KP_NO = C.KP_NO
            ORDER BY EXT_QTY;

        IF T_INPUT_QTY = T_TARGET_QTY
        THEN
            T_FLAG := MES1.IS_LAST_STATION (T_STATION_NAME, T_WO);

            IF T_FLAG = 'TRUE'
            THEN
                UPDATE MES4.R_WO_BASE
                   SET WORK_FLAG = '2', WORK_TIME = SYSDATE
                 WHERE WO = T_WO;
            END IF;

            RES :=
                   'OK '
                || T_SN
                || ', WO ('
                || T_WO
                || ') ALREADY FULL AT THE STATION ('
                || T_STATION_NAME
                || ') COMPLETED.';
        ELSE
            RES := 'OK ' || T_SN;
        END IF;
    ---- END: SSN SCAN ----
    ---------------- END: SN SCAN ----------------
    ELSE
        RES := 'IN_EVENT DOES NOT EXIST. PLEASE CALL IT CHECK!';
        RAISE T_EXIT;
    END IF;

    IF IN_EVENT NOT IN ('MATERIAL_SCAN', 'SN_SCAN')
    THEN
        RES := 'OK ' || IN_EVENT;
    END IF;

    COMMIT;
EXCEPTION
    WHEN T_EXIT
    THEN
        ROLLBACK;
    WHEN OTHERS
    THEN
        RES :=
               'EXCEPTION MES1.SMT_SN_SCAN: '
            || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        ROLLBACK;
END;