CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE user_role AS ENUM ('admin','manager','security','reception','waiter','bartender','warehouse','cashier','customer');
CREATE TYPE order_status AS ENUM ('pending_payment','paid','in_preparation','ready','delivering','delivered','cancelled');
CREATE TYPE ticket_status AS ENUM ('issued','entered','denied','revoked');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text UNIQUE, phone text UNIQUE,
  password_hash text, display_name text NOT NULL, legal_name text, photo_url text,
  date_of_birth date, role user_role NOT NULL DEFAULT 'customer', flirty_visible boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bars (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE, floor text NOT NULL);
CREATE TABLE zones (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE, floor text NOT NULL, bar_id uuid REFERENCES bars(id), map_key text UNIQUE, map_config jsonb NOT NULL DEFAULT '{}', capacity integer NOT NULL DEFAULT 1 CHECK(capacity > 0), extra_capacity integer NOT NULL DEFAULT 0 CHECK(extra_capacity >= 0), base_price_mxn numeric(12,2) NOT NULL DEFAULT 0 CHECK(base_price_mxn >= 0), reservable boolean NOT NULL DEFAULT true, active boolean NOT NULL DEFAULT true);
CREATE TABLE staff_zone_assignments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), employee_id uuid REFERENCES users(id), zone_id uuid REFERENCES zones(id), starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz);
CREATE TABLE events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, opens_at timestamptz NOT NULL, closes_at timestamptz NOT NULL, details text, exchange_rate numeric(10,2), exchange_rate_date date, active boolean NOT NULL DEFAULT true);
CREATE TABLE event_zone_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  zone_id uuid NOT NULL REFERENCES zones(id) ON DELETE CASCADE, price_mxn numeric(12,2) NOT NULL CHECK(price_mxn >= 0),
  included_credit_mxn numeric(12,2) NOT NULL DEFAULT 0 CHECK(included_credit_mxn >= 0),
  included_products jsonb NOT NULL DEFAULT '[]', included_tickets integer NOT NULL DEFAULT 0 CHECK(included_tickets >= 0),
  extra_ticket_enabled boolean NOT NULL DEFAULT false, extra_ticket_price_mxn numeric(12,2), active boolean NOT NULL DEFAULT true,
  UNIQUE(event_id, zone_id)
);
CREATE TABLE payment_providers (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE, enabled boolean NOT NULL DEFAULT false, configuration jsonb NOT NULL DEFAULT '{}', updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE products (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sku text UNIQUE NOT NULL, name text NOT NULL, category text NOT NULL, price_mxn numeric(12,2) NOT NULL CHECK(price_mxn >= 0), price_usd numeric(12,2), unit text NOT NULL DEFAULT 'unit', active boolean NOT NULL DEFAULT true);
CREATE TABLE recipes (product_id uuid REFERENCES products(id) ON DELETE CASCADE, ingredient_product_id uuid REFERENCES products(id), quantity numeric(12,2) NOT NULL CHECK(quantity > 0), unit text NOT NULL CHECK(unit IN ('ml','unit')), PRIMARY KEY(product_id, ingredient_product_id));
CREATE TABLE inventory_locations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE, kind text NOT NULL CHECK(kind IN ('warehouse','bar')));
CREATE TABLE inventory_balances (location_id uuid REFERENCES inventory_locations(id), product_id uuid REFERENCES products(id), quantity numeric(14,2) NOT NULL DEFAULT 0, PRIMARY KEY(location_id, product_id));
CREATE TABLE inventory_movements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid REFERENCES products(id), from_location_id uuid REFERENCES inventory_locations(id), to_location_id uuid REFERENCES inventory_locations(id), quantity numeric(14,2) NOT NULL CHECK(quantity > 0), reason text NOT NULL, actor_id uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE reservations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid REFERENCES events(id), zone_id uuid REFERENCES zones(id), owner_id uuid REFERENCES users(id), status text NOT NULL DEFAULT 'paid', paid_mxn numeric(12,2) NOT NULL, included_credit_mxn numeric(12,2) NOT NULL DEFAULT 0, included_credit_used_mxn numeric(12,2) NOT NULL DEFAULT 0, included_products jsonb NOT NULL DEFAULT '[]', included_products_claimed jsonb NOT NULL DEFAULT '[]', guest_manifest jsonb NOT NULL DEFAULT '[]', activated_at timestamptz, hold_until timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX active_reservation_zone ON reservations(event_id, zone_id) WHERE status IN ('pending_payment','paid','active');
CREATE TABLE tickets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reservation_id uuid REFERENCES reservations(id), holder_name text NOT NULL, holder_phone text, token_hash text NOT NULL UNIQUE, status ticket_status NOT NULL DEFAULT 'issued', entered_at timestamptz, denial_reason text, reassigned_from uuid REFERENCES tickets(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE orders (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), folio text NOT NULL UNIQUE, event_id uuid REFERENCES events(id), zone_id uuid REFERENCES zones(id), bar_id uuid REFERENCES bars(id), customer_id uuid REFERENCES users(id), waiter_id uuid REFERENCES users(id), status order_status NOT NULL DEFAULT 'pending_payment', currency text NOT NULL DEFAULT 'MXN', subtotal numeric(12,2) NOT NULL, tip_mxn numeric(12,2) NOT NULL DEFAULT 0, payment_method text, paid_at timestamptz, ready_at timestamptz, delivered_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid REFERENCES orders(id), reservation_id uuid REFERENCES reservations(id),
  provider text NOT NULL, external_id text UNIQUE, status text NOT NULL DEFAULT 'created', amount_mxn numeric(12,2) NOT NULL,
  currency text NOT NULL DEFAULT 'MXN', checkout_url text, raw_response jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), paid_at timestamptz,
  CHECK ((order_id IS NOT NULL)::integer + (reservation_id IS NOT NULL)::integer = 1)
);
CREATE TABLE order_items (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid REFERENCES orders(id) ON DELETE CASCADE, product_id uuid REFERENCES products(id), quantity integer NOT NULL CHECK(quantity > 0), unit_price_mxn numeric(12,2) NOT NULL, notes text);
CREATE TABLE flirty_gifts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid REFERENCES orders(id), sender_id uuid REFERENCES users(id), recipient_id uuid REFERENCES users(id), visibility text NOT NULL CHECK(visibility IN ('named','anonymous')), status text NOT NULL DEFAULT 'pending', responded_at timestamptz);
CREATE TABLE audit_log (id bigserial PRIMARY KEY, actor_id uuid REFERENCES users(id), action text NOT NULL, entity text NOT NULL, entity_id uuid, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE employee_tip_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), employee_id uuid NOT NULL REFERENCES users(id), order_id uuid REFERENCES orders(id),
  amount_mxn numeric(12,2) NOT NULL CHECK(amount_mxn > 0), status text NOT NULL DEFAULT 'available' CHECK(status IN ('available','withdrawn')),
  withdrawn_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE contingency_passes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid REFERENCES tickets(id), issued_by uuid REFERENCES users(id), token_hash text NOT NULL UNIQUE, reason text NOT NULL, status ticket_status NOT NULL DEFAULT 'issued', expires_at timestamptz NOT NULL, used_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());

INSERT INTO bars(name,floor) VALUES ('Bar Planta Baja','planta_baja'),('Bar Planta Alta','planta_alta');
INSERT INTO inventory_locations(name,kind) VALUES ('Almacén','warehouse'),('Bar Planta Baja','bar'),('Bar Planta Alta','bar');
INSERT INTO payment_providers(name,enabled) VALUES ('mercado_pago',false),('cash',true),('terminal',true);
