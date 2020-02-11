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
), LABS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		--pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_END_DT_TM,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL,
		CASE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
			WHEN 'Creatinine Lvl' THEN 0.5
			WHEN 'Hgb' THEN 8.5
			WHEN 'Platelet' THEN 133
			WHEN 'WBC' THEN 3.7
			WHEN 'Glucose POC' THEN 80
		END AS NORMAL_MIN,
		CASE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
			WHEN 'Creatinine Lvl' THEN 1.4
			WHEN 'Hgb' THEN 10
			WHEN 'Platelet' THEN 250
			WHEN 'WBC' THEN 10.4
			WHEN 'Glucose POC' THEN 180
		END AS NORMAL_MAX
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			31090, -- Creatinine Lvl
			31854, -- Hgb
			33044, -- Platelet
			34402, -- WBC
			12016463 -- Glucose POC
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >=  pi_to_gmt(SYSDATE - 3, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), TEMPS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		--pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_END_DT_TM,
		'Temperature' AS EVENT,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL,
		97.5 AS NORMAL_MIN,
		100.5 AS NORMAL_MAX
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			30100, -- Temperature
			119822492, -- Temperature Tympanic
			119822505, -- Temperature Rectal
			119822517, -- Temperature Axillary
			119822523, -- Temperature Intravascular
			119822536, -- Temperature Oral
			172563303, -- Temperature Skin
			172563306, -- Temperature Esophageal
			172563327, -- Temperature Brain
			263779626, -- Temperature Bladder		
			10679282 -- Temperature Sensor
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), HR AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		--pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_END_DT_TM,
		'HR' AS EVENT,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL,
		60 AS NORMAL_MIN,
		100 AS NORMAL_MAX
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			30065, -- Peripheral Pulse Rate
			119822527 -- Apical Heart Rate
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), SBP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		--pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_END_DT_TM,
		'SBP' AS EVENT,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL,
		90 AS NORMAL_MIN,
		140 AS NORMAL_MAX
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			30098, -- Systolic Blood Pressure
			134401648 -- Arterial Systolic BP 1
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), UOP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		--pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS EVENT_END_DT_TM,
		'UOP' AS EVENT,
		CE_INTAKE_OUTPUT_RESULT.IO_VOLUME AS RESULT_VAL,
		50 AS NORMAL_MIN,
		150 AS NORMAL_MAX
	FROM
		CE_INTAKE_OUTPUT_RESULT,
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID(+)
		AND CLINICAL_EVENT.EVENT_CLASS_CD(+) = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD(+) IN (
			17664566, -- Urine Voided
			699895758, -- Urine Voided Volume
			134426203, -- Urine Output Initial (mL)
			700105361, -- Indwelling Cath Output Volume:
			700105503, -- Indwelling Cath Urine Output Initial:
			700168898 -- Intermittent Catheter Output Volume
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM(+) >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_INTAKE_OUTPUT_RESULT.EVENT_ID(+)
		AND CE_INTAKE_OUTPUT_RESULT.VALID_UNTIL_DT_TM(+) > DATE '2099-12-31'
)

SELECT * FROM LABS

UNION

SELECT * FROM TEMPS

UNION

SELECT * FROM HR

UNION

SELECT * FROM SBP

UNION

SELECT * FROM UOP

