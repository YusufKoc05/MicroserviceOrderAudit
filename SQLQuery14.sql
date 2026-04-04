SELECT
    oy.YontemAdi,
    od.DurumAdi,
    COUNT(*) AS IslemSayisi,
    SUM(o.Tutar) AS ToplamTutar,
    AVG(o.Tutar) AS OrtalamaTutar
FROM [Odeme].[OdemeIslemleri] o
JOIN [Odeme].[OdemeYontemleri] oy
    ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od
    ON o.OdemeDurumID = od.OdemeDurumID
GROUP BY
    oy.YontemAdi,
    od.DurumAdi
ORDER BY ToplamTutar DESC;