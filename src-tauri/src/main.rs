#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod stork_core;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            stork_core::send_file,
            stork_core::receive_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
