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

// Retrieve project_id from query parameters
$project_id = isset($_GET['project_id']) ? intval($_GET['project_id']) : 0;

$sql = "SELECT
  id,
  hostname,
  ansible_ping,
  disk_capacity,
  proc_usage,
  app_check,
  last_updated,
  last_responded,
  uptime,
  project_id,
  task_id
FROM
  system_status
WHERE
  project_id = :project_id
ORDER BY
  id DESC";

try {
    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
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
