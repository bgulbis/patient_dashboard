SELECT DISTINCT
    ENCNTR_DOMAIN.ENCNTR_ID AS ENCOUNTER_ID,
	CE_INTAKE_OUTPUT_RESULT.EVENT_ID AS EVENT_ID,
	TO_CHAR(pi_from_gmt(CE_INTAKE_OUTPUT_RESULT.IO_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))), 'YYYY-MM-DD"T"HH24:MI:SS') AS IO_DATETIME,
	CV_REFERENCE_EVENT.DISPLAY AS EVENT,
	CE_INTAKE_OUTPUT_RESULT.IO_VOLUME AS VOLUME,
	CASE CE_INTAKE_OUTPUT_RESULT.IO_TYPE_FLAG
		WHEN 1 THEN 'In'
		ELSE 'Out'
	END AS IO_TYPE
FROM
    CE_INTAKE_OUTPUT_RESULT,
    CODE_VALUE CV_REFERENCE_EVENT,
    ENCNTR_DOMAIN
WHERE
    ENCNTR_DOMAIN.ACTIVE_IND = 1
    AND ENCNTR_DOMAIN.LOC_FACILITY_CD = 3310
    AND ENCNTR_DOMAIN.LOC_NURSE_UNIT_CD = 5541
    AND ENCNTR_DOMAIN.END_EFFECTIVE_DT_TM > DATE '2099-12-31'
    AND (
        ENCNTR_DOMAIN.ENCNTR_ID = CE_INTAKE_OUTPUT_RESULT.ENCNTR_ID
        AND CE_INTAKE_OUTPUT_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
        AND CE_INTAKE_OUTPUT_RESULT.REFERENCE_EVENT_CD = CV_REFERENCE_EVENT.CODE_VALUE
        AND CE_INTAKE_OUTPUT_RESULT.IO_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
    )


WITH CURR_PTS AS (
	SELECT DISTINCT
		ENCNTR_DOMAIN.ENCNTR_ID,
		ENCNTR_DOMAIN.PERSON_ID,
		ENCNTR_ALIAS.ALIAS,
		ENCNTR_DOMAIN.LOC_NURSE_UNIT_CD,
		ENCNTR_DOMAIN.LOC_BED_CD,
		ENCOUNTER.REG_DT_TM,
		PERSON.NAME_FULL_FORMATTED AS PT_NAME,
		PERSON.BIRTH_DT_TM,
		PERSON.SEX_CD,
		PRSNL.NAME_FULL_FORMATTED AS MD_NAME
	FROM
		ENCNTR_ALIAS,
		ENCNTR_DOMAIN,
		ENCNTR_PRSNL_RELTN,
		ENCOUNTER,
		PERSON,
		PRSNL
	WHERE
		ENCNTR_DOMAIN.LOC_NURSE_UNIT_CD = 5541 -- HH CVICU
		AND ENCNTR_DOMAIN.END_EFFECTIVE_DT_TM > DATE '2099-12-31'
		AND ENCNTR_DOMAIN.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCNTR_DOMAIN.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
		AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
		AND ENCNTR_DOMAIN.PERSON_ID = PERSON.PERSON_ID
		AND ENCNTR_DOMAIN.ENCNTR_ID = ENCNTR_PRSNL_RELTN.ENCNTR_ID
		AND ENCNTR_PRSNL_RELTN.EXPIRATION_IND = 0
		AND ENCNTR_PRSNL_RELTN.ENCNTR_PRSNL_R_CD = 368029 -- Physician Attending
		AND ENCNTR_PRSNL_RELTN.END_EFFECTIVE_DT_TM > DATE '2099-12-31'
		AND ENCNTR_PRSNL_RELTN.PRSNL_PERSON_ID = PRSNL.PERSON_ID
)

SELECT DISTINCT
	CURR_PTS.ENCNTR_ID,
	SUM(CE_INTAKE_OUTPUT_RESULT.IO_VOLUME) AS UOP
FROM
	CE_INTAKE_OUTPUT_RESULT,
	CLINICAL_EVENT,
	CURR_PTS
WHERE
	CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
	AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
	AND CLINICAL_EVENT.EVENT_CD IN (
		17664566, -- Urine Voided
		699895758, -- Urine Voided Volume
		134426203, -- Urine Output Initial (mL)
		700105361, -- Indwelling Cath Output Volume:
		700105503, -- Indwelling Cath Urine Output Initial:
		700168898 -- Intermittent Catheter Output Volume
	)
	AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	AND CLINICAL_EVENT.EVENT_ID = CE_INTAKE_OUTPUT_RESULT.EVENT_ID
	AND CE_INTAKE_OUTPUT_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
GROUP BY
	CURR_PTS.ENCNTR_ID
	