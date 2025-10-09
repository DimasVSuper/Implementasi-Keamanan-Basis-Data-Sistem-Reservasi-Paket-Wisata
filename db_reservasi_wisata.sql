-- Active: 1759996136955@@127.0.0.1@3306@db_reservasi_wisata
-- ═════════════════════════════════════════════════════════════════════════════
-- 🛡️ SISTEM RESERVASI PAKET WISATA - DATABASE SECURITY IMPLEMENTATION
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
DROP DATABASE IF EXISTS db_reservasi_wisata;
CREATE DATABASE db_reservasi_wisata 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;
USE db_reservasi_wisata;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 1: TBL_PENGGUNA
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan kredensial user sistem (admin, petugas)
-- Keamanan    : Password hashing SHA2(512) - mencegah plaintext storage
-- Constraint  : UNIQUE username untuk mencegah duplikasi
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE TBL_PENGGUNA (
    id_pengguna     INT PRIMARY KEY AUTO_INCREMENT,
    username        VARCHAR(50) NOT NULL UNIQUE,
    password_hash   VARCHAR(128) NOT NULL,
    nama_lengkap    VARCHAR(100),
    jabatan         ENUM('Admin', 'Petugas_Reservasi', 'Pelanggan') NOT NULL,
    status          ENUM('Aktif', 'Nonaktif') DEFAULT 'Aktif'
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 2: TBL_PELANGGAN
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Data customer/wisatawan yang melakukan reservasi
-- Keamanan    : UNIQUE constraint pada email & telepon (data integrity)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE TBL_PELANGGAN (
    id_pelanggan    INT PRIMARY KEY AUTO_INCREMENT,
    nama_pelanggan  VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    telepon         VARCHAR(15) NOT NULL UNIQUE,
    alamat          TEXT
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 3: TBL_PAKET_WISATA
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Katalog paket wisata yang ditawarkan
-- Keamanan    : CHECK constraint untuk validasi harga (harus non-negatif)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE TBL_PAKET_WISATA (
    id_paket        INT PRIMARY KEY AUTO_INCREMENT,
    nama_paket      VARCHAR(150) NOT NULL,
    deskripsi       TEXT,
    durasi_hari     INT NOT NULL,
    harga           DECIMAL(10, 2) NOT NULL,
    status_paket    ENUM('Tersedia', 'Penuh', 'Arsip') DEFAULT 'Tersedia',
    CONSTRAINT chk_harga_positive CHECK (harga >= 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 4: TBL_RESERVASI (CORE TABLE - TRANSAKSI UTAMA)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Menyimpan data transaksi booking paket wisata
-- Keamanan    : 
--   - CHECK constraint: jumlah_peserta minimal 1 (data validity)
--   - FOREIGN KEY: menjaga integritas referensial dengan pelanggan & paket
--   - Trigger audit akan mencatat setiap UPDATE status/biaya
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE TBL_RESERVASI (
    id_reservasi        INT PRIMARY KEY AUTO_INCREMENT,
    id_pelanggan        INT NOT NULL,
    id_paket            INT NOT NULL,
    tanggal_reservasi   DATE NOT NULL,
    jumlah_peserta      INT NOT NULL,
    total_biaya         DECIMAL(10, 2) NOT NULL,
    status_pembayaran   ENUM('Pending', 'Lunas', 'Batal') DEFAULT 'Pending',
    FOREIGN KEY (id_pelanggan) REFERENCES TBL_PELANGGAN(id_pelanggan)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (id_paket) REFERENCES TBL_PAKET_WISATA(id_paket)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_jumlah_peserta_positive CHECK (jumlah_peserta > 0)
) ENGINE=InnoDB;



-- ─────────────────────────────────────────────────────────────────────────────
-- Tabel 5: TBL_AUDIT_LOG (AUDIT & ACCOUNTABILITY)
-- ─────────────────────────────────────────────────────────────────────────────
-- Deskripsi   : Mencatat setiap perubahan kritis pada database
-- Keamanan    : Menyimpan jejak audit untuk compliance & forensik
-- Populated   : Otomatis melalui trigger (tidak boleh manual insert)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE TBL_AUDIT_LOG (
    id_log              INT PRIMARY KEY AUTO_INCREMENT,
    tabel_terpengaruh   VARCHAR(50),
    aksi                VARCHAR(10),
    data_lama           TEXT,
    data_baru           TEXT,
    waktu_aksi          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pengguna_mysql      VARCHAR(100)
) ENGINE=InnoDB;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 2: DML (DATA MANIPULATION LANGUAGE) - SAMPLE DATA
-- ═════════════════════════════════════════════════════════════════════════════
-- Mengisi database dengan data sample untuk keperluan testing
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: TBL_PAKET_WISATA (3 paket wisata)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO TBL_PAKET_WISATA (nama_paket, durasi_hari, harga) VALUES
('Paket Jelajah Bandung Lautan Api', 3, 1500000.00),
('Paket Romantis Kawah Putih & Glamping', 2, 950000.00),
('Paket Edukasi Pelabuhan Ratu', 4, 3200000.00);

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: TBL_PELANGGAN (2 pelanggan)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO TBL_PELANGGAN (nama_pelanggan, email, telepon, alamat) VALUES
('Ahmad Bachtiar', 'ahmad.b@mail.com', '081122334455', 'Jl. Merdeka No. 10, Bandung'),
('Siti Rahayu', 'siti.r@mail.com', '085566778899', 'Jl. Asia Afrika No. 5, Jakarta');

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: TBL_PENGGUNA (3 user dengan password hashing)
-- ─────────────────────────────────────────────────────────────────────────────
-- KEAMANAN: Password di-hash menggunakan SHA2(512) sebelum disimpan
-- Password TIDAK PERNAH disimpan dalam plaintext
-- Password untuk testing: admin123, petugas456, passpelanggan
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO TBL_PENGGUNA (username, password_hash, nama_lengkap, jabatan) VALUES
('admin_pusat',   SHA2('admin123', 512),      'Budi Santoso',    'Admin'),
('petugas_bdg',   SHA2('petugas456', 512),    'Citra Dewi',      'Petugas_Reservasi'),
('pelanggan_jkt', SHA2('passpelanggan', 512), 'Ahmad Hidayat',   'Pelanggan');

-- ─────────────────────────────────────────────────────────────────────────────
-- Data Sample: TBL_RESERVASI (2 reservasi awal)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO TBL_RESERVASI (id_pelanggan, id_paket, tanggal_reservasi, jumlah_peserta, total_biaya) VALUES
(1, 1, '2025-12-25', 2, 3000000.00),
(2, 2, '2025-11-01', 1, 950000.00);

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 3: AUDIT & AKUNTABILITAS (TRIGGER)
-- ═════════════════════════════════════════════════════════════════════════════
-- Implementasi audit trail otomatis untuk setiap perubahan kritis
-- Sesuai dengan standar ISO 27001 & NIST SP 800-53 (AU-2, AU-3)
-- ═════════════════════════════════════════════════════════════════════════════

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger: tr_reservasi_update_log
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan      : Mencatat setiap UPDATE pada TBL_RESERVASI (status/biaya)
-- Waktu       : AFTER UPDATE (setelah perubahan berhasil di-commit)
-- Akuntabilitas: Mencatat USER() yang melakukan perubahan dan timestamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER tr_reservasi_update_log
AFTER UPDATE ON TBL_RESERVASI
FOR EACH ROW
BEGIN
    IF OLD.status_pembayaran <> NEW.status_pembayaran 
       OR OLD.total_biaya <> NEW.total_biaya THEN
        
        INSERT INTO TBL_AUDIT_LOG (
            tabel_terpengaruh,
            aksi,
            data_lama,
            data_baru,
            pengguna_mysql
        )
        VALUES (
            'TBL_RESERVASI',
            'UPDATE',
            CONCAT('ID: ', OLD.id_reservasi, 
                   ', Status: ', OLD.status_pembayaran, 
                   ', Biaya: Rp ', FORMAT(OLD.total_biaya, 2)),
            CONCAT('ID: ', NEW.id_reservasi,
                   ', Status: ', NEW.status_pembayaran, 
                   ', Biaya: Rp ', FORMAT(NEW.total_biaya, 2)),
            USER()
        );
    END IF;
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
-- Password: StrongPassAdmin123!, StrongPassPetugas456!, StrongPassWebApp789!
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS 'admin_user'@'localhost'   IDENTIFIED BY 'StrongPassAdmin123!';
CREATE USER IF NOT EXISTS 'petugas_user'@'localhost' IDENTIFIED BY 'StrongPassPetugas456!';
CREATE USER IF NOT EXISTS 'web_app'@'localhost'      IDENTIFIED BY 'StrongPassWebApp789!';

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
-- Hak Akses   : Terbatas pada operasi reservasi dan pelanggan
-- Tujuan      : Kelola transaksi booking, update status pembayaran
-- Prinsip     : Least Privilege - TIDAK boleh ubah master data (paket wisata)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.TBL_PENGGUNA TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.TBL_PELANGGAN TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON db_reservasi_wisata.TBL_RESERVASI TO 'petugas_user'@'localhost';
GRANT SELECT ON db_reservasi_wisata.TBL_PAKET_WISATA TO 'petugas_user'@'localhost';
GRANT SELECT, INSERT ON db_reservasi_wisata.TBL_AUDIT_LOG TO 'petugas_user'@'localhost';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.4. ROLE C: WEB_APP USER (Customer Transactions Only)
-- ─────────────────────────────────────────────────────────────────────────────
-- Hak Akses   : Paling terbatas (INSERT only untuk reservasi & pelanggan baru)
-- Tujuan      : Aplikasi web/mobile untuk customer self-service booking
-- Prinsip     : TIDAK boleh akses data sensitif & UPDATE/DELETE data existing
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON db_reservasi_wisata.TBL_PAKET_WISATA TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.TBL_PELANGGAN TO 'web_app'@'localhost';
GRANT INSERT ON db_reservasi_wisata.TBL_RESERVASI TO 'web_app'@'localhost';

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
-- Expected: Kolom password_hash berisi string 128 karakter (hex), bukan 'admin123'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'A1. Uji Hashing Password' AS Test_Case, 
       username, 
       password_hash,
       LENGTH(password_hash) AS Hash_Length
FROM TBL_PENGGUNA 
WHERE username = 'admin_pusat';

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A2: Uji CHECK Constraint Integritas (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi CHECK constraint mencegah data invalid
-- Expected: ERROR 3819 - Check constraint violated (jumlah_peserta > 0)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'A2. Uji Integritas Data (Harus Gagal)' AS Test_Case;

INSERT INTO TBL_RESERVASI (id_pelanggan, id_paket, tanggal_reservasi, jumlah_peserta, total_biaya) 
VALUES (1, 1, '2025-10-10', 0, 1000000.00);

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST A3: Insert Data Normal (Setup untuk Test B1-B2)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Membuat data reservasi yang akan di-UPDATE untuk test audit trigger
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO TBL_RESERVASI (id_pelanggan, id_paket, tanggal_reservasi, jumlah_peserta, total_biaya) 
VALUES (2, 3, '2026-01-01', 5, 16000000.00);

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES B: OTORISASI - PETUGAS USER (Least Privilege)               ║
-- ╚═════════════════════════════════════════════════════════════════════════╝
-- INSTRUKSI: Jalankan test B1-B4 dengan login sebagai petugas_user
-- Command: mysql -u petugas_user -p
-- Password: StrongPassPetugas456!
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B1: Update Reservasi - Operasi yang Diizinkan (✅ HARUS BERHASIL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas boleh UPDATE transaksi (sesuai job role)
-- Expected: Query berhasil, status berubah menjadi 'Lunas'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B1. Uji UPDATE Reservasi (Petugas - Harusnya Berhasil)' AS Test_Case;

UPDATE TBL_RESERVASI 
SET status_pembayaran = 'Lunas', 
    total_biaya = 16000000.00 
WHERE id_reservasi = 3;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B2: Verifikasi Audit Trail (✅ HARUS BERHASIL MENCATAT)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi trigger audit mencatat UPDATE dari Test B1
-- Expected: Audit log menunjukkan pengguna_mysql = 'petugas_user@localhost'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B2. Uji Audit Log (Harusnya Berhasil Mencatat Aksi Petugas)' AS Test_Case;

SELECT 
    id_log,
    waktu_aksi, 
    pengguna_mysql, 
    tabel_terpengaruh, 
    aksi,
    data_lama,
    data_baru
FROM TBL_AUDIT_LOG 
WHERE tabel_terpengaruh = 'TBL_RESERVASI'
ORDER BY id_log DESC 
LIMIT 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B3: Update Paket Wisata - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas TIDAK boleh ubah master data (paket wisata)
-- Expected: ERROR 1142 - UPDATE command denied to user 'petugas_user'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B3. Uji UPDATE TBL_PAKET_WISATA (Petugas - Harusnya Gagal)' AS Test_Case;

UPDATE TBL_PAKET_WISATA 
SET harga = 0.00 
WHERE id_paket = 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST B4: Drop Table - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi petugas TIDAK punya hak DDL (DROP TABLE)
-- Expected: ERROR 1142 - DROP command denied to user 'petugas_user'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'B4. Uji DROP TABLE (Petugas - Harusnya Gagal)' AS Test_Case;

DROP TABLE TBL_AUDIT_LOG;

-- ╔═════════════════════════════════════════════════════════════════════════╗
-- ║ TEST SERIES C: OTORISASI - WEB_APP USER (Most Restricted)               ║
-- ╚═════════════════════════════════════════════════════════════════════════╝
-- INSTRUKSI: Jalankan test C1-C3 dengan login sebagai web_app
-- Command: mysql -u web_app -p
-- Password: StrongPassWebApp789!
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C1: Insert Reservasi Baru (✅ HARUS BERHASIL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app boleh INSERT reservasi baru (customer booking)
-- Expected: Query berhasil, reservasi baru tercatat
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C1. Uji INSERT Reservasi (Web App - Harusnya Berhasil)' AS Test_Case;

INSERT INTO TBL_RESERVASI (id_pelanggan, id_paket, tanggal_reservasi, jumlah_peserta, total_biaya) 
VALUES (1, 3, '2025-10-25', 2, 6400000.00);

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C2: Update Data Pelanggan - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app TIDAK boleh UPDATE data pelanggan existing
-- Rasional: Mencegah manipulasi data oleh aplikasi (security by design)
-- Expected: ERROR 1142 - UPDATE command denied to user 'web_app'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C2. Uji UPDATE TBL_PELANGGAN (Web App - Harusnya Gagal)' AS Test_Case;

UPDATE TBL_PELANGGAN 
SET email = 'hacker@mail.com' 
WHERE id_pelanggan = 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEST C3: Akses Data Sensitif - Operasi yang Dilarang (❌ HARUS GAGAL)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tujuan: Memverifikasi web_app TIDAK boleh akses TBL_PENGGUNA (data kredensial)
-- Rasional: Isolasi data sensitif dari aplikasi eksternal (defense in depth)
-- Expected: ERROR 1142 - SELECT command denied to user 'web_app'
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'C3. Uji SELECT TBL_PENGGUNA (Web App - Harusnya Gagal)' AS Test_Case;

SELECT * FROM TBL_PENGGUNA;

-- ═════════════════════════════════════════════════════════════════════════════
-- END OF TEST CASES
-- ═════════════════════════════════════════════════════════════════════════════
-- CATATAN PENTING:
-- - Test case yang "GAGAL" adalah HASIL YANG DIHARAPKAN (security berfungsi)
-- - Jalankan test B1-B4 dengan user 'petugas_user'
-- - Jalankan test C1-C3 dengan user 'web_app'
-- - Test A1-A3 dapat dijalankan dengan user apapun (termasuk root)
-- ═════════════════════════════════════════════════════════════════════════════