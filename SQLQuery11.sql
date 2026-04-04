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