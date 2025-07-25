
import { useState } from 'react';
import { Download, Check, FolderOpen, ArrowLeft, Loader2, AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Progress } from '@/components/ui/progress';
import { useToast } from '@/hooks/use-toast';

type ReceiveState = 'input' | 'downloading' | 'complete' | 'error';

interface ReceiveFlowProps {
  onBack: () => void;
  receiveFile: (code: string) => Promise<string>;
}

const ReceiveFlow = ({ onBack, receiveFile }: ReceiveFlowProps) => {
  const [receiveState, setReceiveState] = useState<ReceiveState>('input');
  const [ticket, setTicket] = useState('');
  const [fileName, setFileName] = useState('');
  const [filePath, setFilePath] = useState('');
  const [error, setError] = useState('');
  const { toast } = useToast();

  const isValidTicket = ticket.trim().length > 5; // Basic validation - Magic Wormhole codes vary in format

  const startDownload = async () => {
    if (!isValidTicket) return;
    
    setReceiveState('downloading');
    setError('');
    
    try {
      const downloadedFilePath = await receiveFile(ticket.trim());
      setFilePath(downloadedFilePath);
      
      // Extract filename from path
      const extractedFileName = downloadedFilePath.split('\\').pop() || downloadedFilePath.split('/').pop() || 'Downloaded File';
      setFileName(extractedFileName);
      
      setReceiveState('complete');
      
      toast({
        title: "Download Complete!",
        description: `File saved to ${downloadedFilePath}`,
      });
    } catch (err) {
      console.error('File receive error:', err);
      setError(err instanceof Error ? err.message : 'Failed to receive file');
      setReceiveState('error');
    }
  };

  const showInFolder = () => {
    if (filePath) {
      toast({
        title: "File Location",
        description: filePath,
      });
    }
  };

  return (
    <div className="h-full p-8 animate-fade-in">
      <Button 
        variant="ghost" 
        onClick={onBack}
        className="mb-8 hover:bg-accent -ml-2 font-medium"
      >
        <ArrowLeft className="w-4 h-4 mr-2" />
        Back
      </Button>

      {receiveState === 'input' && (
        <div className="h-full flex flex-col justify-center animate-scale-in max-w-md mx-auto">
          <div className="text-center mb-10">
            <div className="w-20 h-20 bg-gradient-to-br from-green-500/10 to-green-400/5 rounded-3xl 
                            flex items-center justify-center mx-auto mb-8">
              <Download className="w-10 h-10 text-green-600" />
            </div>
            <h2 className="text-3xl font-bold text-foreground mb-3">
              Receive Your File
            </h2>
            <p className="text-muted-foreground text-lg">
              Paste your transfer ticket below
            </p>
          </div>

          <div className="space-y-6">
            <div>
              <Input
                type="text"
                placeholder="Paste your ticket here"
                value={ticket}
                onChange={(e) => setTicket(e.target.value)}
                className="w-full p-6 text-lg font-mono border-2 focus:border-green-500 
                           rounded-xl bg-muted/50 focus:bg-background transition-colors"
              />
            </div>

            <Button
              onClick={startDownload}
              disabled={!isValidTicket}
              className="w-full bg-green-600 hover:bg-green-700 text-white py-6 text-lg font-semibold
                         disabled:bg-muted disabled:text-muted-foreground disabled:cursor-not-allowed
                         rounded-xl shadow-lg hover:shadow-xl transition-all duration-200"
            >
              <Download className="w-5 h-5 mr-2" />
              Start Download
            </Button>
          </div>
        </div>
      )}

      {receiveState === 'downloading' && (
        <div className="h-full flex flex-col justify-center animate-fade-in max-w-md mx-auto">
          <div className="text-center mb-10">
            <div className="w-20 h-20 bg-gradient-to-br from-green-500/10 to-green-400/5 rounded-3xl 
                            flex items-center justify-center mx-auto mb-8">
              <Loader2 className="w-10 h-10 text-green-500 animate-spin" />
            </div>
            <h2 className="text-3xl font-bold text-foreground mb-3">
              Connecting...
            </h2>
            <p className="text-lg text-muted-foreground">
              Establishing secure connection and receiving file
            </p>
          </div>

          <Button
            variant="outline"
            className="w-full py-6 text-lg font-medium rounded-xl border-border/60"
            onClick={() => setReceiveState('input')}
          >
            Cancel
          </Button>
        </div>
      )}

      {receiveState === 'error' && (
        <div className="h-full flex flex-col items-center justify-center animate-fade-in">
          <div className="w-20 h-20 bg-gradient-to-br from-red-500/10 to-red-400/5 rounded-3xl 
                          flex items-center justify-center mb-8">
            <AlertCircle className="w-10 h-10 text-red-600" />
          </div>
          <h2 className="text-3xl font-bold text-foreground mb-3">
            Download Failed
          </h2>
          <p className="text-muted-foreground text-lg text-center mb-8 max-w-md">
            {error || 'An error occurred while receiving your file'}
          </p>
          <Button
            onClick={() => setReceiveState('input')}
            className="bg-primary hover:bg-primary/90 text-primary-foreground py-3 px-8
                       rounded-xl shadow-lg hover:shadow-xl transition-all duration-200"
          >
            Try Again
          </Button>
        </div>
      )}

      {receiveState === 'complete' && (
        <div className="h-full flex flex-col animate-fade-in max-w-md mx-auto">
          <div className="flex-1 flex flex-col justify-center">
            <div className="text-center mb-10">
              <div className="w-20 h-20 bg-gradient-to-br from-green-500/10 to-green-400/5 rounded-3xl 
                              flex items-center justify-center mx-auto mb-8">
                <Check className="w-10 h-10 text-green-600" />
              </div>
              <h2 className="text-3xl font-bold text-foreground mb-3">
                Download Complete!
              </h2>
              <p className="text-xl text-muted-foreground font-medium">
                {fileName}
              </p>
            </div>

            <Button
              onClick={showInFolder}
              className="w-full bg-green-600 hover:bg-green-700 text-white py-6 text-lg font-semibold
                         rounded-xl shadow-lg hover:shadow-xl transition-all duration-200 mb-6"
            >
              <FolderOpen className="w-5 h-5 mr-2" />
              Show in Folder
            </Button>
          </div>

          <Button
            variant="outline"
            onClick={onBack}
            className="w-full py-6 text-lg font-medium rounded-xl border-border/60"
          >
            Receive Another File
          </Button>
        </div>
      )}
    </div>
  );
};

export default ReceiveFlow;
