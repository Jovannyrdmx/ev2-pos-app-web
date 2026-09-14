-- Ejecutar después de init.sql. Carga la estructura editable inicial de EV2.
WITH source(map_key,name,floor,bar_name,capacity,map_config) AS (
  VALUES
  ('pb-vip-01','VIP PB 01','planta_baja','Bar Planta Baja',6,'{"x":8,"y":18,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pb-vip-02','VIP PB 02','planta_baja','Bar Planta Baja',6,'{"x":31,"y":18,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pb-vip-03','VIP PB 03','planta_baja','Bar Planta Baja',8,'{"x":54,"y":18,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pb-vip-04','VIP PB 04','planta_baja','Bar Planta Baja',8,'{"x":77,"y":18,"w":15,"h":20,"shape":"table"}'::jsonb),
  ('pb-pista','Punto de entrega · Pista PB','planta_baja','Bar Planta Baja',999,'{"x":28,"y":51,"w":44,"h":28,"shape":"delivery"}'::jsonb),
  ('pa-vip-01','VIP PA 01','planta_alta','Bar Planta Alta',6,'{"x":8,"y":17,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pa-vip-02','VIP PA 02','planta_alta','Bar Planta Alta',6,'{"x":31,"y":17,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pa-vip-03','VIP PA 03','planta_alta','Bar Planta Alta',8,'{"x":54,"y":17,"w":18,"h":20,"shape":"table"}'::jsonb),
  ('pa-vip-04','VIP PA 04','planta_alta','Bar Planta Alta',8,'{"x":77,"y":17,"w":15,"h":20,"shape":"table"}'::jsonb),
  ('pa-pista','Punto de entrega · Pista PA','planta_alta','Bar Planta Alta',999,'{"x":28,"y":51,"w":44,"h":28,"shape":"delivery"}'::jsonb)
)
INSERT INTO zones(map_key,name,floor,bar_id,capacity,map_config)
SELECT s.map_key,s.name,s.floor,b.id,s.capacity,s.map_config FROM source s JOIN bars b ON b.name=s.bar_name
ON CONFLICT (map_key) DO UPDATE SET name=EXCLUDED.name,floor=EXCLUDED.floor,bar_id=EXCLUDED.bar_id,capacity=EXCLUDED.capacity,map_config=EXCLUDED.map_config;
