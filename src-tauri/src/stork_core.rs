use anyhow::Result;
use magic_wormhole::{
    transfer::{self, AppVersion, APP_CONFIG},
    transit, Code, MailboxConnection, Wormhole,
};

#[tauri::command]
pub async fn send_file(path: String) -> Result<String, String> {
    println!("Starting file send for: {}", path);

    // Convert to PathBuf early to avoid lifetime issues
    let file_path = std::path::PathBuf::from(&path);

    // Verify the file exists first
    if !file_path.exists() {
        return Err("File does not exist".to_string());
    }

    // Create a mailbox connection for sending
    println!("Creating mailbox connection...");
    let mailbox = MailboxConnection::create(APP_CONFIG, 2)
        .await
        .map_err(|e| {
            println!("Mailbox creation failed: {}", e);
            format!("Failed to create mailbox: {}", e)
        })?;

    // Get the code before connecting
    let code = mailbox.code().clone();
    println!("Generated code: {}", code);

    // Store the background task in a way that keeps it alive
    // Use a detached task that won't be cancelled when the function returns
    let _handle = tokio::task::spawn(async move {
        match handle_file_send(mailbox, file_path).await {
            Ok(_) => println!("File transfer completed successfully"),
            Err(e) => println!("File transfer failed: {}", e),
        }
    });

    // Give the background task more time to establish the wormhole connection
    tokio::time::sleep(std::time::Duration::from_millis(2000)).await;

    Ok(code.to_string())
}

async fn handle_file_send(
    mailbox: MailboxConnection<AppVersion>,
    file_path: std::path::PathBuf,
) -> Result<(), String> {
    // Connect to establish the wormhole with timeout
    println!("Waiting for receiver to connect...");
    let wormhole = tokio::time::timeout(
        std::time::Duration::from_secs(300), // 5 minutes timeout
        Wormhole::connect(mailbox),
    )
    .await
    .map_err(|_| "No receiver connected within 5 minutes".to_string())?
    .map_err(|e| {
        println!("Wormhole connection failed: {}", e);
        format!("Failed to connect wormhole: {}", e)
    })?;

    println!("Receiver connected! Starting file transfer...");

    // Send the file using the transfer API
    let file_name = file_path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("file")
        .to_string();

    // Set up transit parameters - use default configuration
    let relay_hints = vec![]; // Use default relay hints for now
    let mut transit_abilities = transit::Abilities::default();
    // Enable direct TCP and relay abilities
    transit_abilities.direct_tcp_v1 = true;
    transit_abilities.relay_v1 = true;
    println!("Transit abilities: {:?}", transit_abilities);
    let transit_handler = |_info| {
        println!("Transit info: {:?}", _info);
    };
    let progress_handler = |sent, total| {
        println!("Transfer progress: {}/{} bytes", sent, total);
    };

    // Get file size first using async_std::fs::metadata
    let file_size = async_std::fs::metadata(&file_path)
        .await
        .map_err(|e| format!("Failed to get file metadata: {}", e))?
        .len();

    // Open the file for reading
    let mut file = async_std::fs::File::open(&file_path)
        .await
        .map_err(|e| format!("Failed to open file: {}", e))?;

    // Create a cancel future
    let cancel = async {
        // Add a longer timeout for the cancel future
        tokio::time::sleep(std::time::Duration::from_secs(600)).await;
    };

    // Use the correct send_file function signature
    transfer::send_file(
        wormhole,
        relay_hints,
        &mut file,
        file_name,
        file_size,
        transit_abilities,
        transit_handler,
        progress_handler,
        cancel,
    )
    .await
    .map_err(|e| format!("Failed to send file: {}", e))?;

    Ok(())
}

#[tauri::command]
pub async fn receive_file(_app: tauri::AppHandle, code_str: String) -> Result<String, String> {
    println!("Starting file receive with code: {}", code_str);

    // Parse the code
    let code: Code = code_str.parse().map_err(|e| {
        println!("Code parsing failed: {}", e);
        format!("Invalid code format: {}", e)
    })?;

    // Connect to the mailbox with the code
    println!("Connecting to mailbox...");
    let mailbox = MailboxConnection::connect(APP_CONFIG, code, false)
        .await
        .map_err(|e| {
            println!("Mailbox connection failed: {}", e);
            format!("Failed to connect to mailbox: {}", e)
        })?;

    // Connect to establish the wormhole with longer timeout to match sender
    println!("Connecting to wormhole...");
    let wormhole = tokio::time::timeout(
        std::time::Duration::from_secs(120), // Increased to 2 minutes to match sender
        Wormhole::connect(mailbox),
    )
    .await
    .map_err(|_| "Connection timeout - took longer than 2 minutes".to_string())?
    .map_err(|e| {
        println!("Wormhole connection failed: {}", e);
        format!("Failed to connect wormhole: {}", e)
    })?;

    // Get the downloads directory
    let downloads_dir = dirs_next::download_dir().ok_or("Could not find downloads directory")?;

    // Set up transit parameters - use default configuration
    let relay_hints = vec![]; // Use default relay hints for now
    let mut transit_abilities = transit::Abilities::default();
    // Enable direct TCP and relay abilities
    transit_abilities.direct_tcp_v1 = true;
    transit_abilities.relay_v1 = true;
    println!("Receiver transit abilities: {:?}", transit_abilities);
    let cancel = async {
        // Add a longer timeout for the cancel future
        tokio::time::sleep(std::time::Duration::from_secs(600)).await;
    };

    // Receive the file using the transfer API with timeout
    println!("Requesting file transfer...");
    let req = tokio::time::timeout(
        std::time::Duration::from_secs(120), // Increased to 2 minutes for file request
        transfer::request_file(wormhole, relay_hints, transit_abilities, cancel),
    )
    .await
    .map_err(|_| "File request timeout - took longer than 2 minutes".to_string())?
    .map_err(|e| {
        println!("Request file error: {}", e);
        format!("Failed to request file: {}", e)
    })?;

    // Check if we got a request
    if let Some(req) = req {
        // Create the file path in the downloads directory
        let file_name = req.file_name();
        let file_path = downloads_dir.join(&file_name);

        println!(
            "Received file offer: {} (saving to: {})",
            file_name,
            file_path.display()
        );

        // Create the file
        let mut file = async_std::fs::File::create(&file_path)
            .await
            .map_err(|e| format!("Failed to create file: {}", e))?;

        // Accept the file and save it to downloads
        println!("Accepting file: {}", file_name);
        let progress_handler = |received, total| {
            println!("Receive progress: {}/{} bytes", received, total);
        };
        let transit_handler = |_info| {
            println!("Transit info: {:?}", _info);
        };
        let cancel = async {
            // Add a longer timeout for the cancel future
            tokio::time::sleep(std::time::Duration::from_secs(600)).await;
        };

        tokio::time::timeout(
            std::time::Duration::from_secs(600), // Increased to 10 minutes for large files
            req.accept(transit_handler, progress_handler, &mut file, cancel),
        )
        .await
        .map_err(|_| "File transfer timeout - took longer than 10 minutes".to_string())?
        .map_err(|e| {
            println!("Accept file error: {}", e);
            format!("Failed to receive file: {}", e)
        })?;

        println!("File successfully saved to: {}", file_path.display());
        Ok(file_path.display().to_string())
    } else {
        println!("No file offer received from sender");
        Err("File transfer was cancelled or failed to receive offer".to_string())
    }
}
