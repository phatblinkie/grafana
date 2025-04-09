<?php

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

// Read POST data
$data = file_get_contents('php://input');
$data = json_decode($data, true);

// Initialize response
$response = ['status' => 'error', 'message' => 'Invalid data', 'received_data' => $data];

// Check if data exists and has all required fields
if ($data && is_array($data)) {
    $valid = true;
    $missing_fields = [];

    foreach ($data as $index => $item) {
        $required_fields = ['hostname', 'ansible_ping', 'disk_capacity', 'proc_usage', 'app_check', 'uptime', 'project_id', 'task_id'];
        foreach ($required_fields as $field) {
            if (!isset($item[$field])) {
                $valid = false;
                $missing_fields[$index][] = $field;
            }
        }
    }

    if ($valid) {
        // Prepare and bind for system_status table
        $stmt = $conn->prepare("INSERT INTO system_status (hostname, ansible_ping, disk_capacity, proc_usage, app_check, uptime, project_id, task_id, last_updated, last_responded)
        VALUES (:hostname, :ansible_ping, :disk_capacity, :proc_usage, :app_check, :uptime, :project_id, :task_id, datetime('now'), CASE WHEN :ansible_ping = 'pong' THEN datetime('now') ELSE NULL END)
        ON CONFLICT(hostname, project_id) DO UPDATE SET ansible_ping=excluded.ansible_ping, disk_capacity=excluded.disk_capacity, proc_usage=excluded.proc_usage, app_check=excluded.app_check, uptime=excluded.uptime, task_id=excluded.task_id, last_updated=datetime('now'), last_responded=CASE WHEN excluded.ansible_ping='pong' THEN datetime('now') ELSE last_responded END");

        // Prepare and bind for system_status_history table
        $stmt_history = $conn->prepare("INSERT INTO system_status_history (hostname, ansible_ping, disk_capacity, proc_usage, app_check, uptime, project_id, task_id, last_updated, last_responded)
        VALUES (:hostname, :ansible_ping, :disk_capacity, :proc_usage, :app_check, :uptime, :project_id, :task_id, datetime('now'), CASE WHEN :ansible_ping = 'pong' THEN datetime('now') ELSE NULL END)");

        $success = true;
        $errors = [];

        foreach ($data as $item) {
            // Extract data
            $hostname = $item['hostname'];
            $ansible_ping = $item['ansible_ping'];
            $disk_capacity = $item['disk_capacity'];
            $proc_usage = implode(",", $item['proc_usage']); // Convert array to string
            $app_check = $item['app_check'];
            $uptime = $item['uptime'];
            $project_id = $item['project_id'];
            $task_id = $item['task_id'];

            // Execute the statement for system_status table
            $stmt->bindParam(':hostname', $hostname);
            $stmt->bindParam(':ansible_ping', $ansible_ping);
            $stmt->bindParam(':disk_capacity', $disk_capacity);
            $stmt->bindParam(':proc_usage', $proc_usage);
            $stmt->bindParam(':app_check', $app_check);
            $stmt->bindParam(':uptime', $uptime);
            $stmt->bindParam(':project_id', $project_id);
            $stmt->bindParam(':task_id', $task_id);

            if (!$stmt->execute()) {
                $success = false;
                $errors[] = $stmt->errorInfo();
                break;
            }

            // Execute the statement for system_status_history table
            $stmt_history->bindParam(':hostname', $hostname);
            $stmt_history->bindParam(':ansible_ping', $ansible_ping);
            $stmt_history->bindParam(':disk_capacity', $disk_capacity);
            $stmt_history->bindParam(':proc_usage', $proc_usage);
            $stmt_history->bindParam(':app_check', $app_check);
            $stmt_history->bindParam(':uptime', $uptime);
            $stmt_history->bindParam(':project_id', $project_id);
            $stmt_history->bindParam(':task_id', $task_id);

            if (!$stmt_history->execute()) {
                $success = false;
                $errors[] = $stmt_history->errorInfo();
                break;
            }
        }

        // Remove entries older than 4 months from system_status_history table
        $delete_stmt = $conn->prepare("DELETE FROM system_status_history WHERE last_updated < datetime('now', '-4 months')");
        if (!$delete_stmt->execute()) {
            $success = false;
            $errors[] = $delete_stmt->errorInfo();
        }

        // Return a response
        if ($success) {
            $response = ['status' => 'success', 'message' => 'Data processed successfully', 'received_data' => $data];
        } else {
            $response = ['status' => 'error', 'message' => 'Failed to insert data', 'errors' => $errors, 'received_data' => $data];
        }
    } else {
        $response = ['status' => 'error', 'message' => 'Missing fields', 'missing_fields' => $missing_fields, 'received_data' => $data];
    }
}

// Set header to JSON
header('Content-Type: application/json');
echo json_encode($response);
?>
