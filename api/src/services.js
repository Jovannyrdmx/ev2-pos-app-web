import crypto from 'node:crypto';

export const token = () => crypto.randomBytes(32).toString('base64url');
export const hash = value => crypto.createHash('sha256').update(value).digest('hex');
export const folio = () => `EV2-${new Date().toISOString().slice(0,10).replaceAll('-','')}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;

export async function audit(db, actorId, action, entity, entityId, metadata = {}) {
  await db.query('INSERT INTO audit_log(actor_id,action,entity,entity_id,metadata) VALUES($1,$2,$3,$4,$5)', [actorId, action, entity, entityId, metadata]);
}

export async function changeInventory(db, { productId, fromLocationId, toLocationId, quantity, quantityMl, reason, actorId }) {
  const amount = Number(quantity ?? quantityMl);
  if (!(amount > 0)) throw new Error('La cantidad debe ser mayor a cero');
  if (fromLocationId) {
    const result = await db.query('UPDATE inventory_balances SET quantity=quantity-$1 WHERE location_id=$2 AND product_id=$3 AND quantity >= $1 RETURNING quantity', [amount, fromLocationId, productId]);
    if (!result.rowCount) throw new Error('Existencia insuficiente en la ubicación de origen');
  }
  if (toLocationId) await db.query('INSERT INTO inventory_balances(location_id,product_id,quantity) VALUES($1,$2,$3) ON CONFLICT(location_id,product_id) DO UPDATE SET quantity=inventory_balances.quantity+EXCLUDED.quantity', [toLocationId, productId, amount]);
  await db.query('INSERT INTO inventory_movements(product_id,from_location_id,to_location_id,quantity,reason,actor_id) VALUES($1,$2,$3,$4,$5,$6)', [productId, fromLocationId, toLocationId, amount, reason, actorId]);
}

export async function consumeRecipe(db, orderId, barId, actorId) {
  const location = await db.query('SELECT il.id FROM inventory_locations il JOIN bars b ON b.name=il.name WHERE b.id=$1', [barId]);
  if (!location.rowCount) return;
  const ingredients = await db.query(`SELECT r.ingredient_product_id, r.unit, SUM(r.quantity*oi.quantity) quantity FROM order_items oi JOIN recipes r ON r.product_id=oi.product_id WHERE oi.order_id=$1 GROUP BY r.ingredient_product_id,r.unit`, [orderId]);
  for (const row of ingredients.rows) await changeInventory(db, { productId: row.ingredient_product_id, fromLocationId: location.rows[0].id, quantity: Number(row.quantity), reason: 'sale_recipe', actorId });
}

export const money = value => Math.round((Number(value) + Number.EPSILON) * 100) / 100;

export async function markOrderPaid(db, orderId, { method, actorId, externalId = null }) {
  const order = await db.query("SELECT * FROM orders WHERE id=$1 FOR UPDATE", [orderId]);
  if (!order.rowCount) throw new Error('Pedido no encontrado');
  const value = order.rows[0];
  if (value.status === 'paid') return value;
  if (value.status !== 'pending_payment') throw new Error('El pedido no está disponible para pago');
  const paid = await db.query("UPDATE orders SET status='paid', payment_method=$1, paid_at=now() WHERE id=$2 RETURNING *", [method, orderId]);
  await consumeRecipe(db, orderId, value.bar_id, actorId);
  await audit(db, actorId, 'order.paid', 'order', orderId, { method, externalId });
  return paid.rows[0];
}
