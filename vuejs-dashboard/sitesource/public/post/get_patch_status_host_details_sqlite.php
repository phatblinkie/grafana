<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$dsn = 'sqlite:/sqlitedata/database.sqlite';

try {
    $conn = new PDO($dsn);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $e->getMessage()]));
}

// Include the file with the create table statements
include 'create_tables.php';

// Create tables if they do not exist
createTables($conn);

$project_id = $_GET['project_id'];
$hostname = $_GET['hostname'];

// Fetch the most recent data for the specified host from patching_status table
$query = "
    SELECT *
    FROM patching_status
    WHERE project_id = :project_id
    AND hostname = :hostname
    ORDER BY timestamp DESC
    LIMIT 1";
$stmt = $conn->prepare($query);
$stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
$stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
$stmt->execute();
$hostDetails = $stmt->fetch(PDO::FETCH_ASSOC);

if ($hostDetails) {
    // Fetch the list of updates for the specified host
    $query = "
        SELECT title
        FROM patching_updates
        WHERE patching_status_id = :patching_status_id and update_type != 'filtered'";
    $stmt = $conn->prepare($query);
    $stmt->bindParam(':patching_status_id', $hostDetails['id'], PDO::PARAM_INT);
    $stmt->execute();
    $updates = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $updates[] = $row['title'];
    }
    $hostDetails['updates'] = $updates;
}

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
echo json_encode($hostDetails);

$conn = null;
?>
