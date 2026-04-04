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