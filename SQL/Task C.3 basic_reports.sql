--3
-- 3.1
--  LEVEL 2 
SELECT * FROM(
SELECT S.NAME, SUM(TOTAL_FLIGHT_AGES)/SUM(TOTAL_PASSENGERS) AS AVERAGE_AGE,
RANK() OVER( ORDER BY SUM(T.TOTAL_FLIGHT_AGES)/SUM(T.TOTAL_PASSENGERS) DESC) AS AGE_RANK
FROM SOURCE_AIRPORTS_DIM_2 S, TRANSACTION_FACT_2 T WHERE T.SOURCEAIRPORTID = S.SOURCEAIRPORTID AND S.COUNTRY = 'Australia' AND CLASSID = 2 GROUP BY S.NAME) WHERE AGE_RANK <= 3;
  
-- LEVEL 0
SELECT * FROM(
SELECT S.NAME, SUM(T.AGE)/SUM(T.TOTAL_PASSENGERS) AS AVERAGE_AGE,
RANK() OVER( ORDER BY SUM(T.AGE)/SUM(T.TOTAL_PASSENGERS) DESC) AS AGE_RANK
FROM SOURCE_AIRPORTS_DIM S, TRANSACTION_FACT T WHERE T.SOURCEAIRPORTID = S.SOURCEAIRPORTID AND S.COUNTRY = 'Australia' AND  1.5*T.FARE <= T.TOTAL_PAID_TICKET AND T.TOTAL_PAID_TICKET < 2*T.FARE GROUP BY S.NAME) WHERE AGE_RANK <= 3;


-- 3.2
-- LEVEL 2

SELECT EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY')) AS MONTH, SUM(TOTAL_MEMBERS) AS NEW_MEMBERS FROM MEMBERSHIP_SALES_FACT_2 WHERE
EXTRACT(YEAR FROM TO_DATE(JOINDATE, 'DD-MM-YY')) = EXTRACT( YEAR FROM TO_DATE('2014', 'YYYY')) AND CATEGORYID = 3 AND MEMBERSHIPTYPEID = 'M3'
GROUP BY EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY')) ORDER BY EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY'));

-- LEVEL 0

SELECT EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY')) AS MONTH, SUM(TOTAL_MEMBERS) AS NEW_MEMBERS FROM MEMBERSHIP_SALES_FACT WHERE
EXTRACT(YEAR FROM TO_DATE(JOINDATE, 'DD-MM-YY')) = EXTRACT( YEAR FROM TO_DATE('2014', 'YYYY')) AND AGE BETWEEN 18 AND 60 AND MEMBERSHIPTYPEID = 'M3'
GROUP BY EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY')) ORDER BY EXTRACT(MONTH FROM TO_DATE(JOINDATE, 'DD-MM-YY'));
