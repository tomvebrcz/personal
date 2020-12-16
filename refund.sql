/* This procedure is looking for returned payouts with reference number, name and bank account in Ledger, CSV and MT940 statements. Also looking for LHV returned payouts which have different reference number.*/

--EXAMPLES: 3855645276,4224908393,3704506155,2029808911,3798653319(only ledger atm)

\prompt 'Enter BankWithdrawalID to find a returned payment: ' bankwithdrawalid

\set QUIET ON

\pset expanded ON

\echo '\n*******************'
\echo '*    STATEMENT    *'
\echo '*******************\n'

WITH tmp AS (

   -- Add new case for each bank which generate new bankreferencenumber (CSV statement)
   SELECT
      CASE
         WHEN ecosysaccount ilike 'CLIENT_FUNDS_ESTONIA_LHVB%' THEN (
            RIGHT(SUBSTRING(array_to_string(textcolumns,','), (POSITION('AcctSvcrRef:' in array_to_string(textcolumns,','))), 31),9)
         )
         ELSE NULL
      END AS "bankreferencenumber"
   FROM
      ledger.view_all_rows
   WHERE
      reference = :'bankwithdrawalid'

   UNION

   -- Add new case for each bank which generate new bankreferencenumber (MT940  statement)
   SELECT
      CASE
         WHEN ecosysaccount ilike 'CLIENT_FUNDS_UNITED_KINGDOM_CITI%' THEN (
            SUBSTRING(array_to_string(textcolumns,','),(POSITION('NMSC' in array_to_string(textcolumns,','))+4),(POSITION('//' in array_to_string(textcolumns,','))-POSITION('NMSC' in array_to_string(textcolumns,','))-4))
         )
         ELSE NULL
      END AS "bankreferencenumber"
   FROM
      mt94xparser.View_All_Rows
   WHERE
      reference = :'bankwithdrawalid'
),
cte AS (
   SELECT
      w.bankwithdrawalid as "reference",
      w.sendingbankaccountid AS "bankaccountid",
      w.datestamp::DATE AS "date",
      w.currency AS "currency",
      w.amount AS "amount",
      CASE
         WHEN (w.amount - (100 * cr.ask)) < 0 THEN 0
         ELSE (w.amount - (100 * cr.ask))
      END AS "amountminusfee",
      w.name AS "name",
      w.toaccountnumber AS "accountnumber",
      ba.ecosysaccount AS "bank"
   FROM
      bankwithdrawals w
      LEFT JOIN bankaccounts ba ON ba.bankaccountid = w.sendingbankaccountid
      LEFT JOIN currencypairs cp ON (w.currency = cp.quotecurrency AND cp.basecurrency = 'EUR')
      LEFT JOIN currencyexchangerates cr ON (cp.currencypairid = cr.currencypairid)
   WHERE
      bankwithdrawalid = :'bankwithdrawalid'
)
SELECT
  'CSV' AS "statement",
  ledgerrowid,
  ecosysaccount,
  currency,
  amount,
  balancedate,
  textcolumns,
  bankledgerid
FROM
  ledger.view_all_rows
WHERE
  ecosysAccount = ( SELECT "bank" FROM cte)
  AND balanceDate BETWEEN ((SELECT "date" FROM cte)) AND ((SELECT "date" FROM cte) + '14 days'::INTERVAL)
  AND currency = (SELECT "currency" FROM cte)
  AND amount BETWEEN (SELECT "amountminusfee" FROM cte) AND (SELECT "amount" FROM cte)
  AND (
         (array_to_string(textcolumns,',') ilike '%' || (SELECT "accountnumber" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "name" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "reference" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "bankreferencenumber" FROM tmp) || '%')
      )

UNION

SELECT
   'MT940' as "statement",
  statementlineid,
  ecosysaccount,
  currency,
  amount,
  balancedate,
  textcolumns,
  bankledgerid
FROM
  mt94xparser.View_All_Rows
WHERE
   ecosysAccount = ( SELECT "bank" FROM cte)
   AND balancedate BETWEEN ((SELECT "date" FROM cte)) AND ((SELECT "date" FROM cte) + '14 days'::INTERVAL)
   AND currency = (SELECT "currency" FROM cte)
   AND amount BETWEEN (SELECT "amountminusfee" FROM cte) AND (SELECT "amount" FROM cte)
   AND (
         (array_to_string(textcolumns,',') ilike '%' || (SELECT "accountnumber" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "name" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "reference" FROM cte) || '%')
      OR (array_to_string(textcolumns,',') ilike '%' || (SELECT "bankreferencenumber" FROM tmp) || '%')
      );

\echo '*******************'
\echo '*   BANK LEDGER   *'
\echo '*******************\n'

WITH tmp AS (

   -- Add new case when the bank generate new bankreferencenumber (CSV statement)
   SELECT
      CASE
         WHEN ecosysaccount ilike 'CLIENT_FUNDS_ESTONIA_LHVB%' THEN (
            RIGHT(SUBSTRING(array_to_string(textcolumns,','), (POSITION('AcctSvcrRef:' in array_to_string(textcolumns,','))), 31),9)
         )
         ELSE NULL
      END AS "bankreferencenumber"
   FROM
      ledger.view_all_rows
   WHERE
      reference = :'bankwithdrawalid'

   UNION

   -- Add new case when the bank generate new bankreferencenumber (MT940  statement)
   SELECT
      CASE
         WHEN ecosysaccount ilike 'CLIENT_FUNDS_UNITED_KINGDOM_CITI%' THEN (
            SUBSTRING(array_to_string(textcolumns,','),(POSITION('NMSC' in array_to_string(textcolumns,','))+4),(POSITION('//' in array_to_string(textcolumns,','))-POSITION('NMSC' in array_to_string(textcolumns,','))-4))
         )
         ELSE NULL
      END AS "bankreferencenumber"
   FROM
      mt94xparser.View_All_Rows
   WHERE
      reference = :'bankwithdrawalid'
),
cte AS (
   SELECT
      w.bankwithdrawalid as "reference",
      w.sendingbankaccountid AS "bankaccountid",
      w.datestamp::DATE AS "date",
      w.currency AS "currency",
      w.amount AS "amount",
      CASE
         WHEN (w.amount - (100 * cr.ask)) < 0 THEN 0
         ELSE (w.amount - (100 * cr.ask))
      END AS "amountminusfee",
      w.name AS "name",
      w.toaccountnumber AS "accountnumber"
   FROM
      bankwithdrawals w
      LEFT JOIN currencypairs cp ON (w.currency = cp.quotecurrency AND cp.basecurrency = 'EUR')
      LEFT JOIN currencyexchangerates cr ON (cp.currencypairid = cr.currencypairid)
   WHERE
      bankwithdrawalid = :'bankwithdrawalid'
)
SELECT
   *
FROM
   view_bank_ledger
WHERE
   bankaccountid = (SELECT "bankaccountid" FROM cte)
   AND date BETWEEN (SELECT "date" FROM cte) AND (SELECT "date" FROM cte) + '14 days'::INTERVAL
   AND currency = (SELECT "currency" FROM cte)
   AND amount BETWEEN (SELECT "amountminusfee" FROM cte) AND (SELECT "amount" FROM cte)
   AND (
         (text ilike '%' || (SELECT "accountnumber" FROM cte) || '%')
      OR (text ilike '%' || (SELECT "name" FROM cte) || '%')
      OR (text ilike '%' || (SELECT "reference" FROM cte) || '%')
      OR (text ilike '%' || (SELECT "bankreferencenumber" FROM tmp) || '%') );

\echo '*******************'
\echo '*      OTHER      *'
\echo '*******************\n'

WITH cte AS (
   SELECT
      w.bankwithdrawalid as "reference",
      w.sendingbankaccountid AS "bankaccountid",
      w.datestamp::DATE AS "date",
      w.currency AS "currency",
      w.amount AS "amount",
      CASE
         WHEN (w.amount - (100 * cr.ask)) < 0 THEN 0
         ELSE (w.amount - (100 * cr.ask))
      END AS "amountminusfee",
      w.name AS "name",
      w.toaccountnumber AS "accountnumber"
   FROM
      bankwithdrawals w
      LEFT JOIN currencypairs cp ON (w.currency = cp.quotecurrency AND cp.basecurrency = 'EUR')
      LEFT JOIN currencyexchangerates cr ON (cp.currencypairid = cr.currencypairid)
   WHERE
      bankwithdrawalid = :'bankwithdrawalid'
)
SELECT
   count(*) AS "POSSIBLE RETURNS",
   'SELECT * FROM view_bank_ledger WHERE bankaccountid = ' || (SELECT "bankaccountid" FROM cte) || ' AND currency = ' || '''' || (SELECT "currency" FROM cte) || '''' || ' AND date BETWEEN ' || '''' || ((SELECT "date" FROM cte)) || '''' || ' AND ' || '''' || ((SELECT "date" FROM cte) + '14 days'::INTERVAL) || '''' || ' AND amount = ' || (SELECT "amount" FROM cte) || ' AND claimable;' AS "QUERY TO RUN"
FROM
   view_bank_ledger
WHERE
   bankaccountid = (SELECT "bankaccountid" FROM cte)
   AND date BETWEEN (SELECT "date" FROM cte) AND ((SELECT "date" FROM cte) + '14 days'::INTERVAL)
   AND currency = (SELECT "currency" FROM cte)
   AND amount = (SELECT "amount" FROM cte)
   AND claimable;

\echo 'ALWAYS DOUBLE CHECK THE RESULT!'

-- Inserts data of this execution in temp table. Copy this data into GoogleDrive. Copy from GoogleDrive ALL data back into another temp table for viewing.
\t
SELECT pg_temp.user_log_function(user::text, now()::timestamp , 'find_returned_payout');
\t
\i '~/.support-sql-procedures/userlogsetup.psql'
