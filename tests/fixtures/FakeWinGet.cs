using System;
using System.IO;
using System.Linq;
using System.Text;

// A real child process at the WinGet boundary. Tests never invoke the host's WinGet.
public static class FakeWinGet
{
    public static int Main(string[] args)
    {
        Console.OutputEncoding = new UTF8Encoding(false);
        string scenario = Environment.GetEnvironmentVariable("COMPACT_TEST_SCENARIO");
        string calls = Environment.GetEnvironmentVariable("COMPACT_TEST_CALLS");
        File.AppendAllText(calls, String.Join(" ", args) + Environment.NewLine);
        if (args[0] == "--version") { Console.WriteLine("v1.29.380"); return 0; }
        int index = Array.IndexOf(args, "--id");
        string id = args[index + 1];
        if (args[0] == "show")
        {
            if (scenario == "missing-package") { Console.Error.WriteLine("Package unavailable"); return unchecked((int)0x8A150014); }
            Console.WriteLine("Verified package installer"); return 0;
        }
        if (args[0] == "list")
        {
            if (scenario == "list-error")
            {
                Console.Error.WriteLine("Cannot open package source.");
                return unchecked((int)0x8A150045);
            }
            if (scenario == "mixed" && id == "Valve.Steam")
            {
                Console.WriteLine("Application deja installee");
                return 0;
            }
            Console.WriteLine("No installed package matches.");
            return unchecked((int)0x8A150014);
        }
        if (!args.Contains("--no-upgrade") || !args.Contains("--silent") || !args.Contains("--exact"))
        {
            Console.Error.WriteLine("Missing safe installation flags.");
            return 87;
        }
        if ((scenario == "mixed" || scenario == "retry") && id == "Discord.Discord")
        {
            int attempts = File.ReadAllLines(calls).Count(line => line.StartsWith("install --id Discord.Discord "));
            if (scenario == "mixed" || attempts == 1)
            {
                Console.Error.WriteLine("Download failed: connection lost.");
                return unchecked((int)0x8A150008);
            }
        }
        if (scenario == "already") { return unchecked((int)0x8A150061); }
        if (scenario == "reboot") { return unchecked((int)0x8A150109); }
        if (scenario == "unknown-exit") { Console.Error.WriteLine("Unexpected installer error."); return 87; }
        Console.WriteLine("Installation completed.");
        return 0;
    }
}
