-- ##################################### LEVEL 2 ###############################################
CREATE TABLE SOURCE_AIRPORTS_DIM_2 AS SELECT DISTINCT R.SOURCEAIRPORTID, A.NAME, A.CITY, A.COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.SOURCEAIRPORTID = A.AIRPORTID;
CREATE TABLE DESTIN_AIRPORTS_DIM_2 AS SELECT DISTINCT R.DESTAIRPORTID, A.NAME, A.CITY, A.COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.DESTAIRPORTID = A.AIRPORTID;

CREATE TABLE AIRLINE_SERVICES_DIM_2 AS SELECT * FROM  AIRLINE_SERVICES_2;
CREATE TABLE AIRLINE_SERVICE_BRIDGE_2 AS SELECT * FROM PROVIDES_2;

CREATE TABLE AIRPORT_DIM_2 AS SELECT DISTINCT AIRPORTID, NAME, CITY, COUNTRY, DST FROM AIRPORTS_2;

CREATE TABLE AIRLINE_DIM_2 AS SELECT A.AIRLINEID, A.NAME,
1/COUNT(P.AIRLINEID) AS WEIGHT_FACTOR, LISTAGG (P.SERVICEID, '_') Within Group (Order By P.SERVICEID) As ServicesList
FROM AIRLINES_2 A, PROVIDES_2 P
WHERE A.AIRLINEID = P.AIRLINEID GROUP BY A.AIRLINEID, A.NAME;

CREATE TABLE ROUTE_FACT_2 AS SELECT A.AIRLINEID, R.SOURCEAIRPORTID, R.DESTAIRPORTID,
COUNT(R.DESTAIRPORTID) AS TOTAL_INCOMING_ROUTES, COUNT(R.SOURCEAIRPORTID) AS TOTAL_OUTGOING_ROUTES,
COUNT(R.ROUTEID) AS TOTAL_NUMBER_OF_ROUTES, SUM(R.SERVICECOST) AS TOTAL_SERVICECOST, SUM(R.DISTANCE) AS TOTAL_DISTANCE FROM AIRLINES_2 A, ROUTES_2 R
WHERE A.AIRLINEID = R.AIRLINEID GROUP BY A.AIRLINEID, R.SOURCEAIRPORTID, R.DESTAIRPORTID;

-- FOR MEMBERSHITYPE FACT

CREATE TABLE MEMBERSHIP_TYPE_SCD_DIM_2 AS
SELECT MT.MEMBERSHIPTYPEID || '_' ||
DENSE_RANK() OVER(PARTITION BY MT.MEMBERSHIPTYPEID ORDER BY TO_DATE(M.JOINDATE, 'DD-MM-YY') ASC) AS MEMBERSHIPTYPEID,
MT.MEMBERSHIPNAME,
M.PASSID,
M.JOINDATE,
M.ENDDATE,
M.PROMOTION,
(MT.MEMBERSHIPFEE -  MT.MEMBERSHIPFEE*P.DISCOUNT) AS FEE,
CASE EXTRACT( YEAR FROM TO_DATE(M.ENDDATE, 'DD-MM-YY')) WHEN EXTRACT( YEAR FROM TO_DATE('2014', 'YYYY')) THEN 'Y' ELSE 'N'
END AS CURRENT_FLAG FROM MEMBERSHIPTYPE_2 MT, MEMBERSHIPJOINRECORDS_2 M, PROMOTION_2 P WHERE M.MEMBERSHIPTYPEID = MT.MEMBERSHIPTYPEID AND P.PROMOTIONID = M.PROMOTION;

CREATE TABLE AGE_CATEGORY_DIM_2 (CATEGORYID NUMBER, CATEGORY_NAME VARCHAR(20));
INSERT INTO AGE_CATEGORY_DIM_2 VALUES (1, 'Child');
INSERT INTO AGE_CATEGORY_DIM_2 VALUES (2, 'Teenager');
INSERT INTO AGE_CATEGORY_DIM_2 VALUES (3, 'Adult');
INSERT INTO AGE_CATEGORY_DIM_2 VALUES (4, 'Elder');

CREATE TABLE MEMBERSHIP_TYPE_DIM_2 AS SELECT * FROM MEMBERSHIPJOINRECORDS_2;

CREATE TABLE PASSENGER_NATIONALITY_DIM_2 AS SELECT DISTINCT NATIONALITY FROM PASSENGERS_2;

CREATE TABLE MEMBERSHIP_TEMPFACT_2 AS SELECT 
M.MEMBERSHIPTYPEID, 
P.AGE,
M.JOINDATE,
COUNT(M.MEMBERSHIPTYPEID) AS TOTAL_MEMBERS, 
SUM(F.MEMBERSHIPFEE - F.MEMBERSHIPFEE*PR.DISCOUNT) AS TOTAL_MEMBERSHIPSALES
FROM MEMBERSHIPJOINRECORDS_2 M, MEMBERSHIPTYPE_2 F,PASSENGERS_2 P, PROMOTION_2 PR 
WHERE F.MEMBERSHIPTYPEID = M.MEMBERSHIPTYPEID AND M.PASSID = P.PASSID AND PR.PROMOTIONID = M.PROMOTION 
GROUP BY M.MEMBERSHIPTYPEID, P.AGE, M.JOINDATE;

ALTER TABLE MEMBERSHIP_TEMPFACT_2
ADD CATEGORYID NUMBER;

UPDATE MEMBERSHIP_TEMPFACT_2
SET CATEGORYID = 1
WHERE AGE <11;

UPDATE MEMBERSHIP_TEMPFACT_2
SET CATEGORYID = 2
WHERE AGE BETWEEN 11 AND 17;

UPDATE MEMBERSHIP_TEMPFACT_2
SET CATEGORYID = 3
WHERE AGE BETWEEN 18 AND 60;

UPDATE MEMBERSHIP_TEMPFACT_2
SET CATEGORYID = 4
WHERE AGE > 60;

CREATE TABLE MEMBERSHIP_SALES_FACT_2 AS SELECT MEMBERSHIPTYPEID, CATEGORYID, JOINDATE ,TOTAL_MEMBERS, TOTAL_MEMBERSHIPSALES FROM MEMBERSHIP_TEMPFACT_2; 

-- FOR TRANSACTION FACT
CREATE TABLE FLIGHT_TYPE_DIM_2 (FLIGHTTYPEID NUMBER, NAME VARCHAR(20));
INSERT INTO FLIGHT_TYPE_DIM_2 VALUES (1, 'Domestic');
INSERT INTO FLIGHT_TYPE_DIM_2 VALUES (2, 'International');

CREATE TABLE FLIGHT_DIM_2 AS SELECT FLIGHTID, FLIGHTDATE, FARE FROM FLIGHTS_2;

CREATE TABLE FLIGHT_CLASS_DIM_2 (CLASSID NUMBER, NAME VARCHAR(20));
INSERT INTO FLIGHT_CLASS_DIM_2 VALUES (1, 'First Class');
INSERT INTO FLIGHT_CLASS_DIM_2 VALUES (2, 'Business Class');
INSERT INTO FLIGHT_CLASS_DIM_2 VALUES (3, 'Economy Class');

CREATE TABLE FLIGHT_DATE_DIM_2 AS SELECT DISTINCT TO_CHAR(FLIGHTDATE, 'DDMMYYYY') AS DATEID, TO_CHAR(FLIGHTDATE, 'DD') AS DAY, TO_CHAR(FLIGHTDATE, 'MM') AS MONTH, TO_CHAR(FLIGHTDATE, 'YYYY') AS YEAR FROM FLIGHTS_2;

-- PRESETUP OF TEMPFACT
CREATE TABLE TRANSACTION_TEMP_2 AS SELECT T.FLIGHTID, AR.AIRLINEID, R.ROUTEID, P.AGE, F.FARE, F.FLIGHTDATE, P.NATIONALITY, R.SOURCEAIRPORTID, R.DESTAIRPORTID, SUM(P.AGE) AS TOTAL_FLIGHT_AGES,
SUM(T.TOTALPAID) AS TOTAL_PAID_TICKET, SUM(T.TOTALPAID - F.FARE) AS TOTAL_AGENT_PROFIT, COUNT(T.PASSID) AS TOTAL_PASSENGERS FROM FLIGHTS_2 F, PASSENGERS_2 P, TRANSACTIONS_2 T, ROUTES_2 R, AIRLINES_2 AR
WHERE T.PASSID = P.PASSID AND T.FLIGHTID = F.FLIGHTID AND F.ROUTEID = R.ROUTEID AND R.AIRLINEID = AR.AIRLINEID
GROUP BY T.FLIGHTID, AR.AIRLINEID ,R.ROUTEID, P.AGE, F.FARE, F.FLIGHTDATE, P.NATIONALITY, R.SOURCEAIRPORTID, R.DESTAIRPORTID;

-- TEMPORARY TABLES TO ASSIGN DOMESTIC AND INTERNATIONAL
CREATE TABLE SAC AS SELECT R.ROUTEID, R.SOURCEAIRPORTID, A.COUNTRY AS SOURCE_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.SOURCEAIRPORTID = A.AIRPORTID;
CREATE TABLE DAC AS SELECT R.ROUTEID, R.DESTAIRPORTID, A.COUNTRY AS DEST_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.DESTAIRPORTID = A.AIRPORTID;
CREATE TABLE FINALE AS SELECT S.ROUTEID, S.SOURCE_COUNTRY, D.DEST_COUNTRY FROM SAC S, DAC D WHERE S.ROUTEID = D.ROUTEID;

CREATE TABLE TRANSACTION_TEMPFACT_2 AS SELECT T.FLIGHTID, T.AIRLINEID, T.AGE, T.FARE, TO_CHAR(T.FLIGHTDATE, 'DDMMYYYY') AS DATEID, T.NATIONALITY, T.SOURCEAIRPORTID, T.DESTAIRPORTID,
T.TOTAL_PAID_TICKET, T.TOTAL_AGENT_PROFIT, T.TOTAL_FLIGHT_AGES ,T.TOTAL_PASSENGERS, FI.SOURCE_COUNTRY, FI.DEST_COUNTRY FROM TRANSACTION_TEMP_2 T, FINALE FI WHERE FI.ROUTEID = T.ROUTEID;

-- ALTER FOR AGE CATEGORY
ALTER TABLE TRANSACTION_TEMPFACT_2
ADD CATEGORYID NUMBER;

UPDATE TRANSACTION_TEMPFACT_2
SET CATEGORYID = 1
WHERE AGE <11;

UPDATE TRANSACTION_TEMPFACT_2
SET CATEGORYID = 2
WHERE AGE BETWEEN 11 AND 17;

UPDATE TRANSACTION_TEMPFACT_2
SET CATEGORYID = 3
WHERE AGE BETWEEN 18 AND 60;

UPDATE TRANSACTION_TEMPFACT_2
SET CATEGORYID = 4
WHERE AGE > 60;

-- ALTER FOR FLIGHT_TYPE

ALTER TABLE TRANSACTION_TEMPFACT_2
ADD FLIGHTTYPEID NUMBER;

UPDATE TRANSACTION_TEMPFACT_2
SET FLIGHTTYPEID = 1 
WHERE SOURCE_COUNTRY = DEST_COUNTRY;

UPDATE TRANSACTION_TEMPFACT_2
SET FLIGHTTYPEID = 2 
WHERE SOURCE_COUNTRY != DEST_COUNTRY;

-- ALTER TABLE FOR CLASSID

ALTER TABLE TRANSACTION_TEMPFACT_2
ADD CLASSID NUMBER;

-- TOTAL PAID TICKET IS SAME AS TOTAL PAID FOR PASSENGER AS WE ARE AT LEVEL 0!
UPDATE TRANSACTION_TEMPFACT_2
SET CLASSID = 1
WHERE TOTAL_PAID_TICKET >= 2*FARE;

UPDATE TRANSACTION_TEMPFACT_2
SET CLASSID = 2
WHERE TOTAL_PAID_TICKET BETWEEN 1.5*FARE AND 2*FARE;

UPDATE TRANSACTION_TEMPFACT_2
SET CLASSID = 3
WHERE TOTAL_PAID_TICKET < 1.5*FARE;

CREATE TABLE TRANSACTION_FACT_2 AS SELECT FLIGHTID, AIRLINEID ,DATEID, CATEGORYID, CLASSID, FLIGHTTYPEID, SOURCEAIRPORTID, DESTAIRPORTID, NATIONALITY,
TOTAL_PAID_TICKET, TOTAL_AGENT_PROFIT, TOTAL_FLIGHT_AGES, TOTAL_PASSENGERS FROM TRANSACTION_TEMPFACT_2;

-- ##################################### LEVEL 0 ###############################################
-- FOR Route_FACT

CREATE TABLE ROUTE_DIM AS SELECT ROUTEID, DISTANCE, SERVICECOST FROM ROUTES_2;
CREATE TABLE SOURCE_AIRPORTS_DIM AS SELECT DISTINCT R.SOURCEAIRPORTID, A.NAME, A.CITY, A.COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.SOURCEAIRPORTID = A.AIRPORTID;
CREATE TABLE DESTIN_AIRPORTS_DIM AS SELECT DISTINCT R.DESTAIRPORTID, A.NAME, A.CITY, A.COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.DESTAIRPORTID = A.AIRPORTID;

CREATE TABLE AIRLINE_SERVICES_DIM AS SELECT * FROM  AIRLINE_SERVICES_2;
CREATE TABLE AIRLINE_SERVICE_BRIDGE AS SELECT * FROM PROVIDES_2;

CREATE TABLE AIRLINE_DIM AS SELECT A.AIRLINEID, A.NAME,
1/COUNT(P.AIRLINEID) AS WEIGHT_FACTOR, LISTAGG (P.SERVICEID, '_') Within Group (Order By P.SERVICEID) As ServicesList
FROM AIRLINES_2 A, PROVIDES_2 P
WHERE A.AIRLINEID = P.AIRLINEID GROUP BY A.AIRLINEID, A.NAME;

CREATE TABLE ROUTE_FACT AS SELECT A.AIRLINEID, R.ROUTEID, R.SOURCEAIRPORTID, R.DESTAIRPORTID,
COUNT(R.DESTAIRPORTID) AS TOTAL_INCOMING_ROUTES, COUNT(R.SOURCEAIRPORTID) AS TOTAL_OUTGOING_ROUTES,
COUNT(R.ROUTEID) AS TOTAL_NUMBER_OF_ROUTES, SUM(R.SERVICECOST) AS TOTAL_SERVICECOST, SUM(R.DISTANCE) AS TOTAL_DISTANCE FROM AIRLINES_2 A, ROUTES_2 R
WHERE A.AIRLINEID = R.AIRLINEID GROUP BY A.AIRLINEID, R.ROUTEID, R.SOURCEAIRPORTID, R.DESTAIRPORTID;

-- MEMBERSHIP FACT

CREATE TABLE MEMBERSHIP_TYPE_SCD_DIM AS
SELECT MT.MEMBERSHIPTYPEID || '_' ||
DENSE_RANK() OVER(PARTITION BY MT.MEMBERSHIPTYPEID ORDER BY TO_DATE(M.JOINDATE, 'DD-MM-YY') ASC) AS MEMBERSHIPTYPEID,
MT.MEMBERSHIPNAME,
M.PASSID,
M.JOINDATE,
M.ENDDATE,
M.PROMOTION,
(MT.MEMBERSHIPFEE -  MT.MEMBERSHIPFEE*P.DISCOUNT) AS FEE,
CASE EXTRACT( YEAR FROM TO_DATE(M.ENDDATE, 'DD-MM-YY')) WHEN EXTRACT( YEAR FROM TO_DATE('2014', 'YYYY')) THEN 'Y' ELSE 'N'
END AS CURRENT_FLAG FROM MEMBERSHIPTYPE_2 MT, MEMBERSHIPJOINRECORDS_2 M, PROMOTION_2 P WHERE M.MEMBERSHIPTYPEID = MT.MEMBERSHIPTYPEID AND P.PROMOTIONID = M.PROMOTION;

CREATE TABLE PASSENGER_DIM AS SELECT * FROM PASSENGERS_2;

CREATE TABLE MEMBERSHIP_SALES_FACT AS SELECT 
M.MEMBERSHIPTYPEID, 
P.PASSID,
P.AGE,
M.JOINDATE,
COUNT(M.MEMBERSHIPTYPEID) AS TOTAL_MEMBERS, 
SUM(F.MEMBERSHIPFEE - F.MEMBERSHIPFEE*PR.DISCOUNT) AS TOTAL_MEMBERSHIPSALES
FROM MEMBERSHIPJOINRECORDS_2 M, MEMBERSHIPTYPE_2 F,PASSENGERS_2 P, PROMOTION_2 PR 
WHERE F.MEMBERSHIPTYPEID = M.MEMBERSHIPTYPEID AND M.PASSID = P.PASSID AND PR.PROMOTIONID = M.PROMOTION 
GROUP BY M.MEMBERSHIPTYPEID, P.PASSID, P.AGE, M.JOINDATE;

-- TRANSACTION FACT

CREATE TABLE FLIGHT_DIM AS SELECT FLIGHTID, FLIGHTDATE, FARE FROM FLIGHTS_2;
CREATE TABLE PASSENGER_NATIONALITY_DIM AS SELECT DISTINCT NATIONALITY FROM PASSENGERS_2;

CREATE TABLE FLIGHT_DATE_DIM AS SELECT DISTINCT FLIGHTDATE FROM FLIGHTS_2;

-- PRESETUP OF TEMPFACT
CREATE TABLE TRANSACTION_TEMP AS SELECT T.FLIGHTID, AR.AIRLINEID,R.ROUTEID, P.PASSID, P.AGE, F.FARE, F.FLIGHTDATE, P.NATIONALITY, R.SOURCEAIRPORTID, R.DESTAIRPORTID,
SUM(T.TOTALPAID) AS TOTAL_PAID_TICKET, SUM(T.TOTALPAID - F.FARE) AS TOTAL_AGENT_PROFIT, COUNT(T.PASSID) AS TOTAL_PASSENGERS FROM FLIGHTS_2 F, PASSENGERS_2 P, TRANSACTIONS_2 T, ROUTES_2 R, AIRLINES_2 AR
WHERE T.PASSID = P.PASSID AND T.FLIGHTID = F.FLIGHTID AND F.ROUTEID = R.ROUTEID AND R.AIRLINEID = AR.AIRLINEID 
GROUP BY T.FLIGHTID, AR.AIRLINEID, R.ROUTEID, P.PASSID, P.AGE, F.FARE, F.FLIGHTDATE, P.NATIONALITY, R.SOURCEAIRPORTID, R.DESTAIRPORTID;

-- TEMPORARY TABLES TO ASSIGN DOMESTIC AND INTERNATIONAL
CREATE TABLE SAC AS SELECT R.ROUTEID, R.SOURCEAIRPORTID, A.COUNTRY AS SOURCE_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.SOURCEAIRPORTID = A.AIRPORTID;
CREATE TABLE DAC AS SELECT R.ROUTEID, R.DESTAIRPORTID, A.COUNTRY AS DEST_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.DESTAIRPORTID = A.AIRPORTID;
CREATE TABLE FINALE AS SELECT S.ROUTEID, S.SOURCE_COUNTRY, D.DEST_COUNTRY FROM SAC S, DAC D WHERE S.ROUTEID = D.ROUTEID;

CREATE TABLE SOURCE_COUNTRY_DIM AS SELECT DISTINCT A.COUNTRY AS SOURCE_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.SOURCEAIRPORTID = A.AIRPORTID;
CREATE TABLE DESTINATION_COUNTRY_DIM AS SELECT DISTINCT A.COUNTRY AS DEST_COUNTRY FROM ROUTES_2 R, AIRPORTS_2 A WHERE R.DESTAIRPORTID = A.AIRPORTID;

CREATE TABLE TRANSACTION_FACT AS SELECT T.FLIGHTID, T.AIRLINEID, T.PASSID, T.AGE, T.FARE, T.FLIGHTDATE AS DATEID, T.NATIONALITY, T.SOURCEAIRPORTID, T.DESTAIRPORTID,
T.TOTAL_PAID_TICKET, T.TOTAL_AGENT_PROFIT, T.TOTAL_PASSENGERS, FI.SOURCE_COUNTRY, FI.DEST_COUNTRY FROM TRANSACTION_TEMP T, FINALE FI WHERE FI.ROUTEID = T.ROUTEID;

