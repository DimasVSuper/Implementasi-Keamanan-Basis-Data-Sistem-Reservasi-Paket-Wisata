# 🗑️ Database Cleanup Guide

## 📌 Kapan Menggunakan Cleanup Script?

Gunakan `cleanup_database.sql` untuk:
- ✅ **Sebelum re-install database** (install ulang dari awal)
- ✅ **Mengatasi error Aria** saat FLUSH PRIVILEGES
- ✅ **Reset database** ke kondisi fresh install
- ✅ **Menghapus users lama** sebelum buat yang baru

---

## 🚀 Cara Menggunakan

### **Opsi 1: Via Command Line (Recommended)**

```bash
# Masuk ke folder project
cd C:\Users\Dimas\github\databaseplayground

# Jalankan cleanup script
C:\xampp\mysql\bin\mysql.exe -u root -p < cleanup_database.sql
```

### **Opsi 2: Via MySQL Workbench/HeidiSQL**

1. Buka MySQL Workbench atau HeidiSQL
2. Connect sebagai **root**
3. Open file `cleanup_database.sql`
4. Execute (Ctrl+Shift+Enter)

### **Opsi 3: Copy-Paste Manual**

Login ke MySQL sebagai root, lalu jalankan:

```sql
DROP USER IF EXISTS 'admin_user'@'localhost';
DROP USER IF EXISTS 'petugas_user'@'localhost';
DROP USER IF EXISTS 'web_app'@'localhost';
DROP DATABASE IF EXISTS db_reservasi_wisata;
FLUSH PRIVILEGES;
```

---

## ⚠️ PERINGATAN

**HATI-HATI!** Script ini akan:
- ❌ Menghapus **SEMUA data** di database `db_reservasi_wisata`
- ❌ Menghapus **3 MySQL users**: `admin_user`, `petugas_user`, `web_app`
- ❌ **TIDAK BISA DI-UNDO!**

Pastikan Anda sudah **backup data** jika diperlukan sebelum menjalankan cleanup.

---

## 🔄 Re-install Database Setelah Cleanup

Setelah cleanup berhasil, install ulang database dengan:

```bash
C:\xampp\mysql\bin\mysql.exe -u root -p < db_reservasi_wisata.sql
```

---

## 🐛 Troubleshooting

### **Error: "Access denied for user 'admin_user'@'localhost'"**

✅ **Solusi:** Jalankan cleanup script untuk hapus user lama, lalu re-install.

### **Error: "Read page with wrong checksum from storage engine Aria"**

✅ **Solusi:** 
1. Jalankan cleanup script (ini akan FLUSH PRIVILEGES dengan aman)
2. Jika masih error, restart MySQL service di XAMPP
3. Re-install database

### **Error: "Database 'db_reservasi_wisata' doesn't exist"**

✅ **Normal!** Ini berarti cleanup berhasil. Lanjut ke re-install.

---

## 📋 Workflow Lengkap (Fresh Install)

```bash
# 1. Cleanup database lama
C:\xampp\mysql\bin\mysql.exe -u root -p < cleanup_database.sql

# 2. Install database baru
C:\xampp\mysql\bin\mysql.exe -u root -p < db_reservasi_wisata.sql

# 3. Verifikasi instalasi
C:\xampp\mysql\bin\mysql.exe -u root -p -e "SHOW DATABASES LIKE 'db_reservasi_wisata';"
C:\xampp\mysql\bin\mysql.exe -u root -p -e "SELECT User, Host FROM mysql.user WHERE User IN ('admin_user', 'petugas_user', 'web_app');"
```

---

## 📝 Catatan

- Script cleanup sudah include `IF EXISTS` untuk menghindari error jika database/user belum ada
- `FLUSH PRIVILEGES` di akhir memastikan perubahan privilege langsung diterapkan
- Script ini **aman dijalankan berulang kali** (idempotent)

---

**Dibuat oleh:** Dimas Bayu Nugroho (19240384)  
**Mata Kuliah:** Keamanan Basis Data  
**Universitas:** Bina Sarana Informatika
