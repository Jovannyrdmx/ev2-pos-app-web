-- Ejecutar una sola vez si la base de datos ya fue creada con una versión anterior.
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS guest_manifest jsonb NOT NULL DEFAULT '[]';
DROP INDEX IF EXISTS active_reservation_zone;
CREATE UNIQUE INDEX active_reservation_zone ON reservations(event_id, zone_id)
  WHERE status IN ('pending_payment','paid','active');

CREATE TABLE IF NOT EXISTS payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid REFERENCES orders(id), reservation_id uuid REFERENCES reservations(id),
  provider text NOT NULL, external_id text UNIQUE, status text NOT NULL DEFAULT 'created', amount_mxn numeric(12,2) NOT NULL,
  currency text NOT NULL DEFAULT 'MXN', checkout_url text, raw_response jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), paid_at timestamptz,
  CHECK ((order_id IS NOT NULL)::integer + (reservation_id IS NOT NULL)::integer = 1)
);
INSERT INTO payment_providers(name,enabled) VALUES ('mercado_pago',false),('cash',true),('terminal',true) ON CONFLICT(name) DO NOTHING;
