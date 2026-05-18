-- WARNUNG: Diese Datei loescht ALLE RP-Tabellen aus der Datenbank rp_local.
-- Nur ausfuehren, wenn ein kompletter Reset gewuenscht ist.

USE `rp_local`;
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
