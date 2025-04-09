<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");


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

// Read POST data
$data = file_get_contents('php://input');
$data = json_decode($data, true);

// Initialize response
$response = ['status' => 'error', 'message' => 'Invalid data'];

// Check if data exists and has all required fields
if ($data && isset($data['hostname']) && isset($data['update_history']) && isset($data['project_id'])) {
    $hostname = $data['hostname'];
    $update_history = $data['update_history'];
    $project_id = $data['project_id'];

    // Function to insert update history
    function insertUpdateHistory($conn, $hostname, $project_id, $updates) {
        $stmt_check = $conn->prepare("SELECT COUNT(*) FROM windows_update_history WHERE hostname = :hostname AND project_id = :project_id AND title = :title AND date = :date AND operation = :operation AND status = :status AND COALESCE(kb, '') = COALESCE(:kb, '') AND pc = :pc");
        $stmt_insert = $conn->prepare("INSERT INTO windows_update_history (hostname, project_id, title, date, operation, status, kb, pc) VALUES (:hostname, :project_id, :title, :date, :operation, :status, :kb, :pc)");
        if (!$stmt_check || !$stmt_insert) {
            return ['status' => 'error', 'message' => 'Prepare failed: ' . $conn->errorInfo()[2]];
        }

        $duplicates = 0;
        $insertions = 0;

        foreach ($updates as $update) {
            $title = $update['Title'] ?? null;
            $date = isset($update['Date']) ? date('Y-m-d H:i:s', strtotime($update['Date'])) : null;
            $operation = $update['Operation'] ?? null;
            $status = $update['Status'] ?? null;
            $kb = $update['KB'] ?? null;
            $pc = $update['PC'] ?? null;

            $stmt_check->bindParam(':hostname', $hostname);
            $stmt_check->bindParam(':project_id', $project_id);
            $stmt_check->bindParam(':title', $title);
            $stmt_check->bindParam(':date', $date);
            $stmt_check->bindParam(':operation', $operation);
            $stmt_check->bindParam(':status', $status);
            $stmt_check->bindParam(':kb', $kb);
            $stmt_check->bindParam(':pc', $pc);
            $stmt_check->execute();
            $count = $stmt_check->fetchColumn();

            if ($count == 0) {
                $stmt_insert->bindParam(':hostname', $hostname);
                $stmt_insert->bindParam(':project_id', $project_id);
                $stmt_insert->bindParam(':title', $title);
                $stmt_insert->bindParam(':date', $date);
                $stmt_insert->bindParam(':operation', $operation);
                $stmt_insert->bindParam(':status', $status);
                $stmt_insert->bindParam(':kb', $kb);
                $stmt_insert->bindParam(':pc', $pc);
                if ($stmt_insert->execute()) {
                    $insertions++;
                } else {
                    return ['status' => 'error', 'message' => 'Execute failed: ' . $stmt_insert->errorInfo()[2]];
                }
            } else {
                $duplicates++;
            }
        }
        return ['status' => 'success', 'message' => 'Data processed successfully', 'duplicates' => $duplicates, 'insertions' => $insertions];
    }

    // Insert update history
    $response = insertUpdateHistory($conn, $hostname, $project_id, $update_history);
}

// Set header to JSON
header('Content-Type: application/json');
echo json_encode($response);

$conn = null;
?>
