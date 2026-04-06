using System;
using System.Collections.Generic;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Windows.Graphics;
using Windows.UI;

namespace WinUI3ReferenceApp;

public sealed partial class MainWindow : Window
{
    private readonly List<ReferencePage> _pages = new List<ReferencePage>();
    private readonly Grid RootLayout = new Grid();
    private readonly TextBlock PageTitleTextBlock = new TextBlock();
    private readonly TextBlock PageDescriptionTextBlock = new TextBlock();
    private readonly ComboBox PageSelector = new ComboBox();
    private readonly ScrollViewer BodyScrollViewer = new ScrollViewer();
    private readonly StackPanel SectionHost = new StackPanel();

    public MainWindow(string? launchPageId = null)
    {
        BuildShell();
        StyleShell();
        BuildPages();
        TryResizeWindow();
        PageSelector.DisplayMemberPath = nameof(ReferencePage.Title);
        PageSelector.ItemsSource = _pages;

        if (_pages.Count > 0)
        {
            SelectInitialPage(launchPageId);
        }
    }

    private void SelectInitialPage(string? launchPageId)
    {
        var page = _pages.Find(candidate =>
            !string.IsNullOrWhiteSpace(launchPageId)
            && string.Equals(candidate.Id, launchPageId, StringComparison.OrdinalIgnoreCase));

        if (page is null)
        {
            page = _pages[0];
        }

        PageSelector.SelectedItem = page;
        RenderPage(page);
    }

    private void TryResizeWindow()
    {
        try
        {
            AppWindow.Resize(new SizeInt32(1440, 960));
        }
        catch (Exception)
        {
        }
    }

    private void BuildShell()
    {
        Title = "WinUI 3 Reference App";

        RootLayout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RootLayout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RootLayout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RootLayout.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        Grid.SetRow(PageTitleTextBlock, 0);
        Grid.SetRow(PageDescriptionTextBlock, 1);
        Grid.SetRow(PageSelector, 2);
        Grid.SetRow(BodyScrollViewer, 3);

        PageSelector.SelectionChanged += PageSelector_SelectionChanged;

        BodyScrollViewer.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        BodyScrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
        BodyScrollViewer.Content = SectionHost;

        RootLayout.Children.Add(PageTitleTextBlock);
        RootLayout.Children.Add(PageDescriptionTextBlock);
        RootLayout.Children.Add(PageSelector);
        RootLayout.Children.Add(BodyScrollViewer);

        Content = RootLayout;
    }

    private void StyleShell()
    {
        RootLayout.Background = Brush("ApplicationPageBackgroundThemeBrush", 243, 243, 243);
        PageTitleTextBlock.Margin = new Thickness(24, 24, 24, 0);
        PageTitleTextBlock.FontSize = 36;
        PageTitleTextBlock.FontWeight = FontWeights.SemiBold;

        PageDescriptionTextBlock.Margin = new Thickness(24, 8, 24, 0);
        PageDescriptionTextBlock.MaxWidth = 880;
        PageDescriptionTextBlock.Opacity = 0.82;
        PageDescriptionTextBlock.TextWrapping = TextWrapping.WrapWholeWords;

        PageSelector.Margin = new Thickness(24, 12, 24, 16);
        PageSelector.Width = 320;
        PageSelector.Header = "Review Page";
        PageSelector.HorizontalAlignment = HorizontalAlignment.Left;

        SectionHost.Margin = new Thickness(24, 0, 24, 24);
        SectionHost.Spacing = 20;
    }

    private void BuildPages()
    {
        _pages.Add(new ReferencePage("controls", "Controls", "Core WinUI 3 control states, emphasis, and density.", BuildControlsPage));
        _pages.Add(new ReferencePage("text-input", "Inputs", "Text fields, search, choice controls, and dense forms.", BuildInputsPage));
        _pages.Add(new ReferencePage("commands", "Command Surfaces", "Menus, toolbars, and contextual actions for document-oriented applications.", BuildCommandPage));
        _pages.Add(new ReferencePage("data-views", "Data Views", "Tables, outline views, tabs, split layouts, and scroll-heavy surfaces.", BuildDataPage));
        _pages.Add(new ReferencePage("dialogs", "Dialogs", "Feedback, confirmation, and file-panel previews for shell-value surfaces.", BuildDialogsPage));
        _pages.Add(new ReferencePage("real-app", "Real App", "A document-oriented shell and editor preview for ObjcMarkdown-style review.", BuildRealAppPage));
    }

    private void PageSelector_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var page = PageSelector.SelectedItem as ReferencePage;
        if (page is not null)
        {
            RenderPage(page);
        }
    }

    private void RenderPage(ReferencePage page)
    {
        Title = "WinUI 3 Reference App - " + page.Title;
        PageTitleTextBlock.Text = page.Title;
        PageDescriptionTextBlock.Text = page.Description;
        SectionHost.Children.Clear();
        page.Build(SectionHost);
    }

    private void BuildControlsPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Buttons And Emphasis",
            "Default emphasis, quiet secondary actions, and segmented command clusters.",
            BuildButtonCard()));
        host.Children.Add(CreateCard(
            "Selection Controls",
            "Checkbox, radio, and switch states for forms and settings-like surfaces.",
            BuildSelectionCard()));
        host.Children.Add(CreateCard(
            "Range And Progress",
            "Slider, progress, and compact stepping references.",
            BuildRangeCard()));
    }

    private void BuildInputsPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Text And Search",
            "Field density, placeholder weight, and multiline rhythm.",
            BuildTextCard()));
        host.Children.Add(CreateCard(
            "Choice Inputs",
            "Combo and popup-like controls that should stay quiet and aligned.",
            BuildChoiceCard()));
        host.Children.Add(CreateCard(
            "Disabled And Read-only",
            "Muted surfaces for inherited, locked, or unavailable values.",
            BuildDisabledInputCard()));
        host.Children.Add(CreateCard(
            "Dense Form",
            "A metadata editor surface where spacing issues show up immediately.",
            BuildFormCard()));
    }

    private void BuildCommandPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Menus And Toolbars",
            "Window-local menu review plus toolbar density and icon-label balance.",
            BuildCommandCard()));
        host.Children.Add(CreateCard(
            "Context Actions",
            "Flyout shape, separators, and shortcut alignment for contextual commands.",
            BuildContextActionCard()));
    }

    private void BuildDataPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Tables And Hierarchy",
            "Selection treatment, header weight, outline rhythm, and tabs.",
            BuildDataCard()));
        host.Children.Add(CreateCard(
            "Split And Scroll",
            "Pane balance and scroller treatment for document-oriented apps.",
            BuildSplitCard()));
    }

    private void BuildDialogsPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Feedback",
            "Informational, success, and warning surfaces used in task-oriented flows.",
            BuildFeedbackCard()));
        host.Children.Add(CreateCard(
            "Confirmation Layout",
            "A sheet-style confirmation surface with concise copy and trailing actions.",
            BuildSheetCard()));
        host.Children.Add(CreateCard(
            "File Panel Preview",
            "Sidebar, location field, file list, and action row for open/save panel review.",
            BuildFilePanelCard()));
    }

    private void BuildRealAppPage(StackPanel host)
    {
        host.Children.Add(CreateCard(
            "Document Shell",
            "A real-window composition target rather than a settings-shell imitation.",
            BuildWindowCard()));
        host.Children.Add(CreateCard(
            "Editor And Preview",
            "A split editing surface inspired by ObjcMarkdown.",
            BuildEditorCard()));
        host.Children.Add(CreateCard(
            "Acceptance Notes",
            "What this theme should still prove in the real ObjcMarkdown app later.",
            BuildChecklistCard()));
    }

    private UIElement BuildButtonCard()
    {
        var stack = Stack();
        stack.Children.Add(Row(
            AccentButton("Save changes"),
            new Button { Content = "Apply" },
            new Button { Content = "Reset" },
            new Button { Content = "Disabled", IsEnabled = false }));
        stack.Children.Add(Row(
            new Button
            {
                Content = new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 8,
                    Children =
                    {
                        new SymbolIcon(Symbol.Edit),
                        new TextBlock { Text = "Icon and label" }
                    }
                }
            },
            AccentButton("Pressed"),
            Segment("Preview", true),
            Segment("Split", false),
            Segment("Source", false)));
        return stack;
    }

    private UIElement BuildSelectionCard()
    {
        var grid = new Grid { ColumnSpacing = 20 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var checks = Stack();
        checks.Children.Add(new CheckBox { Content = "Checked", IsChecked = true });
        checks.Children.Add(new CheckBox { Content = "Unchecked", IsChecked = false });
        checks.Children.Add(new CheckBox { Content = "Mixed", IsThreeState = true, IsChecked = null });
        checks.Children.Add(new CheckBox { Content = "Disabled", IsChecked = true, IsEnabled = false });

        var radios = Stack();
        radios.Children.Add(new RadioButton { Content = "Primary", GroupName = "review", IsChecked = true });
        radios.Children.Add(new RadioButton { Content = "Secondary", GroupName = "review" });
        radios.Children.Add(new RadioButton { Content = "Disabled", GroupName = "review", IsEnabled = false });
        radios.Children.Add(SwitchPreview("Notifications", true));
        radios.Children.Add(SwitchPreview("Background sync", false));

        Grid.SetColumn(checks, 0);
        Grid.SetColumn(radios, 1);
        grid.Children.Add(checks);
        grid.Children.Add(radios);
        return grid;
    }

    private UIElement BuildRangeCard()
    {
        var stack = Stack();
        stack.Children.Add(new Slider { Minimum = 0, Maximum = 100, Value = 72, Width = 360 });
        stack.Children.Add(new ProgressBar { Minimum = 0, Maximum = 100, Value = 64, Width = 360 });
        stack.Children.Add(new ProgressBar { IsIndeterminate = true, Width = 360 });
        stack.Children.Add(Row(
            new ProgressRing { IsActive = true, Width = 28, Height = 28 },
            Stepper("Columns", "3")));
        return stack;
    }

    private UIElement BuildTextCard()
    {
        var stack = Stack();
        stack.Children.Add(new TextBox
        {
            Header = "Document title",
            Width = 420,
            Text = "Release notes"
        });
        stack.Children.Add(new AutoSuggestBox
        {
            Header = "Search",
            Width = 420,
            Text = "markdown",
            PlaceholderText = "Search settings, files, or commands"
        });
        stack.Children.Add(new PasswordBox
        {
            Header = "Password reference",
            Width = 420,
            Password = "secret-value"
        });
        stack.Children.Add(new TextBox
        {
            Header = "Summary",
            Width = 520,
            MinHeight = 96,
            AcceptsReturn = true,
            Text = "A compact multiline field used to review body copy spacing and edge padding."
        });
        return stack;
    }

    private UIElement BuildChoiceCard()
    {
        var stack = Stack();
        stack.Children.Add(Row(
            Combo("Theme variant", 220, "Default", "Light", "Dark", "High contrast"),
            Combo("Density", 180, "Comfortable", "Compact")));
        stack.Children.Add(new AutoSuggestBox
        {
            Header = "Editable combo-like input",
            Width = 320,
            Text = "release-notes",
            PlaceholderText = "Type or pick a recent tag"
        });
        stack.Children.Add(new TextBox
        {
            Width = 520,
            PlaceholderText = "A very long placeholder sentence intended to reveal truncation and padding behavior in dense layouts."
        });
        return stack;
    }

    private UIElement BuildDisabledInputCard()
    {
        var stack = Stack();
        stack.Children.Add(Row(
            new TextBox
            {
                Header = "Inherited value",
                Width = 240,
                Text = "Adwaita-derived spacing",
                IsEnabled = false
            },
            new PasswordBox
            {
                Header = "Locked secret",
                Width = 240,
                Password = "disabled-state",
                IsEnabled = false
            }));
        stack.Children.Add(new TextBox
        {
            Header = "Long placeholder",
            Width = 520,
            PlaceholderText = "Search through commands, recent exports, document titles, and toolbar actions without collapsing the leading icon area."
        });
        return stack;
    }

    private UIElement BuildFormCard()
    {
        var grid = new Grid
        {
            ColumnSpacing = 16,
            RowSpacing = 12,
            MaxWidth = 760
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        AddFormRow(grid, 0, "Title", new TextBox { Text = "Theme parity notes" });
        AddFormRow(grid, 1, "Slug", new TextBox { Text = "theme-parity-notes" });
        AddFormRow(grid, 2, "Category", Combo(null, double.NaN, "How-to", "Reference", "News"));
        AddFormRow(grid, 3, "Author", new TextBox { Text = "Daniel Boyd" });
        AddFormRow(grid, 4, "Publish date", new TextBox { Text = "2026-04-02" });
        AddFormRow(grid, 5, "Summary", new TextBox
        {
            Text = "Concise summary used to stress spacing and baseline alignment.",
            AcceptsReturn = true,
            MinHeight = 72
        });
        return grid;
    }

    private UIElement BuildCommandCard()
    {
        var stack = Stack();
        stack.Children.Add(Menu());

        var commandBar = new CommandBar
        {
            DefaultLabelPosition = CommandBarDefaultLabelPosition.Right
        };
        commandBar.PrimaryCommands.Add(new AppBarButton { Label = "New", Icon = new SymbolIcon(Symbol.Add) });
        commandBar.PrimaryCommands.Add(new AppBarButton { Label = "Open", Icon = new SymbolIcon(Symbol.OpenFile) });
        commandBar.PrimaryCommands.Add(new AppBarButton { Label = "Save", Icon = new SymbolIcon(Symbol.Save) });
        commandBar.PrimaryCommands.Add(new AppBarToggleButton { Label = "Preview", Icon = new SymbolIcon(Symbol.ShowResults), IsChecked = true });
        stack.Children.Add(commandBar);
        return stack;
    }

    private UIElement BuildContextActionCard()
    {
        var stack = Stack();
        var button = new Button
        {
            Content = "Open context menu",
            HorizontalAlignment = HorizontalAlignment.Left
        };

        var flyout = new MenuFlyout();
        flyout.Items.Add(new MenuFlyoutItem { Text = "Rename", Icon = new SymbolIcon(Symbol.Edit) });
        flyout.Items.Add(new MenuFlyoutItem { Text = "Duplicate", Icon = new SymbolIcon(Symbol.Copy) });
        flyout.Items.Add(new MenuFlyoutSeparator());
        flyout.Items.Add(new ToggleMenuFlyoutItem { Text = "Pin for quick access", IsChecked = true });
        FlyoutBase.SetAttachedFlyout(button, flyout);
        button.Click += (_, _) => FlyoutBase.ShowAttachedFlyout(button);

        stack.Children.Add(button);
        stack.Children.Add(new TextBlock
        {
            Opacity = 0.72,
            TextWrapping = TextWrapping.WrapWholeWords,
            Text = "Use this fixture to review flyout stroke, corner treatment, separators, and the spacing between icons and text."
        });
        return stack;
    }

    private UIElement BuildDataCard()
    {
        var stack = Stack();
        var selectionGrid = new Grid
        {
            ColumnSpacing = 16
        };
        selectionGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        selectionGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var active = Stack();
        active.Children.Add(new TextBlock { Text = "Active selection", FontWeight = FontWeights.SemiBold });
        active.Children.Add(Table(
            new[] { "Item", "State", "Owner" },
            new[]
            {
                new[] { "Preview", "Selected", "Editor" },
                new[] { "Outline", "Idle", "Inspector" },
                new[] { "History", "Idle", "Sidebar" }
            },
            0));

        var inactive = Stack();
        inactive.Children.Add(new TextBlock { Text = "Inactive-style reference", FontWeight = FontWeights.SemiBold });
        var inactiveTable = Table(
            new[] { "Item", "State", "Owner" },
            new[]
            {
                new[] { "Preview", "Selected", "Editor" },
                new[] { "Outline", "Idle", "Inspector" },
                new[] { "History", "Idle", "Sidebar" }
            },
            0);
        inactiveTable.Opacity = 0.78;
        inactive.Children.Add(inactiveTable);

        Grid.SetColumn(active, 0);
        Grid.SetColumn(inactive, 1);
        selectionGrid.Children.Add(active);
        selectionGrid.Children.Add(inactive);
        stack.Children.Add(selectionGrid);

        var grid = new Grid
        {
            Height = 280,
            ColumnSpacing = 16
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(280) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var outline = new StackPanel
        {
            Spacing = 8,
            Children =
            {
                new TextBlock { Text = "Documents", FontWeight = FontWeights.SemiBold },
                new TextBlock { Text = "  README.md" },
                new TextBlock { Text = "  Architecture notes" },
                new TextBlock { Text = "References", FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 0) },
                new TextBlock { Text = "  WinUI 3 capture set" },
                new TextBlock { Text = "  ObjcMarkdown review" }
            }
        };

        var tabs = new StackPanel
        {
            Spacing = 12,
            Children =
            {
                new Border
                {
                    Padding = new Thickness(6),
                    CornerRadius = new CornerRadius(12),
                    Background = Brush("LayerFillColorAltBrush", 246, 246, 246),
                    Child = Row(
                        Segment("Preview", true),
                        Segment("Source", false),
                        Segment("History", false))
                },
                Surface(
                    new StackPanel
                    {
                        Spacing = 10,
                        Children =
                        {
                            new TextBlock
                            {
                                Text = "Preview content uses a broad white surface with subtle padding and a concise title bar.",
                                TextWrapping = TextWrapping.WrapWholeWords
                            },
                            new TextBox
                            {
                                Height = 160,
                                AcceptsReturn = true,
                                Text = "# Title\n\nA Markdown sample for tab chrome review."
                            }
                        }
                    },
                    16)
            }
        };

        Grid.SetColumn(outline, 0);
        Grid.SetColumn(tabs, 1);
        grid.Children.Add(Inset(outline, 12));
        grid.Children.Add(tabs);
        stack.Children.Add(grid);
        return stack;
    }

    private UIElement BuildSplitCard()
    {
        var split = new SplitView
        {
            DisplayMode = SplitViewDisplayMode.Inline,
            IsPaneOpen = true,
            OpenPaneLength = 200,
            Height = 280
        };
        split.Pane = new Border
        {
            Padding = new Thickness(12),
            Child = new StackPanel
            {
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = "Sections", FontWeight = FontWeights.SemiBold },
                    new Button { Content = "Documents", HorizontalAlignment = HorizontalAlignment.Stretch },
                    new Button { Content = "Outline", HorizontalAlignment = HorizontalAlignment.Stretch },
                    new Button { Content = "Settings", HorizontalAlignment = HorizontalAlignment.Stretch }
                }
            }
        };
        split.Content = Inset(
            new ScrollViewer
            {
                Width = 480,
                Height = 220,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Content = new Border
                {
                    Width = 860,
                    Height = 420,
                    Background = Brush("LayerFillColorAltBrush", 246, 246, 246),
                    Padding = new Thickness(20),
                    Child = new TextBlock
                    {
                        TextWrapping = TextWrapping.WrapWholeWords,
                        Text = "Use this oversized content area to inspect pane width, thumb sizing, track contrast, and spacing between dense content surfaces."
                    }
                }
            },
            18);
        return split;
    }

    private UIElement BuildFeedbackCard()
    {
        var stack = Stack();
        stack.Children.Add(Notice("Export queued", "The current document was added to the export queue and will run after the active preview render finishes.", 0, 95, 184));
        stack.Children.Add(Notice("Capture completed", "The latest WinUI and GNUstep screenshots were stored successfully.", 16, 124, 16));
        stack.Children.Add(Notice("Visual mismatch detected", "The table header rhythm diverged from the accepted reference capture.", 168, 102, 0));
        return stack;
    }

    private UIElement BuildSheetCard()
    {
        var stack = Stack();
        stack.Children.Add(new TextBlock
        {
            Text = "Discard unsaved changes?",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold
        });
        stack.Children.Add(new TextBlock
        {
            Opacity = 0.76,
            TextWrapping = TextWrapping.WrapWholeWords,
            Text = "This inline preview is for title spacing, body width, and the trailing action cluster rather than shell chrome."
        });
        stack.Children.Add(new Border
        {
            Height = 1,
            Background = Brush("DividerStrokeColorDefaultBrush", 220, 220, 220)
        });
        stack.Children.Add(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            HorizontalAlignment = HorizontalAlignment.Right,
            Children =
            {
                new Button { Content = "Cancel" },
                new Button { Content = "Discard" },
                AccentButton("Save")
            }
        });

        var card = Surface(stack, 18);
        card.MaxWidth = 460;
        return card;
    }

    private UIElement BuildFilePanelCard()
    {
        var grid = new Grid
        {
            Height = 300
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var sidebar = new Border
        {
            Background = Brush("LayerFillColorAltBrush", 246, 246, 246),
            Padding = new Thickness(16),
            Child = new StackPanel
            {
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = "Quick access", FontWeight = FontWeights.SemiBold },
                    new TextBlock { Text = "Desktop" },
                    new TextBlock { Text = "Documents" },
                    new TextBlock { Text = "ObjcMarkdown" }
                }
            }
        };

        var content = new Border
        {
            Padding = new Thickness(18),
            Child = new StackPanel
            {
                Spacing = 12,
                Children =
                {
                    new TextBox { Header = "Current location", Text = @"C:\Users\Support\git\ObjcMarkdown" },
                    Table(
                        new[] { "Name", "Type", "Modified" },
                        new[]
                        {
                            new[] { "README.md", "Markdown", "Today" },
                            new[] { "GNUmakefile", "Build", "Yesterday" },
                            new[] { "Resources", "Folder", "Last week" }
                        },
                        0),
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Spacing = 8,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children =
                        {
                            new Button { Content = "Cancel" },
                            AccentButton("Open")
                        }
                    }
                }
            }
        };

        Grid.SetColumn(sidebar, 0);
        Grid.SetColumn(content, 1);
        grid.Children.Add(sidebar);
        grid.Children.Add(content);
        return Surface(grid, 0);
    }

    private UIElement BuildWindowCard()
    {
        var root = new Grid { Height = 420 };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var menuBar = Menu();
        Grid.SetRow(menuBar, 0);
        root.Children.Add(menuBar);

        var toolbarChrome = new Border
        {
            Padding = new Thickness(12, 12, 12, 8)
        };
        var toolbar = new Grid { ColumnSpacing = 12 };
        toolbar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        toolbar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        toolbar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        toolbar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        toolbar.Children.Add(new Button { Content = "New" });
        var saveButton = AccentButton("Save");
        Grid.SetColumn(saveButton, 1);
        toolbar.Children.Add(saveButton);
        var search = new AutoSuggestBox { Width = 260, PlaceholderText = "Search documents" };
        Grid.SetColumn(search, 2);
        toolbar.Children.Add(search);
        var density = Combo(null, 180, "Comfortable density", "Compact density");
        Grid.SetColumn(density, 3);
        toolbar.Children.Add(density);
        toolbarChrome.Child = toolbar;
        Grid.SetRow(toolbarChrome, 1);
        root.Children.Add(toolbarChrome);

        var content = new Grid
        {
            ColumnSpacing = 1,
            Background = Brush("DividerStrokeColorDefaultBrush", 222, 222, 222)
        };
        content.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });
        content.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(320) });
        content.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var sidebar = new Border
        {
            Background = Brush("LayerFillColorAltBrush", 246, 246, 246),
            Padding = new Thickness(12),
            Child = new ListView { ItemsSource = new[] { "Inbox", "Drafts", "Published", "Archives" }, SelectedIndex = 1 }
        };
        var documents = new Border
        {
            Background = Brush("CardBackgroundFillColorDefaultBrush", 255, 255, 255),
            Padding = new Thickness(12),
            Child = new ListView
            {
                ItemsSource = new[] { "Release notes draft", "Theme parity checklist", "ObjcMarkdown visual audit", "Open issues" },
                SelectedIndex = 0
            }
        };
        var preview = new Border
        {
            Background = Brush("CardBackgroundFillColorDefaultBrush", 255, 255, 255),
            Padding = new Thickness(18),
            Child = new StackPanel
            {
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = "Release notes draft", FontSize = 24, FontWeight = FontWeights.SemiBold },
                    new TextBlock { Text = "Updated 3 minutes ago", Opacity = 0.72 },
                    new TextBlock
                    {
                        TextWrapping = TextWrapping.WrapWholeWords,
                        Text = "This reference surface approximates a document shell without imitating a settings app. It keeps the parity target grounded in real work surfaces."
                    }
                }
            }
        };

        Grid.SetColumn(sidebar, 0);
        Grid.SetColumn(documents, 1);
        Grid.SetColumn(preview, 2);
        content.Children.Add(sidebar);
        content.Children.Add(documents);
        content.Children.Add(preview);
        Grid.SetRow(content, 2);
        root.Children.Add(content);

        return Surface(root, 0);
    }

    private UIElement BuildEditorCard()
    {
        var grid = new Grid
        {
            Height = 320,
            ColumnSpacing = 16
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var editor = new TextBox
        {
            Header = "Editor",
            AcceptsReturn = true,
            TextWrapping = TextWrapping.Wrap,
            Text = "# Heading\n\n- item one\n- item two\n\nThis pane stands in for ObjcMarkdown's editor surface."
        };
        var preview = Surface(
            new StackPanel
            {
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = "Preview", FontSize = 22, FontWeight = FontWeights.SemiBold },
                    new TextBlock { Text = "Heading", FontSize = 28, FontWeight = FontWeights.SemiBold },
                    new TextBlock
                    {
                        TextWrapping = TextWrapping.WrapWholeWords,
                        Text = "item one\nitem two\n\nThis pane stands in for ObjcMarkdown's preview surface."
                    }
                }
            },
            18);

        Grid.SetColumn(editor, 0);
        Grid.SetColumn(preview, 1);
        grid.Children.Add(editor);
        grid.Children.Add(preview);
        return grid;
    }

    private UIElement BuildChecklistCard()
    {
        var stack = Stack();
        stack.Children.Add(Check("Menu bar, toolbar, and content panes feel like one system rather than three unrelated themes."));
        stack.Children.Add(Check("Selection treatment stays readable when the window is inactive."));
        stack.Children.Add(Check("Dense forms retain stable baselines and compact but not cramped spacing."));
        stack.Children.Add(Check("ObjcMarkdown editor and preview panes feel balanced when placed side by side."));
        return stack;
    }

    private Border CreateCard(string title, string body, UIElement content)
    {
        var stack = new StackPanel { Spacing = 16 };
        stack.Children.Add(new TextBlock { Text = title, FontSize = 22, FontWeight = FontWeights.SemiBold });
        stack.Children.Add(new TextBlock { Text = body, Opacity = 0.76, TextWrapping = TextWrapping.WrapWholeWords });
        stack.Children.Add(Inset(content, 18));
        return Surface(stack, 24);
    }

    private Border Table(string[] headers, string[][] rows, int selectedIndex)
    {
        var stack = new StackPanel { Spacing = 0 };
        var headerGrid = new Grid { ColumnSpacing = 12 };

        for (var index = 0; index < headers.Length; index++)
        {
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition
            {
                Width = index == headers.Length - 1 ? new GridLength(1, GridUnitType.Star) : new GridLength(160)
            });
            var label = new TextBlock { Text = headers[index], FontWeight = FontWeights.SemiBold, Opacity = 0.72 };
            Grid.SetColumn(label, index);
            headerGrid.Children.Add(label);
        }

        stack.Children.Add(new Border
        {
            Padding = new Thickness(16, 12, 16, 12),
            Background = Brush("LayerFillColorAltBrush", 246, 246, 246),
            Child = headerGrid
        });

        var list = new ListView { SelectionMode = ListViewSelectionMode.Single, MaxHeight = 220 };
        foreach (var row in rows)
        {
            var rowGrid = new Grid { ColumnSpacing = 12 };
            for (var index = 0; index < row.Length; index++)
            {
                rowGrid.ColumnDefinitions.Add(new ColumnDefinition
                {
                    Width = index == row.Length - 1 ? new GridLength(1, GridUnitType.Star) : new GridLength(160)
                });
                var text = new TextBlock { Text = row[index], TextWrapping = TextWrapping.WrapWholeWords };
                Grid.SetColumn(text, index);
                rowGrid.Children.Add(text);
            }

            list.Items.Add(new Border
            {
                Padding = new Thickness(16, 10, 16, 10),
                Child = rowGrid
            });
        }
        list.SelectedIndex = selectedIndex;
        stack.Children.Add(list);
        return Surface(stack, 0);
    }

    private ComboBox Combo(string? header, double width, params string[] items)
    {
        var combo = new ComboBox { Width = width, ItemsSource = items, SelectedIndex = 0 };
        if (!string.IsNullOrWhiteSpace(header))
        {
            combo.Header = header;
        }
        return combo;
    }

    private MenuBar Menu()
    {
        var menuBar = new MenuBar();
        var file = new MenuBarItem { Title = "File" };
        file.Items.Add(new MenuFlyoutItem { Text = "New", Icon = new SymbolIcon(Symbol.Page2) });
        file.Items.Add(new MenuFlyoutItem { Text = "Open", Icon = new SymbolIcon(Symbol.OpenFile) });
        file.Items.Add(new MenuFlyoutSeparator());
        file.Items.Add(new MenuFlyoutItem { Text = "Export", Icon = new SymbolIcon(Symbol.Save) });

        var edit = new MenuBarItem { Title = "Edit" };
        edit.Items.Add(new MenuFlyoutItem { Text = "Undo", Icon = new SymbolIcon(Symbol.Undo) });
        edit.Items.Add(new MenuFlyoutItem { Text = "Redo", Icon = new SymbolIcon(Symbol.Redo) });
        edit.Items.Add(new MenuFlyoutSeparator());
        edit.Items.Add(new MenuFlyoutItem { Text = "Find", Icon = new SymbolIcon(Symbol.Find) });

        menuBar.Items.Add(file);
        menuBar.Items.Add(edit);
        return menuBar;
    }

    private Button AccentButton(string title)
    {
        var button = new Button { Content = title };
        if (Application.Current.Resources.TryGetValue("AccentButtonStyle", out var styleObject) && styleObject is Style style)
        {
            button.Style = style;
        }
        return button;
    }

    private Button Segment(string title, bool selected)
    {
        return new Button
        {
            Content = title,
            MinWidth = 96,
            Background = selected ? Brush("AccentFillColorDefaultBrush", 0, 95, 184) : Brush("LayerFillColorAltBrush", 246, 246, 246),
            Foreground = selected ? new SolidColorBrush(Color.FromArgb(255, 255, 255, 255)) : Brush("TextFillColorPrimaryBrush", 32, 32, 32)
        };
    }

    private void AddFormRow(Grid grid, int row, string label, FrameworkElement editor)
    {
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var text = new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center };
        Grid.SetRow(text, row);
        Grid.SetColumn(text, 0);
        grid.Children.Add(text);
        Grid.SetRow(editor, row);
        Grid.SetColumn(editor, 1);
        grid.Children.Add(editor);
    }

    private Border Check(string text)
    {
        return new Border
        {
            Padding = new Thickness(14),
            CornerRadius = new CornerRadius(12),
            Background = Brush("LayerFillColorAltBrush", 247, 247, 247),
            Child = Row(
                new SymbolIcon(Symbol.Accept),
                new TextBlock { Text = text, TextWrapping = TextWrapping.WrapWholeWords })
        };
    }

    private UIElement SwitchPreview(string label, bool isOn)
    {
        var track = new Border
        {
            Width = 42,
            Height = 24,
            CornerRadius = new CornerRadius(12),
            Background = isOn
                ? Brush("AccentFillColorDefaultBrush", 0, 95, 184)
                : Brush("CardStrokeColorDefaultBrush", 210, 210, 210),
            Padding = new Thickness(3)
        };

        var thumb = new Border
        {
            Width = 18,
            Height = 18,
            CornerRadius = new CornerRadius(9),
            Background = new SolidColorBrush(Color.FromArgb(255, 255, 255, 255)),
            HorizontalAlignment = isOn ? HorizontalAlignment.Right : HorizontalAlignment.Left
        };
        track.Child = thumb;

        return new StackPanel
        {
            Spacing = 6,
            Children =
            {
                new TextBlock { Text = label },
                Row(track, new TextBlock { Text = isOn ? "On" : "Off", VerticalAlignment = VerticalAlignment.Center })
            }
        };
    }

    private Border Notice(string title, string message, byte r, byte g, byte b)
    {
        var stripe = new Border
        {
            Width = 4,
            CornerRadius = new CornerRadius(999),
            Background = new SolidColorBrush(Color.FromArgb(255, r, g, b))
        };

        var content = new StackPanel
        {
            Spacing = 6,
            Children =
            {
                new TextBlock { Text = title, FontWeight = FontWeights.SemiBold },
                new TextBlock { Text = message, TextWrapping = TextWrapping.WrapWholeWords, Opacity = 0.82 }
            }
        };

        var grid = new Grid
        {
            ColumnSpacing = 12
        };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        Grid.SetColumn(stripe, 0);
        Grid.SetColumn(content, 1);
        grid.Children.Add(stripe);
        grid.Children.Add(content);

        return new Border
        {
            Padding = new Thickness(14),
            CornerRadius = new CornerRadius(12),
            Background = Brush("LayerFillColorAltBrush", 247, 247, 247),
            Child = grid
        };
    }

    private Border Surface(UIElement child, double padding)
    {
        return new Border
        {
            Padding = new Thickness(padding),
            CornerRadius = new CornerRadius(18),
            Background = Brush("CardBackgroundFillColorDefaultBrush", 255, 255, 255),
            BorderBrush = Brush("CardStrokeColorDefaultBrush", 224, 224, 224),
            BorderThickness = new Thickness(1),
            Child = child
        };
    }

    private Border Inset(UIElement child, double padding)
    {
        return new Border
        {
            Padding = new Thickness(padding),
            CornerRadius = new CornerRadius(14),
            Background = Brush("LayerFillColorAltBrush", 248, 248, 248),
            BorderBrush = Brush("CardStrokeColorDefaultBrush", 226, 226, 226),
            BorderThickness = new Thickness(1),
            Child = child
        };
    }

    private SolidColorBrush Brush(string key, byte r, byte g, byte b)
    {
        if (Application.Current.Resources.TryGetValue(key, out var value) && value is SolidColorBrush brush)
        {
            return brush;
        }
        return new SolidColorBrush(Color.FromArgb(255, r, g, b));
    }

    private FrameworkElement Stepper(string label, string value)
    {
        return new StackPanel
        {
            Spacing = 6,
            Children =
            {
                new TextBlock { Text = label, Opacity = 0.72 },
                new Border
                {
                    CornerRadius = new CornerRadius(10),
                    BorderBrush = Brush("CardStrokeColorDefaultBrush", 224, 224, 224),
                    BorderThickness = new Thickness(1),
                    Child = Row(
                        new Button { Content = "-", MinWidth = 36 },
                        new TextBlock
                        {
                            Text = value,
                            Width = 32,
                            VerticalAlignment = VerticalAlignment.Center,
                            TextAlignment = TextAlignment.Center
                        },
                        new Button { Content = "+", MinWidth = 36 })
                }
            }
        };
    }

    private static StackPanel Row(params UIElement[] children)
    {
        var stack = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        foreach (var child in children)
        {
            stack.Children.Add(child);
        }
        return stack;
    }

    private static StackPanel Stack()
    {
        return new StackPanel { Spacing = 12 };
    }

    private sealed class ReferencePage
    {
        public ReferencePage(string id, string title, string description, System.Action<StackPanel> build)
        {
            Id = id;
            Title = title;
            Description = description;
            Build = build;
        }

        public string Id { get; }
        public string Title { get; }
        public string Description { get; }
        public System.Action<StackPanel> Build { get; }
    }

}
