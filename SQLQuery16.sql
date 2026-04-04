SELECT
    COUNT(*) AS IadeSayisi,
    SUM(IadeTutari) AS ToplamIadeTutari,
    AVG(IadeTutari) AS OrtalamaIadeTutari
FROM [Odeme].[IadeIslemleri];