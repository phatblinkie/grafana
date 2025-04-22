<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Database file
$dbfile = '/sqlitedata/database.sqlite';

// Create connection
try {
    $conn = new PDO("sqlite:$dbfile");
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Include the file with the create table statements
include 'create_tables.php';

// Create tables if they do not exist
createTables($conn);


/*
 *     CREATE TABLE IF NOT EXISTS ansible_ping_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        ip_address TEXT,
	ansible_ping TEXT NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_responded DATETIME,
        task_id INTEGER,
        UNIQUE (hostname)
    );
 */

$sql = "SELECT
    id,
    hostname,
    ansible_ping,
    last_updated,
    last_responded,
    task_id,
    -- Age in seconds for last_updated
    strftime('%s', 'now') - strftime('%s', last_updated) AS last_updated_age_seconds,
    -- Age in seconds for last_responded (handle NULL cases)
    CASE
        WHEN last_responded IS NULL THEN NULL
        ELSE strftime('%s', 'now') - strftime('%s', last_responded)
    END AS last_responded_age_seconds
FROM
    ansible_ping_status";

try {
    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Output JSON data
    echo json_encode($data);
} catch (PDOException $e) {
    echo json_encode(['error' => $e->getMessage()]);
}

// Close the connection
$conn = null;
?>
