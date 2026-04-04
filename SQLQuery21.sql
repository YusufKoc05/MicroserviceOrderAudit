DECLARE @SiparisID BIGINT = 1;

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
WHERE s.SiparisID = @SiparisID
ORDER BY sdg.DegisimTarihi;