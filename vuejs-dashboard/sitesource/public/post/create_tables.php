<?php
function createTables($conn) {
    $conn->exec("
    CREATE TABLE IF NOT EXISTS linux_patching_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        changed INTEGER NOT NULL,
        failed INTEGER NOT NULL,
        msg TEXT,
        rc INTEGER NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(hostname)
    );

    CREATE TABLE IF NOT EXISTS linux_patching_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        linux_patching_status_id INTEGER NOT NULL,
        result TEXT NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        FOREIGN KEY (linux_patching_status_id) REFERENCES linux_patching_status(id),
        UNIQUE(linux_patching_status_id, result)
    );

        CREATE TABLE IF NOT EXISTS patching_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        changed INTEGER NOT NULL,
        failed INTEGER NOT NULL,
        failed_update_count INTEGER NOT NULL,
        found_update_count INTEGER NOT NULL,
        installed_update_count INTEGER NOT NULL,
        reboot_required INTEGER NOT NULL,
        rebooted INTEGER NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS patching_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patching_status_id INTEGER NOT NULL,
        update_id TEXT NOT NULL,
        title TEXT NOT NULL,
        categories TEXT NOT NULL,
        downloaded INTEGER NOT NULL,
        installed INTEGER NOT NULL,
        kb TEXT,
        update_type TEXT NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        FOREIGN KEY (patching_status_id) REFERENCES patching_status (id),
        UNIQUE (update_id, patching_status_id)
    );

    

    CREATE TABLE IF NOT EXISTS ansible_ping_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
	hostname TEXT NOT NULL,
        ip_address TEXT,
        ansible_ping TEXT NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_responded DATETIME,
        task_id INTEGER,
        UNIQUE (hostname)
    );

    CREATE TABLE IF NOT EXISTS system_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        ansible_ping TEXT NOT NULL,
        disk_capacity TEXT NOT NULL,
        proc_usage TEXT NOT NULL,
        app_check TEXT NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        uptime INTEGER,
        last_responded DATETIME,
        project_id INTEGER,
        task_id INTEGER,
        UNIQUE (hostname, project_id)
    );

    CREATE TABLE IF NOT EXISTS system_status_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        ansible_ping TEXT NOT NULL,
        disk_capacity TEXT NOT NULL,
        proc_usage TEXT NOT NULL,
        app_check TEXT NOT NULL,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        uptime INTEGER,
        last_responded DATETIME,
        project_id INTEGER,
        task_id INTEGER
    );

        CREATE TABLE IF NOT EXISTS linux_pending_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        update_name TEXT NOT NULL,
        version TEXT NOT NULL,
        repo TEXT NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (hostname, project_id, update_name, version, repo)
    );
    CREATE TABLE IF NOT EXISTS linux_installed_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        update_name TEXT NOT NULL,
        version TEXT NOT NULL,
        repo TEXT NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (hostname, project_id, update_name, version, repo)
    );
    CREATE TABLE IF NOT EXISTS linux_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        pending_updates INTEGER NOT NULL,
        installed_updates INTEGER NOT NULL,
        project_id INTEGER NOT NULL,
        task_id INTEGER NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (hostname, project_id)
    );

    CREATE TABLE IF NOT EXISTS windows_update_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        title TEXT NOT NULL,
        date DATETIME DEFAULT NULL,
        operation TEXT DEFAULT NULL,
        status TEXT DEFAULT NULL,
        kb TEXT DEFAULT NULL,
        pc TEXT DEFAULT NULL,
        project_id INTEGER NOT NULL
    );
    ");
}
?>
