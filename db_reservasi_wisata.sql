-- Active: 1759996136955@@127.0.0.1@3306@db_reservasi_wisata
-- ═════════════════════════════════════════════════════════════════════════════
-- 🛡️ SISTEM RESERVASI PAKET WISATA PELAYARAN - DATABASE SECURITY IMPLEMENTATION
-- ═════════════════════════════════════════════════════════════════════════════
-- Proyek Akhir Mata Kuliah: Keamanan Basis Data
-- Universitas Bina Sarana Informatika (UBSI)
-- Program Studi: Sistem Informasi
-- 
-- IMPLEMENTASI 4 PILAR KEAMANAN DATABASE:
-- 1. AUTENTIKASI     : AES_ENCRYPT Password Encryption
-- 2. OTORISASI       : Role-Based Access Control (RBAC)
-- 3. INTEGRITAS      : CHECK Constraints & Foreign Keys
-- 4. AUDIT           : Trigger Logging untuk Akuntabilitas
--
-- STANDAR KEAMANAN: NIST SP 800-53 & ISO 27001
-- 
-- Oleh: DIMAS BAYU NUGROHO (19240384) - Project Lead & DBA
-- ═════════════════════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 1: DDL (DATA DEFINITION LANGUAGE) & INTEGRITAS DATA
-- ═════════════════════════════════════════════════════════════════════════════

-- Inisialisasi Database (Clean Installation)


-- DROP DATABASE IF EXISTS db_reservasi_wisata;

CREATE DATABASE db_reservasi_wisata 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;
USE db_reservasi_wisata;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 1: USERS (Admin/Petugas Internal)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan kredensial user sistem internal (admin, petugas)
-- Keamanan    : AES_ENCRYPT password encryption dengan secret key
-- Integritas  : UNIQUE email constraint untuk mencegah duplikasi
-- Engine      : InnoDB untuk transaction support & foreign key integrity
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    id              INT PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    password        TEXT NOT NULL,  -- Changed to TEXT for AES_ENCRYPT storage
    remember_token  VARCHAR(100),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 2: CUSTOMERS (Pelanggan/Wisatawan)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Data customer/wisatawan yang melakukan reservasi paket wisata
-- Keamanan    : AES_ENCRYPT password + UNIQUE constraints (email & number)
-- Integritas  : UNIQUE customer number untuk identifikasi unik pelanggan
-- Relasi      : One-to-Many dengan reservations & payments
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE customers (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    number      VARCHAR(20) NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    address     TEXT,
    phone       VARCHAR(15) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    password    TEXT NOT NULL,  -- Changed to TEXT for AES_ENCRYPT storage
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 3: PACKAGES (Master Data - Paket Wisata Pelayaran)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Master catalog paket wisata pelayaran yang ditawarkan
-- Integritas  : CHECK constraint chk_price_positive (price >= 0)
-- Business    : Valid_until untuk periode penawaran paket
-- Relasi      : One-to-Many dengan reservations (referensi produk)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE packages (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(150) NOT NULL,
    destination VARCHAR(150) NOT NULL,
    description TEXT,
    photo       VARCHAR(255),
    price       DECIMAL(10, 2) NOT NULL,
    valid_until DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_price_positive CHECK (price >= 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 4: RESERVATIONS (Core Transaction Table - Booking Wisata)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Core table untuk transaksi booking paket wisata pelayaran
-- Integritas  : 
--   • UNIQUE code untuk identifikasi unik setiap reservasi
--   • FOREIGN KEY ke customers & packages (ON DELETE RESTRICT)
--   • CHECK constraint chk_price_reservation_positive (price >= 0)
-- Audit       : Trigger tr_reservations_update_log mencatat setiap perubahan
-- Status      : ENUM('Pending', 'Confirmed', 'Cancelled') untuk lifecycle
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE reservations (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    code        VARCHAR(50) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    package_id  INT NOT NULL,
    departure   DATE NOT NULL,
    price       DECIMAL(10, 2) NOT NULL,
    status      ENUM('Pending', 'Confirmed', 'Cancelled') DEFAULT 'Pending',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (package_id) REFERENCES packages(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_price_reservation_positive CHECK (price >= 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 5: PAYMENTS (Financial Transaction - Pembayaran)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Transaksi pembayaran dari customer untuk reservasi
-- Integritas  : 
--   • FOREIGN KEY ke reservations & customers (referential integrity)
--   • CHECK constraint chk_paid_positive (paid >= 0)
-- Audit       : Trigger tr_payments_insert_log mencatat setiap pembayaran
-- Business    : Method pembayaran (Transfer Bank, E-wallet, dll)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE payments (
    id              INT PRIMARY KEY AUTO_INCREMENT,
    reservation_id  INT NOT NULL,
    customer_id     INT NOT NULL,
    method          VARCHAR(50) NOT NULL,
    name_of         VARCHAR(100) NOT NULL,
    paid            DECIMAL(10, 2) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (reservation_id) REFERENCES reservations(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_paid_positive CHECK (paid >= 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABEL 6: AUDIT_LOG (Security Audit Trail & Accountability)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Mencatat jejak audit setiap perubahan kritis pada database
-- Keamanan    : 
--   • Non-repudiation: menyimpan bukti digital untuk forensik
--   • Compliance: memenuhi standar ISO 27001 & NIST SP 800-53
-- Populated   : Otomatis via trigger (TIDAK boleh manual insert)
-- Contents    : mysql_user, timestamp, old_data, new_data untuk akuntabilitas
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE audit_log (
    id                  INT PRIMARY KEY AUTO_INCREMENT,
    table_affected      VARCHAR(50),
    action              VARCHAR(10),
    old_data            TEXT,
    new_data            TEXT,
    action_timestamp    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mysql_user          VARCHAR(100)
) ENGINE=InnoDB;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 2: DML (DATA MANIPULATION LANGUAGE) - SAMPLE DATA
-- ═════════════════════════════════════════════════════════════════════════════
-- Mengisi database dengan data sample untuk keperluan testing
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: USERS (2 admin/petugas)
-- ─────────────────────────────────────────────────────────────────────────────
-- KEAMANAN: Password di-encrypt menggunakan AES_ENCRYPT sebelum disimpan
-- Password untuk testing: admin123, petugas456
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO users (name, email, password) VALUES
('Admin Pusat', 'admin@wisatapelayaran.com', TO_BASE64(AES_ENCRYPT('admin123', 'wisata_secret_key_2025'))),
('Petugas Bandung', 'petugas@wisatapelayaran.com', TO_BASE64(AES_ENCRYPT('petugas456', 'wisata_secret_key_2025')));

-- Jangan di jalani! ini hanya testing
-- SELECT CAST(AES_DECRYPT(FROM_BASE64(password), 'wisata_secret_key_2025') AS CHAR) AS decrypted_password FROM users;

-- Verifikasi dekripsi password (hanya untuk testing)

-- select password from users;
-- SELECT name, email, 
--        CAST(AES_DECRYPT(FROM_BASE64(password), 'wisata_secret_key_2025') AS CHAR) AS decrypted_password 
-- FROM users;

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: CUSTOMERS (3 pelanggan)
-- ─────────────────────────────────────────────────────────────────────────────
-- KEAMANAN: Password di-encrypt menggunakan AES_ENCRYPT
-- Password untuk testing: customer123
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO customers (number, name, address, phone, email, password) VALUES
('CUST001', 'Ahmad Bachtiar', 'Jl. Merdeka No. 10, Bandung', '081122334455', 'ahmad.b@mail.com', TO_BASE64(AES_ENCRYPT('customer123', 'wisata_secret_key_2025'))),
('CUST002', 'Siti Rahayu', 'Jl. Asia Afrika No. 5, Jakarta', '085566778899', 'siti.r@mail.com', TO_BASE64(AES_ENCRYPT('customer123', 'wisata_secret_key_2025'))),
('CUST003', 'Budi Santoso', 'Jl. Sudirman No. 20, Surabaya', '087788990011', 'budi.s@mail.com', TO_BASE64(AES_ENCRYPT('customer123', 'wisata_secret_key_2025')));

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: PACKAGES (3 paket wisata pelayaran)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO packages (name, destination, description, photo, price, valid_until) VALUES
('Paket Pelayaran Kepulauan Seribu', 'Kepulauan Seribu, Jakarta', 'Nikmati keindahan pulau-pulau di Kepulauan Seribu dengan kapal pesiar mewah', 'seribu.jpg', 2500000.00, '2025-12-31'),
('Paket Wisata Kapal Komodo', 'Labuan Bajo, NTT', 'Jelajahi habitat komodo dan diving di Raja Ampat', 'komodo.jpg', 5500000.00, '2025-12-31'),
('Paket Sunset Cruise Bali', 'Perairan Bali', 'Dinner cruise mewah dengan pemandangan sunset Bali', 'bali.jpg', 1800000.00, '2025-12-31');

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: RESERVATIONS (2 reservasi awal)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO reservations (code, customer_id, package_id, departure, price, status) VALUES
('RSV-2025-001', 1, 1, '2025-12-25', 2500000.00, 'Confirmed'),
('RSV-2025-002', 2, 3, '2025-11-15', 1800000.00, 'Pending');

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: PAYMENTS (1 pembayaran)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO payments (reservation_id, customer_id, method, name_of, paid) VALUES
(1, 1, 'Transfer Bank', 'Ahmad Bachtiar', 2500000.00);

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 3: AUDIT TRAIL & ACCOUNTABILITY (DATABASE TRIGGERS)
-- ═════════════════════════════════════════════════════════════════════════════
-- Security Implementation Framework:
--   • Automatic audit logging for all critical data changes
--   • Non-repudiation through user identification & timestamping
--   • Compliance with ISO 27001 & NIST SP 800-53 (AU-2, AU-3)
--   • Event-driven monitoring for forensic analysis
-- 
-- Coverage: RESERVATIONS (status/price changes) & PAYMENTS (new transactions)
-- ═════════════════════════════════════════════════════════════════════════════

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGER 1: tr_reservations_update_log (Business Transaction Audit)
-- ─────────────────────────────────────────────────────────────────────────────
-- Purpose         : Log critical changes to RESERVATIONS table
-- Monitored Fields: status (booking lifecycle) & price (financial integrity)
-- Execution Time  : AFTER UPDATE (post-commit for data consistency)  
-- Accountability  : Records MySQL USER() + AUTO timestamp for non-repudiation
-- Business Impact : Ensures auditability of reservation modifications
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER tr_reservations_update_log
AFTER UPDATE ON reservations
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status OR OLD.price <> NEW.price THEN
        INSERT INTO audit_log (
            table_affected,
            action,
            old_data,
            new_data,
            mysql_user
        )
        VALUES (
            'reservations',
            'UPDATE',
            CONCAT('Code: ', OLD.code, 
                   ', Status: ', OLD.status, 
                   ', Price: Rp ', FORMAT(OLD.price, 2)),
            CONCAT('Code: ', NEW.code,
                   ', Status: ', NEW.status, 
                   ', Price: Rp ', FORMAT(NEW.price, 2)),
            USER()
        );
    END IF;
END$$

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGER 2: tr_payments_insert_log (Financial Transaction Audit)
-- ─────────────────────────────────────────────────────────────────────────────
-- Purpose         : Log all new payment transactions for financial control
-- Monitored Event : INSERT operations on PAYMENTS table
-- Execution Time  : AFTER INSERT (immediate logging post-transaction)
-- Accountability  : Complete payment details tracking with user attribution
-- Compliance      : Financial audit requirements & anti-fraud monitoring
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER tr_payments_insert_log
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (
        table_affected,
        action,
        old_data,
        new_data,
        mysql_user
    )
    VALUES (
        'payments',
        'INSERT',
        NULL,
        CONCAT('Reservation ID: ', NEW.reservation_id,
               ', Customer ID: ', NEW.customer_id,
               ', Method: ', NEW.method,
               ', Paid: Rp ', FORMAT(NEW.paid, 2)),
        USER()
    );
END$$

DELIMITER ;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 4: DCL (DATA CONTROL LANGUAGE) - ROLE-BASED ACCESS CONTROL
-- ═════════════════════════════════════════════════════════════════════════════
-- Framework Keamanan Otorisasi:
--   • Role-Based Access Control (RBAC) Implementation
--   • Principle of Least Privilege (NIST SP 800-53 AC-6)
--   • Separation of Duties & Defense in Depth
--   • Multi-layered Security (Database + Application Level)
-- 
-- Arsitektur Role Hierarchy:
--   1. admin_user    : Administrative privileges (DDL, DML, DCL)
--   2. petugas_user  : Operational privileges (DML operations)
--   3. web_app       : Application privileges (limited DML)
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.1. USER ACCOUNT CREATION & AUTHENTICATION
-- ─────────────────────────────────────────────────────────────────────────────
-- Security Implementation:
--   • Strong Password Policy: kompleksitas & panjang minimum
--   • Host-based Access Control: localhost restriction
--   • Account Separation: dedicated users per functional role
-- 
-- Credential Information:
--   admin_user    : AdminPass123!    (Administrative operations)
--   petugas_user  : PetugasPass456!  (Staff operations)  
--   web_app       : WebAppPass789!   (Application integration)
-- 
-- PREREQUISITE: Requires CREATE USER privilege (execute as MySQL root)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS 'admin_user'@'localhost'   IDENTIFIED BY 'AdminPass123!';
CREATE USER IF NOT EXISTS 'petugas_user'@'localhost' IDENTIFIED BY 'PetugasPass456!';
CREATE USER IF NOT EXISTS 'web_app'@'localhost'      IDENTIFIED BY 'WebAppPass789!';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.2. ROLE A: ADMIN USER (Database Administrator Privileges)
-- ─────────────────────────────────────────────────────────────────────────────
-- Privilege Scope : ALL PRIVILEGES (DDL, DML, DCL operations)
-- Use Cases       :
--   • Database schema management & maintenance
--   • System backup, recovery, & disaster planning
--   • User account management & privilege administration
--   • Performance monitoring & optimization
-- Risk Level      : CRITICAL - restricted to certified DBA personnel only
-- Security Control: Should be used only for administrative tasks, not daily ops
-- ─────────────────────────────────────────────────────────────────────────────
GRANT ALL PRIVILEGES ON db_reservasi_wisata.* TO 'admin_user'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.3. ROLE B: PETUGAS USER (Operational Staff Privileges)
-- ─────────────────────────────────────────────────────────────────────────────
-- Privilege Scope : DML operations (SELECT, INSERT, UPDATE) on business tables
-- Use Cases       :
--   • Customer registration & profile management  
--   • Reservation booking & status management
--   • Payment processing & confirmation
--   • Operational reporting & data entry
-- Risk Level      : MEDIUM - business operational access with audit trails
-- Security Control: Cannot modify master data (PACKAGES) - read-only access only
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.users TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON db_reservasi_wisata.customers TO 'petugas_user'@'localhost';
GRANT SELECT ON db_reservasi_wisata.packages TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON db_reservasi_wisata.reservations TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.payments TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.audit_log TO 'petugas_user'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.4. ROLE C: WEB_APP USER (Application Integration Privileges)
-- ─────────────────────────────────────────────────────────────────────────────
-- Privilege Scope : Most restrictive (INSERT-only for customer transactions)
-- Use Cases       :
--   • Mobile/web application backend connectivity
--   • Customer self-service registration & booking
--   • Public API endpoints for reservation system
--   • Automated payment processing integration
-- Risk Level      : LOW - minimal privileges for public-facing applications
-- Security Control: NO access to sensitive data (USERS, AUDIT_LOG tables)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.packages TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.customers TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.reservations TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.payments TO 'web_app'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- PRIVILEGE ACTIVATION & SYSTEM REFRESH
-- ─────────────────────────────────────────────────────────────────────────────
-- Ensures all privilege changes take effect immediately without restart
-- ─────────────────────────────────────────────────────────────────────────────
FLUSH PRIVILEGES;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 5: COMPREHENSIVE SECURITY TEST SUITE
-- ═════════════════════════════════════════════════════════════════════════════
-- Testing Framework: 9 systematic test cases covering 4 security pillars
-- 
-- Test Categories:
--   • Series A (A1-A3): Authentication & Data Integrity verification
--   • Series B (B1-B4): Authorization testing for Petugas User role
--   • Series C (C1-C3): Authorization testing for Web App User role
-- 
-- Methodology: Black-box & white-box testing with positive/negative scenarios
-- ═════════════════════════════════════════════════════════════════════════════

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES A: AUTHENTICATION & DATA INTEGRITY VERIFICATION            ║
-- ╚═════════════════════════════════════════════════════════════════════════╝

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A1: AES Password Encryption Verification (✅ EXPECTED SUCCESS)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objective       : Verify password storage uses AES_ENCRYPT (not plaintext)
-- Security Control: Cryptographic protection of sensitive authentication data
-- Expected Result : Encrypted strings that decrypt correctly with secret key
-- Compliance      : NIST SP 800-63B authentication guidelines
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'A1. Uji AES Encryption (Users)' AS Test_Case, 
       name, 
       email,
       password AS encrypted_password,
       CAST(AES_DECRYPT(FROM_BASE64(password), 'wisata_secret_key_2025') AS CHAR) AS decrypted_password
FROM users 
WHERE email = 'admin@wisatapelayaran.com';

SELECT 'A1. Uji AES Encryption (Customers)' AS Test_Case, 
       name, 
       email,
       password AS encrypted_password,
       CAST(AES_DECRYPT(FROM_BASE64(password), 'wisata_secret_key_2025') AS CHAR) AS decrypted_password
FROM customers 
WHERE email = 'ahmad.b@mail.com';

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A2: Uji CHECK Constraint Integritas (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi CHECK constraint mencegah harga negatif
-- Expected: ERROR 3819 - Check constraint violated (price >= 0)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'A2. Uji Integritas Data - Harga Negatif (Harus Gagal)' AS Test_Case;

INSERT INTO packages (name, destination, description, price, valid_until) 
VALUES ('Paket Test', 'Test Destination', 'Test', -1000.00, '2025-12-31');

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A3: Insert Data Normal (Setup untuk Test B1-B2)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Membuat data reservasi yang akan di-UPDATE untuk test audit trigger
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO reservations (code, customer_id, package_id, departure, price, status) 
VALUES ('RSV-2025-003', 3, 2, '2026-01-15', 5500000.00, 'Pending');

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES B: OTORISASI - PETUGAS USER (Least Privilege)               ║
-- ╚═════════════════════════════════════════════════════════════════════════╝
-- INSTRUKSI: Jalankan test B1-B4 dengan login sebagai petugas_user
-- Command: mysql -u petugas_user -p
-- Password: PetugasPass456!
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B1: Update Reservasi - Operasi yang Diizinkan (✅ HARUS BERHASIL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas boleh UPDATE transaksi (sesuai job role)
-- Expected: Query berhasil, status berubah menjadi 'Confirmed'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B1. Uji UPDATE Reservasi (Petugas - Harusnya Berhasil)' AS Test_Case;

UPDATE reservations 
SET status = 'Confirmed', 
    price = 5500000.00 
WHERE id = 3;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B2: Verifikasi Audit Trail (✅ HARUS BERHASIL MENCATAT)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi trigger audit mencatat UPDATE dari Test B1
-- Expected: Audit log menunjukkan mysql_user = 'petugas_user@localhost'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B2. Uji Audit Log (Harusnya Berhasil Mencatat Aksi Petugas)' AS Test_Case;

SELECT 
    id,
    action_timestamp, 
    mysql_user, 
    table_affected, 
    action,
    old_data,
    new_data
FROM audit_log 
WHERE table_affected = 'reservations'
ORDER BY id DESC 
LIMIT 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B3: Update Paket Wisata - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas TIDAK boleh ubah master data (packages)
-- Expected: ERROR 1142 - UPDATE command denied to user 'petugas_user'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B3. Uji UPDATE packages (Petugas - Harusnya Gagal)' AS Test_Case;

UPDATE packages 
SET price = 0.00 
WHERE id = 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B4: Drop Table - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas TIDAK punya hak DDL (DROP TABLE)
-- Expected: ERROR 1142 - DROP command denied to user 'petugas_user'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B4. Uji DROP TABLE (Petugas - Harusnya Gagal)' AS Test_Case;

DROP TABLE audit_log;

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES C: OTORISASI - WEB_APP USER (Most Restricted)               ║
-- ╚═════════════════════════════════════════════════════════════════════════╝
-- INSTRUKSI: Jalankan test C1-C3 dengan login sebagai web_app
-- Command: mysql -u web_app -p
-- Password: WebAppPass789!
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C1: Insert Reservasi Baru (✅ HARUS BERHASIL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app boleh INSERT reservasi baru (customer booking)
-- Expected: Query berhasil, reservasi baru tercatat
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C1. Uji INSERT Reservasi (Web App - Harusnya Berhasil)' AS Test_Case;

INSERT INTO reservations (code, customer_id, package_id, departure, price, status) 
VALUES ('RSV-2025-004', 2, 1, '2025-11-20', 2500000.00, 'Pending');

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C2: Update Data Customer - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app TIDAK boleh UPDATE data customer existing
-- Rasional: Mencegah manipulasi data oleh aplikasi (security by design)
-- Expected: ERROR 1142 - UPDATE command denied to user 'web_app'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C2. Uji UPDATE customers (Web App - Harusnya Gagal)' AS Test_Case;

UPDATE customers 
SET email = 'hacker@mail.com' 
WHERE id = 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C3: Akses Data Sensitif - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app TIDAK boleh akses users (data kredensial admin)
-- Rasional: Isolasi data sensitif dari aplikasi eksternal (defense in depth)
-- Expected: ERROR 1142 - SELECT command denied to user 'web_app'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C3. Uji SELECT users (Web App - Harusnya Gagal)' AS Test_Case;

SELECT * FROM users;

-- ═════════════════════════════════════════════════════════════════════════════
-- END OF TEST CASES
-- ═════════════════════════════════════════════════════════════════════════════
-- CATATAN PENTING:
-- - Test case yang "GAGAL" adalah HASIL YANG DIHARAPKAN (security berfungsi)
-- - Jalankan test B1-B4 dengan user 'petugas_user'
-- - Jalankan test C1-C3 dengan user 'web_app'
-- - Test A1-A3 dapat dijalankan dengan user apapun (termasuk root)
-- ═════════════════════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 6: CLEANUP & UNINSTALL (OPTIONAL)
-- ═════════════════════════════════════════════════════════════════════════════
-- Gunakan section ini untuk MENGHAPUS database dan users secara CLEAN
-- HATI-HATI: Perintah ini akan menghapus SEMUA data dan users!
-- 
-- CARA PENGGUNAAN:
-- 1. Uncomment (hapus -- di depan) perintah yang ingin dijalankan
-- 2. Jalankan sebagai root: mysql -u root -p < cleanup_section.sql
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.1. Hapus MySQL Users yang Dibuat
-- ─────────────────────────────────────────────────────────────────────────────
-- Uncomment 3 baris di bawah untuk menghapus users
-- DROP USER IF EXISTS 'admin_user'@'localhost';
-- DROP USER IF EXISTS 'petugas_user'@'localhost';
-- DROP USER IF EXISTS 'web_app'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.2. Hapus Database
-- ─────────────────────────────────────────────────────────────────────────────
-- Uncomment baris di bawah untuk menghapus seluruh database
-- DROP DATABASE IF EXISTS db_reservasi_wisata;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.3. Refresh Privileges (Wajib setelah DROP USER)
-- ─────────────────────────────────────────────────────────────────────────────
-- Uncomment baris di bawah setelah DROP USER
-- FLUSH PRIVILEGES;

-- ═════════════════════════════════════════════════════════════════════════════
-- QUICK CLEANUP SCRIPT (Hapus Semua - Use with CAUTION!)
-- ═════════════════════════════════════════════════════════════════════════════
-- Uncomment blok di bawah untuk UNINSTALL LENGKAP:
--
-- DROP USER IF EXISTS 'admin_user'@'localhost';
-- DROP USER IF EXISTS 'petugas_user'@'localhost';
-- DROP USER IF EXISTS 'web_app'@'localhost';
-- DROP DATABASE IF EXISTS db_reservasi_wisata;
-- FLUSH PRIVILEGES;
--
-- ═════════════════════════════════════════════════════════════════════════════
-- Setelah cleanup, Anda bisa re-install dengan menjalankan ulang:
-- mysql -u root -p < db_reservasi_wisata.sql
-- ═════════════════════════════════════════════════════════════════════════════
