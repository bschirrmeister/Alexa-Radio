/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Exportiere Struktur von Tabelle ActualPlaying
DROP TABLE IF EXISTS `ActualPlaying`;
CREATE TABLE IF NOT EXISTS `ActualPlaying` (
  `AP_DV_id` varchar(250) NOT NULL,
  `AP_TK_id` int(10) unsigned NOT NULL,
  `AP_Sort` int(10) unsigned NOT NULL DEFAULT '0',
  `AP_Playcount` int(10) NOT NULL DEFAULT '0',
  `AP_LastSelected` timestamp NULL DEFAULT NULL,
  `AP_LastPlayed` timestamp NULL DEFAULT NULL,
  `AP_Pos` int(10) NOT NULL DEFAULT '0',
  PRIMARY KEY (`AP_DV_id`,`AP_TK_id`),
  KEY `FK_ActualPlaying_TracK` (`AP_TK_id`),
  CONSTRAINT `FK_ActualPlaying_DeVice` FOREIGN KEY (`AP_DV_id`) REFERENCES `DeVice` (`DV_id`),
  CONSTRAINT `FK_ActualPlaying_TracK` FOREIGN KEY (`AP_TK_id`) REFERENCES `TracK` (`TK_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Exportiere Struktur von Tabelle PlaylisT
DROP TABLE IF EXISTS `PlaylisT`;
CREATE TABLE IF NOT EXISTS `PlaylisT` (
  `PT_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `PT_Name` varchar(200) NOT NULL DEFAULT '0',
  PRIMARY KEY (`PT_id`),
  UNIQUE KEY `AM_Name` (`PT_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


-- Exportiere Struktur von Tabelle PlaylistitemS
DROP TABLE IF EXISTS `PlaylistitemS`;
CREATE TABLE IF NOT EXISTS `PlaylistitemS` (
  `PS_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `PS_PT_id` int(10) NOT NULL DEFAULT '0',
  `PS_TK_FileName` varchar(200) NOT NULL DEFAULT '0',
  
  PRIMARY KEY (`PS_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


-- Exportiere Struktur von Tabelle AlbuM
DROP TABLE IF EXISTS `AlbuM`;
CREATE TABLE IF NOT EXISTS `AlbuM` (
  `AM_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `AM_Name` varchar(200) NOT NULL DEFAULT '0',
  `AM_Index` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`AM_id`),
  UNIQUE KEY `AM_Name` (`AM_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Exportiere Struktur von Tabelle ArtisT
DROP TABLE IF EXISTS `ArtisT`;
CREATE TABLE IF NOT EXISTS `ArtisT` (
  `AT_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `AT_Name` varchar(200) NOT NULL DEFAULT '0',
  PRIMARY KEY (`AT_id`),
  UNIQUE KEY `AT_Name` (`AT_Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Exportiere Struktur von Tabelle DeVice
DROP TABLE IF EXISTS `DeVice`;
CREATE TABLE IF NOT EXISTS `DeVice` (
  `DV_id` varchar(250) NOT NULL,
  `DV_Alias` varchar(500) DEFAULT NULL,
  `DV_LastTKid` int(11) unsigned DEFAULT NULL,
  `DV_Shuffle` tinyint(1) NOT NULL DEFAULT '0',
  `DV_Loop` TINYINT(1) NOT NULL DEFAULT '1',
  `DV_LastActive` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`DV_id`),
  KEY `FK_DeVice_TracK` (`DV_LastTKid`),
  CONSTRAINT `FK_DeVice_TracK` FOREIGN KEY (`DV_LastTKid`) REFERENCES `TracK` (`TK_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Exportiere Struktur von Funktion fnAddAlbum
DROP FUNCTION IF EXISTS `fnAddAlbum`;
DELIMITER //
CREATE FUNCTION `fnAddAlbum`(
	`Name` VARCHAR(500),
	`AMIndex` INT
) RETURNS int(11)
    MODIFIES SQL DATA
BEGIN
	DECLARE AMid INT;
	SET AMid = -1;
	
	SELECT AM_id INTO AMid FROM AlbuM WHERE AM_Name = Name;
	
	IF AMid = -1 THEN
		INSERT IGNORE INTO AlbuM (AM_Name, AM_Index) VALUES (Name, AMIndex);
		SELECT AM_id INTO AMid FROM AlbuM WHERE AM_Name = Name;
	END IF;

	RETURN AMid;
END//
DELIMITER ;

-- Exportiere Struktur von Funktion fnAddArtist
DROP FUNCTION IF EXISTS `fnAddArtist`;
DELIMITER //
CREATE FUNCTION `fnAddArtist`(
	`Name` VARCHAR(500)
) RETURNS int(11)
    MODIFIES SQL DATA
BEGIN
	DECLARE ATid INT;
	SET ATid = -1;

	SELECT AT_id INTO ATid FROM ArtisT WHERE AT_Name = Name;
	
	IF ATid = -1 THEN
		INSERT IGNORE INTO ArtisT (AT_Name) VALUES (Name);
		SELECT AT_id INTO ATid FROM ArtisT WHERE AT_Name = Name;
	END IF;

	RETURN ATid;
END//
DELIMITER ;

-- Exportiere Struktur von Funktion fnGetNextTrackFilename
DROP FUNCTION IF EXISTS `fnGetNextTrackFilename`;
DELIMITER //
CREATE FUNCTION `fnGetNextTrackFilename`(
	`deviceid` VARCHAR(250)
) RETURNS varchar(2000) CHARSET utf8
    MODIFIES SQL DATA
BEGIN
	DECLARE TKid INT DEFAULT NULL;
	DECLARE PlayCount INT DEFAULT NULL;
	DECLARE back VARCHAR(2000) CHARSET utf8 DEFAULT NULL;
	SELECT TK_id, AP_Playcount, TK_FileName INTO TKid, PlayCount, back FROM ActualPlaying INNER JOIN TracK ON AP_TK_id = TK_id WHERE AP_DV_id = deviceid ORDER BY AP_Playcount, AP_Sort, AP_TK_id LIMIT 1;
	IF TKid IS NOT NULL THEN
	BEGIN
		UPDATE ActualPlaying SET AP_Playcount =  PlayCount + 1 WHERE AP_DV_id = deviceid AND AP_TK_id = TKid;
		UPDATE DeVice SET DV_LastTKid = TKid WHERE DV_id = deviceid;
		RETURN back;
	END;
	ELSE
	BEGIN
		RETURN '';
	END;
	END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Funktion fnGetRandomTrackFilename
DROP FUNCTION IF EXISTS `fnGetRandomTrackFilename`;
DELIMITER //
CREATE FUNCTION `fnGetRandomTrackFilename`(
	`deviceid` VARCHAR(250)
) RETURNS varchar(2000) CHARSET utf8
    MODIFIES SQL DATA
BEGIN
	DECLARE MinPC INT DEFAULT NULL;
	DECLARE TKid INT DEFAULT NULL;
	DECLARE PlayCount INT DEFAULT NULL;
	DECLARE back VARCHAR(2000) CHARSET utf8 DEFAULT NULL;
	SELECT MIN(AP_Playcount) INTO MinPC FROM ActualPlaying WHERE AP_DV_id = deviceid;
	SELECT TK_id, AP_Playcount, TK_FileName INTO TKid, PlayCount, back FROM ActualPlaying INNER JOIN TracK ON AP_TK_id = TK_id WHERE AP_Playcount = MinPC AND AP_DV_id = deviceid ORDER BY RAND() LIMIT 1;
	IF TKid IS NOT NULL THEN
	BEGIN
		UPDATE ActualPlaying SET AP_Playcount =  PlayCount + 1 WHERE AP_DV_id = deviceid AND AP_TK_id = TKid;
		UPDATE DeVice SET DV_LastTKid = TKid WHERE DV_id = deviceid;
		RETURN back;
	END;
	ELSE
	BEGIN
		RETURN '';
	END;
	END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Funktion radiogo.fnGetNextTrackId
DROP FUNCTION IF EXISTS `fnGetNextTrackId`;
DELIMITER //
CREATE FUNCTION `fnGetNextTrackId`(
    `deviceid` VARCHAR(250),
    `isRandom` INT,
    `currentTrackId` INT(10)

) RETURNS int(11)
BEGIN
    DECLARE TKid INT DEFAULT NULL;
    DECLARE PlayCount INT DEFAULT NULL;
    DECLARE MyPos INT DEFAULT NULL;
    DECLARE NextPos INT DEFAULT NULL;
    DECLARE NextSort INT DEFAULT NULL;
    SELECT AP_Pos INTO MyPos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId;
    SELECT AP_Pos INTO NextPos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_Pos = (SELECT AP_Pos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId)+1;
    SELECT AP_Sort INTO NextSort FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_Sort = (SELECT AP_Sort FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId)+1;
    IF (NextPos > MyPos) THEN
        SELECT AP_TK_id INTO TKid FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_Pos = (SELECT AP_Pos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId)+1;
    ELSEIF (isRandom = 0) THEN
    	IF (NextSort > MyPos) THEN
        	SELECT AP_TK_id INTO TKid FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_Sort = (SELECT AP_Pos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId)+1;
	ELSE
        	SELECT TK_id, AP_Playcount INTO TKid, PlayCount FROM ActualPlaying INNER JOIN TracK ON AP_TK_id = TK_id WHERE AP_DV_id = deviceid ORDER BY AP_Playcount, AP_Sort, AP_TK_id LIMIT 1;
        END IF;
    ELSE
    BEGIN	
        DECLARE MinPC INT DEFAULT NULL;
        SELECT MIN(AP_Playcount) INTO MinPC FROM ActualPlaying WHERE AP_DV_id = deviceid;
        SELECT TK_id, AP_Playcount INTO TKid, PlayCount FROM ActualPlaying INNER JOIN TracK ON AP_TK_id = TK_id WHERE AP_Playcount = MinPC AND AP_DV_id = deviceid ORDER BY RAND() LIMIT 1;
    END;
    END IF;

    IF TKid IS NOT NULL THEN
        RETURN TKid;
    ELSE
        RETURN -1;
    END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Funktion radiogo.fnGetPrevTrackID
DROP FUNCTION IF EXISTS `fnGetPrevTrackID`;
DELIMITER //
CREATE FUNCTION `fnGetPrevTrackID`(
	`deviceid` VARCHAR(250),
	`currentTrackId` INT(10)

) RETURNS int(11)
BEGIN
	DECLARE TKid INT DEFAULT NULL;
	SELECT AP_TK_id INTO TKid FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_Pos < (SELECT AP_Pos FROM ActualPlaying WHERE AP_DV_id = deviceid AND AP_TK_id = currentTrackId) order by AP_Pos DESC limit 1;
	
    IF TKid IS NOT NULL THEN
        RETURN TKid;
    ELSE
        RETURN -1;
    END IF;
END//
DELIMITER ;


-- Exportiere Struktur von Prozedur radiogo.spMarkTackPlayed
DROP PROCEDURE IF EXISTS `spMarkTrackPlayed`;
DELIMITER //
CREATE PROCEDURE `spMarkTrackPlayed`(
	IN `deviceid` VARCHAR(250),
	IN `TKid` INT

)
BEGIN
	UPDATE ActualPlaying SET AP_Playcount =  AP_Playcount + 1, AP_LastPlayed = CURRENT_TIMESTAMP WHERE AP_DV_id = deviceid AND AP_TK_id = TKid;
	UPDATE DeVice SET DV_LastTKid = TKid WHERE DV_id = deviceid;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur radiogo.spMarkTackSelected
DROP PROCEDURE IF EXISTS `spMarkTrackSelected`;
DELIMITER //
CREATE PROCEDURE `spMarkTrackSelected`(
	IN `deviceid` VARCHAR(250),
	IN `TKid` INT

)
BEGIN
	UPDATE ActualPlaying SET AP_LastSelected = CURRENT_TIMESTAMP, AP_Pos=if(AP_Pos=0,(SELECT AP_Pos+1 FROM ActualPlaying WHERE AP_DV_id = deviceid ORDER BY AP_Pos DESC LIMIT 1),AP_Pos) WHERE AP_DV_id = deviceid AND AP_TK_id = TKid;
	UPDATE DeVice SET DV_LastTKid = TKid WHERE DV_id = deviceid;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spDeleteTrack
DROP PROCEDURE IF EXISTS `spDeleteTrack`;
DELIMITER //
CREATE PROCEDURE `spDeleteTrack`(
	IN `TKid` INT
)
    MODIFIES SQL DATA
BEGIN
	DELETE FROM ActualPlaying WHERE AP_TK_id = TKid;
	UPDATE DeVice SET DV_LastTKid = NULL WHERE DV_LastTKid = TKid;
	DELETE FROM TracK WHERE TK_id = TKid;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlaying
DROP PROCEDURE IF EXISTS `spUpdateActualPlaying`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlaying`(
	IN `deviceid` VARCHAR(250),
	IN `search` VARCHAR(500)
)
    READS SQL DATA
BEGIN
	IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
	BEGIN
		SET @LikeSearch = CONCAT('%', search, '%');
		DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;
		
		DROP TABLE IF EXISTS tmppl;
		CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));
		
		INSERT INTO tmppl
	 	SELECT null, TracK.TK_id 
		FROM TracK 
		LEFT JOIN ArtisT ON TK_AT_id = AT_id 
		LEFT JOIN AlbuM ON TK_AM_id = AM_id 
		WHERE TK_Name LIKE @LikeSearch OR TK_Comment LIKE @LikeSearch OR AT_Name LIKE @LikeSearch OR AM_Name LIKE @LikeSearch
		ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;
		
		IF !(SELECT EXISTS (SELECT 1 FROM tmppl)) THEN
		BEGIN
			INSERT INTO tmppl
		 	SELECT null, TracK.TK_id 
			FROM TracK 
			LEFT JOIN ArtisT ON TK_AT_id = AT_id 
			LEFT JOIN AlbuM ON TK_AM_id = AM_id 
			WHERE (TK_Name SOUNDS LIKE search OR TK_Comment SOUNDS LIKE search OR AT_Name SOUNDS LIKE search OR AM_Name SOUNDS LIKE search)
			ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;
		END;
		END IF;
		
		INSERT INTO ActualPlaying
        SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
	END;
	END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlaying
DROP PROCEDURE IF EXISTS `spUpdateActualPlayingMusic`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlayingMusic`(
        IN `deviceid` VARCHAR(250)
)
    READS SQL DATA
BEGIN
        IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
        BEGIN
                DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;

                DROP TABLE IF EXISTS tmppl;
                CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));

                INSERT INTO tmppl
                SELECT null, TracK.TK_id
                FROM TracK
                LEFT JOIN ArtisT ON TK_AT_id = AT_id
                LEFT JOIN AlbuM ON TK_AM_id = AM_id
                WHERE TK_FileName LIKE "//musik%"
                ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;

                INSERT INTO ActualPlaying
       			SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
        END;
        END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlayingAlbumOrTitle
DROP PROCEDURE IF EXISTS `spUpdateActualPlayingAlbumOrTitle`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlayingAlbumOrTitle`(
        IN `deviceid` VARCHAR(250),
        IN `searchAlbumOrTitle` VARCHAR(500),
        IN `searchArtist` VARCHAR(500)
)
    READS SQL DATA
BEGIN
	IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
	BEGIN
		SET @LikeAlbumOrTitle = CONCAT('%', searchAlbumOrTitle, '%');
		SET @LikeArtist = CONCAT('%', searchArtist, '%');
		DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;

		DROP TABLE IF EXISTS tmppl;
		CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));

		INSERT INTO tmppl
		SELECT null, TracK.TK_id
		FROM TracK
		LEFT JOIN ArtisT ON TK_AT_id = AT_id
		LEFT JOIN AlbuM ON TK_AM_id = AM_id
		WHERE AT_Name LIKE @LikeArtist AND (TK_Name LIKE @LikeAlbumOrTitle OR TK_Comment LIKE @LikeAlbumOrTitle OR AM_Name LIKE @LikeAlbumOrTitle)
		ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;

		IF !(SELECT EXISTS (SELECT 1 FROM tmppl)) THEN
		BEGIN
			INSERT INTO tmppl
			SELECT null, TracK.TK_id
			FROM TracK
			LEFT JOIN ArtisT ON TK_AT_id = AT_id
			LEFT JOIN AlbuM ON TK_AM_id = AM_id
			WHERE AT_Name SOUNDS LIKE searchArtist AND (TK_Name SOUNDS LIKE searchAlbumOrTitle OR TK_Comment SOUNDS LIKE searchAlbumOrTitle OR AM_Name SOUNDS LIKE searchAlbumOrTitle)
			ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;
		END;
		END IF;

		INSERT INTO ActualPlaying
        SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
	END;
	END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlaying
DROP PROCEDURE IF EXISTS `spUpdateActualPlayingMusic`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlayingMusic`(
        IN `deviceid` VARCHAR(250)
)
    READS SQL DATA
BEGIN
        IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
        BEGIN
                DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;

                DROP TABLE IF EXISTS tmppl;
                CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));

                INSERT INTO tmppl
                SELECT null, TracK.TK_id
                FROM TracK
                LEFT JOIN ArtisT ON TK_AT_id = AT_id
                LEFT JOIN AlbuM ON TK_AM_id = AM_id
                WHERE TK_FileName LIKE "//musik%" 
                ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;

                INSERT INTO ActualPlaying
        		SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
        END;
        END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlayList
DROP PROCEDURE IF EXISTS `spUpdateActualPlayList`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlayList`(
        IN `deviceid` VARCHAR(250),
        IN `SearchString` VARCHAR(500)
)
    READS SQL DATA
BEGIN
	IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
	BEGIN
		SET @PlayList = CONCAT('%', SearchString, '%');
		DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;

		DROP TABLE IF EXISTS tmppl;
		CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));

		INSERT INTO tmppl
		SELECT null, TracK.TK_id
		FROM PlaylistitemS
		LEFT JOIN PlaylisT on PT_id = PS_PT_id
		LEFT JOIN TracK ON PS_TK_FileName = TK_FileName
		LEFT JOIN ArtisT ON TK_AT_id = AT_id
		LEFT JOIN AlbuM ON TK_AM_id = AM_id
		WHERE PT_Name SOUNDS LIKE @PlayList;

		INSERT INTO ActualPlaying
        SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
	END;
	END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur spUpdateActualPlayingEpisode
DROP PROCEDURE IF EXISTS `spUpdateActualPlayingEpisode`;
DELIMITER //
CREATE PROCEDURE `spUpdateActualPlayingEpisode`(
        IN `deviceid` VARCHAR(250),
        IN `searchEpisode` VARCHAR(500),
        IN `searchArtist` VARCHAR(500)
)
    READS SQL DATA
BEGIN
        IF (SELECT 1 = 1 FROM DeVice WHERE DV_id = deviceid) THEN
        BEGIN
                SET @LikeEpisode = CONCAT('%', searchEpisode, '%');
                SET @LikeArtist = CONCAT('%', searchArtist, '%');
                DELETE FROM ActualPlaying WHERE AP_DV_id = deviceid;

                DROP TABLE IF EXISTS tmppl;
                CREATE TEMPORARY TABLE tmppl (`tmp_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, `tmp_TKid` INT(10) UNSIGNED NOT NULL, PRIMARY KEY (`tmp_id`));

                INSERT INTO tmppl
                SELECT null, TracK.TK_id
                FROM TracK
                LEFT JOIN ArtisT ON TK_AT_id = AT_id
                LEFT JOIN AlbuM ON TK_AM_id = AM_id
                WHERE REPLACE(AT_Name," ","") LIKE REPLACE(@LikeArtist," ","") AND AM_Name LIKE @LikeEpisode  AND TK_FileName LIKE "//audiobooks%"

                ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;

                IF !(SELECT EXISTS (SELECT 1 FROM tmppl)) THEN
                BEGIN
                        INSERT INTO tmppl
                        SELECT null, TracK.TK_id
                        FROM TracK
                        LEFT JOIN ArtisT ON TK_AT_id = AT_id
                        LEFT JOIN AlbuM ON TK_AM_id = AM_id
                        WHERE AT_Name SOUNDS LIKE searchArtist AND AM_Name SOUNDS LIKE LikeEpisode AND TK_FileName LIKE "//audiobooks%"
                        ORDER BY AT_id, AM_Index, AM_id, TK_Index, TK_id;
                END;
                END IF;

                INSERT INTO ActualPlaying
        SELECT deviceid, tmppl.tmp_TKid, tmppl.tmp_id, 0, NULL, NULL, 0 FROM tmppl;
        END;
        END IF;
END//
DELIMITER ;


-- Exportiere Struktur von Tabelle TracK
DROP TABLE IF EXISTS `TracK`;
CREATE TABLE IF NOT EXISTS `TracK` (
  `TK_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `TK_AT_id` int(10) unsigned NOT NULL,
  `TK_AM_id` int(10) unsigned NOT NULL,
  `TK_Index` int(10) unsigned NOT NULL DEFAULT '0',
  `TK_Name` varchar(200) NOT NULL,
  `TK_Comment` varchar(2000) NOT NULL DEFAULT '',
  `TK_FileName` varchar(2000) NOT NULL,
  `TK_LastSeen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`TK_id`),
  KEY `Artist` (`TK_AT_id`),
  KEY `Album` (`TK_AM_id`),
  KEY `TK_FileName` (`TK_FileName`(255)),
  CONSTRAINT `Album` FOREIGN KEY (`TK_AM_id`) REFERENCES `AlbuM` (`AM_id`),
  CONSTRAINT `Artist` FOREIGN KEY (`TK_AT_id`) REFERENCES `ArtisT` (`AT_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Exportiere Struktur von View vActualPlaylists
DROP VIEW IF EXISTS `vActualPlaylists`;
-- Erstelle temporäre Tabelle um View Abhängigkeiten zuvorzukommen
CREATE TABLE `vActualPlaylists` (
	`Device` VARCHAR(500) NOT NULL COLLATE 'utf8_general_ci',
	`Artist` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci',
	`Album` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci',
	`Track` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci',
	`Playcount` INT(10) NOT NULL
) ENGINE=MyISAM;

-- Exportiere Struktur von View vTrackInfo
DROP VIEW IF EXISTS `vTrackInfo`;
-- Erstelle temporäre Tabelle um View Abhängigkeiten zuvorzukommen
CREATE TABLE `vTrackInfo` (
	`TK_id` INT(10) UNSIGNED NOT NULL,
	`AT_Name` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci',
	`AM_Name` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci',
	`TK_Name` VARCHAR(200) NOT NULL COLLATE 'utf8_general_ci'
) ENGINE=MyISAM;

-- Exportiere Struktur von View vActualPlaylists
DROP VIEW IF EXISTS `vActualPlaylists`;
-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `vActualPlaylists`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `vActualPlaylists` AS select ifnull(`DeVice`.`DV_Alias`,`DeVice`.`DV_id`) AS `Device`,`ArtisT`.`AT_Name` AS `Artist`,`AlbuM`.`AM_Name` AS `Album`,`TracK`.`TK_Name` AS `Track`,`ActualPlaying`.`AP_Playcount` AS `Playcount` from ((((`ActualPlaying` join `DeVice` on((`ActualPlaying`.`AP_DV_id` = `DeVice`.`DV_id`))) join `TracK` on((`ActualPlaying`.`AP_TK_id` = `TracK`.`TK_id`))) join `AlbuM` on((`TracK`.`TK_AM_id` = `AlbuM`.`AM_id`))) join `ArtisT` on((`TracK`.`TK_AT_id` = `ArtisT`.`AT_id`))) order by `ActualPlaying`.`AP_Playcount`,`ActualPlaying`.`AP_Sort`,`ActualPlaying`.`AP_TK_id`;

-- Exportiere Struktur von View vTrackInfo
DROP VIEW IF EXISTS `vTrackInfo`;
-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `vTrackInfo`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `vTrackInfo` AS select `TracK`.`TK_id` AS `TK_id`,`ArtisT`.`AT_Name` AS `AT_Name`,`AlbuM`.`AM_Name` AS `AM_Name`,`TracK`.`TK_Name` AS `TK_Name` from ((`TracK` join `AlbuM` on((`TracK`.`TK_AM_id` = `AlbuM`.`AM_id`))) join `ArtisT` on((`TracK`.`TK_AT_id` = `ArtisT`.`AT_id`)));

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
