DECLARE @SiparisID BIGINT = 1;

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
WHERE s.SiparisID = @SiparisID
ORDER BY kh.HareketTarihi;