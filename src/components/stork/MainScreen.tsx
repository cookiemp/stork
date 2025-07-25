import { Send, Download } from 'lucide-react';

interface MainScreenProps {
  onSend: () => void;
  onReceive: () => void;
}

const MainScreen = ({ onSend, onReceive }: MainScreenProps) => {
  return (
    <div className="h-full flex gap-6 p-8">
      {/* Send Panel */}
      <div 
        onClick={onSend}
        className="flex-1 flex flex-col items-center justify-center p-10 cursor-pointer 
                   bg-card hover:bg-accent/50 transition-all duration-300 group 
                   rounded-2xl border border-border/60 hover:border-primary/30 
                   hover:shadow-lg hover:shadow-primary/10 hover:-translate-y-1"
      >
        <div className="transform group-hover:scale-110 transition-all duration-300 mb-8">
          <div className="w-20 h-20 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl 
                          flex items-center justify-center shadow-lg group-hover:shadow-xl 
                          group-hover:shadow-blue-500/25">
            <Send className="w-10 h-10 text-white" />
          </div>
        </div>
        <h2 className="text-2xl font-bold text-foreground mb-4 group-hover:text-primary transition-colors">
          Send a File
        </h2>
        <p className="text-muted-foreground text-center leading-relaxed font-medium">
          Select a file to generate a transfer ticket
        </p>
      </div>

      {/* Receive Panel */}
      <div 
        onClick={onReceive}
        className="flex-1 flex flex-col items-center justify-center p-10 cursor-pointer 
                   bg-card hover:bg-accent/50 transition-all duration-300 group 
                   rounded-2xl border border-border/60 hover:border-green-500/30 
                   hover:shadow-lg hover:shadow-green-500/10 hover:-translate-y-1"
      >
        <div className="transform group-hover:scale-110 transition-all duration-300 mb-8">
          <div className="w-20 h-20 bg-gradient-to-br from-green-500 to-green-600 rounded-2xl 
                          flex items-center justify-center shadow-lg group-hover:shadow-xl 
                          group-hover:shadow-green-500/25">
            <Download className="w-10 h-10 text-white" />
          </div>
        </div>
        <h2 className="text-2xl font-bold text-foreground mb-4 group-hover:text-green-600 transition-colors">
          Receive a File
        </h2>
        <p className="text-muted-foreground text-center leading-relaxed font-medium">
          Paste a ticket to start your download
        </p>
      </div>
    </div>
  );
};

export default MainScreen;
