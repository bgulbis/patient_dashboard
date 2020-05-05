WITH CURR_PTS AS (
	SELECT DISTINCT
		ENCNTR_DOMAIN.ENCNTR_ID,
		ENCNTR_DOMAIN.PERSON_ID,
		ENCOUNTER.ARRIVE_DT_TM,
		ENCOUNTER.REG_DT_TM
	FROM
		ENCNTR_DOMAIN,
		ENCOUNTER
	WHERE
		ENCNTR_DOMAIN.LOC_NURSE_UNIT_CD IN (
			4137, -- HH CCU
			5541 -- HH CVICU 
		) 
		AND ENCNTR_DOMAIN.END_EFFECTIVE_DT_TM > DATE '2099-12-31'
		AND ENCNTR_DOMAIN.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
), LABS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		CASE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
			WHEN 'Creatinine Lvl' THEN 'SCr'
			WHEN 'Glucose POC' THEN 'Glucose'
			WHEN 'Sodium Lvl' THEN 'Sodium'
			WHEN 'Potassium Lvl' THEN 'Potassium'
			WHEN 'Bili Total' THEN 'TBili'
			ELSE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
		END AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL
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
			-- 30544, -- Bands
			32089, -- INR
			32170, -- Potassium Lvl
			32619, -- Sodium Lvl
			33187, -- PTT
			30349, -- ALT
			30514, -- AST
			33552, -- Bili Total
			12016463 -- Glucose POC
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >=  pi_to_gmt(SYSDATE - 3, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), BASELINE AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		CASE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
			WHEN 'Hgb A1C' THEN 'HgbA1c'
			WHEN 'LDL (Calculated)' THEN 'LDL'
			WHEN 'LDL Direct' THEN 'LDL'
			ELSE pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)
		END AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			31856, -- Hgb A1C
			30914, -- Chol
			31821, -- HDL
			33992, -- Trig
			32227, -- LDL (Calculated)
			32228, -- LDL Direct
			34016 -- TSH
		)
		-- AND CLINICAL_EVENT.EVENT_END_DT_TM >=  pi_to_gmt(SYSDATE - 3, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), TEMPS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		'Temperature' AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL
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
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), HR AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		'HR' AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL
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
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), SBP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		'SBP' AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		TO_NUMBER(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS RESULT_VAL
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
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), UOP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		'UOP' AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		MAX(CE_INTAKE_OUTPUT_RESULT.IO_VOLUME) KEEP (DENSE_RANK LAST ORDER BY CE_INTAKE_OUTPUT_RESULT.CE_IO_RESULT_ID) OVER (PARTITION BY CE_INTAKE_OUTPUT_RESULT.EVENT_ID) AS RESULT_VAL
	FROM
		CE_INTAKE_OUTPUT_RESULT,
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			17664566, -- Urine Voided
			699895758, -- Urine Voided Volume
			134426203, -- Urine Output Initial (mL)
			700105361, -- Indwelling Cath Output Volume:
			700105503, -- Indwelling Cath Urine Output Initial:
			700168898 -- Intermittent Catheter Output Volume
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, 'CST')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_INTAKE_OUTPUT_RESULT.EVENT_ID
		AND CE_INTAKE_OUTPUT_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), SPARK_DATA AS (
	SELECT * FROM LABS
	
	UNION
	
	SELECT * FROM BASELINE

	UNION

	SELECT * FROM TEMPS

	UNION

	SELECT * FROM HR

	UNION

	SELECT * FROM SBP

	UNION

	SELECT * FROM UOP
)

SELECT
	SPARK_DATA.ENCNTR_ID,
	pi_from_gmt(SPARK_DATA.EVENT_END_DT_TM, 'CST') AS EVENT_DATETIME,
	SPARK_DATA.EVENT_ID,
	LOWER(SPARK_DATA.EVENT) AS EVENT,
	pi_get_cv_display(SPARK_DATA.EVENT_CD) AS EVENT_NAME,
	SPARK_DATA.RESULT_VAL
FROM
	SPARK_DATA
