
import { useState } from 'react';
import { Upload, Copy, Check, Loader2, ArrowLeft, AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';

type SendState = 'select' | 'generating' | 'ready' | 'error';

interface SendFlowProps {
  onBack: () => void;
  sendFile: (filePath: string) => Promise<string>;
  openFileDialog: () => Promise<string | null>;
}

const SendFlow = ({ onBack, sendFile, openFileDialog }: SendFlowProps) => {
  const [sendState, setSendState] = useState<SendState>('select');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedFilePath, setSelectedFilePath] = useState<string>('');
  const [ticket, setTicket] = useState('');
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState('');
  const { toast } = useToast();

  const handleFileSelection = async () => {
    console.log('File selection started');
    
    // For now, let's test with a hardcoded file path that definitely exists
    const testFilePath = 'C:\\Windows\\System32\\notepad.exe';
    
    setSendState('generating');
    setError('');
    
    try {
      console.log('Testing with file:', testFilePath);
      
      // Extract filename and create a mock File object for display
      const fileName = testFilePath.split('\\').pop() || testFilePath.split('/').pop() || 'Unknown';
      const mockFile = new File([], fileName);
      
      setSelectedFile(mockFile);
      setSelectedFilePath(testFilePath);
      
      console.log('Attempting to send file:', testFilePath);
      const transferTicket = await sendFile(testFilePath);
      console.log('Transfer ticket generated:', transferTicket);
      setTicket(transferTicket);
      setSendState('ready');
    } catch (err) {
      console.error('File selection/send error:', err);
      console.error('Error details:', {
        message: err instanceof Error ? err.message : 'Unknown error',
        stack: err instanceof Error ? err.stack : 'No stack trace',
        name: err instanceof Error ? err.name : 'Unknown error type'
      });
      setError(err instanceof Error ? err.message : 'Failed to generate transfer ticket');
      setSendState('error');
    }
  };

  const copyTicket = async () => {
    try {
      await navigator.clipboard.writeText(ticket);
      setCopied(true);
      toast({
        title: "Copied!",
        description: "Ticket copied to clipboard",
      });
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy ticket:', err);
    }
  };

  return (
    <div className="h-full p-8 animate-fade-in">
      <div className="flex justify-between items-center mb-8">
        <Button 
          variant="ghost" 
          onClick={onBack}
          className="hover:bg-accent -ml-2 font-medium"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back
        </Button>
        <Button 
          variant="outline" 
          onClick={async () => {
            try {
              console.log('Testing Tauri connection...');
              await openFileDialog();
              console.log('Tauri connection test completed');
            } catch (err) {
              console.error('Tauri connection test failed:', err);
            }
          }}
          className="text-sm"
        >
          Test Dialog
        </Button>
      </div>

      {sendState === 'select' && (
        <div 
          className="h-full border-2 border-dashed border-border/60 rounded-2xl 
                     flex flex-col items-center justify-center cursor-pointer
                     hover:border-primary/60 hover:bg-accent/30 transition-all duration-300
                     animate-scale-in bg-card/50"
          onClick={handleFileSelection}
        >
          <div className="w-24 h-24 bg-gradient-to-br from-primary/10 to-primary/5 rounded-3xl 
                          flex items-center justify-center mb-8 group-hover:scale-110 transition-transform">
            <Upload className="w-12 h-12 text-primary" />
          </div>
          <h2 className="text-3xl font-bold text-foreground mb-4">
            Select Your File
          </h2>
          <p className="text-muted-foreground text-lg">
            <span className="text-primary underline font-medium">Click to browse and select a file</span>
          </p>
        </div>
      )}

      {sendState === 'generating' && (
        <div className="h-full flex flex-col items-center justify-center animate-fade-in">
          <div className="w-20 h-20 bg-gradient-to-br from-primary/10 to-primary/5 rounded-3xl 
                          flex items-center justify-center mb-8">
            <Loader2 className="w-10 h-10 text-primary animate-spin" />
          </div>
          <h2 className="text-3xl font-bold text-foreground mb-3">
            Generating Ticket...
          </h2>
          <p className="text-muted-foreground text-lg">
            Preparing <span className="font-medium text-foreground">{selectedFile?.name}</span> for transfer
          </p>
        </div>
      )}

      {sendState === 'error' && (
        <div className="h-full flex flex-col items-center justify-center animate-fade-in">
          <div className="w-20 h-20 bg-gradient-to-br from-red-500/10 to-red-400/5 rounded-3xl 
                          flex items-center justify-center mb-8">
            <AlertCircle className="w-10 h-10 text-red-600" />
          </div>
          <h2 className="text-3xl font-bold text-foreground mb-3">
            Transfer Failed
          </h2>
          <p className="text-muted-foreground text-lg text-center mb-8 max-w-md">
            {error || 'An error occurred while preparing your file for transfer'}
          </p>
          <Button
            onClick={() => setSendState('select')}
            className="bg-primary hover:bg-primary/90 text-primary-foreground py-3 px-8
                       rounded-xl shadow-lg hover:shadow-xl transition-all duration-200"
          >
            Try Again
          </Button>
        </div>
      )}

      {sendState === 'ready' && (
        <div className="h-full flex flex-col animate-fade-in max-w-md mx-auto">
          <div className="flex-1 flex flex-col justify-center">
            <div className="text-center mb-10">
              <div className="w-20 h-20 bg-gradient-to-br from-blue-500/10 to-blue-400/5 rounded-3xl 
                              flex items-center justify-center mx-auto mb-8">
                <Check className="w-10 h-10 text-blue-600" />
              </div>
              <h2 className="text-3xl font-bold text-foreground mb-3">
                Your ticket is ready!
              </h2>
              <p className="text-muted-foreground text-lg">
                Share this ticket with the recipient
              </p>
            </div>

            <div className="space-y-6">
              <div>
                <label className="block text-sm font-semibold text-foreground mb-3">
                  Transfer Ticket
                </label>
                <div className="relative">
                  <input
                    type="text"
                    value={ticket}
                    readOnly
                    className="w-full p-4 border border-border rounded-xl font-mono text-sm
                             bg-muted/50 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2
                             text-foreground selection:bg-primary/20"
                  />
                </div>
              </div>

              <Button
                onClick={copyTicket}
                className="w-full bg-primary hover:bg-primary/90 text-primary-foreground py-6 text-lg font-semibold
                           rounded-xl shadow-lg hover:shadow-xl transition-all duration-200"
                disabled={copied}
              >
                {copied ? (
                  <>
                    <Check className="w-5 h-5 mr-2" />
                    Copied!
                  </>
                ) : (
                  <>
                    <Copy className="w-5 h-5 mr-2" />
                    Copy Ticket
                  </>
                )}
              </Button>

              <div className="text-center py-6">
                <p className="text-sm text-muted-foreground">
                  Status: <span className="text-orange-600 font-semibold">Waiting for receiver to connect...</span>
                </p>
              </div>
            </div>
          </div>

          <Button
            variant="outline"
            onClick={onBack}
            className="w-full mt-6 py-6 text-lg font-medium rounded-xl border-border/60"
          >
            Send Another File
          </Button>
        </div>
      )}
    </div>
  );
};

export default SendFlow;
