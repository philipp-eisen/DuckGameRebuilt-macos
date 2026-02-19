#if DUCKGAME_NET10
using System;
using System.Reflection;

namespace DGWindows
{
    internal static class WindowsPlatformStartup
    {
        public static bool isRunningWine => false;

        public static string wineVersion => null;

        public static void AssemblyLoad(object sender, AssemblyLoadEventArgs args)
        {
        }

        public static void UnhandledExceptionTrapper(object sender, UnhandledExceptionEventArgs e)
        {
        }

        public static string ProcessErrorLine(string line, Exception exception)
        {
            return line;
        }

        public static string GetCrashWindowString(Exception exception, object source, string log)
        {
            return string.Empty;
        }
    }
}
#endif
