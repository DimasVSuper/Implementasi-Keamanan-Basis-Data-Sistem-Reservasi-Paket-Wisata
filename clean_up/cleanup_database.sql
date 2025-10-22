-- Active: 1759996136955@@127.0.0.1@3306@db_reservasi_wisata
-- ═════════════════════════════════════════════════════════════════════════════
-- 🗑️ CLEANUP SCRIPT - UNINSTALL DATABASE & USERS
-- ═════════════════════════════════════════════════════════════════════════════
-- Script untuk menghapus database dan users secara CLEAN
-- Gunakan ini sebelum re-install atau untuk reset database
--
-- CARA PENGGUNAAN:
-- mysql -u root -p < cleanup_database.sql
-- 
-- ⚠️ WARNING: Script ini akan menghapus SEMUA data!
-- ═════════════════════════════════════════════════════════════════════════════

-- Hapus 3 MySQL users yang dibuat
DROP USER IF EXISTS 'admin_user'@'localhost';
DROP USER IF EXISTS 'petugas_user'@'localhost';
DROP USER IF EXISTS 'web_app'@'localhost';

-- Hapus database beserta semua tabel dan data
DROP DATABASE IF EXISTS db_reservasi_wisata;

-- Refresh privileges (penting untuk menghindari error Aria)
FLUSH PRIVILEGES;

-- ═════════════════════════════════════════════════════════════════════════════
-- CLEANUP SELESAI
-- ═════════════════════════════════════════════════════════════════════════════
-- Database dan users berhasil dihapus.
-- Untuk re-install, jalankan:
-- mysql -u root -p < db_reservasi_wisata.sql
-- ═════════════════════════════════════════════════════════════════════════════
