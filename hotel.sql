-- =========================================
-- DROP TABLE 
-- =========================================
DROP TABLE IF EXISTS Pagamento CASCADE;
DROP TABLE IF EXISTS Offerta CASCADE;
DROP TABLE IF EXISTS Prenotazione CASCADE;
DROP TABLE IF EXISTS Servizio CASCADE;
DROP TABLE IF EXISTS Camera CASCADE;
DROP TABLE IF EXISTS Persona CASCADE;
DROP TABLE IF EXISTS Hotel CASCADE;

-- =========================================
-- CREAZIONE TABELLE 
-- =========================================

CREATE TABLE Hotel (
    Codice            VARCHAR(10) PRIMARY KEY,
    Nome              VARCHAR(100) NOT NULL,
    Indirizzo         VARCHAR(150) NOT NULL,
    Citta             VARCHAR(100) NOT NULL,
    Regione           VARCHAR(100) NOT NULL,
    Stelle            INTEGER NOT NULL CHECK (Stelle BETWEEN 1 AND 5),
    Telefono          VARCHAR(20) NOT NULL,
	Data_Apertura     DATE NOT NULL,

    Tipo              VARCHAR(20) NOT NULL CHECK (Tipo IN ('Indipendente', 'Catena')),

    Proprietario      VARCHAR(100),
    Categoria         VARCHAR(50),

    Nome_Catena       VARCHAR(100),
    Sede_Centrale     VARCHAR(150),

    Direttore         CHAR(16) UNIQUE -- nullable per evitare dipendenze circolari durante il caricamento iniziale dei dati.
);

CREATE TABLE Persona (
    CF                   CHAR(16) PRIMARY KEY,
    Nome                 VARCHAR(50) NOT NULL,
    Cognome              VARCHAR(50) NOT NULL,
    Telefono             VARCHAR(20) NOT NULL,
    Email                VARCHAR(100),

    Data_Registrazione   DATE,
    Nazionalita          VARCHAR(50),

    Codice_Dipendente    VARCHAR(20) UNIQUE,
    Data_Assunzione      DATE,
    Stipendio            NUMERIC(10,2),

    Data_Nomina          DATE,
    Bonus_Responsabilita NUMERIC(10,2),

    Hotel                VARCHAR(10),

    FOREIGN KEY (Hotel) REFERENCES Hotel(Codice)
        ON DELETE SET NULL
);

CREATE TABLE Camera (
    Hotel      VARCHAR(10) NOT NULL,
    Numero     INTEGER NOT NULL,
    Tipo       VARCHAR(30) NOT NULL,
    Prezzo     NUMERIC(8,2) NOT NULL CHECK (Prezzo > 0),
    Stato      VARCHAR(20) NOT NULL CHECK (Stato IN ('Libera', 'Occupata', 'Manutenzione')),

    PRIMARY KEY (Hotel, Numero),

    FOREIGN KEY (Hotel) REFERENCES Hotel(Codice)
        ON DELETE CASCADE
);

CREATE TABLE Prenotazione (
    Codice_Prenotazione   VARCHAR(20) PRIMARY KEY,
    Hotel                 VARCHAR(10) NOT NULL,
    Camera                INTEGER NOT NULL,

    Data_Prenotazione     DATE NOT NULL,
    Check_In              DATE NOT NULL,
    Check_Out             DATE NOT NULL,
    N_Ospiti              INTEGER NOT NULL CHECK (N_Ospiti > 0),

    Stato                 VARCHAR(20) NOT NULL
                          CHECK (Stato IN ('Confermata', 'In_Corso', 'Conclusa', 'Annullata')),

    Cliente               CHAR(16) NOT NULL,

    FOREIGN KEY (Cliente) REFERENCES Persona(CF)
        ON DELETE CASCADE,

    FOREIGN KEY (Hotel, Camera) REFERENCES Camera(Hotel, Numero)
        ON DELETE CASCADE,

    CHECK (Check_Out > Check_In)
);

CREATE TABLE Servizio (
    Codice_Servizio    VARCHAR(10) PRIMARY KEY,
    Nome               VARCHAR(100) NOT NULL,
    Descrizione        TEXT,
    Costo_Aggiuntivo   NUMERIC(8,2)
);

CREATE TABLE Offerta (
    Hotel              VARCHAR(10) NOT NULL,
    Servizio           VARCHAR(10) NOT NULL,

    PRIMARY KEY (Hotel, Servizio),

    FOREIGN KEY (Hotel) REFERENCES Hotel(Codice)
        ON DELETE CASCADE,

    FOREIGN KEY (Servizio) REFERENCES Servizio(Codice_Servizio)
        ON DELETE CASCADE
);

CREATE TABLE Pagamento (
    Codice_Pagamento    VARCHAR(20) PRIMARY KEY,
    Data_Pagamento      DATE NOT NULL,
    Importo             NUMERIC(10,2) NOT NULL CHECK (Importo > 0),

    Metodo              VARCHAR(20) NOT NULL
                        CHECK (Metodo IN ('Contanti', 'Carta', 'Bonifico')),

    Stato               VARCHAR(20) NOT NULL
                        CHECK (Stato IN ('Effettuato', 'In_Attesa', 'Rimborsato')),

    Prenotazione        VARCHAR(20) NOT NULL,

    FOREIGN KEY (Prenotazione) REFERENCES Prenotazione(Codice_Prenotazione)
        ON DELETE CASCADE
);

-- =========================================
-- VINCOLI AGGIUNTIVI:
-- =========================================

-- un hotel può indicare come direttore solo una persona già registrata nel sistema
ALTER TABLE Hotel
ADD CONSTRAINT fk_direttore
FOREIGN KEY (Direttore) REFERENCES Persona(CF)
ON DELETE SET NULL;

-- un hotel indipendente non deve avere dati di catena e un hotel di catena non deve avere dati da hotel indipendente
ALTER TABLE Hotel
ADD CONSTRAINT chk_tipo_hotel
CHECK (
    (Tipo = 'Indipendente' AND Nome_Catena IS NULL AND Sede_Centrale IS NULL)
    OR
    (Tipo = 'Catena' AND Proprietario IS NULL AND Categoria IS NULL)
);

-- ogni persona deve essere in uno di tre stati coerenti: cliente, dipendente, direttore
ALTER TABLE Persona
ADD CONSTRAINT chk_ruolo_persona
CHECK (
    -- Cliente
    (
        Codice_Dipendente IS NULL
        AND Hotel IS NULL
        AND Data_Assunzione IS NULL
        AND Stipendio IS NULL
        AND Data_Nomina IS NULL
        AND Bonus_Responsabilita IS NULL
    )

    OR

    -- Dipendente normale
    (
        Codice_Dipendente IS NOT NULL
        AND Hotel IS NOT NULL
        AND Data_Assunzione IS NOT NULL
        AND Stipendio IS NOT NULL
        AND Data_Nomina IS NULL
        AND Bonus_Responsabilita IS NULL
    )

    OR

    -- Direttore
    (
        Codice_Dipendente IS NOT NULL
        AND Hotel IS NOT NULL
        AND Data_Assunzione IS NOT NULL
        AND Stipendio IS NOT NULL
        AND Data_Nomina IS NOT NULL
        AND Bonus_Responsabilita IS NOT NULL
    )
);

-- viene controllato se due prenotazioni della stessa camera si sovrappongono
CREATE OR REPLACE FUNCTION controlla_sovrapposizione_prenotazioni()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Prenotazione p
        WHERE p.Hotel = NEW.Hotel
          AND p.Camera = NEW.Camera
          AND p.Codice_Prenotazione <> NEW.Codice_Prenotazione
          AND p.Stato <> 'Annullata'
          AND NEW.Stato <> 'Annullata'
          AND NEW.Check_In < p.Check_Out
          AND NEW.Check_Out > p.Check_In
    ) THEN
        RAISE EXCEPTION 'La camera è già prenotata in questo intervallo di date';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_controlla_sovrapposizione_prenotazioni
BEFORE INSERT OR UPDATE ON Prenotazione
FOR EACH ROW
EXECUTE FUNCTION controlla_sovrapposizione_prenotazioni();


-- =========================================
-- INSERT DATI 
-- =========================================

INSERT INTO Hotel (Codice, Nome, Indirizzo, Citta, Regione, Stelle, Telefono, Data_Apertura, Tipo, Proprietario, Categoria, Nome_Catena, Sede_Centrale) VALUES
('H001', 'Grand Milano', 'Via Roma 10', 'Milano', 'Lombardia', 5, '0212345678', '2010-05-10', 'Catena', NULL, NULL, 'Luxury Stay', 'Milano'),
('H002', 'Hotel Lago', 'Via Verdi 22', 'Como', 'Lombardia', 4, '0319876543', '2015-06-15', 'Indipendente', 'Mario Rossi', 'Boutique Hotel', NULL, NULL),
('H003', 'Sea Palace', 'Lungomare 8', 'Rimini', 'Emilia-Romagna', 4, '0541123456', '2012-07-01', 'Catena', NULL, NULL, 'Blue Wave', 'Bologna'),
('H004', 'Dolomiti Resort', 'Via Montagna 5', 'Cortina', 'Veneto', 5, '0436123456', '2018-12-20', 'Indipendente', 'Luca Bianchi', 'Resort', NULL, NULL),
('H005', 'Royal Firenze', 'Via dei Calzaiuoli 18', 'Firenze', 'Toscana', 5, '0551234567', '2011-03-25', 'Catena', NULL, NULL, 'Luxury Stay', 'Milano'),
('H006', 'Hotel Vesuvio', 'Via Napoli 45', 'Napoli', 'Campania', 4, '0817654321', '2016-09-12', 'Indipendente', 'Antonio Esposito', 'Albergo', NULL, NULL),
('H007', 'Laguna Blu', 'Canal Grande 55', 'Venezia', 'Veneto', 5, '0412345678', '2013-04-08', 'Catena', NULL, NULL, 'Blue Wave', 'Bologna'),
('H008', 'Etna Resort', 'Via Etnea 210', 'Catania', 'Sicilia', 4, '0958765432', '2019-06-30', 'Indipendente', 'Salvatore Greco', 'Resort', NULL, NULL),
('H009', 'Torino Palace', 'Corso Francia 12', 'Torino', 'Piemonte', 5, '0113456789', '2009-11-15', 'Catena', NULL, NULL, 'Luxury Stay', 'Milano'),
('H010', 'Hotel Adriatico', 'Via del Porto 7', 'Bari', 'Puglia', 3, '0806543210', '2017-08-21', 'Indipendente', 'Giulia Romano', 'Boutique Hotel', NULL, NULL),
('H011', 'aaaaaa', 'Via del Porto 7', 'Bari', 'Puglia', 3, '0806543210', '2017-08-21', 'Indipendente', 'Giulia Romano', 'Boutique Hotel', NULL, NULL);

INSERT INTO Persona (CF, Nome, Cognome, Telefono, Email, Data_Registrazione, Nazionalita, Codice_Dipendente, Data_Assunzione, Stipendio, Data_Nomina, Bonus_Responsabilita, Hotel) VALUES
-- Clienti
('RSSMRA85A01F205X', 'Maria', 'Rossi', '3331111111', 'maria.rossi@email.it', '2024-01-10', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),
('VRDLGI90B12F839Y', 'Luigi', 'Verdi', '3332222222', 'luigi.verdi@email.it', '2024-02-05', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),
('BNCLRA88C41H501Z', 'Laura', 'Bianchi', '3333333333', 'laura.bianchi@email.it', '2024-03-12', 'Francese', NULL, NULL, NULL, NULL, NULL, NULL),
('FRRGPP91A01F205K', 'Paolo', 'Ferrari', '3341111111', 'paolo.ferrari@email.it', '2024-04-01', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),
('CNTMRC87B14L219M', 'Marco', 'Conti', '3342222222', 'marco.conti@email.it', '2024-04-10', 'Spagnola', NULL, NULL, NULL, NULL, NULL, NULL),
('GLRMTA95C22H501N', 'Marta', 'Galli', '3343333333', 'marta.galli@email.it', '2024-04-18', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),
('SNTLCA89D30F839P', 'Luca', 'Santini', '3344444444', 'luca.santini@email.it', '2024-05-02', 'Tedesca', NULL, NULL, NULL, NULL, NULL, NULL),
('PRDFNC93E11C351Q', 'Francesca', 'Parodi', '3345555555', 'francesca.parodi@email.it', '2024-05-15', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),
('RMNGNN90F25D612R', 'Giovanna', 'Romano', '3346666666', 'giovanna.romano@email.it', '2024-06-01', 'Portoghese', NULL, NULL, NULL, NULL, NULL, NULL),
('BLZSMN96G17A944S', 'Simone', 'Belzoni', '3347777777', 'simone.belzoni@email.it', '2024-06-20', 'Italiana', NULL, NULL, NULL, NULL, NULL, NULL),


-- Dipendenti
('FRNGPP80D15F205A', 'Giuseppe', 'Ferri', '3334444444', 'g.ferri@hotel.it', NULL, NULL, 'D001', '2020-06-01', 1800.00, NULL, NULL, 'H001'),
('MRTNNA92E55F205B', 'Anna', 'Martini', '3335555555', 'a.martini@hotel.it', NULL, NULL, 'D002', '2021-03-15', 1600.00, NULL, NULL, 'H001'),
('RSSLGU85H12F205T', 'Gabriele', 'Rossi', '3351111111', 'g.rossi@hotel.it', NULL, NULL, 'D003', '2019-05-10', 1700.00, NULL, NULL, 'H003'),
('BNCMRA90L22H501U', 'Martina', 'Bianchi', '3352222222', 'm.bianchi@hotel.it', NULL, NULL, 'D004', '2022-01-20', 1550.00, NULL, NULL, 'H004'),
('VRDGNN88C14F839V', 'Giovanni', 'Verdi', '3353333333', 'g.verdi@hotel.it', NULL, NULL, 'D005', '2020-09-15', 1900.00, NULL, NULL, 'H005'),
('NRCFRC91D30L219W', 'Francesca', 'Neri', '3354444444', 'f.neri@hotel.it', NULL, NULL, 'D006', '2023-02-01', 1650.00, NULL, NULL, 'H006'),
('GLRMRC87E11C351X', 'Marco', 'Galli', '3355555555', 'm.galli@hotel.it', NULL, NULL, 'D007', '2018-11-12', 1750.00, NULL, NULL, 'H007'),
('PRDLRA93F25D612Y', 'Laura', 'Parodi', '3356666666', 'l.parodi@hotel.it', NULL, NULL, 'D008', '2021-07-08', 1600.00, NULL, NULL, 'H008'),
('RMNSMN89G17A944Z', 'Simone', 'Romani', '3357777777', 's.romani@hotel.it', NULL, NULL, 'D009', '2017-04-18', 2000.00, NULL, NULL, 'H009'),
('CNTNDR94H09F205K', 'Andrea', 'Conti', '3358888888', 'a.conti@hotel.it', NULL, NULL, 'D010', '2022-10-03', 1580.00, NULL, NULL, 'H010'),
('FRTLNZ84A11F205M', 'Lorenzo', 'Ferri', '3371111111', 'l.ferri@hotel.it', NULL, NULL, 'D011', '2019-02-14', 1750.00, NULL, NULL, 'H003'),
('MRCGPP90B22H501N', 'Giuseppe', 'Marconi', '3372222222', 'g.marconi@hotel.it', NULL, NULL, 'D012', '2021-06-01', 1680.00, NULL, NULL, 'H001'),
('VRDLRA88C10F839P', 'Laura', 'Verdi', '3373333333', 'l.verdi@hotel.it', NULL, NULL, 'D013', '2020-09-19', 1820.00, NULL, NULL, 'H007'),
('CNTMRC92D18L219Q', 'Marco', 'Conti', '3374444444', 'm.conti@hotel.it', NULL, NULL, 'D014', '2023-01-10', 1600.00, NULL, NULL, 'H004'),
('GLNFNC86E25C351R', 'Francesca', 'Gallo', '3375555555', 'f.gallo@hotel.it', NULL, NULL, 'D015', '2018-03-21', 1950.00, NULL, NULL, 'H009'),
('PRDGNN91F14D612S', 'Giovanna', 'Parodi', '3376666666', 'g.parodi@hotel.it', NULL, NULL, 'D016', '2022-11-05', 1580.00, NULL, NULL, 'H002'),
('RSSMTA89G09A944T', 'Marta', 'Rossi', '3377777777', 'm.rossi@hotel.it', NULL, NULL, 'D017', '2020-04-12', 1720.00, NULL, NULL, 'H005'),
('BLNSMN87H30F205U', 'Simone', 'Bellini', '3378888888', 's.bellini@hotel.it', NULL, NULL, 'D018', '2017-08-28', 2100.00, NULL, NULL, 'H001'),
('NRILCU93L15H501V', 'Luca', 'Neri', '3381111111', 'l.neri@hotel.it', NULL, NULL, 'D019', '2021-12-01', 1660.00, NULL, NULL, 'H008'),
('FRRMRA90M21F839W', 'Maria', 'Ferraro', '3382222222', 'm.ferraro@hotel.it', NULL, NULL, 'D020', '2019-05-16', 1800.00, NULL, NULL, 'H006'),
('GLRPLA88N17C351X', 'Paola', 'Galli', '3383333333', 'p.galli@hotel.it', NULL, NULL, 'D021', '2020-07-11', 1740.00, NULL, NULL, 'H003'),
('CNTLRA95P10D612Y', 'Laura', 'Conti', '3384444444', 'l.conti2@hotel.it', NULL, NULL, 'D022', '2023-03-01', 1590.00, NULL, NULL, 'H010'),
('VRDGPP84Q22F205Z', 'Giuseppe', 'Verdi', '3385555555', 'g.verdi2@hotel.it', NULL, NULL, 'D023', '2016-09-14', 2200.00, NULL, NULL, 'H009'),
('PRDMRC91R11L219A', 'Marco', 'Parodi', '3386666666', 'm.parodi@hotel.it', NULL, NULL, 'D024', '2022-02-09', 1630.00, NULL, NULL, 'H004'),
('RSSFNC87S18H501B', 'Francesca', 'Rossi', '3387777777', 'f.rossi@hotel.it', NULL, NULL, 'D025', '2018-10-23', 1850.00, NULL, NULL, 'H007'),
('BLNLRA90T30F839C', 'Laura', 'Bellini', '3388888888', 'l.bellini@hotel.it', NULL, NULL, 'D026', '2021-05-18', 1690.00, NULL, NULL, 'H007'),
('NRCGNN86U25C351D', 'Giovanni', 'Neri', '3391111111', 'g.neri@hotel.it', NULL, NULL, 'D027', '2017-06-07', 2050.00, NULL, NULL, 'H001'),
('FRRSMN92V12D612E', 'Simone', 'Ferrari', '3392222222', 's.ferrari@hotel.it', NULL, NULL, 'D028', '2022-08-30', 1610.00, NULL, NULL, 'H006'),
('MRTLCA89W09A944F', 'Luca', 'Martini', '3393333333', 'l.martini@hotel.it', NULL, NULL, 'D029', '2019-11-19', 1780.00, NULL, NULL, 'H002'),
('GLRMRA93X14F205G', 'Maria', 'Galli', '3394444444', 'm.galli@hotel.it', NULL, NULL, 'D030', '2023-04-22', 1570.00, NULL, NULL, 'H008'),

-- Direttori
('BLNLNZ75F10F205C', 'Lorenzo', 'Bellini', '3336666666', 'l.bellini@hotel.it', NULL, NULL, 'DIR001', '2018-01-10', 3500.00, '2020-01-01', 800.00, 'H001'),
('RCCFNC70G20F205D', 'Franco', 'Ricci', '3337777777', 'f.ricci@hotel.it', NULL, NULL, 'DIR002', '2017-09-01', 3200.00, '2019-05-01', 700.00, 'H002'),
('MNCLRA78H15H294E', 'Claudio', 'Mancini', '3338888888', 'c.mancini@hotel.it', NULL, NULL, 'DIR003', '2019-04-10', 3300.00, '2021-02-01', 750.00, 'H003'),
('FRRGNN82L22C372F', 'Giovanni', 'Ferraro', '3339999999', 'g.ferraro@hotel.it', NULL, NULL, 'DIR004', '2020-07-15', 3400.00, '2022-01-10', 780.00, 'H004'),
('VRDLCA76A12F205G', 'Carlo', 'Verdi', '3361111111', 'c.verdi@hotel.it', NULL, NULL, 'DIR005', '2016-03-15', 3600.00, '2018-06-01', 850.00, 'H005'),
('NRIMRA74B20L219H', 'Maria', 'Neri', '3362222222', 'm.neri@hotel.it', NULL, NULL, 'DIR006', '2015-09-10', 3100.00, '2019-03-20', 720.00, 'H006'),
('GLNFNC79C11H501I', 'Francesco', 'Gallo', '3363333333', 'f.gallo@hotel.it', NULL, NULL, 'DIR007', '2017-01-08', 3450.00, '2020-05-15', 790.00, 'H007'),
('RSSNDR81D25F839J', 'Andrea', 'Rossi', '3364444444', 'a.rossi@hotel.it', NULL, NULL, 'DIR008', '2018-11-30', 3250.00, '2021-09-01', 760.00, 'H008'),
('CNTLRA77E14C351K', 'Laura', 'Conti', '3365555555', 'l.conti@hotel.it', NULL, NULL, 'DIR009', '2014-06-18', 3700.00, '2017-12-10', 900.00, 'H009'),
('PRDGNN80F09D612L', 'Giovanna', 'Parodi', '3366666666', 'g.parodi@hotel.it', NULL, NULL, 'DIR010', '2019-02-25', 3150.00, '2022-04-05', 740.00, 'H010');

-- Assegnazione direttori agli hotel
UPDATE Hotel
SET Direttore = CASE Codice
    WHEN 'H001' THEN 'BLNLNZ75F10F205C'
    WHEN 'H002' THEN 'RCCFNC70G20F205D'
    WHEN 'H003' THEN 'MNCLRA78H15H294E'
    WHEN 'H004' THEN 'FRRGNN82L22C372F'
    WHEN 'H005' THEN 'VRDLCA76A12F205G'
    WHEN 'H006' THEN 'NRIMRA74B20L219H'
    WHEN 'H007' THEN 'GLNFNC79C11H501I'
    WHEN 'H008' THEN 'RSSNDR81D25F839J'
    WHEN 'H009' THEN 'CNTLRA77E14C351K'
    WHEN 'H010' THEN 'PRDGNN80F09D612L'
END
WHERE Codice IN ('H001', 'H002', 'H003', 'H004', 'H005', 'H006', 'H007', 'H008', 'H009', 'H010');

INSERT INTO Camera (Hotel, Numero, Tipo, Prezzo, Stato) VALUES 
('H001', 101, 'Singola', 120.00, 'Libera'),
('H001', 102, 'Doppia', 180.00, 'Occupata'),
('H001', 201, 'Suite', 350.00, 'Libera'),
('H002', 101, 'Singola', 90.00, 'Libera'),
('H002', 102, 'Doppia', 140.00, 'Manutenzione'),
('H003', 101, 'Matrimoniale', 160.00, 'Libera'),
('H003', 201, 'Suite', 300.00, 'Occupata'),
('H004', 101, 'Suite', 400.00, 'Libera'),
('H005', 101, 'Singola', 130.00, 'Libera'),
('H005', 102, 'Doppia', 210.00, 'Occupata'),
('H005', 201, 'Suite', 420.00, 'Libera'),
('H006', 101, 'Singola', 95.00, 'Libera'),
('H006', 102, 'Matrimoniale', 170.00, 'Occupata'),
('H006', 201, 'Suite', 310.00, 'Manutenzione'),
('H007', 101, 'Doppia', 190.00, 'Libera'),
('H007', 201, 'Suite', 380.00, 'Occupata'),
('H007', 301, 'Familiare', 450.00, 'Libera'),
('H008', 101, 'Singola', 100.00, 'Libera'),
('H008', 102, 'Doppia', 160.00, 'Occupata'),
('H008', 201, 'Suite', 340.00, 'Libera'),
('H009', 101, 'Matrimoniale', 220.00, 'Libera'),
('H009', 201, 'Suite', 500.00, 'Occupata'),
('H009', 301, 'Familiare', 850.00, 'Libera'),
('H010', 101, 'Singola', 80.00, 'Libera'),
('H010', 102, 'Doppia', 140.00, 'Manutenzione'),
('H010', 201, 'Familiare', 260.00, 'Occupata');

INSERT INTO Servizio (Codice_Servizio, Nome, Descrizione, Costo_Aggiuntivo) VALUES
('S001', 'Wi-Fi', 'Connessione internet ad alta velocita', NULL),
('S002', 'Colazione', 'Colazione a buffet', 15.00),
('S003', 'Parcheggio', 'Posto auto riservato', 10.00),
('S004', 'Piscina', 'Accesso alla piscina dell’hotel', 20.00),
('S005', 'Servizio in Camera', 'Consegna pasti e bevande in camera', 25.00);

INSERT INTO Offerta (Hotel, Servizio) VALUES
('H001', 'S001'),
('H001', 'S002'),
('H001', 'S004'),
('H001', 'S005'),
('H002', 'S001'),
('H002', 'S002'),
('H002', 'S003'),
('H003', 'S001'),
('H003', 'S004'),
('H003', 'S005'),
('H004', 'S001'),
('H004', 'S002'),
('H004', 'S003'),
('H004', 'S004'),
('H005', 'S001'),
('H005', 'S002'),
('H005', 'S004'),
('H005', 'S005'),
('H006', 'S001'),
('H006', 'S002'),
('H006', 'S003'),
('H007', 'S001'),
('H007', 'S004'),
('H008', 'S005'),
('H008', 'S001'),
('H008', 'S002'),
('H008', 'S003'),
('H008', 'S004'),
('H009', 'S001'),
('H009', 'S002'),
('H009', 'S004'),
('H009', 'S005'),
('H010', 'S001'),
('H009', 'S003');

INSERT INTO Prenotazione (Codice_Prenotazione, Hotel, Camera, Data_Prenotazione, Check_In, Check_Out, N_Ospiti, Stato, Cliente) VALUES
('P001', 'H001', 102, '2025-05-01', '2025-05-10', '2025-05-15', 2, 'Conclusa', 'RSSMRA85A01F205X'),
('P002', 'H006', 101, '2025-05-03', '2025-06-01', '2025-06-05', 1, 'Confermata', 'VRDLGI90B12F839Y'),
('P003', 'H003', 201, '2025-05-04', '2025-05-20', '2025-05-25', 2, 'In_Corso', 'BNCLRA88C41H501Z'),
('P004', 'H009', 101, '2025-05-05', '2025-06-10', '2025-06-15', 2, 'Confermata', 'FRRGPP91A01F205K'),
('P005', 'H005', 102, '2025-05-06', '2025-06-12', '2025-06-18', 2, 'In_Corso', 'CNTMRC87B14L219M'),
('P006', 'H002', 101, '2025-05-07', '2025-06-20', '2025-06-22', 1, 'Conclusa', 'GLRMTA95C22H501N'),
('P007', 'H007', 201, '2025-05-08', '2025-07-01', '2025-07-07', 3, 'Confermata', 'SNTLCA89D30F839P'),
('P008', 'H004', 101, '2025-05-09', '2025-06-25', '2025-06-30', 2, 'Annullata', 'PRDFNC93E11C351Q'),
('P009', 'H001', 201, '2025-05-10', '2025-07-10', '2025-07-15', 2, 'Confermata', 'RMNGNN90F25D612R'),
('P010', 'H010', 201, '2025-05-11', '2025-06-05', '2025-06-09', 4, 'In_Corso', 'BLZSMN96G17A944S'),
('P011', 'H008', 101, '2025-05-12', '2025-07-20', '2025-07-23', 1, 'Confermata', 'RSSMRA85A01F205X'),
('P012', 'H005', 201, '2025-05-13', '2025-08-01', '2025-08-05', 2, 'Conclusa', 'VRDLGI90B12F839Y'),
('P013', 'H003', 101, '2025-05-14', '2025-06-14', '2025-06-18', 2, 'Confermata', 'BNCLRA88C41H501Z'),
('P014', 'H007', 101, '2025-05-15', '2025-07-05', '2025-07-12', 2, 'In_Corso', 'FRRGPP91A01F205K'),
('P015', 'H009', 301, '2025-05-16', '2025-08-10', '2025-08-15', 3, 'Confermata', 'CNTMRC87B14L219M'),
('P016', 'H006', 102, '2025-05-17', '2025-06-28', '2025-07-02', 2, 'Conclusa', 'GLRMTA95C22H501N'),
('P017', 'H001', 101, '2025-05-18', '2025-07-18', '2025-07-25', 1, 'Confermata', 'SNTLCA89D30F839P'),
('P018', 'H008', 201, '2025-05-19', '2025-06-16', '2025-06-20', 2, 'In_Corso', 'PRDFNC93E11C351Q'),
('P019', 'H008', 101, '2025-05-20', '2025-08-20', '2025-08-28', 2, 'Confermata', 'RMNGNN90F25D612R'),
('P020', 'H001', 201, '2025-05-21', '2025-06-11', '2025-06-13', 1, 'Conclusa', 'BLZSMN96G17A944S');

INSERT INTO Pagamento (Codice_Pagamento, Data_Pagamento, Importo, Metodo, Stato, Prenotazione) VALUES
('PAY001', '2025-05-01', 900.00, 'Carta', 'Effettuato', 'P001'),
('PAY002', '2025-05-03', 360.00, 'Bonifico', 'In_Attesa', 'P002'),
('PAY003', '2025-05-04', 1500.00, 'Carta', 'Effettuato', 'P003'),
('PAY004', '2025-05-05', 2800.00, 'Carta', 'Effettuato', 'P004'),
('PAY005', '2025-05-06', 1260.00, 'Bonifico', 'Effettuato', 'P005'),
('PAY006', '2025-05-07', 190.00, 'Contanti', 'Effettuato', 'P006'),
('PAY007', '2025-05-08', 2280.00, 'Carta', 'Effettuato', 'P007'),
('PAY008', '2025-05-09', 800.00, 'Carta', 'Effettuato', 'P008'),
('PAY009', '2025-05-10', 2500.00, 'Bonifico', 'Effettuato', 'P009'),
('PAY010', '2025-05-11', 1040.00, 'Carta', 'Effettuato', 'P010'),
('PAY011', '2025-05-12', 360.00, 'Contanti', 'Effettuato', 'P011'),
('PAY012', '2025-05-13', 560.00, 'Carta', 'Effettuato', 'P012'),
('PAY013', '2025-05-14', 640.00, 'Bonifico', 'In_Attesa', 'P013'),
('PAY014', '2025-05-15', 2800.00, 'Carta', 'Effettuato', 'P014'),
('PAY015', '2025-05-16', 2100.00, 'Bonifico', 'In_Attesa', 'P015'),
('PAY016', '2025-05-17', 680.00, 'Contanti', 'Effettuato', 'P016'),
('PAY017', '2025-05-18', 3150.00, 'Carta', 'Effettuato', 'P017'),
('PAY018', '2025-05-19', 1360.00, 'Bonifico', 'In_Attesa', 'P018'),
('PAY019', '2025-05-20', 6800.00, 'Carta', 'Effettuato', 'P019'),
('PAY020', '2025-05-21', 160.00, 'Contanti', 'Effettuato', 'P020');


-- =========================================
-- QUERY
-- =========================================

-- Numero di prenotazioni per hotel 
SELECT h.Nome, COUNT(p.Codice_Prenotazione) AS Totale_Prenotazioni
FROM Hotel h
JOIN Prenotazione p ON h.Codice = p.Hotel
GROUP BY h.Codice, h.Nome
ORDER BY Totale_Prenotazioni DESC;

-- Incasso totale per hotel
SELECT h.Nome, SUM(pa.Importo) AS Incasso_Totale
FROM Hotel h
JOIN Prenotazione pr ON h.Codice = pr.Hotel
JOIN Pagamento pa ON pr.Codice_Prenotazione = pa.Prenotazione
WHERE pa.Stato = 'Effettuato'
  AND pr.Stato IN ('Confermata', 'In_Corso', 'Conclusa')
GROUP BY h.Codice, h.Nome
ORDER BY Incasso_Totale DESC;

-- Numero medio di ospiti per prenotazione per hotel
SELECT h.Nome, AVG(pr.N_Ospiti) AS Media_Ospiti
FROM Hotel h
JOIN Prenotazione pr ON h.Codice = pr.Hotel
GROUP BY h.Codice, h.Nome
ORDER BY Media_Ospiti DESC;

-- Hotel con più di 3 servizi offerti
SELECT h.Nome, COUNT(o.Servizio) AS Numero_Servizi
FROM Hotel h
JOIN Offerta o ON h.Codice = o.Hotel
GROUP BY h.Codice, h.Nome
HAVING COUNT(o.Servizio) > 3
ORDER BY Numero_Servizi DESC;

-- Numero di dipendenti per hotel
SELECT h.Nome, COUNT(p.CF) AS Numero_Dipendenti
FROM Hotel h
JOIN Persona p ON h.Codice = p.Hotel
WHERE p.Codice_Dipendente IS NOT NULL
GROUP BY h.Codice, h.Nome
ORDER BY Numero_Dipendenti DESC;

-- Camere libere con prezzo massimo scelto dall'utente
SELECT h.Nome AS Hotel, c.Numero, c.Tipo, c.Prezzo, c.Stato
FROM Hotel h
JOIN Camera c ON h.Codice = c.Hotel
WHERE c.Stato = 'Libera'
  AND c.Prezzo <= 150
ORDER BY c.Prezzo ASC;

-- =========================================
-- INDICI
-- =========================================

CREATE INDEX idx_pagamento_stato_prenotazione ON Pagamento (Stato, Prenotazione);
CREATE INDEX idx_prenotazione_hotel ON Prenotazione (Hotel);