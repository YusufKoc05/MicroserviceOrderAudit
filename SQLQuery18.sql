SELECT
    kd.DurumAdi,
    COUNT(*) AS GonderiSayisi,
    SUM(kg.GonderiUcreti) AS ToplamKargoUcreti
FROM [Kargo].[KargoGonderileri] kg
JOIN [Kargo].[KargoDurumlari] kd
    ON kg.KargoDurumID = kd.KargoDurumID
GROUP BY kd.DurumAdi
ORDER BY GonderiSayisi DESC;