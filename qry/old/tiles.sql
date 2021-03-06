WITH CURR_PTS AS (
	SELECT DISTINCT
		ENCNTR_DOMAIN.ENCNTR_ID,
		ENCNTR_DOMAIN.PERSON_ID,
		ENCNTR_ALIAS.ALIAS,
		ENCNTR_DOMAIN.LOC_NURSE_UNIT_CD,
		ENCNTR_DOMAIN.LOC_BED_CD,
		ENCOUNTER.ARRIVE_DT_TM,
		ENCOUNTER.REG_DT_TM,
		PERSON.NAME_FULL_FORMATTED AS PT_NAME,
		PERSON.BIRTH_DT_TM,
		TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, (pi_time_zone(1, @Variable('BOUSER'))))) - PERSON.BIRTH_DT_TM) / 365.25, 0) AS AGE,
		PERSON.SEX_CD,
		CASE PERSON.SEX_CD
			WHEN 272 THEN 0.85
			ELSE 1
		END AS CRCL_GENDER_MOD,
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
), LABS_SCR AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		TO_NUMBER(MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) KEEP (DENSE_RANK FIRST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM)) AS FIRST_RESULT,
		TO_NUMBER(MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM)) AS LAST_RESULT
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD = 31090 -- Creatinine Lvl
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= CURR_PTS.ARRIVE_DT_TM -- pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
)

SELECT *
FROM
	LABS_SCR