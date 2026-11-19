-- ============================================================================
-- PROJE: Mikroservis Sipariş ve Merkezi Audit (Denetim) Veritabanı Sistemi
-- DOSYA: 02_indexes_and_constraints.sql
-- AÇIKLAMA: Yüksek hacimli analitik ve operasyonel sorgular için Non-Clustered
--           ve Covering Index tanımlamaları.
-- ============================================================================

USE [MerkeziAuditSiparisDB];
GO

-- 1. Siparişler Tablosu Performans İndeksleri
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Siparisler_KullaniciID_SiparisTarihi')
CREATE NONCLUSTERED INDEX [IX_Siparisler_KullaniciID_SiparisTarihi]
ON [Siparis].[Siparisler] ([KullaniciID] ASC, [SiparisTarihi] DESC)
INCLUDE ([SiparisNo], [SiparisDurumID], [GenelToplam], [ParaBirimi]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Siparisler_SiparisDurumID_Tarih')
CREATE NONCLUSTERED INDEX [IX_Siparisler_SiparisDurumID_Tarih]
ON [Siparis].[Siparisler] ([SiparisDurumID] ASC, [SiparisTarihi] DESC)
INCLUDE ([GenelToplam], [AraToplam], [KullaniciID]);
GO

-- 2. Sipariş Kalemleri Ürün Bazlı Analitik İndeksi
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SiparisKalemleri_UrunKodu')
CREATE NONCLUSTERED INDEX [IX_SiparisKalemleri_UrunKodu]
ON [Siparis].[SiparisKalemleri] ([UrunKodu] ASC)
INCLUDE ([UrunAdi], [Miktar], [BirimFiyat], [SatirToplami], [SiparisID]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SiparisKalemleri_SiparisID')
CREATE NONCLUSTERED INDEX [IX_SiparisKalemleri_SiparisID]
ON [Siparis].[SiparisKalemleri] ([SiparisID] ASC)
INCLUDE ([Miktar], [SatirToplami]);
GO

-- 3. Ödeme ve İade İşlemleri İndeksleri
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_OdemeIslemleri_SiparisID_Durum')
CREATE NONCLUSTERED INDEX [IX_OdemeIslemleri_SiparisID_Durum]
ON [Odeme].[OdemeIslemleri] ([SiparisID] ASC, [OdemeDurumID] ASC)
INCLUDE ([OdemeYontemID], [Tutar], [IslemTarihi], [HataMesaji]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_IadeIslemleri_OdemeID_Tarih')
CREATE NONCLUSTERED INDEX [IX_IadeIslemleri_OdemeID_Tarih]
ON [Odeme].[IadeIslemleri] ([OdemeID] ASC, [IadeTarihi] DESC)
INCLUDE ([IadeTutari], [IadeDurumu]);
GO

-- 4. Kargo Gönderileri ve Hareketleri İndeksleri
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KargoGonderileri_SiparisID_Durum')
CREATE NONCLUSTERED INDEX [IX_KargoGonderileri_SiparisID_Durum]
ON [Kargo].[KargoGonderileri] ([SiparisID] ASC, [KargoDurumID] ASC)
INCLUDE ([TakipNo], [KargoFirmaID], [GonderiUcreti]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KargoHareketleri_GonderiID_Tarih')
CREATE NONCLUSTERED INDEX [IX_KargoHareketleri_GonderiID_Tarih]
ON [Kargo].[KargoHareketleri] ([KargoGonderiID] ASC, [HareketTarihi] ASC)
INCLUDE ([KargoDurumID], [Lokasyon], [Aciklama]);
GO

-- 5. Merkezi Denetim (Audit) Tablosu İndeksleri (Yüksek Okuma/Yazma Optimizasyonu)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DenetimKayitlari_OlayTur_Seviye_Tarih')
CREATE NONCLUSTERED INDEX [IX_DenetimKayitlari_OlayTur_Seviye_Tarih]
ON [Denetim].[DenetimKayitlari] ([OlayTurID] ASC, [SeviyeID] ASC, [OlusturmaTarihi] DESC)
INCLUDE ([ServisID], [BasariliMi], [VarlikTipi], [VarlikID], [KorelasyonID]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DenetimKayitlari_KorelasyonID')
CREATE NONCLUSTERED INDEX [IX_DenetimKayitlari_KorelasyonID]
ON [Denetim].[DenetimKayitlari] ([KorelasyonID] ASC)
INCLUDE ([ServisID], [OlayTurID], [SeviyeID], [OlusturmaTarihi], [Mesaj]);
GO
