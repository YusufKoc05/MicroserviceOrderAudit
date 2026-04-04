SELECT TOP 20
    i.IadeID,
    s.SiparisNo,
    k.Ad + N' ' + k.Soyad AS Musteri,
    i.IadeTutari,
    i.IadeDurumu,
    i.IadeNedeni,
    i.IadeTarihi
FROM [Odeme].[IadeIslemleri] i
JOIN [Odeme].[OdemeIslemleri] o
    ON i.OdemeID = o.OdemeID
JOIN [Siparis].[Siparisler] s
    ON o.SiparisID = s.SiparisID
JOIN [Kimlik].[Kullanicilar] k
    ON s.KullaniciID = k.KullaniciID
ORDER BY i.IadeTarihi DESC;