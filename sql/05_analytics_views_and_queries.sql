-- ============================================================================
-- PROJE: Mikroservis Sipariş ve Merkezi Audit (Denetim) Veritabanı Sistemi
-- DOSYA: 05_analytics_views_and_queries.sql
-- AÇIKLAMA: Depodaki tüm analitik sorguların (SQLQuery2 - SQLQuery23) kategorize
--           edilmiş, açıklamalı ve View / Rapor olarak zenginleştirilmiş hali.
-- ============================================================================

USE [MerkeziAuditSiparisDB];
GO

-- ============================================================================
-- BÖLÜM 1: VERİTABANI GENEL ÖZET VE DOĞRULAMA SORGULARI
-- ============================================================================

-- [Sorgu 01 - Orijinal SQLQuery2] Son 10 Sipariş Önizleme
SELECT TOP 10 *
FROM [Siparis].[Siparisler];
GO

-- [Sorgu 02 - Orijinal SQLQuery3] Tüm Mikroservis Tablolarının Satır Sayıları Özeti
SELECT 'Kullanicilar'     AS TabloAdi, COUNT(*) AS KayitSayisi FROM [Kimlik].[Kullanicilar]
UNION ALL
SELECT 'Siparisler',                   COUNT(*) FROM [Siparis].[Siparisler]
UNION ALL
SELECT 'SiparisKalemleri',             COUNT(*) FROM [Siparis].[SiparisKalemleri]
UNION ALL
SELECT 'OdemeIslemleri',               COUNT(*) FROM [Odeme].[OdemeIslemleri]
UNION ALL
SELECT 'IadeIslemleri',                COUNT(*) FROM [Odeme].[IadeIslemleri]
UNION ALL
SELECT 'KargoGonderileri',             COUNT(*) FROM [Kargo].[KargoGonderileri]
UNION ALL
SELECT 'KargoHareketleri',             COUNT(*) FROM [Kargo].[KargoHareketleri]
UNION ALL
SELECT 'DenetimKayitlari',             COUNT(*) FROM [Denetim].[DenetimKayitlari];
GO

-- ============================================================================
-- BÖLÜM 2: MÜŞTERİ VE KİMLİK ANALİTİĞİ
-- ============================================================================

-- [Sorgu 03 - Orijinal SQLQuery4] En Çok Sipariş Veren ve Harcama Yapan İlk 10 VIP Müşteri
SELECT TOP 10
    k.KullaniciID,
    k.KullaniciAdi,
    k.Ad,
    k.Soyad,
    COUNT(s.SiparisID) AS SiparisSayisi,
    SUM(s.GenelToplam) AS ToplamHarcama
FROM [Kimlik].[Kullanicilar] k
JOIN [Siparis].[Siparisler] s
    ON s.KullaniciID = k.KullaniciID
GROUP BY
    k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad
ORDER BY SiparisSayisi DESC, ToplamHarcama DESC;
GO

-- [Sorgu 04 - Orijinal SQLQuery13] Sisteme Kayıtlı Olup Henüz Sipariş Vermemiş (Pasif) Kullanıcılar
SELECT TOP 20
    k.KullaniciID,
    k.KullaniciAdi,
    k.Ad,
    k.Soyad,
    k.Eposta
FROM [Kimlik].[Kullanicilar] k
LEFT JOIN [Siparis].[Siparisler] s
    ON s.KullaniciID = k.KullaniciID
WHERE s.SiparisID IS NULL
ORDER BY k.KullaniciID;
GO

-- ============================================================================
-- BÖLÜM 3: SİPARİŞ, CİRO VE ÜRÜN PERFORMANS ANALİTİĞİ
-- ============================================================================

-- [Sorgu 05 - Orijinal SQLQuery5] Mikroservis Kaynaklı Son 20 Sipariş Detayı
SELECT TOP 20
    s.SiparisID,
    s.SiparisNo,
    k.Ad + N' ' + k.Soyad AS Musteri,
    sd.DurumAdi AS SiparisDurumu,
    srv.ServisAdi AS OlusturanServis,
    s.GenelToplam,
    s.ParaBirimi,
    s.SiparisTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kimlik].[Kullanicilar] k
    ON s.KullaniciID = k.KullaniciID
JOIN [Siparis].[SiparisDurumlari] sd
    ON s.SiparisDurumID = sd.SiparisDurumID
JOIN [Kimlik].[Servisler] srv
    ON s.OlusturanServisID = srv.ServisID
ORDER BY s.SiparisTarihi DESC;
GO

-- [Sorgu 06 - Orijinal SQLQuery7] Sipariş Durumlarına Göre Sipariş Sayısı ve Ciro Dağılımı
SELECT
    sd.DurumAdi,
    COUNT(*) AS SiparisSayisi,
    SUM(s.GenelToplam) AS ToplamCiro,
    AVG(s.GenelToplam) AS OrtalamaSiparisTutari
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisDurumlari] sd
    ON s.SiparisDurumID = sd.SiparisDurumID
GROUP BY sd.DurumAdi
ORDER BY ToplamCiro DESC;
GO

-- [Sorgu 07 - Orijinal SQLQuery8] Yıl ve Ay Bazında Sipariş Hacmi ve Ortalama Sepet Tutarı
SELECT
    YEAR(s.SiparisTarihi) AS Yil,
    MONTH(s.SiparisTarihi) AS Ay,
    COUNT(*) AS SiparisSayisi,
    SUM(s.GenelToplam) AS ToplamCiro,
    AVG(s.GenelToplam) AS OrtalamaSepetTutari
FROM [Siparis].[Siparisler] s
GROUP BY
    YEAR(s.SiparisTarihi),
    MONTH(s.SiparisTarihi)
ORDER BY Yil, Ay;
GO

-- [Sorgu 08 - Orijinal SQLQuery9] Window Function (LAG) ile Aylık Ciro Büyüme/Fark Analizi
WITH Aylik AS
(
    SELECT
        YEAR(SiparisTarihi) AS Yil,
        MONTH(SiparisTarihi) AS Ay,
        SUM(GenelToplam) AS ToplamCiro
    FROM [Siparis].[Siparisler]
    GROUP BY YEAR(SiparisTarihi), MONTH(SiparisTarihi)
)
SELECT
    Yil,
    Ay,
    ToplamCiro,
    LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS OncekiAyCiro,
    ToplamCiro - LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS AylikFark
FROM Aylik
ORDER BY Yil, Ay;
GO

-- [Sorgu 09 - Orijinal SQLQuery10] Satış Adedine Göre En Çok Satan İlk 10 Ürün
SELECT TOP 10
    sk.UrunKodu,
    sk.UrunAdi,
    SUM(sk.Miktar) AS ToplamAdet,
    SUM(sk.SatirToplami) AS ToplamSatisTutari
FROM [Siparis].[SiparisKalemleri] sk
GROUP BY
    sk.UrunKodu,
    sk.UrunAdi
ORDER BY ToplamAdet DESC, ToplamSatisTutari DESC;
GO

-- [Sorgu 10 - Orijinal SQLQuery11] Toplam Gelire (Ciroya) Göre İlk 10 Ürün
SELECT TOP 10
    sk.UrunKodu,
    sk.UrunAdi,
    SUM(sk.SatirToplami) AS ToplamGelir,
    AVG(sk.BirimFiyat) AS OrtalamaBirimFiyat
FROM [Siparis].[SiparisKalemleri] sk
GROUP BY
    sk.UrunKodu,
    sk.UrunAdi
ORDER BY ToplamGelir DESC;
GO

-- [Sorgu 11 - Orijinal SQLQuery12] Kalem Çeşitliliği En Yüksek İlk 10 Sipariş
SELECT TOP 10
    s.SiparisNo,
    COUNT(sk.SiparisKalemID) AS KalemSayisi,
    SUM(sk.Miktar) AS ToplamUrunAdedi,
    s.GenelToplam
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisKalemleri] sk
    ON s.SiparisID = sk.SiparisID
GROUP BY
    s.SiparisNo,
    s.GenelToplam
ORDER BY KalemSayisi DESC, ToplamUrunAdedi DESC;
GO

-- ============================================================================
-- BÖLÜM 4: ÖDEME VE İADE FİNANSAL ANALİTİĞİ
-- ============================================================================

-- [Sorgu 12 - Orijinal SQLQuery14] Ödeme Yöntemi ve Durumuna Göre Finansal Dağılım
SELECT
    oy.YontemAdi,
    od.DurumAdi,
    COUNT(*) AS IslemSayisi,
    SUM(o.Tutar) AS ToplamTutar,
    AVG(o.Tutar) AS OrtalamaTutar
FROM [Odeme].[OdemeIslemleri] o
JOIN [Odeme].[OdemeYontemleri] oy
    ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od
    ON o.OdemeDurumID = od.OdemeDurumID
GROUP BY
    oy.YontemAdi,
    od.DurumAdi
ORDER BY ToplamTutar DESC;
GO

-- [Sorgu 13 - Orijinal SQLQuery15] Hata Mesajı İçeren Başarısız Ödeme İşlemleri
SELECT TOP 20
    o.OdemeID,
    s.SiparisNo,
    oy.YontemAdi,
    od.DurumAdi,
    o.Tutar,
    o.HataMesaji,
    o.IslemTarihi
FROM [Odeme].[OdemeIslemleri] o
JOIN [Siparis].[Siparisler] s
    ON o.SiparisID = s.SiparisID
JOIN [Odeme].[OdemeYontemleri] oy
    ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od
    ON o.OdemeDurumID = od.OdemeDurumID
WHERE o.HataMesaji IS NOT NULL
ORDER BY o.IslemTarihi DESC;
GO

-- [Sorgu 14 - Orijinal SQLQuery16] Toplam İade Sayısı ve Finansal İade Özeti
SELECT
    COUNT(*) AS IadeSayisi,
    SUM(IadeTutari) AS ToplamIadeTutari,
    AVG(IadeTutari) AS OrtalamaIadeTutari
FROM [Odeme].[IadeIslemleri];
GO

-- [Sorgu 15 - Orijinal SQLQuery17] Son 20 İade İşlemi ve Müşteri Detayları
SELECT TOP 20
    i.IadeID,
    s.SiparisNo,
    k.Ad + N' ' + k.Soyad AS Musteri,
    i.IadeTutari,
    i.IadeDurumu,
    i.IadeNedeni,
    i.IadeTarihi
FROM [Odeme].[IadeIslemleri] i
JOIN [Odeme].[OdemeIslemleri] o
    ON i.OdemeID = o.OdemeID
JOIN [Siparis].[Siparisler] s
    ON o.SiparisID = s.SiparisID
JOIN [Kimlik].[Kullanicilar] k
    ON s.KullaniciID = k.KullaniciID
ORDER BY i.IadeTarihi DESC;
GO

-- ============================================================================
-- BÖLÜM 5: KARGO VE LOJİSTİK OPERASYON ANALİTİĞİ
-- ============================================================================

-- [Sorgu 16 - Orijinal SQLQuery18] Kargo Durumlarına Göre Gönderi Sayısı ve Maliyet
SELECT
    kd.DurumAdi,
    COUNT(*) AS GonderiSayisi,
    SUM(kg.GonderiUcreti) AS ToplamKargoUcreti
FROM [Kargo].[KargoGonderileri] kg
JOIN [Kargo].[KargoDurumlari] kd
    ON kg.KargoDurumID = kd.KargoDurumID
GROUP BY kd.DurumAdi
ORDER BY GonderiSayisi DESC;
GO

-- [Sorgu 17 - Orijinal SQLQuery19] Ödemesi Alınmış Ancak Henüz Kargoya Verilmemiş Siparişler (SLA Takibi)
SELECT TOP 20
    s.SiparisNo,
    k.Ad + N' ' + k.Soyad AS Musteri,
    o.OdemeID,
    o.Tutar,
    o.IslemTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kimlik].[Kullanicilar] k
    ON s.KullaniciID = k.KullaniciID
JOIN [Odeme].[OdemeIslemleri] o
    ON s.SiparisID = o.SiparisID
LEFT JOIN [Kargo].[KargoGonderileri] kg
    ON s.SiparisID = kg.SiparisID
WHERE kg.KargoGonderiID IS NULL
ORDER BY o.IslemTarihi DESC;
GO

-- [Sorgu 18 - Orijinal SQLQuery20] Belirli Bir Siparişin Adım Adım Kargo Hareket Geçmişi
DECLARE @SiparisID_Kargo BIGINT = 1;

SELECT
    s.SiparisNo,
    kg.TakipNo,
    kd.DurumAdi,
    kh.Lokasyon,
    kh.Aciklama,
    kh.HareketTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kargo].[KargoGonderileri] kg
    ON s.SiparisID = kg.SiparisID
JOIN [Kargo].[KargoHareketleri] kh
    ON kg.KargoGonderiID = kh.KargoGonderiID
JOIN [Kargo].[KargoDurumlari] kd
    ON kh.KargoDurumID = kd.KargoDurumID
WHERE s.SiparisID = @SiparisID_Kargo
ORDER BY kh.HareketTarihi;
GO

-- ============================================================================
-- BÖLÜM 6: DENETİM (AUDIT), DURUM İZLEME VE VERİ TUTARLILIĞI (RECONCILIATION)
-- ============================================================================

-- [Sorgu 19 - Orijinal SQLQuery21] Sipariş Durum Geçiş Tarihçesi (State Transition Audit)
DECLARE @SiparisID_Durum BIGINT = 1;

SELECT
    s.SiparisNo,
    es.DurumAdi AS EskiDurum,
    ys.DurumAdi AS YeniDurum,
    k.KullaniciAdi AS DegistirenKullanici,
    sdg.DegisimTarihi,
    sdg.Aciklama
FROM [Siparis].[SiparisDurumGecmisi] sdg
JOIN [Siparis].[Siparisler] s
    ON sdg.SiparisID = s.SiparisID
LEFT JOIN [Siparis].[SiparisDurumlari] es
    ON sdg.EskiSiparisDurumID = es.SiparisDurumID
JOIN [Siparis].[SiparisDurumlari] ys
    ON sdg.YeniSiparisDurumID = ys.SiparisDurumID
LEFT JOIN [Kimlik].[Kullanicilar] k
    ON sdg.DegistirenKullaniciID = k.KullaniciID
WHERE s.SiparisID = @SiparisID_Durum
ORDER BY sdg.DegisimTarihi;
GO

-- [Sorgu 20 - Orijinal SQLQuery22] Merkezi Denetim (Audit) Olay Türü ve Seviye Bazlı Başarı/Hata Dağılımı
SELECT
    ot.OlayAdi,
    sv.SeviyeAdi,
    COUNT(*) AS KayitSayisi,
    SUM(CASE WHEN d.BasariliMi = 1 THEN 1 ELSE 0 END) AS BasariliKayit,
    SUM(CASE WHEN d.BasariliMi = 0 THEN 1 ELSE 0 END) AS BasarisizKayit
FROM [Denetim].[DenetimKayitlari] d
JOIN [Denetim].[OlayTurleri] ot
    ON d.OlayTurID = ot.OlayTurID
JOIN [Denetim].[Seviyeler] sv
    ON d.SeviyeID = sv.SeviyeID
GROUP BY
    ot.OlayAdi,
    sv.SeviyeAdi
ORDER BY KayitSayisi DESC;
GO

-- [Sorgu 21 - Orijinal SQLQuery23] Sipariş AraToplam ile Kalemler Toplamı Tutarsızlık Denetimi (Financial Reconciliation)
SELECT TOP 20
    s.SiparisNo,
    s.AraToplam,
    SUM(sk.SatirToplami) AS KalemlerToplami,
    s.AraToplam - SUM(sk.SatirToplami) AS Fark
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisKalemleri] sk
    ON s.SiparisID = sk.SiparisID
GROUP BY
    s.SiparisNo,
    s.AraToplam
HAVING ABS(s.AraToplam - SUM(sk.SatirToplami)) > 0.01
ORDER BY ABS(s.AraToplam - SUM(sk.SatirToplami)) DESC;
GO
