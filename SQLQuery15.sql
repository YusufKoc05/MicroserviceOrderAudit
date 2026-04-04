SELECT TOP 20
    o.OdemeID,
    s.SiparisNo,
    oy.YontemAdi,
    od.DurumAdi,
    o.Tutar,
    o.HataMesaji,
    o.IslemTarihi
FROM [Odeme].[OdemeIslemleri] o
JOIN [Siparis].[Siparisler] s
    ON o.SiparisID = s.SiparisID
JOIN [Odeme].[OdemeYontemleri] oy
    ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od
    ON o.OdemeDurumID = od.OdemeDurumID
WHERE o.HataMesaji IS NOT NULL
ORDER BY o.IslemTarihi DESC;