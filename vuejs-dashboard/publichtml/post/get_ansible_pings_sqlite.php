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

$sql = "select * from ansible_ping_status";

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
