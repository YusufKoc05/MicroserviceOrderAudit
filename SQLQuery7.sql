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