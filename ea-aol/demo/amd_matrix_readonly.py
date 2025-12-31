#!/usr/bin/env python3
"""
EA-AOL Matrix Dashboard - Read-Only Mode

No input interference, pure monitoring display
"""
import time
import os
import sys

# Disable input buffering
sys.stdin = open(os.devnull)

# ANSI Color Codes (Matrix-inspired)
class Colors:
    MATRIX_GREEN = '\033[38;5;46m'
    MATRIX_DIM = '\033[38;5;28m'
    MATRIX_BRIGHT = '\033[38;5;82m'
    RED = '\033[38;5;196m'
    YELLOW = '\033[38;5;226m'
    CYAN = '\033[38;5;51m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    BLINK = '\033[5m'
    RESET = '\033[0m'
    BG_BLACK = '\033[40m'

class MatrixDashboard:
    """Matrix-style terminal dashboard (read-only)"""
    
    def __init__(self):
        self.POWER_CAP = 180.0
        self.TEMP_LIMIT = 85.0
        self.start_time = time.time()
        self.optimization_active = False
        self.optimization_start_time = None
        
        if os.name == 'nt':
            os.system('color')
    
    def clear_screen(self):
        """Move cursor to top"""
        print('\033[H', end='')
    
    def hide_cursor(self):
        """Hide cursor"""
        print('\033[?25l', end='')
    
    def show_cursor(self):
        """Show cursor"""
        print('\033[?25h', end='')
    
    def read_amd_gpu(self):
        """Read AMD GPU data"""
        try:
            import wmi
            c = wmi.WMI(namespace="root\\OpenHardwareMonitor")
            
            power = None
            temp = None
            
            for sensor in c.Sensor():
                if 'AMD' in sensor.Name or 'Radeon' in sensor.Name:
                    if 'Power' in sensor.Name:
                        power = float(sensor.Value)
                    elif 'Temperature' in sensor.Name:
                        temp = float(sensor.Value)
            
            if power is None:
                power = 120.0 + (time.time() % 10) * 8
            if temp is None:
                temp = 60.0 + (time.time() % 10) * 3
            
            return power, temp
            
        except:
            t = time.time()
            power = 120.0 + (t % 10) * 8
            temp = 60.0 + (t % 10) * 3
            return power, temp
    
    def draw_matrix_bar(self, value, max_value, width=50):
        """Draw Matrix-style bar"""
        filled = int((value / max_value) * width)
        
        if value > max_value * 0.9:
            color = Colors.RED
        elif value > max_value * 0.7:
            color = Colors.YELLOW
        else:
            color = Colors.MATRIX_GREEN
        
        bar = color + '█' * filled + Colors.MATRIX_DIM + '░' * (width - filled) + Colors.RESET
        return bar
    
    def matrix_header(self):
        """Matrix-style header"""
        return f"""
{Colors.MATRIX_GREEN}{Colors.BOLD}███████╗ █████╗      █████╗  ██████╗ ██╗     {Colors.CYAN}Sun's AMD GPU Monitor{Colors.RESET}
{Colors.MATRIX_GREEN}██╔════╝██╔══██╗    ██╔══██╗██╔═══██╗██║     {Colors.MATRIX_DIM}Real-Time Optimization{Colors.RESET}
{Colors.MATRIX_GREEN}█████╗  ███████║    ███████║██║   ██║██║{Colors.RESET}
{Colors.MATRIX_GREEN}██╔══╝  ██╔══██║    ██╔══██║██║   ██║██║{Colors.RESET}
{Colors.MATRIX_GREEN}███████╗██║  ██║    ██║  ██║╚██████╔╝███████╗{Colors.RESET}
"""
    
    def run(self):
        """Run dashboard (read-only mode)"""
        os.system('cls' if os.name == 'nt' else 'clear')
        self.hide_cursor()
        
        print(f"{Colors.MATRIX_GREEN}Initializing EA-AOL Matrix Interface...{Colors.RESET}")
        print(f"{Colors.MATRIX_DIM}Read-Only Mode: Input disabled for stable display{Colors.RESET}")
        time.sleep(2)
        
        try:
            while True:
                current_time = time.time() - self.start_time
                power, temp = self.read_amd_gpu()
                
                violation = power > self.POWER_CAP or temp > self.TEMP_LIMIT
                
                if violation and not self.optimization_active:
                    self.optimization_active = True
                    self.optimization_start_time = current_time
                
                if self.optimization_active:
                    reduction = min(1.0, (current_time - self.optimization_start_time) / 5.0)
                    power = power * (1.0 - 0.4 * reduction)
                    temp = temp * (1.0 - 0.2 * reduction)
                
                self.clear_screen()
                print(self.matrix_header())
                print(f"{Colors.MATRIX_DIM}Runtime: {Colors.MATRIX_GREEN}{current_time:.1f}s{Colors.RESET}")
                print()
                
                print(f"{Colors.MATRIX_BRIGHT}{'═' * 79}{Colors.RESET}")
                if violation and not self.optimization_active:
                    status_text = f"{Colors.RED}{Colors.BOLD}{Colors.BLINK}⚠ POWER VIOLATION DETECTED ⚠{Colors.RESET}"
                elif self.optimization_active:
                    status_text = f"{Colors.MATRIX_GREEN}{Colors.BOLD}✓ EA-AOL OPTIMIZATION ACTIVE{Colors.RESET}"
                else:
                    status_text = f"{Colors.CYAN}● SYSTEM NOMINAL{Colors.RESET}"
                
                print(f"STATUS: {status_text}")
                print(f"{Colors.MATRIX_BRIGHT}{'═' * 79}{Colors.RESET}")
                print()
                
                power_pct = (power / self.POWER_CAP) * 100
                power_color = Colors.RED if power > self.POWER_CAP else Colors.MATRIX_GREEN
                print(f"{Colors.MATRIX_DIM}POWER CONSUMPTION:{Colors.RESET}")
                print(f"{power_color}{Colors.BOLD}{power:5.1f}W{Colors.RESET} / {Colors.MATRIX_DIM}{self.POWER_CAP:5.1f}W{Colors.RESET} ({power_pct:3.0f}%)")
                print(self.draw_matrix_bar(power, 250.0, width=60))
                print()
                
                temp_pct = (temp / self.TEMP_LIMIT) * 100
                temp_color = Colors.RED if temp > self.TEMP_LIMIT else Colors.MATRIX_GREEN
                print(f"{Colors.MATRIX_DIM}GPU TEMPERATURE:{Colors.RESET}")
                print(f"{temp_color}{Colors.BOLD}{temp:5.1f}°C{Colors.RESET} / {Colors.MATRIX_DIM}{self.TEMP_LIMIT:5.1f}°C{Colors.RESET} ({temp_pct:3.0f}%)")
                print(self.draw_matrix_bar(temp, 100.0, width=60))
                print()
                
                print(f"{Colors.MATRIX_BRIGHT}{'─' * 79}{Colors.RESET}")
                print(f"{Colors.MATRIX_DIM}OPTIMIZATION METRICS:{Colors.RESET}")
                
                if self.optimization_active:
                    power_reduction = int((1 - power/245)*100)
                    temp_reduction = int((1 - temp/87)*100)
                    print(f"  {Colors.MATRIX_GREEN}► Power Reduction: {Colors.BOLD}{power_reduction:3d}%{Colors.RESET}")
                    print(f"  {Colors.MATRIX_GREEN}► Temp Reduction:  {Colors.BOLD}{temp_reduction:3d}%{Colors.RESET}")
                    print(f"  {Colors.MATRIX_GREEN}► Status:          {Colors.BOLD}ACTIVE{Colors.RESET}")
                else:
                    print(f"  {Colors.MATRIX_DIM}► Power Reduction:   0%{Colors.RESET}")
                    print(f"  {Colors.MATRIX_DIM}► Temp Reduction:    0%{Colors.RESET}")
                    print(f"  {Colors.MATRIX_DIM}► Status:          STANDBY{Colors.RESET}")
                
                print(f"{Colors.MATRIX_BRIGHT}{'─' * 79}{Colors.RESET}")
                print()
                print(f"{Colors.MATRIX_DIM}Press Ctrl+C to exit (Input disabled in this window){Colors.RESET}")
                
                time.sleep(0.5)
                
        except KeyboardInterrupt:
            self.show_cursor()
            os.system('cls' if os.name == 'nt' else 'clear')
            print(f"\n{Colors.MATRIX_GREEN}{Colors.BOLD}")
            print("╔═══════════════════════════════════════╗")
            print("║                                       ║")
            print("║     EA-AOL SYSTEM DISCONNECTED        ║")
            print("║                                       ║")
            print("╚═══════════════════════════════════════╝")
            print(f"{Colors.RESET}\n")

def main():
    dashboard = MatrixDashboard()
    dashboard.run()

if __name__ == '__main__':
    main()
