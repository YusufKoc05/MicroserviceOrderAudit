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