import { useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';
import MainScreen from './stork/MainScreen';
import SendFlow from './stork/SendFlow';
import ReceiveFlow from './stork/ReceiveFlow';

export type AppState = 'main' | 'send' | 'receive';

const StorkApp = () => {
  const [currentState, setCurrentState] = useState<AppState>('main');

  const resetToMain = () => setCurrentState('main');

  // Tauri backend integration functions
  const sendFile = async (filePath: string): Promise<string> => {
    try {
      return await invoke('send_file', { path: filePath }) as string;
    } catch (error) {
      console.error('Error sending file:', error);
      throw error;
    }
  };

  const receiveFile = async (code: string): Promise<string> => {
    try {
      return await invoke('receive_file', { codeStr: code }) as string;
    } catch (error) {
      console.error('Error receiving file:', error);
      throw error;
    }
  };

  const openFileDialog = async (): Promise<string | null> => {
    try {
      console.log('openFileDialog: Starting file dialog...');
      const result = await open({
        multiple: false,
        filters: [
          {
            name: 'All Files',
            extensions: ['*'],
          },
        ],
      });
      console.log('openFileDialog: File dialog result:', result);
      const finalResult = Array.isArray(result) ? result[0] : result;
      console.log('openFileDialog: Final processed result:', finalResult);
      return finalResult;
    } catch (error) {
      console.error('openFileDialog: Error opening file dialog:', error);
      console.error('openFileDialog: Error details:', {
        message: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : 'No stack trace',
        name: error instanceof Error ? error.name : 'Unknown error type'
      });
      return null;
    }
  };

  return (
    <div className="w-[680px] h-[520px] bg-card rounded-3xl shadow-2xl overflow-hidden relative border border-border/50">
      {/* Centered Header with stork logo */}
      <div className="absolute top-8 left-1/2 transform -translate-x-1/2 z-10 text-center">
        <div className="flex flex-col items-center justify-center">
          <img 
            src="/lovable-uploads/4ca6cf24-5aec-428d-a113-0ab76cbe242b.png" 
            alt="Stork" 
            className="w-28 h-28 object-contain -mb-4"
          />
          <h1 className="text-4xl font-bold text-foreground tracking-tight">Stork</h1>
          <p className="text-muted-foreground text-lg font-normal -mt-2">Simple file transfer</p>
        </div>
      </div>

      <div className="h-full pt-48">
        {currentState === 'main' && (
          <MainScreen onSend={() => setCurrentState('send')} onReceive={() => setCurrentState('receive')} />
        )}
        {currentState === 'send' && (
          <SendFlow onBack={resetToMain} sendFile={sendFile} openFileDialog={openFileDialog} />
        )}
        {currentState === 'receive' && (
          <ReceiveFlow onBack={resetToMain} receiveFile={receiveFile} />
        )}
      </div>
    </div>
  );
};

export default StorkApp;
