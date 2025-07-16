#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod stork_core;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            stork_core::send_file,
            stork_core::receive_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
