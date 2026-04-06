using System;
using Microsoft.UI.Xaml;

namespace WinUI3ReferenceApp;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(ParseLaunchPage());
        _window.Activate();
    }

    private static string? ParseLaunchPage()
    {
        var tokens = Environment.GetCommandLineArgs();
        if (tokens is null || tokens.Length == 0)
        {
            return null;
        }

        for (var index = 0; index < tokens.Length; index++)
        {
            if (string.Equals(tokens[index], "--page", StringComparison.OrdinalIgnoreCase)
                && index + 1 < tokens.Length)
            {
                return tokens[index + 1];
            }
        }

        return null;
    }
}
