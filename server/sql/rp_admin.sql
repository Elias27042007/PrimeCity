USE `rp_local`;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `priority` INT UNSIGNED NOT NULL DEFAULT 0,
  `is_system` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_admin_roles_name` (`role_name`),
  KEY `idx_admin_roles_priority` (`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_permissions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `permission_key` VARCHAR(64) NOT NULL,
  `label` VARCHAR(96) NOT NULL,
  `description` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_admin_permissions_key` (`permission_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_role_permissions` (
  `role_id` BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  `allow` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`role_id`, `permission_id`),
  CONSTRAINT `fk_admin_role_permissions_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_role_permissions_permission` FOREIGN KEY (`permission_id`) REFERENCES `admin_permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_user_roles` (
  `user_id` BIGINT UNSIGNED NOT NULL,
  `role_id` BIGINT UNSIGNED NOT NULL,
  `assigned_by_user_id` BIGINT UNSIGNED NULL,
  `assigned_note` VARCHAR(255) NULL,
  `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  KEY `idx_admin_user_roles_role` (`role_id`),
  KEY `idx_admin_user_roles_assigned_by` (`assigned_by_user_id`),
  CONSTRAINT `fk_admin_user_roles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_user_roles_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_user_roles_assigned_by` FOREIGN KEY (`assigned_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_bans` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `identifier_snapshot` VARCHAR(128) NULL,
  `reason` VARCHAR(255) NOT NULL,
  `banned_by_user_id` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `revoked_by_user_id` BIGINT UNSIGNED NULL,
  `revoked_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_admin_bans_user_active` (`user_id`, `active`),
  KEY `idx_admin_bans_expires` (`expires_at`),
  CONSTRAINT `fk_admin_bans_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_bans_by_user` FOREIGN KEY (`banned_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_bans_revoked_by` FOREIGN KEY (`revoked_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_tickets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `creator_user_id` BIGINT UNSIGNED NOT NULL,
  `creator_character_id` BIGINT UNSIGNED NULL,
  `title` VARCHAR(128) NOT NULL,
  `description` TEXT NOT NULL,
  `status` ENUM('open','in_progress','closed') NOT NULL DEFAULT 'open',
  `assigned_user_id` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `closed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_admin_tickets_status` (`status`),
  KEY `idx_admin_tickets_creator` (`creator_user_id`),
  CONSTRAINT `fk_admin_tickets_creator` FOREIGN KEY (`creator_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_tickets_character` FOREIGN KEY (`creator_character_id`) REFERENCES `characters` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_tickets_assigned` FOREIGN KEY (`assigned_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_ticket_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` BIGINT UNSIGNED NOT NULL,
  `author_user_id` BIGINT UNSIGNED NULL,
  `message` TEXT NOT NULL,
  `is_internal` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_ticket_messages_ticket` (`ticket_id`, `created_at`),
  CONSTRAINT `fk_admin_ticket_messages_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `admin_tickets` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_ticket_messages_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_user_id` BIGINT UNSIGNED NULL,
  `action_key` VARCHAR(64) NOT NULL,
  `target_user_id` BIGINT UNSIGNED NULL,
  `payload_json` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_audit_actor` (`actor_user_id`),
  KEY `idx_admin_audit_action` (`action_key`, `created_at`),
  CONSTRAINT `fk_admin_audit_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_audit_target` FOREIGN KEY (`target_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `admin_roles` (`role_name`, `label`, `priority`) VALUES
('supporter', 'Supporter', 10),
('moderator', 'Moderator', 20),
('admin', 'Admin', 30),
('manager', 'Manager', 40),
('projektleitung', 'Projektleitung', 50)
ON DUPLICATE KEY UPDATE
`label` = VALUES(`label`),
`priority` = VALUES(`priority`);

INSERT INTO `admin_permissions` (`permission_key`, `label`, `description`) VALUES
('admin.menu.open', 'Admin-Menü öffnen', 'Darf das Admin-Menü öffnen'),
('dashboard.view', 'Dashboard sehen', 'Darf Dashboard-Informationen sehen'),
('players.view', 'Spielerliste sehen', 'Darf alle Spieler sehen'),
('players.kick', 'Spieler kicken', 'Darf Spieler vom Server kicken'),
('players.ban', 'Spieler bannen', 'Darf Spieler bannen'),
('vehicles.spawn.command', 'Fahrzeugspawn-Befehl', 'Darf den Befehl /car <modell> nutzen'),
('vehicles.delete.command', 'Fahrzeuglösch-Befehl', 'Darf den Befehl /delete [umkreis] nutzen'),
('commands.heal', 'Heal-Befehl', 'Darf den Befehl /heal [id] nutzen'),
('commands.revive', 'Revive-Befehl', 'Darf den Befehl /revive [id] nutzen'),
('commands.repair', 'Repair-Befehl', 'Darf den Befehl /repair [id] nutzen'),
('commands.name', 'Nametag-Befehl', 'Darf den Befehl /name nutzen'),
('bans.view', 'Banns sehen', 'Darf Bann-Liste sehen'),
('bans.manage', 'Banns verwalten', 'Darf Banns entbannen/ändern'),
('tickets.view', 'Tickets sehen', 'Darf Supporttickets sehen'),
('tickets.manage', 'Tickets verwalten', 'Darf Tickets erstellen/Status ändern'),
('rights.view', 'Rechte sehen', 'Darf Rollen und Rechte sehen'),
('rights.assign', 'Rollen vergeben', 'Darf Spieler-Rollen vergeben')
ON DUPLICATE KEY UPDATE
`label` = VALUES(`label`),
`description` = VALUES(`description`);

INSERT IGNORE INTO `admin_role_permissions` (`role_id`, `permission_id`, `allow`)
SELECT r.id, p.id, 1
FROM `admin_roles` r
JOIN `admin_permissions` p ON (
  (r.role_name = 'supporter' AND p.permission_key IN ('admin.menu.open','dashboard.view','tickets.view','tickets.manage')) OR
  (r.role_name = 'moderator' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','bans.view','tickets.view','tickets.manage','commands.heal','commands.revive','commands.repair','commands.name')) OR
  (r.role_name = 'admin' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.name','bans.view','bans.manage','tickets.view','tickets.manage','rights.view')) OR
  (r.role_name = 'manager' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.name','bans.view','bans.manage','tickets.view','tickets.manage','rights.view','rights.assign')) OR
  (r.role_name = 'projektleitung' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.name','bans.view','bans.manage','tickets.view','tickets.manage','rights.view','rights.assign'))
);
