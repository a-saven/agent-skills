CREATE TABLE orders (
  id             text PRIMARY KEY,
  customer_email text NOT NULL,
  status         text NOT NULL CHECK (status IN ('pending', 'paid', 'refunded')),
  total_cents    integer NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX orders_status_created_at ON orders (status, created_at DESC);
