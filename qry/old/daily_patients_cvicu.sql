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
		PERSON.NAME_FIRST,
		PERSON.NAME_LAST,
		PERSON.BIRTH_DT_TM,
		TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, (pi_time_zone(1, @Variable('BOUSER'))))) - PERSON.BIRTH_DT_TM) / 365.25, 0) AS AGE,
		PERSON.SEX_CD,
		CASE PERSON.SEX_CD
			WHEN 272 THEN 0.85
			ELSE 1
		END AS CRCL_GENDER_MOD,
		PRSNL.NAME_FULL_FORMATTED AS MD_NAME,
		PRSNL.NAME_FIRST AS MD_FIRST,
		PRSNL.NAME_LAST AS MD_LAST
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
), HEIGHT AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		TO_NUMBER(MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) AS RESULT_VAL,
		CASE CURR_PTS.SEX_CD
			WHEN 272 THEN (0.65 * MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) - 50.74 -- Female
			ELSE (0.73 * MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) - 59.42 -- Male
		END AS LEAN_WT
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 30066 -- Height
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= CURR_PTS.ARRIVE_DT_TM
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
		AND CLINICAL_EVENT.RESULT_UNITS_CD = 164 -- cm
	GROUP BY
		CURR_PTS.ENCNTR_ID,
		CURR_PTS.SEX_CD
), WEIGHT AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		TO_NUMBER(MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CURR_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 30107 -- Weight
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= CURR_PTS.ARRIVE_DT_TM
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
		AND CLINICAL_EVENT.RESULT_UNITS_CD = 170 -- kg
	GROUP BY
		CURR_PTS.ENCNTR_ID
), LABS_SCR AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		TO_NUMBER(MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) AS RESULT_VAL
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
), LABS_BANDS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		TO_NUMBER(MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_ID)) AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD = 30544 -- Bands
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
), VITALS_TMAX AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		TO_NUMBER(MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<'))) AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
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
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
), SOFA_LABS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD,
		CASE CLINICAL_EVENT.EVENT_CD
			WHEN 33552 THEN -- Bili
				(CASE 
					WHEN MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) >= 12 THEN 4
					WHEN MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) >= 6 THEN 3
					WHEN MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) >= 2 THEN 2
					WHEN MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) >= 1.2 THEN 1
					ELSE 0
				END)
			WHEN 33044 THEN -- Platelet
				(CASE 
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 20 THEN 4
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 50 THEN 3
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 100 THEN 2
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 150 THEN 1
					ELSE 0
				END)
			WHEN 134422765 THEN -- GCS
				(CASE 
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 6 THEN 4
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 9 THEN 3
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 12 THEN 2
					WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 14 THEN 1
					ELSE 0
				END)
		END AS SOFA_SCORE
			
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			33044, -- Platelet
			33552, -- Bili Total
			134422765 -- Glasgow Coma Score
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD
), SOFA_MAP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CASE 
			WHEN MIN(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) < 70 THEN 1
			ELSE 0
		END AS SOFA_SCORE
			
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			119822453, -- Mean Arterial Pressure
			173814326 -- Mean Arterial Pressure (Invasive)
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
), SOFA_MEDS AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
		CASE CE_MED_RESULT.INFUSION_UNIT_CD 
			WHEN 135198896 THEN MAX(CE_MED_RESULT.INFUSION_RATE) -- microgram/kg/min 
			ELSE MAX(CE_MED_RESULT.INFUSION_RATE / TO_NUMBER(ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE))
		END AS RATE
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		CURR_PTS,
		ORDER_DETAIL
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		AND CLINICAL_EVENT.EVENT_CD IN (
			37556849, -- EPINephrine
			37557691, -- norepinephrine
			37558389, -- DOPamine
			63003651 -- DOBUTamine
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.INFUSION_RATE > 0
		AND CLINICAL_EVENT.ORDER_ID = ORDER_DETAIL.ORDER_ID(+)
		AND ORDER_DETAIL.OE_FIELD_MEANING_ID(+) = 99 -- WEIGHT
		AND ORDER_DETAIL.ACTION_SEQUENCE(+) = 1
	GROUP BY
		CURR_PTS.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD,
		CE_MED_RESULT.INFUSION_UNIT_CD,
		ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
), SOFA_MEDS_SCORE AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		CASE 
			WHEN (EVENT_CD = 37558389 AND RATE > 15) OR ((EVENT_CD = 37556849 OR EVENT_CD = 37557691) AND RATE > 0.1) THEN 4 -- DOPamine, EPINephrine, norepinephrine
			WHEN (EVENT_CD = 37558389 AND RATE > 5) OR ((EVENT_CD = 37556849 OR EVENT_CD = 37557691) AND RATE > 0) THEN 3 -- DOPamine, EPINephrine, norepinephrine
			WHEN (EVENT_CD = 37558389 OR EVENT_CD = 63003651) AND RATE > 0 THEN 2 -- -- DOPamine, DOBUTamine
			ELSE 0
		END AS SOFA_SCORE
	FROM
		CURR_PTS,
		SOFA_MEDS 	
	WHERE
		CURR_PTS.ENCNTR_ID = SOFA_MEDS.ENCNTR_ID
), SOFA_BP AS (
	SELECT * FROM SOFA_MEDS_SCORE
	
	UNION
	
	SELECT * FROM SOFA_MAP

), SOFA_BP_SCORE AS (
	SELECT
		ENCNTR_ID,
		'BP' AS EVENT,
		MAX(SOFA_SCORE) AS SOFA_SCORE
	FROM
		SOFA_BP
	GROUP BY 
		ENCNTR_ID
), SOFA_RESP AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		--CLINICAL_EVENT.EVENT_CD,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<') AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			10662250, -- FIO2 (%)
			515653299, -- POC A %FIO2
			53807856 -- POC A PO2
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
), SOFA_RESP_PIVOT AS (
	SELECT * FROM SOFA_RESP
	PIVOT(
		MIN(RESULT_VAL) FOR EVENT IN (
			'FIO2 (%)' AS FIO2,
			'POC A %FIO2' AS POC_FIO2,
			'POC A PO2' AS PO2
		)
	)
), SOFA_RESP_RATIO AS (
	SELECT
		ENCNTR_ID,
		EVENT_END_DT_TM,
		PO2 / (LAST_VALUE(COALESCE(FIO2, POC_FIO2) IGNORE NULLS) OVER (PARTITION BY ENCNTR_ID ORDER BY EVENT_END_DT_TM ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 100) AS PO2_FIO2
	FROM SOFA_RESP_PIVOT
), SOFA_RESP_SCORE AS (
	SELECT 
		ENCNTR_ID,
		'RESP' AS EVENT,
		CASE 
			WHEN MIN(PO2_FIO2) < 100 THEN 4
			WHEN MIN(PO2_FIO2) < 200 THEN 3
			WHEN MIN(PO2_FIO2) < 300 THEN 2
			WHEN MIN(PO2_FIO2) < 400 THEN 1
			ELSE 0
		END AS SOFA_SCORE
	FROM 
		SOFA_RESP_RATIO
	WHERE
		PO2_FIO2 > 0
	GROUP BY
		ENCNTR_ID
), SOFA_SCR AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		MAX(REGEXP_REPLACE(CLINICAL_EVENT.RESULT_VAL, '>|<')) AS SCR
	FROM
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD = 31090 -- Creatinine Lvl
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
), SOFA_UOP AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		COALESCE(SUM(CE_INTAKE_OUTPUT_RESULT.IO_VOLUME), 0) AS UOP
	FROM
		CE_INTAKE_OUTPUT_RESULT,
		CLINICAL_EVENT,
		CURR_PTS
	WHERE
		CURR_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID(+)
		AND CLINICAL_EVENT.EVENT_CLASS_CD(+) = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD(+) IN (
			17664566, -- Urine Voided
			699895758, -- Urine Voided Volume
			134426203, -- Urine Output Initial (mL)
			700105361, -- Indwelling Cath Output Volume:
			700105503, -- Indwelling Cath Urine Output Initial:
			700168898 -- Intermittent Catheter Output Volume
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM(+) >= pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND CLINICAL_EVENT.EVENT_ID = CE_INTAKE_OUTPUT_RESULT.EVENT_ID(+)
		AND CE_INTAKE_OUTPUT_RESULT.VALID_UNTIL_DT_TM(+) > DATE '2099-12-31'
	GROUP BY
		CURR_PTS.ENCNTR_ID
), SOFA_RENAL AS (
	SELECT DISTINCT
		CURR_PTS.ENCNTR_ID,
		'RENAL' AS EVENT,
		CASE 
			WHEN SOFA_SCR.SCR >= 5 OR SOFA_UOP.UOP < 200 THEN 4
			WHEN SOFA_SCR.SCR >= 3.5 OR SOFA_UOP.UOP < 500 THEN 3
			WHEN SOFA_SCR.SCR >= 2 THEN 2
			WHEN SOFA_SCR.SCR >= 1 THEN 1
			ELSE 0
		END AS SOFA_SCORE
	FROM
		CURR_PTS,
		SOFA_SCR,
		SOFA_UOP 	
	WHERE
		CURR_PTS.ENCNTR_ID = SOFA_SCR.ENCNTR_ID(+)
		AND CURR_PTS.ENCNTR_ID = SOFA_UOP.ENCNTR_ID(+)
), SOFA_SCORES AS (
	SELECT
		SOFA_LABS.ENCNTR_ID,
		pi_get_cv_display(SOFA_LABS.EVENT_CD) AS EVENT,
		SOFA_LABS.SOFA_SCORE
	FROM
		SOFA_LABS
		
	UNION
	
	SELECT * FROM SOFA_BP_SCORE

	UNION
	
	SELECT * FROM SOFA_RENAL
	
	UNION
	
	SELECT * FROM SOFA_RESP_SCORE
		
), SOFA AS (
	SELECT DISTINCT
		SOFA_SCORES.ENCNTR_ID,
		SUM(SOFA_SCORES.SOFA_SCORE) AS SOFA
	FROM
		SOFA_SCORES
	GROUP BY
		SOFA_SCORES.ENCNTR_ID
)

SELECT DISTINCT
    CURR_PTS.ENCNTR_ID,
	CURR_PTS.ALIAS AS FIN,
	pi_get_cv_display(CURR_PTS.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	pi_get_cv_display(CURR_PTS.LOC_BED_CD) AS BED,
    --CURR_PTS.PT_NAME AS NAME,
	(INITCAP(CURR_PTS.NAME_LAST) || ', ' || INITCAP(CURR_PTS.NAME_FIRST)) AS NAME,
	(INITCAP(CURR_PTS.MD_LAST) || ', ' || INITCAP(CURR_PTS.MD_FIRST)) AS ATTENDING,
    SYSDATE - CURR_PTS.REG_DT_TM AS LOS,
    CURR_PTS.AGE AS AGE,
    SUBSTR(pi_get_cv_display(CURR_PTS.SEX_CD), 1, 1) AS SEX,
	HEIGHT.RESULT_VAL AS HEIGHT,
	WEIGHT.RESULT_VAL AS WEIGHT,
	HEIGHT.LEAN_WT AS LEAN_WT,
	LABS_SCR.RESULT_VAL AS SCR,
	CRCL_GENDER_MOD * ((140 - CURR_PTS.AGE) / LABS_SCR.RESULT_VAL) * (LEAST(WEIGHT.RESULT_VAL, HEIGHT.LEAN_WT) / 72) AS CRCL,
	VITALS_TMAX.RESULT_VAL AS TMAX,
	LABS_BANDS.RESULT_VAL AS BANDS,
	SOFA.SOFA AS SOFA
FROM
	CURR_PTS,
	HEIGHT,
	LABS_BANDS,
	LABS_SCR,
	SOFA,
	VITALS_TMAX,
	WEIGHT
WHERE
	CURR_PTS.ENCNTR_ID = SOFA.ENCNTR_ID(+)
	AND CURR_PTS.ENCNTR_ID = HEIGHT.ENCNTR_ID(+)
	AND CURR_PTS.ENCNTR_ID = WEIGHT.ENCNTR_ID(+)
	AND CURR_PTS.ENCNTR_ID = LABS_BANDS.ENCNTR_ID(+)
	AND CURR_PTS.ENCNTR_ID = LABS_SCR.ENCNTR_ID(+)
	AND CURR_PTS.ENCNTR_ID = VITALS_TMAX.ENCNTR_ID(+)
