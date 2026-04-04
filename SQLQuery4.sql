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