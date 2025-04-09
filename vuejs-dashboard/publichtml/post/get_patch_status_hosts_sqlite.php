<?php
$dsn = 'sqlite:/sqlitedata/database.sqlite';

try {
    $conn = new PDO($dsn);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Include the file with the create table statements
include 'create_tables.php';

// Create tables if they do not exist
createTables($conn);

$project_id = $_GET['project_id'];

// Fetch hosts and number of available updates from patching_status and linux_updates tables
$query = "
    SELECT hostname, timestamp, found_update_count AS available_updates, 'windows' AS os_type
    FROM patching_status
    WHERE project_id = :project_id
    AND timestamp = (
        SELECT MAX(timestamp)
        FROM patching_status AS ps
        WHERE ps.hostname = patching_status.hostname
        AND ps.project_id = patching_status.project_id
    )
    UNION
    SELECT hostname, timestamp, pending_updates AS available_updates, 'linux' AS os_type
    FROM linux_updates
    WHERE project_id = :project_id
    AND timestamp = (
        SELECT MAX(timestamp)
        FROM linux_updates AS lu
        WHERE lu.hostname = linux_updates.hostname
        AND lu.project_id = linux_updates.project_id
    )
    ORDER BY hostname";
$stmt = $conn->prepare($query);
$stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
$stmt->execute();
$result = $stmt->fetchAll(PDO::FETCH_ASSOC);

$hosts = [];
foreach ($result as $row) {
    $row['formatted_timestamp'] = formatTimestamp($row['timestamp']);
    $hostname = $row['hostname'];

    if ($row['os_type'] === 'linux') {
        // Fetch pending and installed updates for the Linux host
        $updates_query = "
            SELECT pending_updates, installed_updates
            FROM linux_updates
            WHERE hostname = :hostname
            AND project_id = :project_id
            ORDER BY timestamp DESC
            LIMIT 1";
        $updates_stmt = $conn->prepare($updates_query);
        $updates_stmt->bindParam(':hostname', $hostname, PDO::PARAM_STR);
        $updates_stmt->bindParam(':project_id', $project_id, PDO::PARAM_INT);
        $updates_stmt->execute();
        $updates_result = $updates_stmt->fetch(PDO::FETCH_ASSOC);
        if ($updates_result) {
            $row['available_updates'] = $updates_result['pending_updates'];
            $row['installed_updates'] = $updates_result['installed_updates'];
        } else {
            $row['available_updates'] = 0;
            $row['installed_updates'] = 0;
        }
    }

    $hosts[] = $row;
}

function formatTimestamp($timestamp) {
    // Set the desired timezone
    $timezone = new DateTimeZone('America/Chicago'); // Change to your desired timezone

    $datetime1 = new DateTime($timestamp, $timezone);
    $datetime2 = new DateTime('now', $timezone);
    $interval = $datetime1->diff($datetime2);

    if ($interval->y > 0) {
        return $interval->y . ' year' . ($interval->y > 1 ? 's' : '') . ' ago';
    } elseif ($interval->m > 0) {
        return $interval->m . ' month' . ($interval->m > 1 ? 's' : '') . ' ago';
    } elseif ($interval->d > 0) {
        return $interval->d . ' day' . ($interval->d > 1 ? 's' : '') . ' ago';
    } elseif ($interval->h > 0) {
        return $interval->h . ' hour' . ($interval->h > 1 ? 's' : '') . ' ago';
    } elseif ($interval->i > 0) {
        return $interval->i . ' minute' . ($interval->i > 1 ? 's' : '') . ' ago';
    } else {
        return 'just now';
    }
}

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
echo json_encode($hosts);


?>
