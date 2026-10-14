
CREATE TABLE Country (
                         name VARCHAR(100) PRIMARY KEY,
                         population INT NOT NULL
);

CREATE TABLE Team (
                      yrFound INT,
                      name VARCHAR(100),
                      nGPWin INT,
                      nConChampWin INT,
                      nDrivChampWin INT,
                      country VARCHAR(100),
                      PRIMARY KEY (name, yrFound),
                      FOREIGN KEY (country) REFERENCES Country(name)
);

CREATE TABLE Car (
                     carid VARCHAR(50) PRIMARY KEY,
                     costOfRepay INT,
                     costOfBuilding INT,
                     teamName VARCHAR(100),
                     teamYr INT,
                     FOREIGN KEY (teamName, teamYr) REFERENCES Team(name, yrFound)
);

CREATE TABLE Sponsor (
                         name VARCHAR(100) PRIMARY KEY
);

CREATE TABLE Driver (
                        ssn VARCHAR(20) PRIMARY KEY,
                        points INT,
                        surname VARCHAR(100),
                        name VARCHAR(100),
                        age INT,
                        nGPWin INT,
                        carid VARCHAR(50),
                        country VARCHAR(100),
                        FOREIGN KEY (carid) REFERENCES Car(carid),
                        FOREIGN KEY (country) REFERENCES Country(name)
);

CREATE TABLE Circuit (
                         name VARCHAR(100) PRIMARY KEY,
                         length Int,
                         country VARCHAR(100),
                         FOREIGN KEY (country) REFERENCES Country(name)
);

CREATE TABLE Tyreset (
                         seriesNumber VARCHAR(50),
                         car VARCHAR(50),
                         color VARCHAR(50),
                         FOREIGN KEY (car) REFERENCES Car(carid),
                         PRIMARY KEY(seriesNumber, car)
);

CREATE TABLE Time (
                      timeStamp TIMESTAMP(3),
                      driver VARCHAR(20),
                      lapTime INTERVAL,
                      boxStop bool,
                      PRIMARY KEY (timeStamp, driver),
                      FOREIGN KEY (driver) REFERENCES Driver(ssn)
);

CREATE TABLE Qualification (
                               timeStamp TIMESTAMP,
                               driver VARCHAR(20),
                               lapType VARCHAR(50),
                               PRIMARY KEY (timeStamp, driver),
                               FOREIGN KEY (timeStamp, driver) REFERENCES Time(timeStamp, driver)
);

CREATE TABLE Prove (
                       timeStamp TIMESTAMP,
                       driver VARCHAR(20),
                       lapType VARCHAR(50),
                       PRIMARY KEY (timeStamp, driver),
                       FOREIGN KEY (timeStamp, driver) REFERENCES Time(timeStamp, driver)
);

CREATE TABLE Race (
                      timeStamp TIMESTAMP,
                      driver VARCHAR(20),
                      lapNumber INT,
                      PRIMARY KEY (timeStamp, driver),
                      FOREIGN KEY (timeStamp, driver) REFERENCES Time(timeStamp, driver)
);

CREATE TABLE MotorUser (
                           nameT VARCHAR(100),
                           yearFoundT INT,
                           costOfBuying INT,
                           PRIMARY KEY (nameT, yearFoundT),
                           FOREIGN KEY (nameT, yearFoundT) REFERENCES Team(name, yrFound)
);

CREATE TABLE MotorProducer (
                               yearFoundT INT,
                               nameT VARCHAR(100),
                               timeToProduce INT,
                               PRIMARY KEY (nameT, yearFoundT),
                               FOREIGN KEY (nameT, yearFoundT) REFERENCES Team(name, yrFound)
);

CREATE TABLE RaceIn (
                        carId VARCHAR(50),
                        nameCirc VARCHAR(100),
                        PRIMARY KEY (carId, nameCirc),
                        FOREIGN KEY (carId) REFERENCES Car(carid),
                        FOREIGN KEY (nameCirc) REFERENCES Circuit(name)
);

CREATE TABLE Team_S (
                        teamN VARCHAR(100),
                        teamYrFound INT,
                        sponsor VARCHAR(100),
                        PRIMARY KEY (teamN, teamYrFound, sponsor),
                        FOREIGN KEY (teamN, teamYrFound) REFERENCES Team(name, yrFound),
                        FOREIGN KEY (sponsor) REFERENCES Sponsor(name) ON DELETE CASCADE
);

CREATE TABLE WorkFor (
                         driver VARCHAR(20),
                         teamN VARCHAR(100),
                         teamYrFound INT,
                         PRIMARY KEY (driver),
                         FOREIGN KEY (driver) REFERENCES Driver(ssn),
                         FOREIGN KEY (teamN, teamYrFound) REFERENCES Team(name, yrFound)
);

CREATE TABLE RaceParticipation (
                                   driver VARCHAR(20) ,
                                   carid VARCHAR(50),
                                   circuit VARCHAR(100),
                                   PRIMARY KEY (driver, circuit),
                                   FOREIGN KEY (driver) REFERENCES Driver(ssn),
                                   FOREIGN KEY (carid) REFERENCES Car(carid),
                                   FOREIGN KEY (circuit) REFERENCES Circuit(name)
);

-- TRIGGERS


-- 1. check that each team has two car not less not more
CREATE OR REPLACE FUNCTION check_team_car_count()
    RETURNS TRIGGER AS $$
DECLARE
    team_rec RECORD;
BEGIN
        FOR team_rec IN SELECT name, yrFound FROM Team LOOP
                IF (SELECT COUNT(*) FROM Car
                    WHERE teamName = team_rec.name AND teamYr = team_rec.yrFound) != 2 THEN
                    RAISE EXCEPTION 'Team % (%) does not have two cars', team_rec.name, team_rec.yrFound;
                END IF;
            END LOOP;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER check_all_teams_after_changes
    AFTER INSERT OR UPDATE OR DELETE ON Car
    FOR EACH STATEMENT
    EXECUTE FUNCTION check_team_car_count();

-- 2. It let us to be sure that lapTime is not null, if lapTime=null then boxstop=true, lapTime=not null then boxstop is false
CREATE OR REPLACE FUNCTION check_time_constraints()
    RETURNS TRIGGER AS $$
BEGIN
    -- check that boxstop is not null
    IF NEW.boxstop IS NULL THEN
        RAISE EXCEPTION 'boxstop must be true or false';
    END IF;
    IF (NEW.lapTime IS NOT NULL AND NEW.boxStop = TRUE) OR
       (NEW.lapTime IS NULL AND NEW.boxStop =FALSE ) THEN
        RAISE EXCEPTION 'Invalid combination: lapTime=%, boxStop=%',
            NEW.lapTime, NEW.boxStop;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER time_constraints_trigger
    BEFORE INSERT OR UPDATE ON Time
    FOR EACH ROW EXECUTE FUNCTION check_time_constraints();

--3. to check that there are a maximum 20 cars for each circuit
CREATE OR REPLACE FUNCTION check_circuit_max_cars()
    RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM RaceIn WHERE nameCirc = NEW.nameCirc) > 20 THEN
        RAISE EXCEPTION 'Circuit % has reached the maximum of 20 cars', NEW.nameCirc;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER circuit_max_cars_trigger
    BEFORE INSERT OR UPDATE ON RaceIn
    FOR EACH ROW EXECUTE FUNCTION check_circuit_max_cars();

--4. so that race, prove and qualification are not the same
CREATE OR REPLACE FUNCTION check_time_exclusivity()
    RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Qualification WHERE timeStamp = NEW.timeStamp AND driver = NEW.driver) THEN
        RAISE EXCEPTION 'Entry already exists in Qualification';
    ELSIF EXISTS (SELECT 1 FROM Prove WHERE timeStamp = NEW.timeStamp AND driver = NEW.driver) THEN
        RAISE EXCEPTION 'Entry already exists in Prove';
    ELSIF EXISTS (SELECT 1 FROM Race WHERE timeStamp = NEW.timeStamp AND driver = NEW.driver) THEN
        RAISE EXCEPTION 'Entry already exists in Race';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER qualification_exclusivity_trigger
    BEFORE INSERT ON Qualification
    FOR EACH ROW EXECUTE FUNCTION check_time_exclusivity();

CREATE TRIGGER prove_exclusivity_trigger
    BEFORE INSERT ON Prove
    FOR EACH ROW EXECUTE FUNCTION check_time_exclusivity();

CREATE TRIGGER race_exclusivity_trigger
    BEFORE INSERT ON Race
    FOR EACH ROW EXECUTE FUNCTION check_time_exclusivity();