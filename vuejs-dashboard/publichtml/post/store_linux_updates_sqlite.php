<?php

// Database file
$dbfile = '/sqlitedata/database.sqlite';

// Create connection
try {
    $conn = new PDO("sqlite:$dbfile");
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die(json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $e->getMessage()]));
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
if ($data && isset($data['pending_updates']) && isset($data['installed_updates']) && isset($data['hostname']) && isset($data['project_id']) && isset($data['task_id'])) {
    $hostname = $data['hostname'];
    $project_id = $data['project_id'];
    $task_id = $data['task_id'];
    $pending_updates = json_decode($data['pending_updates'], true);
    $installed_updates = json_decode($data['installed_updates'], true);

    // Parse installed updates
    $parsed_installed_updates = [];
    foreach ($installed_updates as $update) {
        $parts = preg_split('/\s{2,}/', trim($update));
        if (count($parts) === 3) {
            $parsed_installed_updates[] = [
                'name' => $parts[0],
                'version' => $parts[1],
                'repo' => $parts[2]
            ];
        }
    }

    // Parse pending updates
    $parsed_pending_updates = [];
    foreach ($pending_updates as $update) {
        $parts = preg_split('/\s{2,}/', trim($update));
        if (count($parts) === 3) {
            $parsed_pending_updates[] = [
                'name' => $parts[0],
                'version' => $parts[1],
                'repo' => $parts[2]
            ];
        }
    }

    $inserted_count = 0;
    $updated_count = 0;

    // Insert pending updates into the database
    if (!empty($parsed_pending_updates)) {
        foreach ($parsed_pending_updates as $update) {
            $stmt = $conn->prepare("INSERT INTO linux_pending_updates (hostname, update_name, version, repo, project_id, task_id) VALUES (:hostname, :update_name, :version, :repo, :project_id, :task_id)
                                    ON CONFLICT(hostname, project_id, update_name, version, repo) DO UPDATE SET update_name=excluded.update_name, version=excluded.version, repo=excluded.repo, project_id=excluded.project_id, task_id=excluded.task_id, timestamp=CURRENT_TIMESTAMP");
            if ($stmt === false) {
                $response['message'] = "Prepare failed: " . $conn->errorInfo()[2];
                echo json_encode($response);
                die();
            }
            $stmt->bindParam(':hostname', $hostname);
            $stmt->bindParam(':update_name', $update['name']);
            $stmt->bindParam(':version', $update['version']);
            $stmt->bindParam(':repo', $update['repo']);
            $stmt->bindParam(':project_id', $project_id);
            $stmt->bindParam(':task_id', $task_id);
            if (!$stmt->execute()) {
                $response['message'] = "Execute failed: " . $stmt->errorInfo()[2];
                echo json_encode($response);
                die();
            }
            if ($stmt->rowCount() === 1) {
                $inserted_count++;
            } elseif ($stmt->rowCount() === 2) {
                $updated_count++;
            }
        }
    }

    // Insert installed updates into the database
    if (!empty($parsed_installed_updates)) {
        foreach ($parsed_installed_updates as $update) {
            $stmt = $conn->prepare("INSERT INTO linux_installed_updates (hostname, update_name, version, repo, project_id, task_id) VALUES (:hostname, :update_name, :version, :repo, :project_id, :task_id)
                                    ON CONFLICT(hostname, project_id, update_name, version, repo) DO UPDATE SET update_name=excluded.update_name, version=excluded.version, repo=excluded.repo, project_id=excluded.project_id, task_id=excluded.task_id, timestamp=CURRENT_TIMESTAMP");
            if ($stmt === false) {
                $response['message'] = "Prepare failed: " . $conn->errorInfo()[2];
                echo json_encode($response);
                die();
            }
            $stmt->bindParam(':hostname', $hostname);
            $stmt->bindParam(':update_name', $update['name']);
            $stmt->bindParam(':version', $update['version']);
            $stmt->bindParam(':repo', $update['repo']);
            $stmt->bindParam(':project_id', $project_id);
            $stmt->bindParam(':task_id', $task_id);
            if (!$stmt->execute()) {
                $response['message'] = "Execute failed: " . $stmt->errorInfo()[2];
                echo json_encode($response);
                die();
            }
            if ($stmt->rowCount() === 1) {
                $inserted_count++;
            } elseif ($stmt->rowCount() === 2) {
                $updated_count++;
            }
        }
    }

    // Update linux_updates table with the total number of installed and available updates
    $total_pending_updates = count($parsed_pending_updates);
    $total_installed_updates = count($parsed_installed_updates);

    $stmt = $conn->prepare("INSERT INTO linux_updates (hostname, pending_updates, installed_updates, project_id, task_id) VALUES (:hostname, :pending_updates, :installed_updates, :project_id, :task_id)
                            ON CONFLICT(hostname, project_id) DO UPDATE SET pending_updates=excluded.pending_updates, installed_updates=excluded.installed_updates, project_id=excluded.project_id, task_id=excluded.task_id, timestamp=CURRENT_TIMESTAMP");
    if ($stmt === false) {
        $response['message'] = "Prepare failed: " . $conn->errorInfo()[2];
        echo json_encode($response);
        die();
    }
    $stmt->bindParam(':hostname', $hostname);
    $stmt->bindParam(':pending_updates', $total_pending_updates);
    $stmt->bindParam(':installed_updates', $total_installed_updates);
    $stmt->bindParam(':project_id', $project_id);
    $stmt->bindParam(':task_id', $task_id);
    if (!$stmt->execute()) {
        $response['message'] = "Execute failed: " . $stmt->errorInfo()[2];
        echo json_encode($response);
        die();
    }

    $response = [
        'status' => 'success',
        'message' => 'Updates stored successfully',
        'inserted' => $inserted_count,
        'updated' => $updated_count
    ];
} else {
    $response['message'] = 'Invalid data: Missing required fields';
}

// Set header to JSON
header('Content-Type: application/json');
echo json_encode($response);

$conn = null;
?>
