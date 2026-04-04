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