import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import StorkApp from './components/StorkApp';
import './App.css';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-background 
                        flex items-center justify-center p-4 sm:p-8">
          <StorkApp />
        </div>
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
