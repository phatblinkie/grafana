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

// Sanity check function
function checkAndSetDefault(&$array, $key, $default, &$missing_fields) {
    if (!isset($array[$key]) || $array[$key] === null || $array[$key] === '') {
        $array[$key] = $default;
        $missing_fields[] = $key;
        return false;
    }
    return true;
}

// Check if data exists and has all required fields
$missing_fields = [];
if ($data && isset($data['changed']) && isset($data['failed']) && isset($data['failed_update_count']) && isset($data['found_update_count']) && isset($data['installed_update_count']) && isset($data['reboot_required']) && isset($data['rebooted']) && isset($data['project_id']) && isset($data['task_id'])) {
    $status = $data;
    $hostname = $data['hostname'] ?? 'unknown_host';
    $filtered_updates = $status['filtered_updates'] ?? [];
    $updates = $status['updates'] ?? [];

    // Sanity checks for status fields
    if (!checkAndSetDefault($status, 'changed', false, $missing_fields)) $missing_fields[] = 'changed';
    if (!checkAndSetDefault($status, 'failed', false, $missing_fields)) $missing_fields[] = 'failed';
    if (!checkAndSetDefault($status, 'failed_update_count', 0, $missing_fields)) $missing_fields[] = 'failed_update_count';
    if (!checkAndSetDefault($status, 'found_update_count', 0, $missing_fields)) $missing_fields[] = 'found_update_count';
    if (!checkAndSetDefault($status, 'installed_update_count', 0, $missing_fields)) $missing_fields[] = 'installed_update_count';
    if (!checkAndSetDefault($status, 'reboot_required', false, $missing_fields)) $missing_fields[] = 'reboot_required';
    if (!checkAndSetDefault($status, 'rebooted', false, $missing_fields)) $missing_fields[] = 'rebooted';
    if (!checkAndSetDefault($status, 'project_id', 0, $missing_fields)) $missing_fields[] = 'project_id';
    if (!checkAndSetDefault($status, 'task_id', 0, $missing_fields)) $missing_fields[] = 'task_id';

    // Insert or update patching status
    $patching_status_id = insertOrUpdatePatchingStatus($conn, $hostname, $status);

    // Insert or update filtered updates
    insertOrUpdatePatchingUpdates($conn, $patching_status_id, $filtered_updates, 'filtered', $status['project_id'], $status['task_id']);

    // Insert or update updates
    insertOrUpdatePatchingUpdates($conn, $patching_status_id, $updates, 'regular', $status['project_id'], $status['task_id']);

    $response = ['status' => 'success'];
    if (!empty($missing_fields)) {
        $response['message'] = 'Missing fields: ' . implode(', ', $missing_fields);
    }
} else {
    $response['message'] = 'Invalid data: Missing required fields';
}

// Function to insert or update patching status
function insertOrUpdatePatchingStatus($conn, $hostname, $status) {
    // Check if the record exists
    $stmt = $conn->prepare("SELECT id FROM patching_status WHERE hostname = :hostname AND project_id = :project_id");
    $stmt->bindParam(':hostname', $hostname);
    $stmt->bindParam(':project_id', $status['project_id']);
    $stmt->execute();
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        // Update existing record
        $stmt = $conn->prepare("UPDATE patching_status SET
                                changed = :changed,
                                failed = :failed,
                                failed_update_count = :failed_update_count,
                                found_update_count = :found_update_count,
                                installed_update_count = :installed_update_count,
                                reboot_required = :reboot_required,
                                rebooted = :rebooted,
                                task_id = :task_id,
                                timestamp = CURRENT_TIMESTAMP
                                WHERE id = :id");
        $stmt->bindParam(':changed', $status['changed']);
        $stmt->bindParam(':failed', $status['failed']);
        $stmt->bindParam(':failed_update_count', $status['failed_update_count']);
        $stmt->bindParam(':found_update_count', $status['found_update_count']);
        $stmt->bindParam(':installed_update_count', $status['installed_update_count']);
        $stmt->bindParam(':reboot_required', $status['reboot_required']);
        $stmt->bindParam(':rebooted', $status['rebooted']);
        $stmt->bindParam(':task_id', $status['task_id']);
        $stmt->bindParam(':id', $existing['id']);
        $stmt->execute();
        return $existing['id'];
    } else {
        // Insert new record
        $stmt = $conn->prepare("INSERT INTO patching_status (hostname, changed, failed, failed_update_count, found_update_count, installed_update_count, reboot_required, rebooted, project_id, task_id, timestamp)
                                VALUES (:hostname, :changed, :failed, :failed_update_count, :found_update_count, :installed_update_count, :reboot_required, :rebooted, :project_id, :task_id, CURRENT_TIMESTAMP)");
        $stmt->bindParam(':hostname', $hostname);
        $stmt->bindParam(':changed', $status['changed']);
        $stmt->bindParam(':failed', $status['failed']);
        $stmt->bindParam(':failed_update_count', $status['failed_update_count']);
        $stmt->bindParam(':found_update_count', $status['found_update_count']);
        $stmt->bindParam(':installed_update_count', $status['installed_update_count']);
        $stmt->bindParam(':reboot_required', $status['reboot_required']);
        $stmt->bindParam(':rebooted', $status['rebooted']);
        $stmt->bindParam(':project_id', $status['project_id']);
        $stmt->bindParam(':task_id', $status['task_id']);
        $stmt->execute();
        return $conn->lastInsertId();
    }
}

// Function to insert or update patching updates
function insertOrUpdatePatchingUpdates($conn, $patching_status_id, $updates, $update_type, $project_id, $task_id) {
    foreach ($updates as $update_id => $update) {
        $categories = implode(", ", $update['categories']);
        $kb = implode(", ", $update['kb']);
        $downloaded = $update['downloaded'] ? 1 : 0;
        $installed = $update['installed'] ? 1 : 0;

        // Check if the record exists
        $stmt = $conn->prepare("SELECT id FROM patching_updates WHERE update_id = :update_id AND patching_status_id = :patching_status_id");
        $stmt->bindParam(':update_id', $update_id);
        $stmt->bindParam(':patching_status_id', $patching_status_id);
        $stmt->execute();
        $existing = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($existing) {
            // Update existing record
            $stmt = $conn->prepare("UPDATE patching_updates SET
                                    title = :title,
                                    categories = :categories,
                                    downloaded = :downloaded,
                                    installed = :installed,
                                    kb = :kb,
                                    update_type = :update_type,
                                    project_id = :project_id,
                                    task_id = :task_id
                                    WHERE id = :id");
            $stmt->bindParam(':title', $update['title']);
            $stmt->bindParam(':categories', $categories);
            $stmt->bindParam(':downloaded', $downloaded);
            $stmt->bindParam(':installed', $installed);
            $stmt->bindParam(':kb', $kb);
            $stmt->bindParam(':update_type', $update_type);
            $stmt->bindParam(':project_id', $project_id);
            $stmt->bindParam(':task_id', $task_id);
            $stmt->bindParam(':id', $existing['id']);
            $stmt->execute();
        } else {
            // Insert new record
            $stmt = $conn->prepare("INSERT INTO patching_updates (patching_status_id, update_id, title, categories, downloaded, installed, kb, update_type, project_id, task_id)
                                    VALUES (:patching_status_id, :update_id, :title, :categories, :downloaded, :installed, :kb, :update_type, :project_id, :task_id)");
            $stmt->bindParam(':patching_status_id', $patching_status_id);
            $stmt->bindParam(':update_id', $update_id);
            $stmt->bindParam(':title', $update['title']);
            $stmt->bindParam(':categories', $categories);
            $stmt->bindParam(':downloaded', $downloaded);
            $stmt->bindParam(':installed', $installed);
            $stmt->bindParam(':kb', $kb);
            $stmt->bindParam(':update_type', $update_type);
            $stmt->bindParam(':project_id', $project_id);
            $stmt->bindParam(':task_id', $task_id);
            $stmt->execute();
        }
    }
}

// Set header to JSON
header('Content-Type: application/json');
echo json_encode($response);

$conn = null;
?>
