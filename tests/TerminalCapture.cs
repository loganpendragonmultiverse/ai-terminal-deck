// Test-only Windows Terminal stand-in. It runs the exact pane PowerShell code
// without -NoExit so CI can verify cmd/PowerShell argument and environment binding.
// This does not prove Windows Terminal UI behavior.
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Collections.Generic;
public class TerminalCapture {
    static string Quote(string value) {
        var b = new StringBuilder("\""); int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') b.Append('\\', slashes * 2 + 1);
            else b.Append('\\', slashes);
            b.Append(c); slashes = 0;
        }
        b.Append('\\', slashes * 2); return b.Append('"').ToString();
    }
    public static int Main(string[] args) {
        var lines = new List<string>();
        foreach (string arg in args) lines.Add("ARG:" + Convert.ToBase64String(Encoding.UTF8.GetBytes(arg)));
        int count = 0;
        for (int i = 0; i + 1 < args.Length; i++) {
            if (args[i] != "-Command") continue;
            var info = new ProcessStartInfo();
            info.FileName = Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
            info.Arguments = "-NoLogo -NoProfile -Command " + Quote(args[i + 1]);
            info.UseShellExecute = false; info.CreateNoWindow = true;
            info.RedirectStandardOutput = true; info.RedirectStandardError = true;
            using (var process = Process.Start(info)) {
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                lines.Add("EXIT:" + process.ExitCode);
                lines.Add("OUT:" + Convert.ToBase64String(Encoding.UTF8.GetBytes(output)));
                lines.Add("ERR:" + Convert.ToBase64String(Encoding.UTF8.GetBytes(error)));
            }
            count++;
        }
        lines.Add("PANES:" + count);
        File.WriteAllLines(Environment.GetEnvironmentVariable("AI_TERMINAL_DECK_TEST_CAPTURE"), lines.ToArray());
        return 0;
    }
}
