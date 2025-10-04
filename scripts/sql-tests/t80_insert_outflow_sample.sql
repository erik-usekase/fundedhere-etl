-- scripts/sql-tests/t80_insert_outflow_sample.sql
-- Minimal-column INSERT matching raw.va_txn schema.
-- Adds demo OUTFLOWS so Level-2 "Paid" buckets light up.

INSERT INTO raw.va_txn(
  sender_virtual_account_id,
  sender_virtual_account_number,
  sender_note_id,
  receiver_virtual_account_id,
  receiver_virtual_account_number,
  receiver_note_id,
  receiver_va_opening_balance,
  receiver_va_closing_balance,
  amount,
  date,
  remarks
) VALUES
  -- Admin fee outflow (maps via ref.remarks_category_map to admin_fee)
  ('na','8850633926172','44',NULL,NULL,NULL,NULL,NULL,'3.01','9/30/2025','fh-admin-fee'),

  -- Management fee outflow (maps via regex "management fee" -> mgmt_fee)
  ('na','8850633926172','44',NULL,NULL,NULL,NULL,NULL,'2.51','9/30/2025','management fee'),

  -- Senior principal outflow (maps via regex "sr principal" -> sr_prin)
  ('na','8850633926172','44',NULL,NULL,NULL,NULL,NULL,'91','9/30/2025','sr principal');
