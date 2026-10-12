using System;
using Microsoft.UI.Xaml;

namespace WinUI3ReferenceApp;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
        /* --mode light|dark, as ThemeDemo takes it, for comparing the two
           (Tests/Scripts/Compare-Reference.ps1). */
        var mode = ParseArgument("--mode");
        if (string.Equals(mode, "dark", StringComparison.OrdinalIgnoreCase))
        {
            RequestedTheme = ApplicationTheme.Dark;
        }
        else if (string.Equals(mode, "light", StringComparison.OrdinalIgnoreCase))
        {
            RequestedTheme = ApplicationTheme.Light;
        }
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(ParseLaunchPage());
        _window.Activate();
    }

    private static string? ParseLaunchPage()
    {
        return ParseArgument("--page");
    }

    private static string? ParseArgument(string name)
    {
        var tokens = Environment.GetCommandLineArgs();
        if (tokens is null || tokens.Length == 0)
        {
            return null;
        }

        for (var index = 0; index < tokens.Length; index++)
        {
            if (string.Equals(tokens[index], name, StringComparison.OrdinalIgnoreCase)
                && index + 1 < tokens.Length)
            {
                return tokens[index + 1];
            }
        }

        return null;
    }
}
