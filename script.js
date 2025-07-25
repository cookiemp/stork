import { open } from '@tauri-apps/plugin-dialog';
import { invoke } from '@tauri-apps/api/core';

// Wait for both DOM and Tauri to be ready
function initializeApp() {
  let currentState = 'main';

  const render = () => {
    const app = document.getElementById('app');
    switch (currentState) {
      case 'main':
        app.innerHTML = renderMainScreen();
        break;
      case 'send':
        app.innerHTML = renderSendFlow();
        break;
      case 'receive':
        app.innerHTML = renderReceiveFlow();
        break;
    }
    addEventListeners();
  };

  const setState = (newState) => {
    currentState = newState;
    render();
  };

  const renderMainScreen = () => `
    <div class="stork-app">
      <div class="stork-header">
        <img src="public/lovable-uploads/4ca6cf24-5aec-428d-a113-0ab76cbe242b.png" alt="Stork" />
        <h1>Stork</h1>
        <p>Simple file transfer</p>
      </div>
      <div class="main-screen">
        <div class="panel send" data-action="send">
          <div class="panel-icon">
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="m22 2-7 20-4-9-9-4 20-7z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="m7 13 3 3 3-3" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h2>Send a File</h2>
          <p>Select a file to generate a transfer ticket</p>
        </div>
        <div class="panel receive" data-action="receive">
          <div class="panel-icon">
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="7,10 12,15 17,10" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="12" y1="15" x2="12" y2="3" stroke="white" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <h2>Receive a File</h2>
          <p>Paste a ticket to start your download</p>
        </div>
      </div>
    </div>
  `;

  const renderSendFlow = () => `
    <div class="stork-app">
      <div class="flow">
        <button class="back-button" data-action="main">&larr; Back</button>
        <div class="file-drop-zone" id="dropZone">
          <div class="upload-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="#3b82f6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="17,8 12,3 7,8" stroke="#3b82f6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="12" y1="3" x2="12" y2="15" stroke="#3b82f6" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <h2>Click to Select Your File</h2>
          <p><span class="browse-link">Browse for file</span></p>
        </div>
      </div>
    </div>
  `;

  const renderReceiveFlow = () => `
    <div class="stork-app">
      <div class="flow">
        <button class="back-button" data-action="main">&larr; Back</button>
        <div class="receive-form">
          <div class="receive-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="#10b981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="7,10 12,15 17,10" stroke="#10b981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="12" y1="15" x2="12" y2="3" stroke="#10b981" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <h2>Receive Your File</h2>
          <p>Paste your transfer ticket below</p>
          <input type="text" id="ticketInput" placeholder="Paste your ticket here" class="ticket-input">
          <button id="startDownload" class="download-button" disabled>Start Download</button>
        </div>
      </div>
    </div>
  `;

  const addEventListeners = () => {
    document.querySelectorAll('[data-action]').forEach(element => {
      element.addEventListener('click', () => {
        setState(element.dataset.action);
      });
    });

    // Send flow event listeners
    const dropZone = document.getElementById('dropZone');
    
    if (dropZone) {
      dropZone.addEventListener('click', async (e) => {
        // Only trigger file selection if clicking on the drop zone itself, not its children
        if (e.target === dropZone || e.target.closest('.file-drop-zone') === dropZone) {
          // Don't trigger if clicking on buttons or inputs inside the drop zone
          if (e.target.tagName === 'BUTTON' || e.target.tagName === 'INPUT') {
            return;
          }
          
          try {
            // Use the imported Tauri dialog
            const filePath = await open({
              multiple: false,
              filters: [{
                name: 'All Files',
                extensions: ['*']
              }]
            });
              
            if (filePath) {
              // Extract filename from path
              const fileName = filePath.split('\\').pop() || filePath.split('/').pop() || 'Unknown';
              
              const fileInfo = {
                name: fileName,
                path: filePath,
                size: 0 // We don't have size info from dialog
              };
              
              await handleFileSelect(fileInfo);
            }
          } catch (error) {
            console.error('Error opening file dialog:', error);
            
            // Show error message instead of using fallback
            const dropZone = document.getElementById('dropZone');
            if (dropZone) {
              dropZone.innerHTML = `
                <div class="upload-icon">
                  <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="12" cy="12" r="10" stroke="#ef4444" stroke-width="2" fill="none"/>
                    <line x1="12" y1="8" x2="12" y2="12" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
                    <line x1="12" y1="16" x2="12.01" y2="16" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </div>
                <h2>File Dialog Not Available</h2>
                <p style="color: #ef4444;">The Tauri file dialog could not be opened. Please ensure the app is running in a Tauri environment.</p>
                <button onclick="location.reload()" style="background: #3b82f6; color: white; border: none; padding: 0.5rem 1rem; border-radius: 8px; cursor: pointer; margin-top: 1rem;">
                  Try Again
                </button>
              `;
            }
          }
        }
      });
    }

    // Receive flow event listeners
    const ticketInput = document.getElementById('ticketInput');
    const downloadButton = document.getElementById('startDownload');
    
    if (ticketInput && downloadButton) {
      ticketInput.addEventListener('input', (e) => {
        const isValid = e.target.value.length > 5; // Basic validation
        downloadButton.disabled = !isValid;
      });
      
      downloadButton.addEventListener('click', async () => {
        const ticket = ticketInput.value.trim();
        
        try {
          // Update UI to show downloading state
          downloadButton.textContent = 'Downloading...';
          downloadButton.disabled = true;
          
          // Call Tauri backend to receive file
          const filePath = await invoke('receive_file', { 
            codeStr: ticket 
          });
          
          // Show success
          downloadButton.textContent = 'Download Complete!';
          downloadButton.style.background = '#10b981';
          
          alert(`File downloaded successfully!\\nSaved to: ${filePath}`);
        } catch (error) {
          console.error('Error receiving file:', error);
          downloadButton.textContent = 'Error - Try Again';
          downloadButton.style.background = '#ef4444';
          downloadButton.disabled = false;
          
          alert(`Download failed: ${error}`);
          
          // Reset button after delay
          setTimeout(() => {
            downloadButton.textContent = 'Start Download';
            downloadButton.style.background = '#10b981';
          }, 3000);
        }
      });
    }
  };

  const handleFileSelect = async (file) => {
    try {
      // Update UI to show generating state
      const dropZone = document.getElementById('dropZone');
      if (dropZone) {
        dropZone.innerHTML = `
          <div class="upload-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" stroke="#3b82f6" stroke-width="2" fill="none"/>
              <path d="m9 12 2 2 4-4" stroke="#3b82f6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h2>Generating Ticket...</h2>
          <p>Preparing ${file.name} for transfer</p>
        `;
      }

      // Use the file path
      const filePath = file.path;
      
      if (!filePath) {
        throw new Error('No file path available.');
      }
      
      // Call Tauri backend with the file path
      const ticket = await invoke('send_file', { path: filePath });
      
      // Show success with ticket
      if (dropZone) {
        dropZone.innerHTML = `
          <div class="upload-icon" style="background: linear-gradient(135deg, rgba(34, 197, 94, 0.1), rgba(34, 197, 94, 0.05));">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" stroke="#10b981" stroke-width="2" fill="none"/>
              <path d="m9 12 2 2 4-4" stroke="#10b981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h2>Ticket Ready!</h2>
          <div style="margin: 1rem 0;">
            <input type="text" value="${ticket}" readonly 
                   style="width: 100%; padding: 0.5rem; font-family: monospace; border: 2px solid #10b981; border-radius: 8px; background: #f0fdf4;">
          </div>
          <button onclick="event.stopPropagation(); navigator.clipboard.writeText('${ticket}'); this.textContent='Copied!'; setTimeout(() => this.textContent='Copy Ticket', 2000);" 
                  style="background: #10b981; color: white; border: none; padding: 0.5rem 1rem; border-radius: 8px; cursor: pointer;">
            Copy Ticket
          </button>
          <p style="margin-top: 1rem; color: #f59e0b;">Status: Waiting for receiver to connect...</p>
        `;
      }
    } catch (error) {
      console.error('Error generating ticket:', error);
      const dropZone = document.getElementById('dropZone');
      if (dropZone) {
        dropZone.innerHTML = `
          <div class="upload-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" stroke="#ef4444" stroke-width="2" fill="none"/>
              <line x1="12" y1="8" x2="12" y2="12" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
              <line x1="12" y1="16" x2="12.01" y2="16" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <h2>Error</h2>
          <p style="color: #ef4444;">${error.message || error}</p>
          <button onclick="location.reload()" style="background: #ef4444; color: white; border: none; padding: 0.5rem 1rem; border-radius: 8px; cursor: pointer; margin-top: 1rem;">
            Try Again
          </button>
        `;
      }
    }
  };

  // Initialize the app
  render();
}

// Initialize the app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeApp);
} else {
  // DOM is already ready, initialize immediately
  initializeApp();
}
