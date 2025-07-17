import { useState } from "react";
import { invoke } from '@tauri-apps/api/core';
import { open } from "@tauri-apps/plugin-dialog";
import "./App.css";

function App() {
  const [transferCode, setTransferCode] = useState("");
  const [receiveCode, setReceiveCode] = useState("");
  const [status, setStatus] = useState("");
  const [selectedFile, setSelectedFile] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function selectAndSendFile() {
    try {
      setIsLoading(true);
      setStatus("Selecting file...");
      
      // Open file dialog
      const selected = await open({
        multiple: false,
        directory: false,
        filters: [{
          name: "All Files",
          extensions: ["*"]
        }]
      });
      
      if (!selected) {
        setStatus("No file selected");
        setIsLoading(false);
        return;
      }
      
      const filePath = Array.isArray(selected) ? selected[0] : selected;
      setSelectedFile(filePath);
      setStatus("Sending file...");
      
      // Call the send_file command
      const code = await invoke("send_file", { path: filePath }) as string;
      setTransferCode(code);
      setStatus(`File sent successfully! Share this code: ${code}`);
    } catch (error) {
      setStatus(`Error: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }

  async function receiveFile() {
    if (!receiveCode.trim()) {
      setStatus("Please enter a transfer code");
      return;
    }
    
    try {
      setIsLoading(true);
      setStatus("Receiving file...");
      
      // Call the receive_file command
      const result = await invoke("receive_file", { codeStr: receiveCode.trim() }) as string;
      setStatus(`File received successfully! Saved to: ${result}`);
      setReceiveCode("");
    } catch (error) {
      setStatus(`Error: ${error}`);
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className="container">
      <h1>🐦 Stork - P2P File Sharing</h1>
      
      <div className="section">
        <h2>Send File</h2>
        <button 
          onClick={selectAndSendFile} 
          disabled={isLoading}
          className="action-button"
        >
          {isLoading ? "Processing..." : "Select & Send File"}
        </button>
        
        {selectedFile && (
          <p className="file-info">Selected: {selectedFile}</p>
        )}
        
        {transferCode && (
          <div className="code-display">
            <h3>Transfer Code:</h3>
            <div className="code-box">
              <code>{transferCode}</code>
              <button 
                onClick={() => navigator.clipboard.writeText(transferCode)}
                className="copy-button"
              >
                Copy
              </button>
            </div>
          </div>
        )}
      </div>
      
      <div className="section">
        <h2>Receive File</h2>
        <div className="receive-form">
          <input
            type="text"
            value={receiveCode}
            onChange={(e) => setReceiveCode(e.target.value)}
            placeholder="Enter transfer code..."
            className="code-input"
          />
          <button 
            onClick={receiveFile} 
            disabled={isLoading || !receiveCode.trim()}
            className="action-button"
          >
            {isLoading ? "Receiving..." : "Receive File"}
          </button>
        </div>
      </div>
      
      {status && (
        <div className="status">
          <p>{status}</p>
        </div>
      )}
    </main>
  );
}

export default App;
