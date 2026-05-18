USE `rp_local`;

-- Optionales Zusatz-Seeding
-- Diese Datei kann nach rp_database.sql importiert werden.

INSERT INTO `inventory_items` (`item_name`, `label`, `description`, `stackable`, `max_stack`, `weight`, `usable`)
VALUES ('repair_kit', 'Reparaturset', 'Kann fuer einfache Reparaturen genutzt werden.', 1, 5, 1500, 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT INTO `shops` (`shop_code`, `label`, `shop_type`, `pos_x`, `pos_y`, `pos_z`, `heading`, `enabled`)
VALUES ('247_3', '24/7 Senora Fwy', '24_7', 2678.1000, 3280.4100, 55.2410, 332.0, 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);
