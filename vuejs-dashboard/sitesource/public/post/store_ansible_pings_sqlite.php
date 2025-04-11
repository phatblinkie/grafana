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
        $required_fields = ['hostname', 'ansible_ping', 'task_id', 'ip_address'];
        foreach ($required_fields as $field) {
            if (!isset($item[$field])) {
                $valid = false;
                $missing_fields[$index][] = $field;
            }
        }
    }
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
    if ($valid) {
        // Prepare and bind for system_status table
        $stmt = $conn->prepare("INSERT INTO ansible_ping_status (hostname, ip_address, ansible_ping, task_id, last_updated, last_responded)
        VALUES (:hostname, :ip_address, :ansible_ping, :task_id, datetime('now'), CASE WHEN :ansible_ping = 'pong' THEN datetime('now') ELSE NULL END)
        ON CONFLICT(hostname) DO UPDATE SET ansible_ping=excluded.ansible_ping, ip_address=excluded.ip_address, task_id=excluded.task_id, last_updated=datetime('now'), last_responded=CASE WHEN excluded.ansible_ping='pong' THEN datetime('now') ELSE last_responded END");

        $success = true;
        $errors = [];

        foreach ($data as $item) {
            // Extract data
	    $hostname = $item['hostname'];
            $ip_address = $item['ip_address'];
            $ansible_ping = $item['ansible_ping'];
            $task_id = $item['task_id'];

            // Execute the statement for system_status table
	    $stmt->bindParam(':hostname', $hostname);
	    $stmt->bindParam(":ip_address", $ip_address);
            $stmt->bindParam(':ansible_ping', $ansible_ping);
            $stmt->bindParam(':task_id', $task_id);

            if (!$stmt->execute()) {
                $success = false;
                $errors[] = $stmt->errorInfo();
                break;
            }

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
