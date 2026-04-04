SELECT TOP 20
    s.SiparisID,
    s.SiparisNo,
    k.Ad + N' ' + k.Soyad AS Musteri,
    sd.DurumAdi AS SiparisDurumu,
    srv.ServisAdi AS OlusturanServis,
    s.GenelToplam,
    s.ParaBirimi,
    s.SiparisTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kimlik].[Kullanicilar] k
    ON s.KullaniciID = k.KullaniciID
JOIN [Siparis].[SiparisDurumlari] sd
    ON s.SiparisDurumID = sd.SiparisDurumID
JOIN [Kimlik].[Servisler] srv
    ON s.OlusturanServisID = srv.ServisID
ORDER BY s.SiparisTarihi DESC;