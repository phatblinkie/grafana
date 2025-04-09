<?php
// Database credentials
$dbname = '/sqlitedata/database.sqlite';

// Create connection
$conn = new SQLite3($dbname);

// Check connection
if (!$conn) {
    die("Connection failed: " . $conn->lastErrorMsg());
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

// Sanity check function
function checkAndSetDefault(&$array, $key, $default, &$missing_fields, $allow_empty_string = false) {
    if (!isset($array[$key]) || $array[$key] === null || (!$allow_empty_string && $array[$key] === '')) {
        $array[$key] = $default;
        $missing_fields[] = $key;
        return false;
    }
    return true;
}

// Check if data exists and has all required fields
$missing_fields = [];
if ($data && isset($data['changed']) && isset($data['failed']) && isset($data['msg']) && isset($data['rc']) && isset($data['project_id']) && isset($data['task_id'])) {
    $status = $data;
    $hostname = $data['hostname'] ?? 'unknown_host';
    $results = $status['results'] ?? [];

    // Sanity checks for status fields
    if (!checkAndSetDefault($status, 'changed', false, $missing_fields)) $missing_fields[] = 'changed';
    if (!checkAndSetDefault($status, 'failed', false, $missing_fields)) $missing_fields[] = 'failed';
    if (!checkAndSetDefault($status, 'msg', '', $missing_fields, true)) $missing_fields[] = 'msg';
    if (!checkAndSetDefault($status, 'rc', 0, $missing_fields)) $missing_fields[] = 'rc';
    if (!checkAndSetDefault($status, 'project_id', 0, $missing_fields)) $missing_fields[] = 'project_id';
    if (!checkAndSetDefault($status, 'task_id', 0, $missing_fields)) $missing_fields[] = 'task_id';

    // Insert or update patching status
    $linux_patching_status_id = insertOrUpdatePatchingStatus($conn, $hostname, $status);

    // Insert or update patching results
    insertOrUpdatePatchingResults($conn, $linux_patching_status_id, $results, $status['project_id'], $status['task_id']);

    $response = ['status' => 'success'];
    if (!empty($missing_fields)) {
        $response['message'] = 'Missing fields: ' . implode(', ', $missing_fields);
    }
} else {
    $response['message'] = 'Invalid data: Missing required fields';
}

// Function to insert or update patching status
function insertOrUpdatePatchingStatus($conn, $hostname, $status) {
    $stmt = $conn->prepare("INSERT INTO linux_patching_status (hostname, changed, failed, msg, rc, project_id, task_id)
                            VALUES (:hostname, :changed, :failed, :msg, :rc, :project_id, :task_id)
                            ON CONFLICT(hostname) DO UPDATE SET changed=excluded.changed, failed=excluded.failed, msg=excluded.msg, rc=excluded.rc, project_id=excluded.project_id, task_id=excluded.task_id, timestamp=CURRENT_TIMESTAMP");
    $stmt->bindValue(':hostname', $hostname, SQLITE3_TEXT);
    $stmt->bindValue(':changed', $status['changed'], SQLITE3_INTEGER);
    $stmt->bindValue(':failed', $status['failed'], SQLITE3_INTEGER);
    $stmt->bindValue(':msg', $status['msg'], SQLITE3_TEXT);
    $stmt->bindValue(':rc', $status['rc'], SQLITE3_INTEGER);
    $stmt->bindValue(':project_id', $status['project_id'], SQLITE3_INTEGER);
    $stmt->bindValue(':task_id', $status['task_id'], SQLITE3_INTEGER);
    $stmt->execute();
    $linux_patching_status_id = $conn->lastInsertRowID();
    $stmt->close();
    return $linux_patching_status_id;
}

// Function to insert or update patching results
function insertOrUpdatePatchingResults($conn, $linux_patching_status_id, $results, $project_id, $task_id) {
    foreach ($results as $result) {
        $stmt = $conn->prepare("INSERT INTO linux_patching_results (linux_patching_status_id, result, project_id, task_id)
                                VALUES (:linux_patching_status_id, :result, :project_id, :task_id)
                                ON CONFLICT(linux_patching_status_id, result) DO UPDATE SET result=excluded.result, project_id=excluded.project_id, task_id=excluded.task_id");
        $stmt->bindValue(':linux_patching_status_id', $linux_patching_status_id, SQLITE3_INTEGER);
        $stmt->bindValue(':result', $result, SQLITE3_TEXT);
        $stmt->bindValue(':project_id', $project_id, SQLITE3_INTEGER);
        $stmt->bindValue(':task_id', $task_id, SQLITE3_INTEGER);
        $stmt->execute();
        $stmt->close();
    }
}

// Set header to JSON
header('Content-Type: application/json');
echo json_encode($response);

$conn->close();
?>
