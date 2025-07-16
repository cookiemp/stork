use anyhow::Result;
use std::path::Path;
use magic_wormhole::{
    transfer::{self, APP_CONFIG},
    transit,
    Code, MailboxConnection, Wormhole,
};

#[tauri::command]
pub async fn send_file(path: String) -> Result<String, String> {
    // Create a mailbox connection for sending
    let mailbox = MailboxConnection::create(APP_CONFIG, 2)
        .await
        .map_err(|e| format!("Failed to create mailbox: {}", e))?;
    
    // Get the code before connecting
    let code = mailbox.code().clone();
    
    // Connect to establish the wormhole
    let wormhole = Wormhole::connect(mailbox)
        .await
        .map_err(|e| format!("Failed to connect wormhole: {}", e))?;
    
    // Send the file using the transfer API
    let file_path = Path::new(&path);
    let file_name = file_path.file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("file")
        .to_string();
    
    // Set up transit parameters
    let relay_hints = vec![]; // Use default relay hints
    let transit_abilities = transit::Abilities::default();
    let transit_handler = |_info| {}; // No special transit handling
    let progress_handler = |_sent, _total| {}; // No progress updates
    let cancel = async { }; // No cancellation for now
    
    #[allow(deprecated)]
    transfer::send_file_or_folder(
        wormhole,
        relay_hints,
        file_path,
        file_name,
        transit_abilities,
        transit_handler,
        progress_handler,
        cancel,
    )
    .await
    .map_err(|e| format!("Failed to send file: {}", e))?;
    
    Ok(format!("File sent successfully! Code: {}", code))
}

#[tauri::command]
pub async fn receive_file(_app: tauri::AppHandle, code_str: String) -> Result<String, String> {
    // Parse the code
    let code: Code = code_str.parse()
        .map_err(|e| format!("Invalid code format: {}", e))?;
    
    // Connect to the mailbox with the code
    let mailbox = MailboxConnection::connect(APP_CONFIG, code, false)
        .await
        .map_err(|e| format!("Failed to connect to mailbox: {}", e))?;
    
    // Connect to establish the wormhole
    let wormhole = Wormhole::connect(mailbox)
        .await
        .map_err(|e| format!("Failed to connect wormhole: {}", e))?;
    
    // Get the downloads directory
    let downloads_dir = dirs_next::download_dir()
        .ok_or("Could not find downloads directory")?;
    
    // Set up transit parameters
    let relay_hints = vec![]; // Use default relay hints
    let transit_abilities = transit::Abilities::default();
    let cancel = async { }; // No cancellation for now
    
    // Receive the file using the transfer API
    let req = transfer::request_file(wormhole, relay_hints, transit_abilities, cancel)
        .await
        .map_err(|e| format!("Failed to request file: {}", e))?;
    
    // Check if we got a request
    if let Some(req) = req {
        // Create the file path in the downloads directory
        let file_name = req.file_name();
        let file_path = downloads_dir.join(&file_name);
        
        // Create the file
        let mut file = async_std::fs::File::create(&file_path)
            .await
            .map_err(|e| format!("Failed to create file: {}", e))?;
        
        // Accept the file and save it to downloads
        let progress_handler = |_received, _total| {};
        let transit_handler = |_info| {};
        let cancel = async { };
        
        req.accept(transit_handler, progress_handler, &mut file, cancel)
            .await
            .map_err(|e| format!("Failed to receive file: {}", e))?;
        
        Ok(format!("File received successfully! Saved to: {}", file_path.display()))
    } else {
        Err("File transfer was cancelled or failed to receive offer".to_string())
    }
}
