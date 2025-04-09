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

// Retrieve project_id, hostname, and time_frame from query parameters
$project_id = isset($_GET['project_id']) ? intval($_GET['project_id']) : 0;
$hostname = isset($_GET['hostname']) ? $_GET['hostname'] : '';
$time_frame = isset($_GET['time_frame']) ? $_GET['time_frame'] : 'today';

// Determine the date range based on the time frame
switch ($time_frame) {
    case 'week':
        $date_condition = "last_updated >= datetime('now', '-7 days')";
        break;
    case 'month':
        $date_condition = "last_updated >= datetime('now', '-1 month')";
        break;
    case '90days':
        $date_condition = "last_updated >= datetime('now', '-3 months')";
        break;
    case 'today':
    default:
        $date_condition = "date(last_updated) = date('now')";
        break;
}

// Updated SQL query with subquery to find the ip_address
$sql = "SELECT
  last_updated,
  disk_capacity,
  proc_usage,
  uptime
FROM
  system_status_history
WHERE
  project_id = :project_id
  AND (
    hostname = :hostname
    OR hostname LIKE :hostname_like
  )
  AND $date_condition
ORDER BY
  last_updated ASC";

$stmt = $conn->prepare($sql);
$hostname_like = $hostname . '.%';
$stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
$stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
$stmt->bindParam(':hostname_like', $hostname_like, PDO::PARAM_STR);
$stmt->execute();

$data = [];
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    // Parse disk_capacity to handle multiple disks
    $row['disk_capacity'] = array_map(function($disk) {
        $parts = explode(' ', $disk);
        if (count($parts) === 2) {
            list($name, $used) = $parts;
            return ['name' => $name, 'used' => (float) rtrim($used, '%')];
        }
        return null;
    }, explode(', ', $row['disk_capacity'] ?? ''));
    $row['disk_capacity'] = array_filter($row['disk_capacity']); // Remove null values
    $data[] = $row;
}

echo json_encode($data);
?>
