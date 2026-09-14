/**
 * Construye datos importables a partir de los dos PDF entregados por EV2.
 * Requiere poppler-utils (pdftotext), incluido en Ubuntu 24.04.
 *
 * Ejecutar: node data/build-ev2-source-data.mjs
 * Los archivos producidos no contienen precios B2/B3 duplicados: por cada
 * artículo se conserva el precio más alto, como acordó EV2.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const text = name => execFileSync('pdftotext', ['-raw', path.join(here, 'source', name), '-'], { encoding: 'utf8' })
  .replace(/\f/g, '\n');
const clean = value => value.replace(/\s+/g, ' ').trim();
const baseName = value => clean(value).replace(/\s+B[23](?=\s|$)/gi, '').replace(/\s+/g, ' ').trim();
const slug = value => baseName(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase()
  .replace(/[^A-Z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 80);
const category = name => {
  const n = name.toUpperCase();
  if (/CUB|MICHELOB|TECATE|CERVEZA|CAGUAMA/.test(n)) return 'beer';
  if (/COVER|BOLETO|PULSERA|BARRA LIBRE|PASWORD/.test(n)) return 'access';
  if (/BOTELLA|ABSOLUT|BACARDI|LABEL|BUCHANANS|TEQUILA|MEZCAL|MOET|DOM |VODKA|TITOS|BOMBAY|JAGER|TORRES|NUVO|GREY GOOSE|CHAMPAGNE|CLASE AZUL|DON JULIO/.test(n)) return 'bottle';
  if (/CUBETA|RONDA|SHOT/.test(n)) return 'shots_and_buckets';
  if (/AGUA|COCA|JUGO|MONSTER|SPRITE|SQUIRT/.test(n)) return 'mixer';
  return 'cocktail';
};

// Catálogo de venta. El PDF usa una línea por artículo y conserva variantes B2/B3.
const catalog = new Map();
for (const line of text('productos.pdf').split('\n').map(clean)) {
  const match = line.match(/^(.*?)\s+\$([\d,]+\.\d{2})$/);
  if (!match || /^DESCRIPCION\s+PRECIO$/i.test(match[1]) || match[1] === '.') continue;
  const name = baseName(match[1]);
  if (!name) continue;
  const price_mxn = Number(match[2].replaceAll(',', ''));
  const key = slug(name);
  const current = catalog.get(key);
  if (!current || price_mxn > current.price_mxn) catalog.set(key, { sku: `SALE-${key}`, name, category: category(name), price_mxn, unit: 'unit', active: price_mxn > 0 });
}

// Recetas. Se conservan ingredientes por código del sistema de origen. OZ se
// convierte con la regla aprobada: 1 oz = 30 ml. Las unidades físicas (PZA,
// BOTE, CUAR) quedan declaradas para que el inventario no las trate como ml.
const recipeText = text('recetas.pdf').split('\n').map(clean).filter(Boolean);
const recipeProducts = new Map();
const ingredients = new Map();
let current = null;
for (let index = 0; index < recipeText.length; index += 1) {
  const line = recipeText[index];
  const directHeader = line.match(/^(\d{5,6})\s+(.+?)\s+(\d{2})\s+[A-ZÑ][A-ZÑ 0-9/]+\s+-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+\s+0\s+0$/);
  const splitHeader = line.match(/^(\d{5,6})\s+(.+)$/);
  if (directHeader) {
    current = { code: directHeader[1], name: baseName(directHeader[2]) };
    recipeProducts.set(current.code, current);
    continue;
  }
  if (splitHeader && !line.startsWith('0 ')) {
    const next = recipeText[index + 1] || '';
    if (/^\d{2}\s+[A-ZÑ]/.test(next) && /\s+-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+\s+0\s+0$/.test(next)) {
      current = { code: splitHeader[1], name: baseName(splitHeader[2]) };
      recipeProducts.set(current.code, current);
      continue;
    }
  }
  const item = line.match(/^0\s+0\s+0\s+([\d.]+)\s+(OZ|PZA|BOTE|CUAR|LITRO|LT|ML)\s+(\d{6})\s+(.+)$/i);
  if (!current || !item) continue;
  const [, rawQuantity, sourceUnit, ingredientCode, rawDescription] = item;
  const unit = sourceUnit.toUpperCase();
  const quantity = Number(rawQuantity);
  const description = clean(rawDescription.replace(/\s+-?[\d.]+$/, ''));
  const ingredientSku = `ING-${ingredientCode}`;
  if (!ingredients.has(ingredientSku)) ingredients.set(ingredientSku, {
    sku: ingredientSku, name: description || `Insumo ${ingredientCode}`, category: 'ingredient', price_mxn: 0,
    unit: unit === 'OZ' || unit === 'ML' || unit === 'LT' || unit === 'LITRO' ? 'ml' : 'unit', active: false,
    source_code: ingredientCode
  });
  const productName = baseName(current.name);
  const productSku = `SALE-${slug(productName)}`;
  const measurement = unit === 'OZ' ? { quantity: quantity * 30, unit: 'ml' } : unit === 'ML' ? { quantity, unit: 'ml' } : unit === 'LT' || unit === 'LITRO' ? { quantity: quantity * 1000, unit: 'ml' } : { quantity, unit: 'unit' };
  const key = `${productSku}|${ingredientSku}|${measurement.unit}`;
  const old = current.ingredients?.get(key) || 0;
  if (!current.ingredients) current.ingredients = new Map();
  current.ingredients.set(key, old + measurement.quantity);
}

const products = [...catalog.values(), ...[...ingredients.values()].filter(item => !catalog.has(item.sku.replace(/^ING-/, 'SALE-')))];
const recipeCandidates = new Map();
const unmatchedRecipeProducts = [];
for (const record of recipeProducts.values()) {
  const product_sku = `SALE-${slug(record.name)}`;
  if (!catalog.has(slug(record.name))) { unmatchedRecipeProducts.push({ source_code: record.code, name: record.name }); continue; }
  for (const [key, quantity] of record.ingredients || []) {
    const [, ingredient_sku, unit] = key.split('|');
    const candidateKey = `${product_sku}|${ingredient_sku}|${unit}`;
    if (!recipeCandidates.has(candidateKey)) recipeCandidates.set(candidateKey, []);
    recipeCandidates.get(candidateKey).push(quantity);
  }
}
// B2/B3 son la misma presentación comercial. Para recetas repetidas se toma
// la cantidad más frecuente; en empate se prefiere la menor, evitando que un
// valor anómalo de una sola variante multiplique la salida de inventario.
const recipes = [...recipeCandidates.entries()].map(([key, amounts]) => {
  const [product_sku, ingredient_sku, unit] = key.split('|');
  const frequency = new Map();
  for (const amount of amounts) frequency.set(amount, (frequency.get(amount) || 0) + 1);
  const quantity = [...frequency.entries()].sort((a, b) => b[1] - a[1] || a[0] - b[0])[0][0];
  return { product_sku, ingredient_sku, quantity, unit };
});
const payload = { generated_at: new Date().toISOString(), source: { catalog: 'productos.pdf', recipes: 'recetas.pdf' }, products, recipes, unmatched_recipe_products: unmatchedRecipeProducts };
fs.writeFileSync(path.join(here, 'ev2-catalog.json'), JSON.stringify(payload, null, 2) + '\n');
fs.writeFileSync(path.join(here, 'products.csv'), ['sku,name,category,price_mxn,price_usd,unit,active', ...products.map(p => [p.sku, JSON.stringify(p.name), p.category, p.price_mxn, '', p.unit, p.active].join(','))].join('\n') + '\n');
fs.writeFileSync(path.join(here, 'recipes.json'), JSON.stringify({ recipes, unmatched_recipe_products: unmatchedRecipeProducts }, null, 2) + '\n');
console.log(`Datos EV2 generados: ${catalog.size} artículos de venta, ${ingredients.size} insumos, ${recipes.length} líneas de receta. ${unmatchedRecipeProducts.length} recetas requieren revisión de nombre.`);
