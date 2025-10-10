-- Active: 1759996136955@@127.0.0.1@3306@db_reservasi_wisata
-- ═════════════════════════════════════════════════════════════════════════════
-- 🛡️ SISTEM RESERVASI PAKET WISATA PELAYARAN - DATABASE SECURITY IMPLEMENTATION
-- ═════════════════════════════════════════════════════════════════════════════
-- Proyek Akhir Mata Kuliah Keamanan Basis Data
-- 
-- Implementasi 4 Pilar Keamanan:
-- 1. Autentikasi    : SHA2(512) Password Hashing
-- 2. Otorisasi      : Role-Based Access Control (RBAC)
-- 3. Integritas     : CHECK Constraints & Foreign Keys
-- 4. Audit          : Trigger Logging untuk Akuntabilitas
--
-- Standar: NIST SP 800-53 & ISO 27001
-- ═════════════════════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 1: DDL (DATA DEFINITION LANGUAGE) & INTEGRITAS DATA
-- ═════════════════════════════════════════════════════════════════════════════

-- Inisialisasi Database (Clean Installation)
CREATE DATABASE db_reservasi_wisata 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;
USE db_reservasi_wisata;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 1: USERS (Admin/Petugas)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan kredensial user sistem (admin, petugas)
-- Keamanan    : Password hashing SHA2(512) - mencegah plaintext storage
-- Constraint  : UNIQUE email untuk mencegah duplikasi
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    id              INT PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    password        VARCHAR(128) NOT NULL,
    remember_token  VARCHAR(100),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 2: CUSTOMERS (Pelanggan)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Data customer/wisatawan yang melakukan reservasi
-- Keamanan    : UNIQUE email & number, password hashing SHA2(512)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE customers (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    number      VARCHAR(20) NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    address     TEXT,
    phone       VARCHAR(15) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    password    VARCHAR(128) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 3: PACKAGES (Paket Wisata Pelayaran)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Katalog paket wisata pelayaran yang ditawarkan
-- Keamanan    : CHECK constraint untuk validasi harga (harus non-negatif)
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
-- Tabel 4: RESERVATIONS (Reservasi - CORE TABLE TRANSAKSI UTAMA)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan data transaksi booking paket wisata pelayaran
-- Keamanan    : 
--   - UNIQUE code untuk setiap reservasi
--   - FOREIGN KEY: menjaga integritas referensial dengan customers & packages
--   - Trigger audit akan mencatat setiap UPDATE status/price
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
-- Tabel 5: PAYMENTS (Pembayaran)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan data pembayaran dari customer untuk reservasi
-- Keamanan    : FOREIGN KEY ke reservations & customers untuk integritas data
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
-- Tabel 6: AUDIT_LOG (AUDIT & ACCOUNTABILITY)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Mencatat setiap perubahan kritis pada database
-- Keamanan    : Menyimpan jejak audit untuk compliance & forensik
-- Populated   : Otomatis melalui trigger (tidak boleh manual insert)
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
-- KEAMANAN: Password di-hash menggunakan SHA2(512) sebelum disimpan
-- Password untuk testing: admin123, petugas456
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO users (name, email, password) VALUES
('Admin Pusat', 'admin@wisatapelayaran.com', SHA2('admin123', 512)),
('Petugas Bandung', 'petugas@wisatapelayaran.com', SHA2('petugas456', 512));

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: CUSTOMERS (3 pelanggan)
-- ─────────────────────────────────────────────────────────────────────────────
-- KEAMANAN: Password di-hash menggunakan SHA2(512)
-- Password untuk testing: customer123
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO customers (number, name, address, phone, email, password) VALUES
('CUST001', 'Ahmad Bachtiar', 'Jl. Merdeka No. 10, Bandung', '081122334455', 'ahmad.b@mail.com', SHA2('customer123', 512)),
('CUST002', 'Siti Rahayu', 'Jl. Asia Afrika No. 5, Jakarta', '085566778899', 'siti.r@mail.com', SHA2('customer123', 512)),
('CUST003', 'Budi Santoso', 'Jl. Sudirman No. 20, Surabaya', '087788990011', 'budi.s@mail.com', SHA2('customer123', 512));

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
-- SECTION 3: AUDIT & AKUNTABILITAS (TRIGGER)
-- ═════════════════════════════════════════════════════════════════════════════
-- Implementasi audit trail otomatis untuk setiap perubahan kritis
-- Sesuai dengan standar ISO 27001 & NIST SP 800-53 (AU-2, AU-3)
-- ═════════════════════════════════════════════════════════════════════════════

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger: tr_reservations_update_log
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan      : Mencatat setiap UPDATE pada RESERVATIONS (status/price)
-- Waktu       : AFTER UPDATE (setelah perubahan berhasil di-commit)
-- Akuntabilitas: Mencatat USER() yang melakukan perubahan dan timestamp
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
-- Trigger: tr_payments_insert_log
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan      : Mencatat setiap INSERT pembayaran baru
-- Waktu       : AFTER INSERT
-- Akuntabilitas: Tracking semua transaksi pembayaran
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
-- Implementasi Otorisasi dengan Prinsip "Least Privilege"
-- Setiap role hanya diberikan akses minimal yang diperlukan
-- Sesuai dengan NIST SP 800-53 (AC-6: Least Privilege)
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.1. Pembuatan User MySQL untuk Setiap Role
-- ─────────────────────────────────────────────────────────────────────────────
-- CATATAN: Memerlukan privilege CREATE USER (jalankan sebagai root)
-- Password: AdminPass123!, PetugasPass456!, WebAppPass789!
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS 'admin_user'@'localhost'   IDENTIFIED BY 'AdminPass123!';
CREATE USER IF NOT EXISTS 'petugas_user'@'localhost' IDENTIFIED BY 'PetugasPass456!';
CREATE USER IF NOT EXISTS 'web_app'@'localhost'      IDENTIFIED BY 'WebAppPass789!';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.2. ROLE A: ADMIN USER (Full Control)
-- ─────────────────────────────────────────────────────────────────────────────
-- Hak Akses   : ALL PRIVILEGES (DDL, DML, DCL)
-- Tujuan      : Manajemen database, backup, recovery, user management
-- Risiko      : TINGGI - harus dibatasi hanya untuk DBA
-- ─────────────────────────────────────────────────────────────────────────────
GRANT ALL PRIVILEGES ON db_reservasi_wisata.* TO 'admin_user'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.3. ROLE B: PETUGAS USER (Transaction Management)
-- ─────────────────────────────────────────────────────────────────────────────
-- Hak Akses   : Terbatas pada operasi reservasi, pelanggan, dan pembayaran
-- Tujuan      : Kelola transaksi booking, update status, kelola pembayaran
-- Prinsip     : Least Privilege - TIDAK boleh ubah master data (packages)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.users TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON db_reservasi_wisata.customers TO 'petugas_user'@'localhost';
GRANT SELECT ON db_reservasi_wisata.packages TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON db_reservasi_wisata.reservations TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.payments TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.audit_log TO 'petugas_user'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.4. ROLE C: WEB_APP USER (Customer Transactions Only)
-- ─────────────────────────────────────────────────────────────────────────────
-- Hak Akses   : Paling terbatas (SELECT packages, INSERT customer/reservation)
-- Tujuan      : Aplikasi Android untuk customer self-service booking
-- Prinsip     : TIDAK boleh akses data sensitif (users, audit_log)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.packages TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.customers TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.reservations TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.payments TO 'web_app'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- Terapkan semua perubahan privilege
-- ─────────────────────────────────────────────────────────────────────────────
FLUSH PRIVILEGES;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 5: TEST CASES - VERIFIKASI KEAMANAN DATABASE
-- ═════════════════════════════════════════════════════════════════════════════
-- Total 9 Test Cases untuk memverifikasi 4 pilar keamanan:
-- - Test A1-A3: Autentikasi & Integritas Data
-- - Test B1-B4: Otorisasi (Petugas User)
-- - Test C1-C3: Otorisasi (Web App User)
-- ═════════════════════════════════════════════════════════════════════════════

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES A: AUTENTIKASI & INTEGRITAS DATA                            ║
-- ╚═════════════════════════════════════════════════════════════════════════╝

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A1: Verifikasi Password Hashing (✅ HARUS BERHASIL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memastikan password disimpan sebagai hash SHA2(512), bukan plaintext
-- Expected: Kolom password berisi string 128 karakter (hex)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'A1. Uji Hashing Password (Users)' AS Test_Case, 
       name, 
       email,
       password,
       LENGTH(password) AS Hash_Length
FROM users 
WHERE email = 'admin@wisatapelayaran.com';

SELECT 'A1. Uji Hashing Password (Customers)' AS Test_Case, 
       name, 
       email,
       password,
       LENGTH(password) AS Hash_Length
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
