USE [MerkeziAuditSiparisDB];
GO

CREATE OR ALTER PROCEDURE dbo.usp_BulkImportCsv
    @SchemaName SYSNAME,
    @TableName  SYSNAME,
    @FileName   NVARCHAR(4000),
    @BasePath   NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) =
        N'BULK INSERT ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N'
          FROM ' + QUOTENAME(@BasePath + @FileName, '''') + N'
          WITH
          (
              FORMAT = ''CSV'',
              FIRSTROW = 2,
              CODEPAGE = ''65001'',
              KEEPIDENTITY,
              TABLOCK
          );';

    PRINT N'Importing ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' from ' + @FileName;
    EXEC sp_executesql @sql;
END;
GO

DECLARE @BasePath NVARCHAR(4000) = N'C:\CSVImport\';

BEGIN TRY
    BEGIN TRAN;

    DELETE FROM [Denetim].[DenetimKayitlari];
    DELETE FROM [Kargo].[KargoHareketleri];
    DELETE FROM [Odeme].[IadeIslemleri];
    DELETE FROM [Siparis].[SiparisDurumGecmisi];
    DELETE FROM [Siparis].[SiparisKalemleri];
    DELETE FROM [Kargo].[KargoGonderileri];
    DELETE FROM [Odeme].[OdemeIslemleri];
    DELETE FROM [Siparis].[Siparisler];
    DELETE FROM [Kimlik].[KullaniciRolleri];
    DELETE FROM [Kimlik].[Adresler];
    DELETE FROM [Denetim].[OlayTurleri];
    DELETE FROM [Denetim].[Seviyeler];
    DELETE FROM [Kargo].[KargoFirmalari];
    DELETE FROM [Kargo].[KargoDurumlari];
    DELETE FROM [Odeme].[OdemeYontemleri];
    DELETE FROM [Odeme].[OdemeDurumlari];
    DELETE FROM [Siparis].[SiparisDurumlari];
    DELETE FROM [Kimlik].[Servisler];
    DELETE FROM [Kimlik].[Roller];
    DELETE FROM [Kimlik].[Kullanicilar];

    EXEC dbo.usp_BulkImportCsv 'Kimlik',  'Kullanicilar',        'Kimlik_Kullanicilar.csv',         @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kimlik',  'Roller',              'Kimlik_Roller.csv',               @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kimlik',  'Servisler',           'Kimlik_Servisler.csv',            @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Siparis', 'SiparisDurumlari',    'Siparis_SiparisDurumlari.csv',    @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Odeme',   'OdemeYontemleri',     'Odeme_OdemeYontemleri.csv',       @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Odeme',   'OdemeDurumlari',      'Odeme_OdemeDurumlari.csv',        @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kargo',   'KargoDurumlari',      'Kargo_KargoDurumlari.csv',        @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kargo',   'KargoFirmalari',      'Kargo_KargoFirmalari.csv',        @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Denetim', 'OlayTurleri',         'Denetim_OlayTurleri.csv',         @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Denetim', 'Seviyeler',           'Denetim_Seviyeler.csv',           @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kimlik',  'Adresler',            'Kimlik_Adresler.csv',             @BasePath;

    EXEC dbo.usp_BulkImportCsv 'Kimlik',  'KullaniciRolleri',    'Kimlik_KullaniciRolleri.csv',     @BasePath;

    EXEC dbo.usp_BulkImportCsv 'Siparis', 'Siparisler',          'Siparis_Siparisler.csv',          @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Siparis', 'SiparisKalemleri',    'Siparis_SiparisKalemleri.csv',    @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Siparis', 'SiparisDurumGecmisi', 'Siparis_SiparisDurumGecmisi.csv', @BasePath;

    EXEC dbo.usp_BulkImportCsv 'Odeme',   'OdemeIslemleri',      'Odeme_OdemeIslemleri.csv',        @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Odeme',   'IadeIslemleri',       'Odeme_IadeIslemleri.csv',         @BasePath;

    EXEC dbo.usp_BulkImportCsv 'Kargo',   'KargoGonderileri',    'Kargo_KargoGonderileri.csv',      @BasePath;
    EXEC dbo.usp_BulkImportCsv 'Kargo',   'KargoHareketleri',    'Kargo_KargoHareketleri.csv',      @BasePath;

    EXEC dbo.usp_BulkImportCsv 'Denetim', 'DenetimKayitlari',    'Denetim_DenetimKayitlari.csv',    @BasePath;

    COMMIT TRAN;
    PRINT N'CSV import tamamlandi.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    PRINT N'HATA: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO

SELECT COUNT(*) AS KullaniciSayisi    FROM [Kimlik].[Kullanicilar];
SELECT COUNT(*) AS SiparisSayisi      FROM [Siparis].[Siparisler];
SELECT COUNT(*) AS OdemeSayisi        FROM [Odeme].[OdemeIslemleri];
SELECT COUNT(*) AS DenetimKayitSayisi FROM [Denetim].[DenetimKayitlari];
GO