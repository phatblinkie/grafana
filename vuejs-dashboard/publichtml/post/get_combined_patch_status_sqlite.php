<?php
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
$os_type = $_GET['os_type'];

$hostDetails = [];

if ($os_type === 'windows') {
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

        // Fetch the list of installed updates for the specified host
        $query = "
            SELECT title
            FROM windows_update_history
            WHERE hostname = :hostname
              AND operation = 'Installation'
              AND status = 'Succeeded'
            ORDER BY date DESC";
        $stmt = $conn->prepare($query);
        $stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
        $stmt->execute();
        $installedUpdates = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $installedUpdates[] = $row['title'];
        }
        $hostDetails['installedUpdates'] = $installedUpdates;

        // Fetch the list of failed updates for the specified host
        $query = "
            SELECT title, status, date
            FROM windows_update_history
            WHERE hostname = :hostname
              AND operation = 'Installation'
              AND status != 'Succeeded'
            ORDER BY date DESC";
        $stmt = $conn->prepare($query);
        $stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
        $stmt->execute();
        $failedUpdates = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $failedUpdates[] = [
                'title' => $row['title'],
                'status' => $row['status'],
                'date' => $row['date']
            ];
        }
        $hostDetails['Failures'] = $failedUpdates;
    }
} elseif ($os_type === 'linux') {
    // Fetch the most recent data for the specified host from linux_updates table
    $query = "
        SELECT *
        FROM linux_updates
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
        // Fetch the list of pending updates for the specified host
        $hostDetails['updates'] = [];
        $pending_updates_query = "
            SELECT update_name, version, repo
            FROM linux_pending_updates
            WHERE hostname = :hostname
            AND project_id = :project_id";
        $pending_updates_stmt = $conn->prepare($pending_updates_query);
        $pending_updates_stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
        $pending_updates_stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
        $pending_updates_stmt->execute();
        while ($row = $pending_updates_stmt->fetch(PDO::FETCH_ASSOC)) {
            $hostDetails['updates'][] = [
                'name' => $row['update_name'],
                'version' => $row['version'],
                'repo' => $row['repo']
            ];
        }

        // Fetch the list of installed updates for the specified host
        $hostDetails['installedUpdates'] = [];
        $installed_updates_query = "
            SELECT update_name, version, repo
            FROM linux_installed_updates
            WHERE hostname = :hostname
            AND project_id = :project_id";
        $installed_updates_stmt = $conn->prepare($installed_updates_query);
        $installed_updates_stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
        $installed_updates_stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
        $installed_updates_stmt->execute();
        while ($row = $installed_updates_stmt->fetch(PDO::FETCH_ASSOC)) {
            $hostDetails['installedUpdates'][] = [
                'name' => $row['update_name'],
                'version' => $row['version'],
                'repo' => $row['repo']
            ];
        }
    }
}

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
echo json_encode($hostDetails);
?>
