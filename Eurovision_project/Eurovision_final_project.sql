CREATE SCHEMA `Eurovison` ;

-- Creating SONGS table--------------------------------------------------------------------------
CREATE TABLE songs (
  song_id INT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  duration TIME NOT NULL,
  language VARCHAR(50) NOT NULL,
  author VARCHAR(255),
  song_link VARCHAR(255)
);
-- Creating ARTISTS table--------------------------------------------------------------------------
CREATE TABLE artists (
  artist_id INT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  surname VARCHAR(50),
  date_of_birth DATE,
  gender ENUM('Male', 'Female', 'Other') NOT NULL,
  song_id INT NOT NULL,
  FOREIGN KEY (song_id) REFERENCES songs(song_id)
);



-- Creating COUNTRIES table--------------------------------------------------------------------------
CREATE TABLE countries (
  country_name VARCHAR(255) NOT NULL,
  year_entered INT NOT NULL,
  num_of_participations INT NOT NULL,
  winnings INT NOT NULL,
  PRIMARY KEY (country_name),
  CONSTRAINT ck_year_entered CHECK (year_entered >= 1956)
);

ALTER TABLE artists ADD COLUMN country VARCHAR(255) NOT NULL;
ALTER TABLE artists ADD FOREIGN KEY (country) REFERENCES countries(country_name);

-- Creating BANDS table--------------------------------------------------------------------------
CREATE TABLE bands (
  band_id INT PRIMARY KEY,
  name VARCHAR(50) NOT NULL
);

-- Creating ARTISTS_WITH_BANDS table--------------------------------------------------------------------------
CREATE TABLE artists_wih_bands (
  artist_id INT NOT NULL,
  band_id INT NOT NULL,
  PRIMARY KEY (artist_id, band_id), 
  FOREIGN KEY (artist_id) REFERENCES artists(artist_id),
  FOREIGN KEY (band_id) REFERENCES bands(band_id)
);


-- Creating CONTESTS table--------------------------------------------------------------------------
CREATE TABLE contests (
  contest_id INT PRIMARY KEY,
  year INT NOT NULL,
  host_country VARCHAR(50) NOT NULL,
  host_city VARCHAR(50) NOT NULL,
  audience INT NOT NULL,
  num_of_participants INT NOT NULL,
  FOREIGN KEY (host_country) REFERENCES countries(country_name)
);

-- Creating PARTICIPATIONS table--------------------------------------------------------------------------
CREATE TABLE participations (
  artist_id INT NOT NULL,
  contest_id INT NOT NULL,
  delegation_head VARCHAR(255),
  staging_author VARCHAR(255),
  num_of_people_on_stage INT NOT NULL,
  staging_main_color VARCHAR(255) NOT NULL,
  performance_link VARCHAR(255),
  PRIMARY KEY (artist_id, contest_id),
  FOREIGN KEY (artist_id) REFERENCES artists(artist_id),
  FOREIGN KEY (contest_id) REFERENCES contests(contest_id)
);

-- Creating RESULTS table--------------------------------------------------------------------------
CREATE TABLE results (
  artist_id INT NOT NULL,
  contest_id INT NOT NULL,
  max_stage_reached ENUM('Semifinal', 'Final') NOT NULL,
  televoting INT NOT NULL,
  jury_points INT NOT NULL,
  place INT NOT NULL,
  PRIMARY KEY (artist_id, contest_id),
  FOREIGN KEY (artist_id) REFERENCES artists(artist_id),
  FOREIGN KEY (contest_id) REFERENCES contests(contest_id)
);

-- Creating WINNERS table--------------------------------------------------------------------------
CREATE TABLE winners (
  artist_id INT NOT NULL,
  contest_id INT NOT NULL,
  total_points INT NOT NULL,
  PRIMARY KEY (contest_id, artist_id), 
  FOREIGN KEY (artist_id) REFERENCES artists(artist_id),
  FOREIGN KEY (contest_id) REFERENCES contests(contest_id)
);



-- Creating Triggers --------------------------------------------------------------------------
-- Updating the number of participants after adding participations  --------------------------------------------------------------------------

DELIMITER //

CREATE TRIGGER update_num_of_participants AFTER INSERT ON participations
FOR EACH ROW
BEGIN
  UPDATE contests
  SET num_of_participants = (SELECT COUNT(*) FROM participations WHERE contest_id = NEW.contest_id)
  WHERE contest_id = NEW.contest_id;
END//

DELIMITER ;


-- Calculating total points as sum of jury_points and televoting
DELIMITER //

CREATE TRIGGER calculate_total_points AFTER INSERT ON results
FOR EACH ROW
BEGIN
  UPDATE winners
  SET total_points = NEW.jury_points + NEW.televoting
  WHERE artist_id = NEW.artist_id AND contest_id = NEW.contest_id;
END//

DELIMITER ;





-- Calculating the number of winnings  --------------------------------------------------------------------------

DELIMITER //
CREATE TRIGGER calculate_winnings AFTER INSERT ON winners
FOR EACH ROW
BEGIN
  UPDATE countries
  SET winnings = winnings + 1
  WHERE country_name = (SELECT country FROM artists WHERE artist_id = NEW.artist_id);
END//

DELIMITER ;

-- Calculating the number of participations  --------------------------------------------------------------------------


DELIMITER //

CREATE TRIGGER calculate_num_of_participations AFTER INSERT ON participations
FOR EACH ROW
BEGIN
  DECLARE countryName VARCHAR(255);
  
  SET countryName = (SELECT country FROM artists WHERE artist_id = NEW.artist_id);
  
  IF NOT EXISTS (
    SELECT 1
    FROM participations p
    INNER JOIN artists a ON p.artist_id = a.artist_id
    WHERE a.country = countryName
      AND p.contest_id = NEW.contest_id
      AND p.artist_id <> NEW.artist_id
  ) THEN
    UPDATE countries
    SET num_of_participations = num_of_participations + 1
    WHERE country_name = countryName;
  END IF;
END//

DELIMITER ;


-- Function to calculate the age of an artist
DELIMITER //

CREATE FUNCTION calculate_age(date_of_birth DATE)
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE age INT;
    SET age = YEAR(CURDATE()) - YEAR(date_of_birth);
    IF MONTH(CURDATE()) < MONTH(date_of_birth) OR (MONTH(CURDATE()) = MONTH(date_of_birth) AND DAY(CURDATE()) < DAY(date_of_birth)) THEN
      SET age = age - 1;
    END IF;
    RETURN age;
  END//
  
DELIMITER ;




-- Creating a view to retrieve artist information with their respective song information-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------
CREATE VIEW artist_song_info AS
SELECT a.artist_id, a.name, a.surname, a.date_of_birth, a.gender, s.title, s.duration
FROM artists a
JOIN songs s ON a.song_id = s.song_id;

SELECT * FROM artist_song_info;


-- Creating a view to retrieve country information with their respective winner information-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE VIEW country_winners AS
SELECT a.country AS country_name, w.artist_id, a.name, a.surname, w.total_points
FROM winners w
JOIN artists a ON w.artist_id = a.artist_id;



-- Creating a view to retrieve contest information with their respective winner information-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE VIEW contest_winners AS
SELECT c.contest_id, c.year, c.host_country, c.host_city, w.artist_id, a.name, a.surname, w.total_points
FROM contests c
JOIN winners w ON c.contest_id = w.contest_id
JOIN artists a ON w.artist_id = a.artist_id;

-- Creating a view to retrieve artist information with their respective band information-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE VIEW artist_bands AS
SELECT a.artist_id, a.name, a.surname, b.name AS band_name
FROM artists a
JOIN artists_wih_bands awb ON a.artist_id = awb.artist_id
JOIN bands b ON awb.band_id = b.band_id;


-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------

-- Create an index on the contest_id column in the participations table
CREATE INDEX idx_participations_contest_id ON participations (contest_id);

-- Create an index on the contest_id column in the results table
CREATE INDEX idx_results_contest_id ON results (contest_id);

-- Create an index on the country_name column in the countries table
CREATE INDEX idx_countries_country_name ON countries (country_name);



-- Check indexes on the participations table
SHOW INDEX FROM participations;

-- Check indexes on the results table
SHOW INDEX FROM results;

-- Check indexes on the countries table
SHOW INDEX FROM countries;



-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------
-- Inserting data into the SONGS table
-- 2012
INSERT INTO songs (song_id, title, duration, language, author, song_link)
VALUES (1, 'Euro Neuro', '03:05:00', 'English', 'Rambo Amadeus', 'https://youtu.be/hGYm3EwOI1Q'),
       (2, 'Never Forget', '03:29:00', 'English', 'Greta Salóme Stefánsdóttir', 'https://youtu.be/p8RS0eulXDo'),
       (3, 'Aphrodisiac', '03:13:00', 'English', 'Dimitri Stassos', 'https://youtu.be/isPtzi5cxBg'),
       (4, 'Beautiful Song', '03:47:00', 'English', 'Ivars Makstnieks', 'https://youtu.be/BeXo4HzpmuU'),
       (5, 'Suus', '03:33:00', 'Albanian', 'Florent Boshnjaku', 'https://youtu.be/v9zIP4FA-1Y'),
       (6, 'Zaleilah', '04:15:00', 'Spanish', 'Elena Ionescu', 'https://youtu.be/zck5xsG9SOI'),
       (7, 'Unbreakable', '03:21:00', 'English', 'Gabriel Broggini', 'https://youtu.be/8yX1dIK9vuc'),
       (8, 'Would You?', '03:05:00', 'English', 'Nina Sampermans', 'https://youtu.be/5pGWkV7y6As'),
       (9, 'När jag blundar', '03:09:00', 'Swedish', 'Jonas Karlsson', 'https://youtu.be/43GWoVxRk2Y'),
       (10, 'Time', '03:19:00', 'English', 'Ran Shem-Tov', 'https://youtu.be/lWMH6ID6Enc'),
       (11, 'The Social Network Song (OH OH - Uh - OH OH)', '03:10:00', 'English', 'Timothy Touchton', 'https://youtu.be/PqwBh9hq9PE'),
       (12, 'La La Love', '03:10:00', 'English', 'Alex Papaconstantinou', 'https://youtu.be/Pedf_OQmcmI'),
       (13, 'Should Hageave Known Better', '03:17:00', 'English', 'Remee', 'https://youtu.be/YKWvUEY8pPA'),
       (14, 'Party for Everybody', '03:09:00', 'Udmurt, English', 'Olga Tuktaryova', 'https://youtu.be/WKNRGc71hjc'), 
	   (15, 'Sound of Our Hearts', '03:08:00', 'English', 'Behnam Lotfi', 'https://youtu.be/qVXhElLlWb8'),
       (16, 'Woki mit deim Popo', '03:14:00', 'German', 'Lukas Plöchl', 'https://youtu.be/BKQf8Z5uWQ8'), 
       (17, 'Lăutar', '03:14:00', 'English', 'Pasha Parfeny', 'https://youtu.be/3H7AILnPoio'),
       (18, 'Waterline', '03:07:00', 'English', 'Nick Jarl', 'https://youtu.be/D_ViQfViDPo'),
       (19, 'Nije ljubav stvar', '03:13:00', 'Serbian', 'Marina Tucaković', 'https://www.youtube.com/watch?v=LnrTDS85rC8'),
       (20, 'Crno i belo', '03:01:00', 'Macedonian', 'Romeo Grill ', 'https://www.youtube.com/watch?v=uUzIr3db25M'),
       (21, 'You and Me', '03:20:00', 'English', ' Joan Franka ', 'https://www.youtube.com/watch?v=oiBaOceaaA0'),
       (22, 'This Is the Night', '03:03:00', 'English', ' Jonah C. Sirott ', 'https://www.youtube.com/watch?v=cjhBsCop3Ys'),
       (23, 'We Are the Heroes', '03:30:00', 'English', ' Ivan Mangraviti ', 'https://www.youtube.com/watch?v=LbUSs1BCiKY'),
       (24, 'Vida minha', '02:56:00', 'Portuguese', ' Andrej Babić ', 'https://www.youtube.com/watch?v=bzNaOsnLHo0'),
       (25, 'Be My Guest', '03:15:00', 'English', ' Yuliia Bondar ', 'https://www.youtube.com/watch?v=i-LyyCxlSFc'),
       (26, 'Love Unlimited', '03:09:00', 'Bulgarian', ' Sofi Marinova ', 'https://www.youtube.com/watch?v=MoQKRIK3HKU'),
       (27, 'Verjamem', '03:04:00', 'Slovene', ' Ahmed Pašić ', 'https://www.youtube.com/watch?v=1SWuO0rTuuQ'),
       (28, 'Nebo', '03:04:00', 'Croatian', ' Imagine Francia', 'https://www.youtube.com/watch?v=z5_tqyCjFZ8'),
       (29, 'Euphoria', '02:59:00', 'English', ' Thomas G:son', 'https://www.youtube.com/watch?v=_v9iT4SZPT8'),
       (30, "Im a Joker", '03:06:00', 'Georgian', ' Vernon Green', 'https://www.youtube.com/watch?v=o1kCgD626Go'),
       (31, 'Love Me Back', '03:02:00', 'English', ' Can Bonomo', 'https://www.youtube.com/watch?v=oKCwuwYnvGs'),
       (32, 'Kuula', '03:01:00', 'Estonian', ' Can Bonomo', 'https://www.youtube.com/watch?v=PSQdnvzV8CE'),
       (33, 'Dont Close Your Eyes', '03:13:00', 'English', ' Max Jason Mai ', 'https://www.youtube.com/watch?v=z2_7YdLk1Tc'),
       (34, 'Stay', '03:18:00', 'English', ' Kjetil Mørland', 'https://www.youtube.com/watch?v=fOdRFtwTzb8'),
       (35, 'Korake ti znam', '03:13:00', 'Bosnian', 'Maja Sarihodzic', 'https://www.youtube.com/watch?v=v_fyisw2--M'),
       (36, 'Love Is Blind', '03:03:00', 'English', 'Brandon Stone', 'https://www.youtube.com/watch?v=Ak3mY0L6gpk'),
       (37, 'Love Will Set You Free', '03:00:00', 'English', 'Martin Terefe', 'https://youtu.be/pFNv9pjqZkk'), -- GB--
       (38, 'Echo (You and I)', '03:11:00', 'French, English', 'Anggun, ', 'https://youtu.be/SnSmB7uBo-Y'), -- France --
       (39, 'Quédate conmigo', '03:13:00', 'Spanish', 'Thomas G:son,', 'https://youtu.be/fL-s0eRRYTE'), -- Spain --
       (40, 'Standing Still', '03:27:00', 'English', 'Jamie CullumSteve', 'https://youtu.be/MxA6TWLttZo'), -- Gremany --
       (41, 'Lamore è femmina (Out of Love)', '03:23:00', 'English', 'Nina Zilli', 'https://youtu.be/coqLVynejo8'), -- Italy --
       (42, 'When the Music Dies', '03:22:00', 'English', 'Anders Bagge', 'https://youtu.be/-8ejpLyXSuY');
       
 -- 2013
INSERT INTO songs (song_id, title, duration, language, author, song_link)
VALUES (43, 'Only Teardrops', '03:03:00', 'English', 'Lise Cabble', 'https://www.youtube.com/watch?v=k59E7T0H-Us'),
       (44, 'Hold Me', '03:00:00', 'English', 'Avtandil Babakishiyev', 'https://www.youtube.com/watch?v=stHqxuLoT3o'),
       (45, 'Gravity', '03:00:00', 'English', 'Dmitry Karyakin', 'https://www.youtube.com/watch?v=5AAYVcV4bB8'),
       (46, 'Believe in Me', '03:00:00', 'English', 'Molly Smitten-Downes', 'https://www.youtube.com/watch?v=WbGSVrEx8nk'),
       (47, 'Birds', '03:00:00', 'English', 'Anouk Teeuwe', 'https://www.youtube.com/watch?v=75Xt8X8eKdA'),
       (48, 'Its My Life', '03:00:00', 'English', 'Egor Bulatkin', 'https://www.youtube.com/watch?v=-hDpslmVt5c'),
       (49, 'Et Uus Saaks Alguse', '03:00:00', 'Estonian', 'Lenna Kuurmaa', 'https://www.youtube.com/watch?v=2Z0R1TsxZwA'),
       (50, 'Lenfer et moi', '03:00:00', 'French', 'Damien Saez', 'https://www.youtube.com/watch?v=1m_uus7ZrYw'),
       (51, 'Waterfall', '03:00:00', 'English', 'Farid Mammadov', 'https://www.youtube.com/watch?v=V7vavDxCJN0'),
       (52, 'I Feed You My Love', '03:00:00', 'English', 'Karla-Therese Kjellvander', 'https://www.youtube.com/watch?v=2BxE8NOqgME'),
       (53, 'You', '03:00:00', 'English', 'Rasmus Palmgren', 'https://www.youtube.com/watch?v=LxKrTIkI8V0'),
       (54, 'Tomorrow', '03:00:00', 'English', 'Ilias Kozas', 'https://www.youtube.com/watch?v=NCa4QA9Fy_0'),
       (55, 'Something', '03:00:00', 'English', 'Ryan Dolan', 'https://www.youtube.com/watch?v=Ac1EGLOxpmE'),
       (56, 'Identitet', '03:00:00', 'Montenegrin', 'Dejan Ljujić', 'https://www.youtube.com/watch?v=I8iz3Lm8PTI'),
       (57, 'Love Kills', '03:00:00', 'English', 'Johan Jämtberg', 'https://www.youtube.com/watch?v=bTURyvyu9lY'),
       (58, 'Glorious', '03:00:00', 'English', 'Jane Bogaert', 'https://www.youtube.com/watch?v=zP0WoX4P2LM'),
       (59, 'Alcohol Is Free', '03:00:00', 'English', 'Kostas Martakis', 'https://www.youtube.com/watch?v=1xEZB6Ln3fQ'),
       (60, 'Samo Shampioni', '03:00:00', 'Bulgarian', 'Borislav Milanov', 'https://www.youtube.com/watch?v=BJvZgBXSpzc'),
       (61, 'You and Me', '03:00:00', 'English', 'Robin Stjernberg', 'https://www.youtube.com/watch?v=V9zcw5n7_O0'),
       (62, 'Marry Me', '03:00:00', 'English', 'Kai Narezo', 'https://www.youtube.com/watch?v=4EV53fzBNFg'),
       (63, 'Here We Go', '03:00:00', 'English', 'Peppiina Pällijeff,', 'https://www.youtube.com/watch?v=s0x4h6zqOOE'),
       (64, 'Crisalide (Vola)', '03:00:00', 'Italian', 'Alessandro Mahmoud', 'https://www.youtube.com/watch?v=Lu4R8v2bQyk'),
       (65, 'Lessenziale', '03:00:00', 'Italian', 'Cheope', 'https://www.youtube.com/watch?v=ZCKCzvvfE1A'),
       (66, 'Rak Bishvilo', '03:00:00', 'Hebrew', 'Shlomi Levi', 'https://www.youtube.com/watch?v=z-qGeF6P0wY'),
       (67, 'What If', '03:00:00', 'English', 'Jamie Cullum', 'https://www.youtube.com/watch?v=McsWKczU6wc'),
       (68, 'Only Love Survives', '03:00:00', 'English', 'Wezo Hofstede', 'https://www.youtube.com/watch?v=0vEbB4eb4bI'),
       (69, 'Contigo hasta el final', '03:00', 'Spanish', 'Tony Sánchez-Ohlsson', 'https://www.youtube.com/watch?v=9OgbWbAm2Ok'),
       (70, 'Solayoh', '03:00:00', 'English', 'Marc Paelinck', 'https://www.youtube.com/watch?v=_1gE7lfvTSw'),
       (71, 'Pred da se razdeni', '03:00:00', 'Macedonian', 'Elvir Mekić', 'https://www.youtube.com/watch?v=n4CqqIhX9yk'),
       (72, 'Lenfer et moi', '03:00:00', 'French', 'Damien Saez', 'https://www.youtube.com/watch?v=1m_uus7ZrYw'),
       (73, 'Igranka', '03:00:00', 'Montenegrin', 'Slaven Knezović', 'https://www.youtube.com/watch?v=Hi6x7xIjHuQ'),
       (74, 'Only Love Survives', '03:00:00', 'English', 'Wezo Hofstede', 'https://www.youtube.com/watch?v=0vEbB4eb4bI'),
       (75, 'Shine', '03:02:00', 'English', 'Natália Kelly', 'https://www.youtube.com/watch?v=1RPLzJ5hqYc'),
       (76, 'Straight into Love', '03:04:00', 'English', 'Hannah', 'https://www.youtube.com/watch?v=SqL0SP3zARg'),
       (77, 'Mižerja', '03:01:00', 'Croatian', 'Goran Topolovac', 'https://www.youtube.com/watch?v=UuEcT_SzfuQ'),
       (78, 'O mie', '03:07:00', 'Romanian', 'Iuliana Scutaru', 'https://www.youtube.com/watch?v=a2MAIExkd7I'),
       (79, 'An me thimasai', '03:02:00', 'Greek', 'Despina Olympiou', 'https://www.youtube.com/watch?v=OEd1TsVBo9U'),
       (80, 'Ljubav je svuda', '03:00:00', 'Serbian', 'Saša Milošević', 'https://www.youtube.com/watch?v=u88zenZTaqY'),
       (81, 'Ég á lí', '03:01:00', 'Icelandic', 'Charlene Li,', 'https://www.youtube.com/watch?v=o-ULC9XGdvs'),
       (82, 'Lonely Planet', '03:04:00', 'English', 'Tony Iommi,', 'https://www.youtube.com/watch?v=JSs03Sp-4ME'),
       (83, 'Kedvesem', '03:23:00', 'Hungarian', 'ByeAlex,', 'https://www.youtube.com/watch?v=cBOmcnHMJ3E');
-- 2023

INSERT INTO songs (song_id, title, duration, language, author, song_link)
VALUES (84, 'Queen of Kings', '02:52:00', 'English', 'Alessandra Mele', 'https://www.youtube.com/watch?v=vSfffjHjdTk'),
       (85, 'Dance (Our Own Party)', '03:03:00', 'English', 'Jean Paul Borg', 'https://www.youtube.com/watch?v=Apqwl0ayL6A'),
       (86, 'Samo mi se spava', '02:53:00', 'Serbian', 'Luke Black', 'https://www.youtube.com/watch?v=XRWW02clx8c'),
       (87, 'Aijā', '03:01:00', 'English', 'Marta Metuzāle', 'https://www.youtube.com/watch?v=XRV2-jPqaUw'),
       (88, 'Ai coração', '03:05:00', 'Portuguese', 'Mimicat Canção', 'https://www.youtube.com/watch?v=-uY37gGPkNU'),
       (89, 'We Are One', '03:04:00', 'English', ' Conor ODonohoe', 'https://www.youtube.com/watch?v=ak5Fevs424Y'),
       (90, 'Mama ŠČ!', '02:45:00', 'Croatian', 'Damir Martinović', 'https://www.youtube.com/watch?v=AyKj8jA0Qoc'),
       (91, 'Watergun', '02:52:00', 'English', 'Remo Forrer', 'https://www.youtube.com/watch?v=Z2wmJnsLWT8'),
       (92, 'Unicorn', '03:51:00', 'English', 'Doron Medalie', 'https://www.youtube.com/watch?v=jrqXLSHbUkA'),
       (93, 'Soarele și luna', '03:00:00', 'Romanian', 'Andrei Vulpe', 'https://www.youtube.com/watch?v=jatc6dNgpjs'),
       (94, 'Tattoo', '03:03:00', 'English', 'Karl Stig-Erland', 'https://www.youtube.com/watch?v=_IqI2bf9CCQ'),
       (95, 'Tell Me More', '03:30:00', 'English', ' TuralTuranX', 'https://www.youtube.com/watch?v=5dvsr-L3HgY'),
       (96, 'My Sisters Crown', '03:30:00', 'Czech', 'Adam Albrecht Micha', 'https://www.youtube.com/watch?v=bFm-hw2rUeA'),
       (97, 'Burning Daylight', '03:16:00', 'English', 'Nicolai', 'https://www.youtube.com/watch?v=UOf-oKDlO6A'),
       (98, 'Cha Cha Cha', '03:56:00', 'Finnish', 'Oliver Adams', 'https://www.youtube.com/watch?v=rj4YyPzPiPE'),
       (99, 'Breaking My Heart', '02:49:00', 'English', 'Bård Mathias Bonsaksen', 'https://www.youtube.com/watch?v=04C8E7PUMQo'),
       (100, 'Future Lover', '03:00:00', 'English', 'Brunette', 'https://www.youtube.com/watch?v=Co8ZJIejXBA'),
       (101, 'D.G.T. (Off and On)', '03:15:00', 'Romanian', 'Theodor Andrei', 'https://www.youtube.com/watch?v=NRxv-AUCinQ'),
       (102, 'Bridges', '03:27:00', 'English', 'Nina Sampermans', 'https://www.youtube.com/watch?v=_IqI2bf9CCQ'),
       (103, 'Because of you', '03:13:00', 'English', 'Stef Caers Jaouad Alloul', 'https://www.youtube.com/watch?v=ORhEoS6d8e4'),
       (104, 'Break a Broken Heart', '03:06:00', 'English', 'Andrew Lambrou', 'https://www.youtube.com/watch?v=YQG9YH2nCJw'),
       (105, 'Power', '03:20:00', 'English', 'Diljá Pétursdóttir', 'https://www.youtube.com/watch?v=BhlJXcCv7gw'),
       (106, 'What They Say', '03:19:00', 'English', 'Victor Vernicos', 'https://www.youtube.com/watch?v=qL0EkId_sTY'),
       (107, 'Solo', '03:10:00', 'English', 'Blanka', 'https://www.youtube.com/watch?v=PvQRpV1-ZhY'),
       (108, 'Carpe Diem', '03:09:00', 'Slovene', 'Bojan Cvjetićanin', 'https://www.youtube.com/watch?v=zDBSIGITdY4'),
       (109, 'Echo', '03:18:00', 'English', 'Beni Kadagidze', 'https://www.youtube.com/watch?v=E8kO-QPippo'),
       (110, 'Like an Animal', '03:09:00', 'English', 'Andrea Lazzeretti', 'https://www.youtube.com/watch?v=D1opw3IpJWA'),
       (111, 'Who the Hell Is Edgar?', '02:50:00', 'English', 'Teodora Špirić', 'https://www.youtube.com/watch?v=ZMmLeV47Au4'),
       (112, 'Duje', '03:33:00', 'Albanian', 'Enis Mullaj', 'https://www.youtube.com/watch?v=mp8OG4ApocI'),
       (113, 'Stay', '03:10:00', 'English', 'Monika Linkytė', 'https://www.youtube.com/watch?v=68lbEUDuWUQ'),
       (114, 'Promise', '03:14:00', 'English', 'Voyager', 'https://www.youtube.com/watch?v=aqtu2GspT80'),
       (115, 'Eaea', '03:24:00', 'Spanish', 'Blanca Paloma', 'https://www.youtube.com/watch?v=NGnEoSypBhE'),
       (116, 'Due vite', '03:45:00', 'Italian', 'Marco Mengoni', 'https://www.youtube.com/watch?v=_iS4STWKSvk'),
       (117, 'Heart of Steel', '02:44:00', 'English', 'Andrii Hutsuliak', 'https://www.youtube.com/watch?v=neIscK1hNxs'),
       (118, 'Blood & Glitter', '04:11:00', 'English', 'Chris Harms', 'https://www.youtube.com/watch?v=5I9CYu668jA'),
       (119, 'I wrote a song', '03:14:00', 'English', 'Mae Muller', 'https://www.youtube.com/watch?v=rRaVGKk4k6k'),
       (120, 'Évidemment', '03:16:00', 'French', ' La Zarra', 'https://www.youtube.com/watch?v=GWfbEFH9NvQ');








 -- Inserting data into the COUNTRIES table
INSERT INTO countries (country_name, year_entered, num_of_participations, winnings)
VALUES ('Albania', 2004, 0, 0),
       ('Andorra', 2004, 0, 0),
       ('Armenia', 2006, 0, 0),
       ('Australia', 2015, 0, 0),
       ('Austria', 1966, 0, 0),
       ('Azerbaijan', 2008, 0, 0),
       ('Belarus', 2004, 0, 0),
       ('Belgium', 1956, 0, 0),
       ('Bosnia and Herzegovina', 1993, 0, 0),
       ('Bulgaria', 2005, 0, 0),
       ('Croatia', 1993, 0, 0),
       ('Cyprus', 1981, 0, 0),
       ('Czechia', 2007, 0, 0),
       ('Denmark', 1957, 0, 0),
       ('Estonia', 1994, 0, 0),
       ('Finland', 1961, 0, 0),
       ('France', 1956, 0, 0),
	   ('Georgia', 2007, 0, 0),
       ('Germany', 1956, 0, 0),
	   ('Greece', 1974, 0, 0),
       ('Hungary', 1994, 0, 0),
	   ('Iceland', 1986, 0, 0),
       ('Ireland', 1965, 0, 0),
	   ('Israel', 1973, 0, 0),
       ('Italy', 1956, 0, 0),
	   ('Latvia', 2000, 0, 0),
       ('Lithuania', 1994, 0, 0),
	   ('Luxembourg', 1956, 0, 0),
       ('Malta', 1971, 0, 0),
	   ('Moldova', 2005, 0, 0),
       ('Monaco', 1959, 0, 0),
	   ('Montenegro', 2007, 0, 0),
       ('Morocco', 1980, 0, 0),
       ('Netherlands', 1956, 0, 0),
	   ('North Macedonia', 1998, 0, 0),
       ('Norway', 1960, 0,0),
       ('Poland', 1994, 0, 0),
	   ('Portugal', 1964, 0, 0),
       ('Romania', 1994, 0, 0),
       ('Russia', 1994, 0, 0),
	   ('San Marino', 2008, 0, 0),
       ('Serbia', 2007, 0, 0),
       ('Serbia and Montenegro', 2004, 0, 0),
	   ('Slovakia', 1994, 0, 0),
       ('Slovenia', 1993, 0, 0),
       ('Spain', 1961, 0, 0),
       ('Sweden', 1958, 0, 0),
	   ('Switzerland', 1956, 0, 0),
       ('Turkey', 1975, 0, 0),
	   ('Ukraine', 2003, 0, 0),
       ('United Kingdom', 1957, 0, 0),
	   ('Yugoslavia', 1961, 0, 0);     
        
       -- Inserting data into the ARTISTS table
INSERT INTO artists (artist_id, name, surname, date_of_birth, gender, song_id, country)
VALUES (1, 'Rambo', 'Amadeus', '1963-06-14', 'Male', 1, 'Montenegro'),
       (2, 'Greta', 'Salóme', '1986-11-11', 'Female', 2, 'Iceland'),
	   (3, 'Jónsi', 1963-06-14, '1977-06-01', 'Male', 2, 'Iceland'),
       (4, 'Eleftheria', 'Eleftheriou', '1989-05-12', 'Female', 3, 'Greece'),
       (5, 'Anmary', 1963-06-14, '1980-03-03', 'Female', 4, 'Latvia'),
       (6, 'Rona', 'Nishliu', '1986-08-25', 'Female', 5, 'Albania'),
       (7, 'Barbara', 'Isasi', '1993-06-14', 'Female', 6, 'Romania'),
       (8, 'Alex', NULL, '1983-06-14', 'Male', 6, 'Romania'),
       (9, 'Chupi', NULL, '1999-08-14', 'Other', 6, 'Romania'),
       (10, 'Zach (Valle)', NULL, '1989-06-14', 'Other', 6, 'Romania'),
       (11, 'El Niño', NULL, '1986-08-25', 'Other', 6, 'Romania'),
       (12, 'Omar', NULL, '1989-08-25', 'Male', 6, 'Romania'),
       (13, 'Tony', NULL, '1986-08-25', 'Male', 6, 'Romania'),
       (14, 'Ivan', 'Broggini', '1981-08-25', 'Male', 7, 'Switzerland'),
       (15, 'Gabriel', 'Broggini', '1986-08-25', 'Male', 7, 'Switzerland'),
       (16, 'Laura', 'van den Bruel', '1995-01-19', 'Female', 8, 'Belgium'),
       (17, 'Pernilla', 'Karlsson', '1981-08-25', 'Female', 9, 'Finland'),
       (18, 'Ran', 'Shem Tov','1980-08-25', 'Male', 10, 'Israel'),
       (19, 'Shiri', 'Hadar', '1999-08-25', 'Female', 10, 'Israel'),
       (20, 'Valentina', 'Monetta', '1975-03-01', 'Female', 11, 'San Marino'),
       (21, 'Ivi', 'Adamou', '1993-11-24', 'Female', 12, 'Cyprus'),
       (22, 'Soluna', 'Samay', '1990-08-27', 'Female', 13, 'Denmark'),
       (23, 'Anna', 'Prokopyeva', '1982-08-25', 'Female', 14, 'Russia'),
       (24, 'Valentina', 'Serebrennikova', '1986-10-20', 'Female', 14, 'Russia'),
       (25, 'Yekaterina', 'Antonova', '1995-02-20', 'Female', 14, 'Russia'),
       (26, 'Behnam', 'Lotfi', '1986-08-25', 'Male', 15, 'Hungary'),
       (27, 'Gábor', 'Pál', '1986-08-25', 'Male', 15, 'Hungary'),
       (28, 'Csaba', 'Walkó', '1986-08-25', 'Male', 15, 'Hungary'),
       (29, 'Lukas', 'Plöchl', '1982-08-25', 'Male', 16, 'Austria'),
       (30, 'Manuel', 'Hoffelner','1981-08-25', 'Male', 16, 'Austria'),
       (31, 'Pasha', 'Parfeni', '1986-05-30', 'Male', 17, 'Moldova'),
       (32, 'John', 'Grimes', '1991-10-16', 'Male', 18, 'Ireland'),
       (33, 'Edward', 'Grimes', '1991-10-16', 'Male', 18, 'Ireland'),
       (34, 'Željko', 'Joksimović', '1972-04-20', 'Male', 19, 'Serbia'),
       (35, 'Kaliopi', NULL, '1966-12-28', 'Female', 20, 'North Macedonia'),
       (36, 'Joan', 'Franka', '1990-04-02', 'Female', 21, 'Netherlands'),
       (37, 'Kurt', 'Calleja', '1989-05-05', 'Male', 22, 'Malta'),
       (38, 'Dmitry', 'Karyakin', NUll, 'Male', 23, 'Belarus'),
       (39, 'Vladimir', 'Karyakin', NULL, 'Male', 23, 'Belarus'),
       (40, 'Evgeny', 'Balchuys', NULL, 'Male', 23, 'Belarus'),
       (41, 'Max', 'Bobko', NULL, 'Male', 23, 'Belarus'),
       (42, 'Filipa', 'Sousa', '1985-03-02', 'Female', 24, 'Portugal'),
       (43, 'Gaitana', NULL, '1979-03-24', 'Female', 25, 'Ukraine'),
       (44, 'Sofi', 'Marinova', '1975-12-05', 'Female', 26, 'Bulgaria'),
       (45, 'Eva', 'Boto', '1995-12-01', 'Female', 27, 'Slovenia'),
       (46, 'Nina', 'Badrić', '1972-07-04', 'Female', 28, 'Croatia'),
       (47, 'Loreen', NULL, '1983-10-16', 'Female', 29, 'Sweden'),
       (48, 'Anri', 'Jokhadze', '1980-11-06', 'Male', 30, 'Georgia'),
       (49, 'Can', 'Bonomo', '1987-05-16', 'Male', 31, 'Turkey'),
       (50, 'Ott', 'Lepland', '1987-05-17', 'Male', 32, 'Estonia'),
       (51, 'Max', 'Jason Mai', '1988-11-27', 'Male', 33, 'Slovakia'),
       (52, 'Tooji', NULL, '1987-05-26', 'Male', 34, 'Norway'),
       (53, 'Maya', 'Sar', '1981-07-12', 'Female', 35, 'Bosnia and Herzegovina'),
       (54, 'Donny', 'Montell', '1987-10-22', 'Male', 36, 'Lithuania'),
       -- big 5
       (55, 'Engelbert', 'Humperdinck', '1936-05-02', 'Male', 37, 'United Kingdom'),
       (56, 'Anggun', NULL, '1974-04-29', 'Female', 38, 'France'),
       (57, 'Pastora', 'Soler', '1978-09-28', 'Female', 39, 'Spain'),
	   (58, 'Roman', 'Lob', '1990-07-02', 'Male', 40, 'Germany'),
       (59, 'Nina', 'Zilli', '1980-02-02', 'Female', 41, 'Italy'),
       (60, 'Sabina', 'Babayeva', '1979-12-02', 'Female', 42, 'Hungary'),   
       
       -- 2023
       (61, 'Alessandra', 'Mele', '2002-09-5', 'Female', 84, 'Norway'),
       (62, 'David', 'Meilak', '1999-11-02', 'Male', 85, 'Malta'),
       (63, 'Jean Paul ', 'Borg', '1989-02-05', 'Male', 85, 'Malta'),
       (64, 'Sean ', 'Meachen', '2000-10-10', 'Male', 85, 'Malta'),
       (65, 'Luka', 'Ivanovic', '1992-05-18', 'Male', 86, 'Serbia'),
       (66, 'Andrejs', 'Zitmanis', '1989-10-02', 'Male', 87, 'Latvia'),
       (67, 'Kārlis', 'Zitmanis', '1999-01-02', 'Male', 87, 'Latvia'),
       (68, 'Mārtiņš', 'Zemītis', '2000-10-12', 'Male', 87, 'Latvia'), 
       (69, 'Kārlis', ' Vārtiņš', '1999-11-22', 'Male', 87, 'Latvia'), 
       (70, 'Marisa Isabel', 'Lopes Mena', '1985-10-25', 'Female', 88, 'Portugal'),
       (71, 'David ', 'Whelan', '1989-02-12', 'Male', 89, 'Ireland'),
       (72, 'Conor ', 'ODonohoe', '1999-06-02', 'Male', 89, 'Ireland'),        
       (73, 'Ed ', 'Porter', '1987-12-09', 'Male', 89, 'Ireland'), 
       (74, 'Callum ', 'McAdam', '1989-09-18', 'Male', 89, 'Ireland'),   
       (75, 'Damir', 'Martinović', '1979-12-02', 'Male', 90, 'Croatia'), 
       (76, 'Zoran', 'Prodanović', '1979-10-21', 'Male', 90, 'Croatia'),
       (77, 'Ivan', 'Bojčić', '1969-11-12', 'Male', 90, 'Croatia'),
       (78, 'Dražen', 'Baljak', '1967-05-08', 'Male', 90, 'Croatia'),
       (79, 'Matej', 'Zec', '1979-07-07', 'Male', 90, 'Croatia'), 
       (80, 'Remo', 'Forrer', '2001-09-08', 'Male', 91, 'Switzerland'),
       (81, 'Noa', 'Kirel', '2001-04-10', 'Female', 92, 'Israel'),
       (82, 'Pasha', 'Parfeni', '1986-05-30', 'Male', 93, 'Moldova'),
       (83, 'Loreen ', NULL, '1983-10-13', 'Female', 94, 'Sweden'),   
       (84, 'Tural', 'Bağmanov', '2000-10-30', 'Male', 95, 'Azerbaijan'),
       (85, 'Turan', 'Bağmanov', '2000-10-30', 'Male', 95, 'Azerbaijan'),  
       (86, 'Patricie', 'Fuxová', '2000-07-07', 'Female', 96, 'Czechia'),
       (87, 'Bára', 'Šůstková', '2001-09-07', 'Female', 96, 'Czechia'),
       (88, 'Olesya', 'Ochepovská', '1999-01-19', 'Female', 96, 'Czechia'),
       (89, 'Markéta', 'Vedralová', '1992-11-03', 'Female', 96, 'Czechia'),
       (90, 'Tereza', 'Čepková', '1999-09-16', 'Female', 96, 'Czechia'), 
       (91, 'Tanita', 'Yanková', '2000-06-07', 'Female', 96, 'Czechia'),
       (92, 'Mia', 'Nicolai', '1996-03-07', 'Female', 97, 'Netherlands'),
       (93, 'Dion', 'Cooper', '1993-11-29', 'Male', 97, 'Netherlands'),
       (94, 'Jere', 'Pöyhönen', '1993-10-21', 'Male', 98, 'Finland'),
       (95, 'Rani', 'Peterson', '1997-11-24', 'Other', 99, 'Denmark'),
       (96, 'Elen', 'Yermyan', '2001-05-27', 'Female', 100, 'Armenia'), 
       (97, 'Theodor', 'Andrei', '2004-10-09', 'Male', 101, 'Romania'),
       (98, 'Alika', 'Milova', '1980-07-05', 'Male', 102, 'Estonia'),
       (99, 'Stef', 'Caers', '1997-11-24', 'Other', 103, 'Belgium'),
       (100, 'Andrew', 'Lambrou', '1998-05-25', 'Male', 104, 'Cyprus'), 
       (101, 'Diljá ', 'Pétursdóttir', '2001-12-15', 'Female', 105, 'Iceland'),   
       (102, 'Victor', 'Vernicos', '2006-10-23', 'Male', 106, 'Greece'),
       (103, 'Blanka', 'Stajkow', '1999-05-23', 'Female', 107, 'Poland'), 
       (104, 'Bojan ', 'Cvjetićanin ', '2001-10-18', 'Male', 108, 'Slovenia'),
       (105, 'Jure ', 'Maček', '2000-02-15', 'Male', 108, 'Slovenia'),       
       (106, 'Kris ', 'Guštin', '1998-12-10', 'Male', 108, 'Slovenia'),       
       (107, 'Jan ', 'Peteh', '2001-01-01', 'Male', 108, 'Slovenia'),       
       (108, 'Nace ', 'Jordan', '2000-09-06', 'Male', 108, 'Slovenia'),       
       (109, 'Iru', 'Khechanovi', '2000-12-03', 'Female', 109, 'Georgia'), 
       (110, 'Andrea ', 'Lazzeretti ', '2001-10-18', 'Male', 110, 'San Marino'),
       (111, 'Francesco ', 'Bini', '2000-02-15', 'Male', 110, 'San Marino'),       
       (112, 'Tommaso ', 'Oliveri', '1998-12-10', 'Male', 110, 'San Marino'),       
       (113, 'Marco ', 'Sgaramella', '2001-01-01', 'Male', 110, 'San Marino'),  
       (114, 'Teodora', ' Špirić ', '2000-08-12', 'Female', 111, 'Austria'),       
       (115, 'Selina-Maria ', 'Edbauer ', '1998-03-11', 'Female', 111, 'Austria'),   
       (116, 'Albina ', 'Kelmendi', '1998-01-27', 'Female', 112, 'Albania'),         
       (117, 'Monika ', 'Linkytė ', '1992-06-03', 'Female', 113, 'Lithuania'),         
       (118, 'Daniel ', 'Estrin', '1981-04-29', 'Male', 114, 'Australia'),         
       (119, 'Blanca ', 'Paloma', '1999-06-09', 'Female', 115, 'Spain'),         
       (120, 'Marco ', 'Mengoni ', '1988-12-25', 'Male', 116, 'Italy'),  
       (121, 'Andrii ', 'Hutsuliak', '1991-04-29', 'Male', 117, 'Ukraine'),   
       (122, 'Jimoh ', 'Kehinde', '1998-01-27', 'Male', 117, 'Ukraine'),  
       (123, 'Chris ', 'Harms ', '1982-06-03', 'Male', 118, 'Germany'),         
       (124, 'Class ', 'Grenayde', '1983-04-29', 'Male', 118, 'Germany'),   
       (125, 'Gared ', 'Dirge ', '1989-06-03', 'Male', 118, 'Germany'),         
       (126, 'Pi ', NULL, '1999-04-29', 'Male', 118, 'Germany'),   
       (127, 'Niklas ', 'Kahl ', '1992-06-03', 'Male', 118, 'Germany'),  
       (128, 'Mae ', 'Muller', '1997-08-26', 'Female', 119, 'United Kingdom'),   
       (129, 'Fatima-Zahra ', 'Hafdi', '1987-08-25', 'Female', 120, 'France');        
       
-- Inserting data into the CONTESTS table
INSERT INTO contests (contest_id, year, host_country, host_city, audience, num_of_participants)
VALUES (1, 2012, 'Azerbaijan', 'Baku', 640000 , 42),
	   (2, 2013, 'Sweden', 'Malmö', 170000, 39),
       (3, 2014, 'Denmark', 'Copenhagen', 1950000, 37),
       (4, 2015, 'Austria', 'Vienna', 2000000, 40),
       (5, 2016, 'Sweden', 'Stockholm', 2040000, 42),
	   (6, 2017, 'Ukraine',  'Kyiv', 1820000, 42),
       (7, 2018, 'Portugal', 'Lisbon', 1860000, 43),
       (8, 2019, 'Israel', 'Tel Aviv', 1820000, 41),
	   (9, 2020, 'Netherlands', 'Rotterdam', 0, 41),
       (10, 2021, 'Netherlands', 'Rotterdam',  1830000, 39),
       (11, 2022, 'Italy', 'Turin', 1610000, 40),
       (12, 2023,  'United Kingdom', 'Liverpool', 1420000, 37);


-- Inserting data into the WINNERS table
INSERT INTO winners (artist_id, contest_id, total_points)
VALUES (47, 1, 0),
	   (83, 12, 0);




-- Inserting data into the BANDS table
INSERT INTO bands (band_id, name)
VALUES (1, 'Greta Salóme and Jónsi'),
       (2, 'Mandinga'),
       (3, 'Sinplus'),
	   (4, 'Izabo'),
       (5, 'Buranovskiye Babushki'),
       (6, 'Compact Disco'),
       (7, 'Trackshittaz'),
       (8, 'Jedward'),
       (9, 'Litesound'),
       (10,'The Busker'),
       (11,'Sudden Lights'),
       (12, 'Wild Youth'),
       (13, 'Let 3'),
       (14, 'TuralTuranX'),
       (15, 'Vesna'),
       (16, 'Mia and Dion'),
       (17, 'Joker Out'),
       (18, 'Teya and Selena'),
       (19, 'Tvorchi'),
       (20, 'Lord of the Lost');

       

-- Inserting data into the ARTISTS_WITH_BANDS table
INSERT INTO artists_wih_bands (artist_id, band_id)
VALUES (2, 1),
       (3, 1),
       (7, 2),
       (8, 2),
       (9, 2),
       (10, 2),
       (11, 2),
       (12, 2),
       (13, 2),
       (14, 3),
       (15, 3),
       (18, 4),
       (19, 4),
       (23, 5),
       (24, 5),
       (25, 5),
       (26, 6),
       (27, 6),
       (28, 6),
       (29, 7),
       (30, 7),
       (32, 8),
       (33, 8),
       (38, 9),
       (39, 9),
       (40, 9),
       (41, 9),
       (62, 10),
       (63, 10),
       (64, 10),
       (66, 11),
       (67, 11),
       (68, 11),
       (69, 11),
       (71, 12),
       (72, 12),
       (73,12),
       (74, 12),
       (75, 13),
       (76, 13),
       (77, 13),
       (78, 13),
       (79, 13),
       (84, 14), 
       (85, 14),
       (86, 15),
       (87, 15),
       (88, 15),
       (89, 15),
       (90, 15),
       (91, 15),
       (92, 16),
       (93, 16),
       (104, 17),
       (105, 17),
       (106, 17),
       (107, 17),
       (108, 17),
       (114, 18),
       (115, 18),
       (121, 19),
       (122, 19),
       (123, 20),
       (124, 20),
       (125, 20),
       (126, 20),
       (127, 20);
       
       
-- Inserting data into the PARTICIPATIONS table
-- 2012
INSERT INTO participations (artist_id, contest_id, delegation_head, staging_author, num_of_people_on_stage, staging_main_color, performance_link)
VALUES (1, 1, 'Nataša Baranin', 'RTCG', 5, 'Blue', 'https://youtu.be/JHnqF5PLP2w'),
       (2, 1, 'Felix Bergsson', 'RÚV', 6, 'Blue', 'https://youtu.be/zRqmHRbJvTo'),
	   (3, 1, 'Felix Bergsson', 'RÚV', 6, 'Blue', 'https://youtu.be/zRqmHRbJvTo'),
       (4, 1, 'Monica Papadatos', 'ERT', 5, 'Purple', 'https://youtu.be/ex133UhxB64'),
	   (5, 1, 'Zita Kaminska', 'LTV', 5, 'Orange', 'https://youtu.be/KAxYfMFE_94'),
       (6, 1, 'Kleart Duraj', 'RTSH', 1, 'Red', 'https://youtu.be/QeBL2UHhyEc'),
       (7, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
       (8, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
       (9, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
	   (10,1,'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
       (11, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
	   (12, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
       (13, 1, 'Iuliana Marciuc', 'TVR', 6, 'Purple', 'https://youtu.be/K3ruy639kTQ'),
       (14, 1, 'Jean Paul Cara', 'SRG SSR', 2, 'Red', 'https://youtu.be/lkMSptuVqHQ'),
       (15, 1, 'Jean Paul Cara', 'SRG SSR', 2, 'Red', 'https://youtu.be/lkMSptuVqHQ'),
	   (16, 1, 'Leslie Cable', 'RTBF', 4, 'Pink', 'https://youtu.be/7Z_5s5gnrCM'),
	   (17, 1, 'Terhi Norvasto', 'YLE', 2, 'Red', 'https://youtu.be/MRC5NzxmrAA'),
       (18, 1, 'Yoav Ginai', 'IBA', 4, 'Pink', 'https://youtu.be/-uy4ggnLzKI'),
	   (19, 1, 'Yoav Ginai', 'IBA', 4, 'Pink', 'https://youtu.be/-uy4ggnLzKI'),
       (20, 1, 'Alessandro Capicchioni', 'SMRTV', 5, 'Yellow', 'https://youtu.be/y7IoR_5HPQ0'),
       (21, 1, 'Evi Papamichael', 'CyBC (RIK)', 5, 'Blue', 'https://youtu.be/ex133UhxB64'),
       (22, 1, 'Molly Plank', 'DR', 5, 'Orange', 'https://youtu.be/U5X2r_t-KBk'),   
	   (23, 1, 'Jury Aksyuta', 'C1R', 6, 'Red', 'https://youtu.be/BgUstrmJzyc'),
	   (24, 1, 'Jury Aksyuta', 'C1R', 6, 'Red', 'https://youtu.be/BgUstrmJzyc'),
       (25, 1, 'Jury Aksyutak', 'C1R', 6, 'Red', 'https://youtu.be/BgUstrmJzyc'),
	   (26, 1, 'Szilvia Püspök', 'HMG', 4, 'Blue', 'https://youtu.be/sw85G2AlU2c'),
       (27, 1, 'Szilvia Püspök', 'HMG', 4, 'Blue', 'https://youtu.be/sw85G2AlU2c'),
       (28, 1, 'Szilvia Püspök', 'HMG', 5, 'Blue', 'https://youtu.be/sw85G2AlU2c'),
       (29, 1, 'Stefan Zechner', 'ORF', 5, 'Green', 'https://youtu.be/BKQf8Z5uWQ8'),
	   (30, 1, 'Stefan Zechner', 'ORF', 5, 'Green', 'https://youtu.be/BKQf8Z5uWQ8'),
       (31, 1, 'Vitalie Cojocaru', 'TRM', 6, 'Orange', 'https://youtu.be/vIy0EtEeLEw'),
	   (32, 1, 'Michael Kealy', 'RTÉ', 6, 'Blue', 'https://youtu.be/e1cuimKLNpU'),
       (33, 1, 'Michael Kealy', 'RTÉ', 6, 'Blue', 'https://youtu.be/e1cuimKLNpU'),
       (34, 1, 'Anja Rogljić', 'RTS', 6, 'Blue', 'https://youtu.be/R9x9VbJzaDQ'),
       (35, 1, 'Meri Popova', 'MRT', 5, 'Blue', 'https://youtu.be/MSuCdNEy9w0'),
	   (36, 1, 'Lars Lourenco', 'TROS', 5, 'Red', 'https://youtu.be/JCc0Iiu3DiU'),
       (37, 1, 'Gordon Bonello', 'PBS', 6, 'Orange', 'https://youtu.be/lUnEZp-qHxs'),
	   (38, 1, 'Olga Salamakha', 'BTRC', 5, 'Blue', 'https://youtu.be/-JWbOKNaIAo'),
       (39, 1, 'Olga Salamakha', 'BTRC', 5, 'Blue', 'https://youtu.be/-JWbOKNaIAo'),
       (40, 1, 'Olga Salamakha', 'BTRC', 5, 'Blue', 'https://youtu.be/-JWbOKNaIAo'),
       (41, 1, 'Olga Salamakha', 'BTRC', 5, 'Blue', 'https://youtu.be/-JWbOKNaIAoo'),
       (42, 1, 'Carla Bugalho Trindade', 'RTP', 6, 'Pink', 'https://youtu.be/fk5i7Hfyy3o'),
	   (43, 1, 'Oksana Skybinska', 'NSTU (Suspilne)', 5, 'Blue', 'https://youtu.be/sLsTn_li5d8'),
       (44, 1, 'Joana Levieva-Sawyer', 'BNT', 1, 'Purple', 'https://youtu.be/WAUAETPcFBI'),
	   (45, 1, 'Aleksander Radic', 'RTV SLO', 6, 'Blue', 'https://youtu.be/QzdI4yuqwzY'),
       (46, 1, 'Kazimir Bacic', 'HRT', 3, 'Blue', 'https://youtu.be/zRqmHRbJvTo'),
       (47, 1, 'Lotta Furebäck', 'SVT', 2, 'Blue', 'https://youtu.be/Pfo-8z86x80'),
       (48, 1, 'Natia Mshvenieradze', '', 6, 'Blue', 'https://youtu.be/xfpKnMBjdrU'),
       (49, 1, NULL, 'TRT', 6, 'Blue', 'https://youtu.be/3Qa7_y21oOY'),
	   (50, 1, 'Mart Normet', 'ERR', 1, 'Red', 'https://youtu.be/T7BaTBe0UD8'),
       (51, 1, NULL, 'STV', 5, 'White', 'https://youtu.be/OTXz60794lI'),
       (52, 1, 'Stig Karlsen', 'NRK', 5, 'Orange', 'https://youtu.be/-ZaxIY1VAbM'),
       (53, 1, 'Lejla Babovic', 'BHRT', 1, 'Blue', 'https://youtu.be/81hIbZNoFU8'),
       (54, 1, 'Audrius Giržadas', 'LRT', 1, 'Blue', 'https://youtu.be/x2vNoZnJxgY'),
	   (55, 1, 'Andrew Cartmell', 'BBC', 1, 'Black', 'https://youtu.be/rXw4Q5jbNqQ'),
       (56, 1, 'Alexandra Redde-Amiel', 'GRF (France 3)', 6, 'Yellow', 'https://youtu.be/0DZ7DbdeOeE'),
	   (57, 1, 'Eva Mora', 'TVE', 1, 'Blue', 'https://youtu.be/U8J1b62wOao'),
       (58, 1, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Yellow', 'https://youtu.be/cScJPH20P3A'),
       (59, 1, 'Simona Martorelli', 'RAI', 4, 'Silver', 'https://youtu.be/v0kGpDEvtbQ'),
       (60, 1, 'Vasif Mammadov', 'İTV', 5, 'Blue', 'https://youtu.be/yzT7O3Fnwpk'),
       
       -- 2023
       (61, 12, 'Stig Karlsen', 'NRK', 5, 'Blue', 'https://youtu.be/PUHSM_vTqTI'), 
       (62, 12, 'Gordon Bonello', 'PBS', 3, 'Purple', 'https://youtu.be/zVmVt9qmg9g'), 
       (63, 12, 'Gordon Bonello', 'PBS', 3, 'Purple', 'https://youtu.be/zVmVt9qmg9g'), 
       (64, 12, 'Gordon Bonello', 'PBS', 3, 'Purple', 'https://youtu.be/zVmVt9qmg9g'), 
       (65, 12, 'Anja Rogljić', 'RTS', 5, 'Blue', 'https://youtu.be/E89gtz9rdBM'), 
       (66, 12, 'Guntars Gulbiņš', 'LTV', 4, 'Orange', 'https://youtu.be/SEykwl9X9SY'), 
       (67, 12, 'Guntars Gulbiņš', 'LTV', 4, 'Orange', 'https://youtu.be/SEykwl9X9SY'), 
       (68, 12, 'Guntars Gulbiņš', 'LTV', 4, 'Orange', 'https://youtu.be/SEykwl9X9SY'), 
       (69, 12, 'Guntars Gulbiņš', 'LTV', 4, 'Orange', 'https://youtu.be/SEykwl9X9SY'), 
       (70, 12, 'Carla Bugalho Trindade', 'RTP', 5, 'Red', 'https://youtu.be/HYfkxX4PFyw'), 
       (71, 12, 'Michael Kealy', 'RTÉ', 4, 'Golden', 'https://youtu.be/80-4_rjW10U'), 
       (72, 12, 'Michael Kealy', 'RTÉ', 4, 'Golden', 'https://youtu.be/80-4_rjW10U'), 
       (73, 12, 'Michael Kealy', 'RTÉ', 4, 'Golden', 'https://youtu.be/80-4_rjW10U'), 
       (74, 12, 'Michael Kealy', 'RTÉ', 4, 'Golden', 'https://youtu.be/80-4_rjW10U'), 
       (75, 12, 'Kazimir Bacic', 'HRT', 6, 'Red', 'https://youtu.be/JPiY1v3EfNc'), 
       (76, 12, 'Kazimir Bacic', 'HRT', 6, 'Red', 'https://youtu.be/JPiY1v3EfNc'), 
       (77, 12, 'Kazimir Bacic', 'HRT', 6, 'Red', 'https://youtu.be/JPiY1v3EfNc'), 
       (78, 12, 'Kazimir Bacic', 'HRT', 6, 'Red', 'https://youtu.be/JPiY1v3EfNc'), 
       (79, 12, 'Kazimir Bacic', 'HRT', 6, 'Red', 'https://youtu.be/JPiY1v3EfNc'), 
       (80, 12, 'Yves Schifferle', 'SRG SSR', 5, 'Red', 'https://youtu.be/LWiW2GDNZ0s'), 
	   (81, 12, 'Yoav Ginai', 'IPBC', 6, 'Pink', 'https://youtu.be/Z3mIcCllJXY'), 
       (82, 12, 'Vitalie Cojocaru', 'TRM', 6, 'Orange', 'https://youtu.be/SABOfYgGk8M'), 
       (83, 12, 'Lotta Furebäck', 'SVT', 1, 'Nude', 'https://youtu.be/BE2Fj0W4jP4'), 
	   (84, 12, 'Vasif Mammadov', 'İTV', 2, 'Green', 'https://youtu.be/8BNtaW1IEtA'), 
       (85, 12, 'Vasif Mammadov', 'İTV', 2, 'Green', 'https://youtu.be/8BNtaW1IEtA'), 
	   (86, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (87, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (88, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (89, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (90, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (91, 12, 'Kryštof Šámal', ' ČT', 6, 'White', 'https://youtu.be/ag8qxpvTTy0'), 
       (92, 12, 'Lars Lourenco', 'NPO AVROTROS', 2, 'Black', 'https://youtu.be/UOf-oKDlO6A'), 
       (93, 12, 'Lars Lourenco', 'NPO AVROTROS', 2, 'Black', 'https://youtu.be/UOf-oKDlO6A'), 
       (94, 12, 'Terhi Norvasto', 'YLE', 5, 'Neon Green', 'https://youtu.be/l6rS8Dv5g-8'), 
       (95, 12, 'Molly Plank', 'DR', 1, 'Pink', 'https://youtu.be/XVZvzZF1JOk'), 
       (96, 12, 'David Tserunyan', 'AMPTV', 1, 'Pink', 'https://youtu.be/h0q7AkYk2hY'), 
       (97, 12, 'Liana Stanciu', 'TVR', 2, 'Red', 'https://youtu.be/Bf3iPXU1RYU'), 
       (98, 12, 'Mart Normet', 'ERR', 1, 'Orange', 'https://youtu.be/HsbC-OYMA3s'), 
       (99, 12, 'Leslie Cable', 'RTBF', 4, 'Pink', 'https://youtu.be/enaSSMIo8AY'), 
       (100, 12, 'Evi Papamichael', 'CyBC', 1, 'Blue', 'https://youtu.be/r3Y5E8_kYsQ'),  
       (101, 12, 'Felix Bergsson', 'RÚV', 1, 'Blue', 'https://youtu.be/lzlTcA0OC5s'), 
       (102, 12, 'Monica Papadatos', 'ERT', 1, 'Nude', 'https://youtu.be/gJSZA0Zh2xU'), 
       (103, 12, 'Mateusz Grzesiński', 'TVP', 5, 'Orange', 'https://youtu.be/SEgF1aP-U1o'), 
       (104, 12, 'Aleksander Radic', ' RTV SLO', 5, 'Pink', 'https://youtu.be/3LXlPviGiWc'), 
       (105, 12, 'Aleksander Radic', ' RTV SLO', 5, 'Pink', 'https://youtu.be/3LXlPviGiWc'), 
       (106, 12, 'Aleksander Radic', ' RTV SLO', 5, 'Pink', 'https://youtu.be/3LXlPviGiWc'), 
       (107, 12, 'Aleksander Radic', ' RTV SLO', 5, 'Pink', 'https://youtu.be/3LXlPviGiWc'), 
       (108, 12, 'Aleksander Radic', ' RTV SLO', 5, 'Pink', 'https://youtu.be/3LXlPviGiWc'), 
       (109, 12, 'Natia Mshvenieradze', 'GPB', 1, 'White', 'https://youtu.be/HNvGZeEQvfc'), 
       (110, 12, 'Alessandro Capicchioni', 'SMRTV', 4, 'Red', 'https://youtu.be/pIdHjcqyLfo'), 
       (111, 12, 'Alessandro Capicchioni', 'SMRTV', 4, 'Red', 'https://youtu.be/pIdHjcqyLfo'), 
       (112, 12, 'Alessandro Capicchioni', 'SMRTV', 4, 'Red', 'https://youtu.be/pIdHjcqyLfo'), 
       (113, 12, 'Alessandro Capicchioni', 'SMRTV', 4, 'Red', 'https://youtu.be/pIdHjcqyLfo'), 
       (114, 12, 'Stefan Zechner', 'ORF', 6, 'Red', 'https://youtu.be/8uk64V9h0Ko'), 
       (115, 12, 'Stefan Zechner', 'ORF', 6, 'Red', 'https://youtu.be/8uk64V9h0Ko'), 
       (116, 12, 'Kleart Duraj', ' RTSH', 6, 'Red', 'https://youtu.be/TI9rSDhXwyc'), 
       (117, 12, 'Audrius Giržadas', ' LRT', 5, 'Orange', 'https://youtu.be/QsgouAEd34U'), 
       (118, 12, 'Emily Griggs', 'SBS', 5, 'Blue', 'https://youtu.be/GSoy_mJMlMY'), 
       (119, 12, 'Eva Mora', 'TVE', 6, 'Red', 'https://youtu.be/Vw6qPWhjevk'), 
       (120, 12, 'Simona Martorelli', 'RAI', 3, 'Blue', 'https://youtu.be/d6IiOSut_4M'), 
       (121, 12, 'Oksana Skybinska', 'NSTU (Suspilne)', 2, 'Yellow', 'https://youtu.be/I2oqDpefJ1s'), 
       (122, 12, 'Oksana Skybinska', 'NSTU (Suspilne)', 2, 'Yellow', 'https://youtu.be/I2oqDpefJ1s'), 
       (123, 12, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Red', 'https://youtu.be/dyGR4YWlPEs'), 
       (124, 12, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Red', 'https://youtu.be/dyGR4YWlPEs'), 
       (125, 12, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Red', 'https://youtu.be/dyGR4YWlPEs'), 
       (126, 12, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Red', 'https://youtu.be/dyGR4YWlPEs'), 
       (127, 12, 'Alexandra Wolfslast', 'ARD/NDR', 5, 'Red', 'https://youtu.be/dyGR4YWlPEs'), 
       (128, 12, 'Andrew Cartmell', 'BBC', 5, 'Pink', 'https://youtu.be/tvJEE2ryCRQ'), 
       (129, 12, 'Alexandra Redde-Amiel', 'GRF France 2', 1, 'Blue', 'https://youtu.be/fOtQJ4o-HoA');

       
INSERT INTO results (artist_id, contest_id, max_stage_reached, televoting, jury_points, place)
VALUES (1, 1, 'Semifinal', 20, 0, 39),
       (2, 1, 'Final', 46, 0, 20),
       (3, 1, 'Final', 46, 0, 20),   
	   (4, 1, 'Final', 64, 0, 17),
	   (5, 1, 'Semifinal', 17, 0, 40),
       (6, 1, 'Final', 146, 0, 5),      
	   (7, 1, 'Final', 71, 0, 12),      
       (8, 1, 'Final', 71, 0, 12),
       (9, 1, 'Final', 71, 0, 12),       
	   (10, 1, 'Final', 71, 0, 12),       
       (11, 1, 'Final', 71, 0, 12),
       (12, 1, 'Final', 71, 0, 12),       
	   (13, 1, 'Final', 71, 0, 12),  
       (14, 1, 'Semifinal', 45, 0, 28),
       (15, 1, 'Semifinal', 45, 0, 28),     
	   (16, 1, 'Semifinal', 16, 0, 41),   
	   (17, 1, 'Semifinal', 41, 0, 30),       
       (18, 1, 'Semifinal', 33, 0, 35),
       (19, 1, 'Semifinal', 33, 0, 35),  
	   (20, 1, 'Semifinal', 31, 0, 36),    
       (21, 1, 'Final', 65, 0, 16),
       (22, 1, 'Final', 21, 0, 23),  
	   (23, 1, 'Final', 259, 0, 2), 
	   (24, 1, 'Final', 259, 0, 2),       
       (25, 1, 'Final', 259, 0, 2),
       (26, 1, 'Final', 19, 0, 24),       
	   (27, 1, 'Final', 19, 0, 24), 
       (28, 1, 'Final', 19, 0, 24),
       (29, 1, 'Semifinal', 8, 0, 42),       
	   (30, 1, 'Semifinal', 8, 0, 42), 
	   (31, 1, 'Final', 81, 0, 11),    
       (32, 1, 'Final', 46, 0, 19),
       (33, 1, 'Final', 36, 0, 19),   
	   (34, 1, 'Final', 214, 0, 3),       
       (35, 1, 'Final', 71, 0, 13),
       (36, 1, 'Semifinal', 35, 0, 33),     
	   (37, 1, 'Final', 70, 0, 21), 
	   (38, 1, 'Final', 35, 0, 16),       
       (39, 1, 'Final', 35, 0, 16),
       (40, 1, 'Final', 35, 0, 16),       
	   (41, 1, 'Final', 35, 0, 16),  
       (42, 1, 'Final', 39, 0, 31),
       (43, 1, 'Final', 65, 0, 15),       
	   (44, 1, 'Semifinal', 45, 0, 27), 
	   (45, 1, 'Semifinal', 31, 0, 37), 
	   (46, 1, 'Semifinal', 42, 0, 29),       
       (47, 1, 'Final', 372, 0, 1),
       (48, 1, 'Semifinal', 36, 0, 32),  
	   (49, 1, 'Final', 112, 0, 7),      
       (50, 1, 'Final', 120, 0, 6),
       (51, 1, 'Semifinal', 22, 0, 38),  
       (52, 1, 'Final', 7, 0, 29), 
	   (53, 1, 'Final', 55, 0, 18),  
       (54, 1, 'Final', 70, 0, 14),
       (55, 1, 'Final', 12, 0, 25),       
	   (56, 1, 'Final', 21, 0, 22),       
       (57, 1, 'Final', 97, 0, 10),
       (58, 1, 'Final', 110, 0, 8),       
	   (59, 1, 'Final', 101, 0, 9), 
	   (60, 1, 'Final', 150, 0, 4),
       -- 2023
       (61, 12, 'Final', 216, 51, 5),  
       (62, 12, 'Semifinal', 3, 0, 35),
       (63, 12, 'Semifinal', 3, 0, 35),
       (64, 12, 'Semifinal', 3, 0, 35),
       (65, 12, 'Final', 16, 14, 24), 
       (66, 12, 'Final', 34, 0, 28),
       (67, 12, 'Final', 34, 0, 28),
       (68, 12, 'Final', 34, 0, 28),
       (69, 12, 'Final', 34, 0, 28),
       (70, 12, 'Final', 16, 43, 23), 
       (71, 12, 'Semifinal', 10, 0, 31),
       (72, 12, 'Semifinal', 10, 0, 31),
       (73, 12, 'Semifinal', 10, 0, 31),
       (74, 12, 'Semifinal', 10, 0, 31),
       (75, 12, 'Final', 122, 11, 23),
       (76, 12, 'Final', 122, 11, 23),
       (77, 12, 'Final', 122, 11, 23),
       (78, 12, 'Final', 122, 11, 23),
       (79, 12, 'Final', 122, 11, 23),
       (80, 12, 'Final', 31, 61, 20),
	   (81, 12, 'Final', 185, 177, 3),  
       (82, 12, 'Final', 76, 20, 18),
       (83, 12, 'Final', 243, 340, 1),   
	   (84, 12, 'Semifinal', 4, 0, 34), 
       (85, 12, 'Semifinal', 4, 0, 34), 
	   (86, 12, 'Final', 35, 94, 10), 
       (87, 12, 'Final', 35, 94, 10), 
       (88, 12, 'Final', 35, 94, 10), 
       (89, 12, 'Final', 35, 94, 10), 
       (90, 12, 'Final', 35, 94, 10), 
       (91, 12, 'Final', 35, 94, 10), 
       (92, 12, 'Semifinal', 7, 0, 32), 
       (93, 12, 'Semifinal', 7, 0, 32), 
       (94, 12, 'Final', 376, 150, 2), 
       (95, 12, 'Semifinal', 6, 0, 33), 
       (96, 12, 'Final', 53, 69, 14), 
       (97, 12, 'Semifinal', 0, 0, 37), 
       (98, 12, 'Final', 22, 146, 8), 
       (99, 12, 'Final', 55, 127, 7), 
       (100, 12, 'Final', 58, 68, 12), 
       (101, 12, 'Semifinal', 44, 0, 27), 
       (102, 12, 'Semifinal', 14, 0, 30), 
       (103, 12, 'Final', 81, 12, 19), 
       (104, 12, 'Semifinal', 7, 0, 32), 
       (105, 12, 'Final', 45, 33, 21), 
       (106, 12, 'Final', 45, 33, 21), 
       (107, 12, 'Final', 45, 33, 21), 
       (108, 12, 'Final', 45, 33, 21), 
       (109, 12, 'Semifinal', 33, 0, 29), 
       (110, 12, 'Semifinal', 0, 0, 36), 
       (111, 12, 'Semifinal', 0, 0, 36), 
       (112, 12, 'Semifinal', 0, 0, 36), 
       (113, 12, 'Semifinal', 0, 0, 36), 
       (114, 12, 'Final', 16, 104, 15), 
       (115, 12, 'Final', 16, 104, 15), 
       (116, 12, 'Final', 59, 17, 22), 
       (117, 12, 'Final', 46, 81, 11), 
       (118, 12, 'Final', 21, 130, 9), 
       (119, 12, 'Final', 5, 95, 17), 
       (120, 12, 'Final', 174, 176, 4), 
       (121, 12, 'Final', 189, 54, 6), 
       (122, 12, 'Final', 189, 54, 6), 
       (123, 12, 'Final', 15, 3, 26), 
       (124, 12, 'Final', 15, 3, 26), 
       (125, 12, 'Final', 15, 3, 26), 
       (126, 12, 'Final', 15, 3, 26), 
       (127, 12, 'Final', 15, 3, 26), 
       (128, 12, 'Final', 9, 15, 15), 
       (129, 12, 'Final', 50, 54, 16);
       
       
       


select* from countries;
select* from winners;
select * from artists;
select* from songs;
select* from contests;
select* from participations;
select* from results;
select* from bands;
select* from artists_wih_bands;
--  Quaries 
SELECT name, surname, calculate_age(date_of_birth) AS age FROM artists;


SELECT * FROM artist_song_info;
SELECT * FROM country_winners;
SELECT * FROM contest_winners;
SELECT * FROM artist_bands;

SELECT contest_id, COUNT(*) AS total_participants
FROM participations
GROUP BY contest_id;



SELECT a.name AS artist_name, s.title AS song_title
FROM artists a
JOIN songs s ON a.song_id = s.song_id;


SELECT c.year, a.name AS winner_name, r.jury_points
FROM contests c
JOIN winners w ON c.contest_id = w.contest_id
JOIN artists a ON w.artist_id = a.artist_id
JOIN results r ON w.artist_id = r.artist_id AND w.contest_id = r.contest_id
WHERE r.place = 1;




SELECT a.artist_id, a.name, COUNT(*) AS num_of_participations
FROM artists a
JOIN participations p ON a.artist_id = p.artist_id
GROUP BY a.artist_id, a.name
ORDER BY num_of_participations DESC
LIMIT 5;



SELECT c.year, a.name AS winner_name, r.televoting
FROM contests c
JOIN winners w ON c.contest_id = w.contest_id
JOIN artists a ON w.artist_id = a.artist_id
JOIN results r ON w.artist_id = r.artist_id AND w.contest_id = r.contest_id
WHERE r.place = 1;


SELECT contests.contest_id, AVG(calculate_age(artists.date_of_birth)) AS average_age
FROM contests
JOIN participations ON contests.contest_id = participations.contest_id
JOIN artists ON participations.artist_id = artists.artist_id
GROUP BY contests.contest_id;

SELECT gender, COUNT(*) AS artist_count
FROM artists
GROUP BY gender;


SELECT gender, AVG(YEAR(CURDATE()) - YEAR(date_of_birth)) AS average_age
FROM artists
GROUP BY gender;

SELECT language, COUNT(*) AS song_count
FROM songs
GROUP BY language
ORDER BY song_count DESC;



SELECT s.language, s.title, s.duration
FROM songs s
JOIN (
  SELECT language, MAX(duration) AS max_duration
  FROM songs
  GROUP BY language
) AS max_durations ON s.language = max_durations.language AND s.duration = max_durations.max_duration;












