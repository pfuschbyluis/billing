-- ESX Rechnungssystem - Datenbankinstallation
-- Wird beim Script-Start automatisch ausgeführt (Config.AutoInstallSQL)
-- Kann bei Bedarf weiterhin manuell importiert werden

-- Globale Einstellungen (Key-Value)
CREATE TABLE IF NOT EXISTS `rechnungen_settings` (
    `setting_key` VARCHAR(100) NOT NULL,
    `setting_value` TEXT DEFAULT NULL,
    PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Job-spezifische Einstellungen
CREATE TABLE IF NOT EXISTS `rechnungen_job_settings` (
    `job_name` VARCHAR(50) NOT NULL,
    `can_issue` TINYINT(1) NOT NULL DEFAULT 0,
    `can_issue_player` TINYINT(1) NOT NULL DEFAULT 1,
    `can_issue_society` TINYINT(1) NOT NULL DEFAULT 0,
    `max_amount` INT NOT NULL DEFAULT 10000,
    `require_proximity` TINYINT(1) NOT NULL DEFAULT 1,
    `max_distance` FLOAT NOT NULL DEFAULT 5.0,
    `payment_bank` TINYINT(1) NOT NULL DEFAULT 1,
    `payment_cash` TINYINT(1) NOT NULL DEFAULT 1,
    `money_destination` ENUM('society', 'employee', 'split') NOT NULL DEFAULT 'society',
    `society_percent` INT NOT NULL DEFAULT 70,
    `employee_percent` INT NOT NULL DEFAULT 30,
    `tax_rate` DECIMAL(5,2) NOT NULL DEFAULT 19.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Firmen-/Society-Informationen und Steuerdaten
CREATE TABLE IF NOT EXISTS `rechnungen_society_info` (
    `society_name` VARCHAR(50) NOT NULL,
    `company_name` VARCHAR(150) DEFAULT NULL,
    `company_address` TEXT DEFAULT NULL,
    `tax_id` VARCHAR(50) DEFAULT NULL COMMENT 'Steuernummer',
    `vat_id` VARCHAR(50) DEFAULT NULL COMMENT 'Umsatzsteuer-ID',
    `invoice_prefix` VARCHAR(10) NOT NULL DEFAULT 'RE',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`society_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rechnungszähler für automatische Nummern (RE-2026-000001)
CREATE TABLE IF NOT EXISTS `rechnungen_counters` (
    `year` INT NOT NULL,
    `last_number` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rechnungen
CREATE TABLE IF NOT EXISTS `rechnungen_invoices` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `invoice_number` VARCHAR(30) NOT NULL,
    `issuer_identifier` VARCHAR(60) NOT NULL,
    `issuer_name` VARCHAR(100) DEFAULT NULL,
    `issuer_job` VARCHAR(50) DEFAULT NULL,
    `issuer_society` VARCHAR(50) DEFAULT NULL,
    `recipient_type` ENUM('player', 'society') NOT NULL DEFAULT 'player',
    `recipient_identifier` VARCHAR(60) NOT NULL,
    `recipient_name` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `net_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `tax_rate` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    `tax_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `gross_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `payment_status` ENUM('open', 'paid', 'cancelled', 'overdue') NOT NULL DEFAULT 'open',
    `payment_method` VARCHAR(20) DEFAULT NULL,
    `paid_at` DATETIME DEFAULT NULL,
    `due_date` DATE DEFAULT NULL,
    `reminder_fee` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `cancelled_by` VARCHAR(60) DEFAULT NULL,
    `cancelled_reason` TEXT DEFAULT NULL,
    `edited_by` VARCHAR(60) DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `line_items` JSON DEFAULT NULL,
    `signature` MEDIUMTEXT DEFAULT NULL,
    `duration_days` INT DEFAULT NULL,
    `issuer_mode` VARCHAR(20) DEFAULT 'personal',
    PRIMARY KEY (`id`),
    UNIQUE KEY `invoice_number` (`invoice_number`),
    KEY `recipient_identifier` (`recipient_identifier`),
    KEY `issuer_identifier` (`issuer_identifier`),
    KEY `payment_status` (`payment_status`),
    KEY `issuer_job` (`issuer_job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Standard-Einstellungen einfügen
INSERT IGNORE INTO `rechnungen_settings` (`setting_key`, `setting_value`) VALUES
    ('discord_enabled', 'false'),
    ('discord_webhook', ''),
    ('tax_enabled', 'true'),
    ('default_tax_rate', '19.0'),
    ('auto_invoice_numbers', 'true'),
    ('reminder_fee', '25.0'),
    ('payment_deadline_days', '14'),
    ('show_unpaid_on_login', 'true'),
    ('admin_can_view', 'true'),
    ('admin_can_edit', 'true'),
    ('admin_can_delete', 'true'),
    ('admin_can_cancel', 'true'),
    ('rejection_enabled', 'true');

-- Gespeicherte Kontakte (schnelle Empfängerauswahl)
CREATE TABLE IF NOT EXISTS `rechnungen_contacts` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner_identifier` VARCHAR(60) NOT NULL,
    `contact_name` VARCHAR(100) NOT NULL,
    `contact_identifier` VARCHAR(60) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `owner_contact` (`owner_identifier`, `contact_identifier`),
    KEY `owner_identifier` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rechnungsvorlagen (persönlich & Job-geteilt)
CREATE TABLE IF NOT EXISTS `rechnungen_templates` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner_identifier` VARCHAR(60) NOT NULL,
    `job_name` VARCHAR(50) DEFAULT NULL,
    `is_shared` TINYINT(1) NOT NULL DEFAULT 0,
    `name` VARCHAR(100) NOT NULL,
    `title` VARCHAR(200) DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `line_items` JSON DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `owner_identifier` (`owner_identifier`),
    KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Benutzereinstellungen (Theme, Ansicht, Konto)
CREATE TABLE IF NOT EXISTS `rechnungen_user_prefs` (
    `identifier` VARCHAR(60) NOT NULL,
    `theme` VARCHAR(10) NOT NULL DEFAULT 'dark',
    `view_mode` VARCHAR(10) NOT NULL DEFAULT 'table',
    `account_mode` VARCHAR(10) NOT NULL DEFAULT 'personal',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
