-- RP Local Database Schema
-- Ziel: Lokaler FiveM RP Server mit ESX-kompatibler Struktur und eigenen Spieler-Systemen

CREATE DATABASE IF NOT EXISTS `rp_local`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `rp_local`;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `audit_log`;
DROP TABLE IF EXISTS `phone_contacts`;
DROP TABLE IF EXISTS `licenses`;
DROP TABLE IF EXISTS `outfits`;
DROP TABLE IF EXISTS `character_jobs`;
DROP TABLE IF EXISTS `job_grades`;
DROP TABLE IF EXISTS `jobs`;
DROP TABLE IF EXISTS `owned_vehicles`;
DROP TABLE IF EXISTS `vehicles`;
DROP TABLE IF EXISTS `shop_vehicles`;
DROP TABLE IF EXISTS `shop_items`;
DROP TABLE IF EXISTS `shops`;
DROP TABLE IF EXISTS `character_inventory`;
DROP TABLE IF EXISTS `inventory_items`;
DROP TABLE IF EXISTS `bank_transactions`;
DROP TABLE IF EXISTS `bank_accounts`;
DROP TABLE IF EXISTS `accounts`;
DROP TABLE IF EXISTS `spawn_points`;
DROP TABLE IF EXISTS `garages`;
DROP TABLE IF EXISTS `character_skin`;
DROP TABLE IF EXISTS `character_identity`;
DROP TABLE IF EXISTS `characters`;
DROP TABLE IF EXISTS `users`;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license` VARCHAR(64) NOT NULL,
  `fivem_id` VARCHAR(32) NULL,
  `steam_id` VARCHAR(64) NULL,
  `discord_id` VARCHAR(64) NULL,
  `first_seen_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_banned` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_users_license` (`license`),
  KEY `idx_users_fivem_id` (`fivem_id`),
  KEY `idx_users_discord_id` (`discord_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `characters` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `slot` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `character_code` VARCHAR(24) NOT NULL,
  `first_name` VARCHAR(64) NOT NULL,
  `last_name` VARCHAR(64) NOT NULL,
  `date_of_birth` DATE NOT NULL,
  `sex` ENUM('m','f','d') NOT NULL DEFAULT 'd',
  `height_cm` SMALLINT UNSIGNED NOT NULL DEFAULT 175,
  `nationality` VARCHAR(64) NOT NULL,
  `last_pos_x` DECIMAL(10,4) NULL,
  `last_pos_y` DECIMAL(10,4) NULL,
  `last_pos_z` DECIMAL(10,4) NULL,
  `last_heading` DECIMAL(10,4) NULL,
  `is_new` TINYINT(1) NOT NULL DEFAULT 1,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_characters_character_code` (`character_code`),
  UNIQUE KEY `ux_characters_user_slot` (`user_id`, `slot`),
  KEY `idx_characters_user_active` (`user_id`, `is_active`),
  CONSTRAINT `fk_characters_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_identity` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `first_name` VARCHAR(64) NOT NULL,
  `last_name` VARCHAR(64) NOT NULL,
  `date_of_birth` DATE NOT NULL,
  `sex` ENUM('m','f','d') NOT NULL,
  `height_cm` SMALLINT UNSIGNED NOT NULL,
  `nationality` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  CONSTRAINT `fk_character_identity_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_skin` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `model` VARCHAR(64) NOT NULL DEFAULT 'mp_m_freemode_01',
  `skin_json` JSON NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  CONSTRAINT `fk_character_skin_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `account_type` ENUM('cash','bank') NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_accounts_character_type` (`character_id`, `account_type`),
  KEY `idx_accounts_character` (`character_id`),
  CONSTRAINT `fk_accounts_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `bank_accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `account_number` VARCHAR(20) NOT NULL,
  `iban` VARCHAR(34) NULL,
  `pin_hash` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_bank_accounts_character` (`character_id`),
  UNIQUE KEY `ux_bank_accounts_account_number` (`account_number`),
  CONSTRAINT `fk_bank_accounts_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `bank_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bank_account_id` BIGINT UNSIGNED NOT NULL,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `transaction_type` ENUM('deposit','withdraw','transfer_in','transfer_out','system') NOT NULL,
  `amount` BIGINT NOT NULL,
  `balance_before` BIGINT NOT NULL,
  `balance_after` BIGINT NOT NULL,
  `target_account_number` VARCHAR(20) NULL,
  `target_character_id` BIGINT UNSIGNED NULL,
  `reference` VARCHAR(128) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bank_transactions_account` (`bank_account_id`, `created_at`),
  KEY `idx_bank_transactions_character` (`character_id`, `created_at`),
  KEY `idx_bank_transactions_target_character` (`target_character_id`),
  CONSTRAINT `fk_bank_transactions_bank_account` FOREIGN KEY (`bank_account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_bank_transactions_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_bank_transactions_target_character` FOREIGN KEY (`target_character_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `inventory_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `item_name` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `description` VARCHAR(255) NULL,
  `stackable` TINYINT(1) NOT NULL DEFAULT 1,
  `max_stack` INT UNSIGNED NOT NULL DEFAULT 999,
  `weight` INT UNSIGNED NOT NULL DEFAULT 0,
  `usable` TINYINT(1) NOT NULL DEFAULT 0,
  `metadata_schema` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_inventory_items_name` (`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_inventory` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `item_id` BIGINT UNSIGNED NOT NULL,
  `quantity` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot` INT UNSIGNED NULL,
  `metadata` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_character_inventory_stack` (`character_id`, `item_id`),
  KEY `idx_character_inventory_character` (`character_id`),
  CONSTRAINT `fk_character_inventory_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_character_inventory_item` FOREIGN KEY (`item_id`) REFERENCES `inventory_items` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `shops` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `shop_code` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `shop_type` ENUM('24_7','clothing','vehicle') NOT NULL DEFAULT '24_7',
  `pos_x` DECIMAL(10,4) NOT NULL,
  `pos_y` DECIMAL(10,4) NOT NULL,
  `pos_z` DECIMAL(10,4) NOT NULL,
  `heading` DECIMAL(10,4) NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `blip_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_shops_code` (`shop_code`),
  KEY `idx_shops_type_enabled` (`shop_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `shop_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `shop_id` BIGINT UNSIGNED NOT NULL,
  `item_id` BIGINT UNSIGNED NOT NULL,
  `price` INT UNSIGNED NOT NULL,
  `currency` ENUM('cash','bank') NOT NULL DEFAULT 'cash',
  `stock` INT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_shop_items_shop_item` (`shop_id`, `item_id`),
  KEY `idx_shop_items_shop_enabled` (`shop_id`, `enabled`),
  CONSTRAINT `fk_shop_items_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_shop_items_item` FOREIGN KEY (`item_id`) REFERENCES `inventory_items` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `vehicles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `model` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `price` INT UNSIGNED NOT NULL DEFAULT 0,
  `category` VARCHAR(32) NOT NULL DEFAULT 'civil',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_vehicles_model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `shop_vehicles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `shop_id` BIGINT UNSIGNED NOT NULL,
  `vehicle_id` BIGINT UNSIGNED NOT NULL,
  `price` INT UNSIGNED NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_shop_vehicles_shop_vehicle` (`shop_id`, `vehicle_id`),
  KEY `idx_shop_vehicles_shop_enabled` (`shop_id`, `enabled`),
  CONSTRAINT `fk_shop_vehicles_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_shop_vehicles_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `garages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `garage_code` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `pos_x` DECIMAL(10,4) NOT NULL,
  `pos_y` DECIMAL(10,4) NOT NULL,
  `pos_z` DECIMAL(10,4) NOT NULL,
  `spawn_x` DECIMAL(10,4) NOT NULL,
  `spawn_y` DECIMAL(10,4) NOT NULL,
  `spawn_z` DECIMAL(10,4) NOT NULL,
  `spawn_heading` DECIMAL(10,4) NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_garages_code` (`garage_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `owned_vehicles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `vehicle_id` BIGINT UNSIGNED NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `props_json` JSON NOT NULL,
  `stored` TINYINT(1) NOT NULL DEFAULT 1,
  `garage_id` BIGINT UNSIGNED NULL,
  `fuel` DECIMAL(5,2) NOT NULL DEFAULT 100.00,
  `engine_health` DECIMAL(8,2) NOT NULL DEFAULT 1000.00,
  `body_health` DECIMAL(8,2) NOT NULL DEFAULT 1000.00,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_owned_vehicles_plate` (`plate`),
  KEY `idx_owned_vehicles_character` (`character_id`),
  KEY `idx_owned_vehicles_garage` (`garage_id`),
  CONSTRAINT `fk_owned_vehicles_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_owned_vehicles_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_owned_vehicles_garage` FOREIGN KEY (`garage_id`) REFERENCES `garages` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `jobs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `default_duty` TINYINT(1) NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_jobs_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `job_grades` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_id` BIGINT UNSIGNED NOT NULL,
  `grade` INT UNSIGNED NOT NULL,
  `grade_name` VARCHAR(64) NOT NULL,
  `salary` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_job_grades_job_grade` (`job_id`, `grade`),
  CONSTRAINT `fk_job_grades_job` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_jobs` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `job_id` BIGINT UNSIGNED NOT NULL,
  `grade_id` BIGINT UNSIGNED NOT NULL,
  `on_duty` TINYINT(1) NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  KEY `idx_character_jobs_job` (`job_id`),
  CONSTRAINT `fk_character_jobs_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_character_jobs_job` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_character_jobs_grade` FOREIGN KEY (`grade_id`) REFERENCES `job_grades` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `spawn_points` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `spawn_code` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `pos_x` DECIMAL(10,4) NOT NULL,
  `pos_y` DECIMAL(10,4) NOT NULL,
  `pos_z` DECIMAL(10,4) NOT NULL,
  `heading` DECIMAL(10,4) NOT NULL DEFAULT 0,
  `is_default` TINYINT(1) NOT NULL DEFAULT 0,
  `is_new_player` TINYINT(1) NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_spawn_points_code` (`spawn_code`),
  KEY `idx_spawn_points_default_new` (`is_default`, `is_new_player`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `outfits` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `skin_json` JSON NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_outfits_character` (`character_id`),
  CONSTRAINT `fk_outfits_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `licenses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `license_type` VARCHAR(64) NOT NULL,
  `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_licenses_character_type` (`character_id`, `license_type`),
  CONSTRAINT `fk_licenses_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `phone_contacts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `contact_name` VARCHAR(64) NOT NULL,
  `contact_number` VARCHAR(32) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_phone_contacts_character` (`character_id`),
  CONSTRAINT `fk_phone_contacts_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `audit_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_type` VARCHAR(64) NOT NULL,
  `character_id` BIGINT UNSIGNED NULL,
  `user_id` BIGINT UNSIGNED NULL,
  `source` VARCHAR(64) NULL,
  `details` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_event_type` (`event_type`),
  KEY `idx_audit_character` (`character_id`),
  KEY `idx_audit_user` (`user_id`),
  CONSTRAINT `fk_audit_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed: Jobs
INSERT INTO `jobs` (`job_name`, `label`, `default_duty`, `enabled`) VALUES
('unemployed', 'Arbeitslos', 0, 1),
('delivery', 'Lieferfahrer', 0, 1),
('garbage', 'Muellabfuhr', 0, 1),
('taxi', 'Taxi', 0, 1);

INSERT INTO `job_grades` (`job_id`, `grade`, `grade_name`, `salary`)
SELECT j.id, 0, 'Einsteiger', 250 FROM jobs j WHERE j.job_name IN ('unemployed', 'delivery', 'garbage', 'taxi')
UNION ALL
SELECT j.id, 1, 'Erfahren', 400 FROM jobs j WHERE j.job_name IN ('delivery', 'garbage', 'taxi');

-- Seed: Spawnpunkte
INSERT INTO `spawn_points` (`spawn_code`, `label`, `pos_x`, `pos_y`, `pos_z`, `heading`, `is_default`, `is_new_player`, `enabled`) VALUES
('airport_arrival', 'Flughafen Ankunft', -1037.6600, -2737.8200, 20.1693, 327.0, 1, 1, 1),
('city_center', 'Stadtzentrum', 215.7600, -920.3300, 30.6920, 249.0, 1, 0, 1);

-- Seed: Garagen
INSERT INTO `garages` (`garage_code`, `label`, `pos_x`, `pos_y`, `pos_z`, `spawn_x`, `spawn_y`, `spawn_z`, `spawn_heading`, `enabled`) VALUES
('airport_garage', 'Flughafen Garage', -1034.5300, -2732.0200, 20.1693, -1026.1000, -2730.7000, 20.1136, 240.0, 1),
('legion_garage', 'Legion Garage', 219.9300, -804.2600, 30.7400, 232.5400, -801.2700, 30.5700, 159.0, 1);

-- Seed: Items
INSERT INTO `inventory_items` (`item_name`, `label`, `description`, `stackable`, `max_stack`, `weight`, `usable`) VALUES
('water', 'Wasser', 'Eine Flasche Wasser.', 1, 20, 250, 1),
('bread', 'Brot', 'Frisches Brot.', 1, 20, 300, 1),
('phone', 'Handy', 'Ein einfaches Smartphone.', 0, 1, 500, 0),
('id_card', 'Personalausweis', 'Amtliches Ausweisdokument.', 0, 1, 10, 0),
('driver_license', 'Fuehrerschein', 'Erlaubt das Fahren von Fahrzeugen.', 0, 1, 10, 0);

-- Seed: Shops
INSERT INTO `shops` (`shop_code`, `label`, `shop_type`, `pos_x`, `pos_y`, `pos_z`, `heading`, `enabled`, `blip_enabled`) VALUES
('247_1', '24/7 Innocence Blvd', '24_7', 25.8400, -1345.2200, 29.4970, 271.0, 1, 1),
('247_2', '24/7 Vespucci', '24_7', -1222.9100, -906.9800, 12.3260, 35.0, 1, 1),
('clothing_1', 'Kleidung Downtown', 'clothing', 73.9200, -1392.5600, 29.3760, 270.0, 1, 1);

INSERT INTO `shop_items` (`shop_id`, `item_id`, `price`, `currency`, `stock`, `enabled`)
SELECT s.id, i.id, 15, 'cash', NULL, 1 FROM shops s JOIN inventory_items i ON i.item_name = 'water' WHERE s.shop_type = '24_7'
UNION ALL
SELECT s.id, i.id, 12, 'cash', NULL, 1 FROM shops s JOIN inventory_items i ON i.item_name = 'bread' WHERE s.shop_type = '24_7'
UNION ALL
SELECT s.id, i.id, 850, 'bank', 50, 1 FROM shops s JOIN inventory_items i ON i.item_name = 'phone' WHERE s.shop_type = '24_7';

-- Seed: Fahrzeuge
INSERT INTO `vehicles` (`model`, `label`, `price`, `category`, `enabled`) VALUES
('blista', 'Blista', 15000, 'compact', 1),
('asea', 'Asea', 18000, 'sedan', 1),
('faggio', 'Faggio', 6000, 'bike', 1);

SET FOREIGN_KEY_CHECKS = 1;
