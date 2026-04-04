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