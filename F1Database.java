import java.sql.*;
import java.util.Scanner;

public class F1Database {
    private final static String JDBC_CONNECTOR = "jdbc:postgresql";
    private final static String HOST = "localhost:5432";
    private final static String DB_NAME = "postgres";
    private final static String USER = "javauser";
    private final static String PASSWORD = "securepass123";
    private final static String SCHEMA = "public";
    public static void main(String[] args) {
        String url = String.format("%s://%s/%s?user=%s&password=%s&currentSchema=%s",
                JDBC_CONNECTOR, HOST, DB_NAME, USER, PASSWORD, SCHEMA);
        System.out.println("Welcome to the system to interact with the database of Formula 1");
        try (Connection conn = DriverManager.getConnection(url)) {
            Scanner scanner = new Scanner(System.in);
            int choice;
            do {
                System.out.println("\nChoose an operation:");
                System.out.println("1. Operation 1");
                System.out.println("2. Operation 2");
                System.out.println("3. Operation 3");
                System.out.println("4. Operation 4");
                System.out.println("5. Operation 5");
                System.out.println("0. Exit");
                System.out.print("Choiche: ");
                choice = scanner.nextInt();
                switch (choice) {
                    case 1 -> averageLapTimeDriver10(conn);
                    case 2 -> driverFatestLap3(conn);
                    case 3 -> {
                        System.out.print("Enter the SSN of the driver (surname + number): ");
                        scanner.nextLine();
                        String driverId = scanner.nextLine();
                        circuitsFastestQualAndRace(conn, driverId);
                    }
                    case 4 -> totalPointTeams(conn);
                    case 5 -> topCOuntryBYDriverPoints(conn);
                    case 0 -> System.out.println("Created by Stefano Pugnani");
                    default -> System.out.println("Invalid choice.");
                }
            } while (choice != 0);
        } catch (SQLException e) {
            System.out.println("Error during the connection with the database: " + e.getMessage());
        }
    }

    public static void averageLapTimeDriver10(Connection con) {
        String query = """
    SELECT
        d.ssn AS driver_id,
        d.name || ' ' || d.surname AS driver_name,
        AVG(EXTRACT(EPOCH FROM t.lapTime)) AS avg_lap_time_seconds,
        COUNT(*) AS total_laps
    FROM Time t
    JOIN Driver d ON t.driver = d.ssn
    WHERE t.boxStop = FALSE
    GROUP BY d.ssn, d.name, d.surname
    HAVING COUNT(*) >= 10
    ORDER BY avg_lap_time_seconds;
    """;
        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(query)) {
            System.out.println("Average lap time for drivers (min. 10 laps, excluding pit stops):");
            while (rs.next()) {
                String driverName = rs.getString("driver_name");
                double avgTime = rs.getDouble("avg_lap_time_seconds");
                int laps = rs.getInt("total_laps");
                System.out.printf("%s - %.2f seconds (%d laps)%n", driverName, avgTime, laps);
            }
        } catch (SQLException e) {
            System.out.println("Error in the query: " + e.getMessage());
        }
    }

    public static void driverFatestLap3(Connection con) {
        String query = """
    WITH FastestLaps AS (
        SELECT r.driver, r.timeStamp, r.lapNumber, t.lapTime, rp.circuit
        FROM Race r
        JOIN Time t ON r.timeStamp = t.timeStamp AND r.driver = t.driver
        JOIN RaceParticipation rp ON r.driver = rp.driver
        WHERE t.boxStop = FALSE
    ),
    CircuitFastest AS (
        SELECT circuit, MIN(EXTRACT(EPOCH FROM lapTime)) AS bestTime
        FROM FastestLaps
        GROUP BY circuit
    ),
    DriverFastest AS (
        SELECT f.driver, f.circuit
        FROM FastestLaps f
        JOIN CircuitFastest cf ON f.circuit = cf.circuit AND EXTRACT(EPOCH FROM f.lapTime) = cf.bestTime
    )
    SELECT d.name || ' ' || d.surname AS driver_name,
           COUNT(DISTINCT df.circuit) AS num_races,
           STRING_AGG(DISTINCT c.name || ' (' || c.length || 'm)', ', ') AS circuits
    FROM DriverFastest df
    JOIN Driver d ON df.driver = d.ssn
    JOIN Circuit c ON df.circuit = c.name
    GROUP BY d.name, d.surname
    HAVING COUNT(DISTINCT df.circuit) >= 3
    ORDER BY num_races DESC;
    """;
        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(query)) {
            System.out.println("Drivers with fastest laps in at least 3 races:");
            while (rs.next()) {
                String name = rs.getString("driver_name");
                int races = rs.getInt("num_races");
                String circuits = rs.getString("circuits");
                System.out.printf("%s: %d circuits – %s%n", name, races, circuits);
            }
        } catch (SQLException e) {
            System.out.println("Error in the query: " + e.getMessage());
        }
    }

    public static void circuitsFastestQualAndRace(Connection con, String driverId) {
        String query = """
    WITH QualLaps AS (
        SELECT rp.circuit, t.lapTime
        FROM Qualification q
        JOIN Time t ON q.timeStamp = t.timeStamp AND q.driver = t.driver
        JOIN RaceParticipation rp ON q.driver = rp.driver
        WHERE q.driver = ? AND t.boxStop = FALSE
    ),
    BestQual AS (
        SELECT circuit, MIN(EXTRACT(EPOCH FROM lapTime)) AS best_time
        FROM QualLaps
        GROUP BY circuit
    ),
    RaceLaps AS (
        SELECT rp.circuit, t.lapTime
        FROM Race r
        JOIN Time t ON r.timeStamp = t.timeStamp AND r.driver = t.driver
        JOIN RaceParticipation rp ON r.driver = rp.driver
        WHERE r.driver = ? AND t.boxStop = FALSE
    ),
    BestRace AS (
        SELECT circuit, MIN(EXTRACT(EPOCH FROM lapTime)) AS best_time
        FROM RaceLaps
        GROUP BY circuit
    )
    SELECT bq.circuit
    FROM BestQual bq
    JOIN BestRace br ON bq.circuit = br.circuit AND bq.best_time = br.best_time;
    """;
        try (PreparedStatement ps = con.prepareStatement(query)) {
            ps.setString(1, driverId);
            ps.setString(2, driverId);
            try (ResultSet rs = ps.executeQuery()) {
                System.out.println("Circuits where driver " + driverId + " had fastest lap in both Qualification and Race:");
                while (rs.next()) {
                    String circuit = rs.getString("circuit");
                    System.out.println("- " + circuit);
                }
            }
        } catch (SQLException e) {
            System.out.println("Error in the query: " + e.getMessage());
        }
    }

    public static void totalPointTeams(Connection con) {
        String query = """
        SELECT t.name AS team_name, SUM(d.points) AS total_points
        FROM Driver d
        JOIN WorkFor w ON d.ssn = w.driver
        JOIN Team t ON t.name = w.teamN AND t.yrFound = w.teamYrFound
        GROUP BY t.name
        ORDER BY total_points DESC;
        """;
        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(query)) {
            System.out.println("Total points per team:");
            while (rs.next()) {
                String team = rs.getString("team_name");
                int points = rs.getInt("total_points");
                System.out.printf("%s - %d points%n", team, points);
            }
        } catch (SQLException e) {
            System.out.println("Error in the query: " + e.getMessage());
        }
    }

    public static void topCOuntryBYDriverPoints(Connection con) {
        String query = """
        SELECT d.country, SUM(d.points) AS total_points
        FROM Driver d
        GROUP BY d.country
        ORDER BY total_points DESC
        LIMIT 1;
        """;
        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(query)) {
            if (rs.next()) {
                String country = rs.getString("country");
                int points = rs.getInt("total_points");
                System.out.printf("Country with most driver points: %s (%d points)%n", country, points);
            }
        } catch (SQLException e) {
            System.out.println("Error in the query:" + e.getMessage());
        }
    }
}
