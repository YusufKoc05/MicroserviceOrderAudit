-- ============================================================================
-- PROJE: Mikroservis Sipariş ve Merkezi Audit (Denetim) Veritabanı Sistemi
-- DOSYA: 03_triggers_and_procedures.sql
-- AÇIKLAMA: Otomatik Sipariş Durum Geçmişi & Merkezi Audit Trigger'ları,
--           CSV Bulk Import ve Merkezi Audit Kayıt Stored Procedure'leri.
-- ============================================================================

USE [MerkeziAuditSiparisDB];
GO

-- ============================================================================
-- 1. MERKEZİ DENETİM (AUDIT) KAYDI EKLEME STORED PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE [Denetim].[usp_DenetimKaydiEkle]
    @ServisKodu    NVARCHAR(50),
    @OlayKodu      NVARCHAR(100),
    @SeviyeKodu    NVARCHAR(50),
    @KullaniciID   BIGINT = NULL,
    @VarlikTipi    NVARCHAR(100),
    @VarlikID      NVARCHAR(100) = NULL,
    @KorelasyonID  NVARCHAR(100) = NULL,
    @IpAdresi      NVARCHAR(50)  = NULL,
    @BasariliMi    BIT           = 1,
    @Mesaj         NVARCHAR(1000),
    @DetayJson     NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ServisID INT = (SELECT TOP 1 ServisID FROM [Kimlik].[Servisler] WHERE ServisKodu = @ServisKodu);
    DECLARE @OlayTurID INT = (SELECT TOP 1 OlayTurID FROM [Denetim].[OlayTurleri] WHERE OlayKodu = @OlayKodu);
    DECLARE @SeviyeID INT = (SELECT TOP 1 SeviyeID FROM [Denetim].[Seviyeler] WHERE SeviyeKodu = @SeviyeKodu);

    IF @KorelasyonID IS NULL
        SET @KorelasyonID = CONVERT(NVARCHAR(100), NEWID());

    IF @ServisID IS NOT NULL AND @OlayTurID IS NOT NULL AND @SeviyeID IS NOT NULL
    BEGIN
        INSERT INTO [Denetim].[DenetimKayitlari] (
            [ServisID], [OlayTurID], [SeviyeID], [KullaniciID],
            [VarlikTipi], [VarlikID], [KorelasyonID], [IpAdresi],
            [BasariliMi], [Mesaj], [DetayJson], [OlusturmaTarihi]
        )
        VALUES (
            @ServisID, @OlayTurID, @SeviyeID, @KullaniciID,
            @VarlikTipi, @VarlikID, @KorelasyonID, @IpAdresi,
            @BasariliMi, @Mesaj, @DetayJson, SYSDATETIME()
        );
    END
END;
GO

-- ============================================================================
-- 2. SİPARİŞ DURUM DEĞİŞİKLİĞİ VE AUDIT TRIGGER'I
-- ============================================================================
CREATE OR ALTER TRIGGER [Siparis].[trg_Siparisler_DurumVeAudit]
ON [Siparis].[Siparisler]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE([SiparisDurumID])
    BEGIN
        -- 1. Sipariş Durum Geçmişine otomatik kayıt ekle
        INSERT INTO [Siparis].[SiparisDurumGecmisi] (
            [SiparisID],
            [EskiSiparisDurumID],
            [YeniSiparisDurumID],
            [DegistirenKullaniciID],
            [DegisimTarihi],
            [Aciklama]
        )
        SELECT
            i.[SiparisID],
            d.[SiparisDurumID],
            i.[SiparisDurumID],
            i.[KullaniciID],
            SYSDATETIME(),
            N'Otomatik durum geçişi (Trigger): Durum ' + CAST(d.[SiparisDurumID] AS NVARCHAR(10)) +
            N' -> ' + CAST(i.[SiparisDurumID] AS NVARCHAR(10))
        FROM inserted i
        INNER JOIN deleted d ON i.[SiparisID] = d.[SiparisID]
        WHERE i.[SiparisDurumID] <> d.[SiparisDurumID];

        -- 2. Merkezi Denetim (Audit) tablosuna otomatik log kaydı düş
        DECLARE @OlayTurID INT = (SELECT TOP 1 OlayTurID FROM [Denetim].[OlayTurleri] WHERE OlayKodu = N'ORDER_STATUS_CHANGED');
        DECLARE @SeviyeID  INT = (SELECT TOP 1 SeviyeID  FROM [Denetim].[Seviyeler]   WHERE SeviyeKodu = N'INFO');

        IF @OlayTurID IS NOT NULL AND @SeviyeID IS NOT NULL
        BEGIN
            INSERT INTO [Denetim].[DenetimKayitlari] (
                [ServisID], [OlayTurID], [SeviyeID], [KullaniciID],
                [VarlikTipi], [VarlikID], [KorelasyonID], [IpAdresi],
                [BasariliMi], [Mesaj], [DetayJson], [OlusturmaTarihi]
            )
            SELECT
                i.[OlusturanServisID],
                @OlayTurID,
                @SeviyeID,
                i.[KullaniciID],
                N'Siparis',
                i.[SiparisNo],
                CONVERT(NVARCHAR(100), NEWID()),
                N'10.0.0.10',
                1,
                N'Sipariş durumu güncellendi: ' + i.[SiparisNo],
                (
                    SELECT
                        d.[SiparisDurumID] AS EskiDurumID,
                        i.[SiparisDurumID] AS YeniDurumID,
                        i.[GenelToplam]    AS GenelToplam
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ),
                SYSDATETIME()
            FROM inserted i
            INNER JOIN deleted d ON i.[SiparisID] = d.[SiparisID]
            WHERE i.[SiparisDurumID] <> d.[SiparisDurumID];
        END
    END
END;
GO

-- ============================================================================
-- 3. CSV BULK IMPORT STORED PROCEDURE (Orijinal Csv_import.sql)
-- ============================================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_BulkImportCsv]
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
