using System.Collections;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using YamlDotNet.Serialization;

namespace MissionControl.Forms;

internal static class Program
{
    private const int GWL_STYLE = -16;
    private const int WS_HSCROLL = 0x00100000;
    private const int WS_VSCROLL = 0x00200000;
    private const int SB_HORZ = 0;
    private const int SB_VERT = 1;
    private const uint SIF_RANGE = 0x1;
    private const uint SIF_PAGE = 0x2;
    private const uint SIF_POS = 0x4;
    private const uint SIF_TRACKPOS = 0x10;
    private const uint SIF_ALL = SIF_RANGE | SIF_PAGE | SIF_POS | SIF_TRACKPOS;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern bool GetScrollInfo(IntPtr hwnd, int nBar, ref SCROLLINFO lpsi);

    private static CoreWebView2Environment? sharedWebView2Environment;

    [StructLayout(LayoutKind.Sequential)]
    private struct SCROLLINFO
    {
        public uint cbSize;
        public uint fMask;
        public int nMin;
        public int nMax;
        public uint nPage;
        public int nPos;
        public int nTrackPos;
    }

    private class MdiMainForm : Form
    {
        private readonly List<LayoutItem> _topItems;
        private readonly double _rootWidth;
        private readonly double _rootHeight;
        private readonly string _scriptDirectory;

        public MdiMainForm(List<LayoutItem> topItems, double rootWidth, double rootHeight, string scriptDirectory)
        {
            _topItems = topItems;
            _rootWidth = rootWidth;
            _rootHeight = rootHeight;
            _scriptDirectory = scriptDirectory;
        }

        public void ToggleBorderless()
        {
            FormBorderStyle = FormBorderStyle == FormBorderStyle.None 
                ? FormBorderStyle.FixedSingle 
                : FormBorderStyle.None;
        }

        public void HandleF5()
        {
            ReinitializeLayout(this, _topItems, _rootWidth, _rootHeight, _scriptDirectory);
        }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == Keys.F5)
            {
                ReinitializeLayout(this, _topItems, _rootWidth, _rootHeight, _scriptDirectory);
                return true;
            }
            if (keyData == Keys.F6)
            {
                ToggleBorderless();
                return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }
    }

    private class MdiChildForm : Form
    {
        private readonly MdiMainForm _parent;

        public MdiChildForm(MdiMainForm parent)
        {
            _parent = parent;
        }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            // Forward F5 and F6 to parent
            if (keyData == Keys.F5)
            {
                _parent.HandleF5();
                return true;
            }
            if (keyData == Keys.F6)
            {
                _parent.ToggleBorderless();
                return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }
    }

    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();

        var scriptDirectory = Environment.CurrentDirectory;
        var yamlPath = Path.Combine(scriptDirectory, "config.yml");
        if (!File.Exists(yamlPath))
        {
            MessageBox.Show($"config.yml not found at {yamlPath}", "Mission Control", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        var (rootWidth, rootHeight, topItems) = LoadLayout(yamlPath);
        if (topItems.Count == 0)
        {
            MessageBox.Show("No panels defined in config.yml", "Mission Control", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var mainForm = new MdiMainForm(topItems, rootWidth, rootHeight, scriptDirectory)
        {
            Text = "Mission Control",
            StartPosition = FormStartPosition.CenterScreen,
            ClientSize = new Size((int)Math.Round(rootWidth), (int)Math.Round(rootHeight)),
            FormBorderStyle = FormBorderStyle.None,
            MaximizeBox = false,
            MinimizeBox = true,
            BackColor = Color.FromArgb(45, 45, 50),
            IsMdiContainer = true
        };

        // Add toolbar with buttons
        var toolbar = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 28,
            BackColor = Color.FromArgb(90, 90, 90),
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            Padding = new Padding(0),
            Margin = new Padding(0)
        };

        // Make toolbar draggable to move main window
        Point lastMousePos = Point.Empty;
        bool isDragging = false;

        toolbar.MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
            {
                isDragging = true;
                lastMousePos = e.Location;
            }
        };

        toolbar.MouseMove += (_, e) =>
        {
            if (isDragging)
            {
                mainForm.Location = new Point(
                    mainForm.Location.X + e.X - lastMousePos.X,
                    mainForm.Location.Y + e.Y - lastMousePos.Y
                );
            }
        };

        toolbar.MouseUp += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
            {
                isDragging = false;
            }
        };

        var refreshButton = new Button
        {
            Text = "Refresh",
            Width = 90,
            Height = 28,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(60, 60, 60),
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 8F),
            Padding = new Padding(0),
            Margin = new Padding(0),
            TextAlign = ContentAlignment.MiddleCenter,
            UseCompatibleTextRendering = false
        };
        refreshButton.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
        refreshButton.Click += (_, _) => mainForm.HandleF5();

        var borderlessButton = new Button
        {
            Text = "Borderless",
            Width = 100,
            Height = 28,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(60, 60, 60),
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 8F),
            Padding = new Padding(0),
            Margin = new Padding(0),
            TextAlign = ContentAlignment.MiddleCenter,
            UseCompatibleTextRendering = false
        };
        borderlessButton.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
        borderlessButton.Click += (_, _) => mainForm.ToggleBorderless();

        toolbar.Controls.Add(refreshButton);
        toolbar.Controls.Add(borderlessButton);
        mainForm.Controls.Add(toolbar);

        mainForm.Load += async (_, _) =>
        {
            await InitializeWebView2Environment(scriptDirectory);
            ReinitializeLayout(mainForm, topItems, rootWidth, rootHeight, scriptDirectory);
        };

        Application.Run(mainForm);
    }

    private static async Task InitializeWebView2Environment(string scriptDirectory)
    {
        if (sharedWebView2Environment != null) { return; }

        var userDataFolder = Path.Combine(scriptDirectory, ".WebView2Data");
        Directory.CreateDirectory(userDataFolder);

        try
        {
            sharedWebView2Environment = await CoreWebView2Environment.CreateAsync(browserExecutableFolder: null, userDataFolder: userDataFolder, options: null);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to create WebView2 environment: {ex.Message}", "Mission Control", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void ReinitializeLayout(Form parent, List<LayoutItem> topItems, double rootWidth, double rootHeight, string scriptDirectory)
    {
        if (topItems.Count == 0) { return; }

        // Ensure the main window outer size matches the config-provided dimensions (rule 2: dimensions are outer bounds in hidden chrome mode).
        parent.ClientSize = new Size((int)Math.Round(rootWidth), (int)Math.Round(rootHeight));

        // Close existing MDI children
        var existingChildren = parent.MdiChildren.ToList();
        foreach (var child in existingChildren)
        {
            child.Close();
            child.Dispose();
        }

        // Measure actual MDI client area (accounts for chrome automatically)
        // For an MDI container, the client area is where the children live
        // Note: toolbar height is 28px and is docked at top, so subtract from available height when MDI client is not yet found
        var toolbarHeight = 28;
        var mdiClientArea = parent.Controls.OfType<MdiClient>().FirstOrDefault();
        var availableWidth = mdiClientArea?.ClientSize.Width ?? parent.ClientSize.Width;
        var availableHeight = mdiClientArea?.ClientSize.Height ?? (parent.ClientSize.Height - toolbarHeight);

        // Rule 2.5 diagnostics: compute panel totals vs client space after toolbar subtraction.
        var panelRectsPreview = GetPanelRects(topItems[0], 0, 0, availableWidth, availableHeight);
        var totalPanelWidth = panelRectsPreview.Any() ? panelRectsPreview.Max(r => r.Left + r.Width) : 0;
        var totalPanelHeight = panelRectsPreview.Any() ? panelRectsPreview.Max(r => r.Top + r.Height) : 0;
        Console.WriteLine("Layout summary (rule 2.5):");
        Console.WriteLine($"  Client available (after toolbar): Width={availableWidth}, Height={availableHeight}");
        Console.WriteLine($"  Panels combined:                Width={totalPanelWidth}, Height={totalPanelHeight}");
        Console.WriteLine($"  Match:                          Width {(totalPanelWidth == availableWidth ? "OK" : "MISMATCH")}, Height {(totalPanelHeight == availableHeight ? "OK" : "MISMATCH")}");
        Console.WriteLine();

        // Compute panel rects to fill the actual available MDI space
        var rects = panelRectsPreview;

        // Use the shared WebView2 environment (persists across reinitializations to preserve logins/cache)
        if (sharedWebView2Environment == null)
        {
            MessageBox.Show("WebView2 environment not initialized", "Mission Control", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        foreach (var rect in rects)
        {
            CreateChild(parent, sharedWebView2Environment, rect, scriptDirectory);
        }

        // Rule 6: inspect MDI client scrollbars using GetScrollInfo for accuracy.
        var mdiClient = parent.Controls.OfType<MdiClient>().FirstOrDefault();
        if (mdiClient != null)
        {
            bool HasScrollbar(IntPtr handle, int bar)
            {
                var info = new SCROLLINFO
                {
                    cbSize = (uint)Marshal.SizeOf<SCROLLINFO>(),
                    fMask = SIF_ALL
                };
                if (!GetScrollInfo(handle, bar, ref info)) { return false; }
                var visible = (info.nMax - info.nMin + 1) > info.nPage;
                return visible;
            }

            var hVisible = HasScrollbar(mdiClient.Handle, SB_HORZ);
            var vVisible = HasScrollbar(mdiClient.Handle, SB_VERT);
            Console.WriteLine($"Scrollbar check (rule 6): Horizontal={(hVisible ? "VISIBLE" : "hidden")}, Vertical={(vVisible ? "VISIBLE" : "hidden")}");
            Console.WriteLine();
        }
    }

    private static void CreateChild(Form parent, CoreWebView2Environment env, PanelRect rect, string scriptDirectory)
    {
        var item = rect.Item;
        var title = item.Title ?? item.Name ?? "panel";
        var url = item.Url ?? "about:blank";
        var scriptPath = item.Script;

        // Create MDI child form with WebView2 (full MDI chrome retained)
        var childForm = new MdiChildForm((MdiMainForm)parent)
        {
            MdiParent = parent,
            Text = title,
            FormBorderStyle = FormBorderStyle.Sizable,
            ControlBox = true,
            MinimizeBox = true,
            MaximizeBox = true,
            BackColor = Color.FromArgb(45, 45, 50),
            StartPosition = FormStartPosition.Manual,
            Left = (int)Math.Round(rect.Left),
            Top = (int)Math.Round(rect.Top)
        };

        // Set outer size from layout (rect carries outer dimensions); client will shrink by chrome automatically.
        var expectedFormWidth = (int)Math.Round(rect.Width);
        var expectedFormHeight = (int)Math.Round(rect.Height);
        childForm.Size = new Size(expectedFormWidth, expectedFormHeight);

        // Measure resulting chrome and expected client size after size assignment.
        var chromeWidth = childForm.Width - childForm.ClientSize.Width;
        var chromeHeight = childForm.Height - childForm.ClientSize.Height;
        var expectedClientWidth = expectedFormWidth - chromeWidth;
        var expectedClientHeight = expectedFormHeight - chromeHeight;

        var webView = new WebView2
        {
            Dock = DockStyle.Fill,
            AllowExternalDrop = true
        };

        childForm.Controls.Add(webView);
        childForm.Show();

        // Debug: measure actual vs expected dimensions
        Console.WriteLine($"Panel '{title}':");
        Console.WriteLine($"  Expected (Form):   Left={rect.Left}, Top={rect.Top}, Width={expectedFormWidth}, Height={expectedFormHeight}");
        Console.WriteLine($"  Expected (Client): Width={expectedClientWidth}, Height={expectedClientHeight}");
        Console.WriteLine($"  Actual (Form):     Left={childForm.Left}, Top={childForm.Top}, Width={childForm.Width}, Height={childForm.Height}");
        Console.WriteLine($"  Actual (Client):   Width={childForm.ClientSize.Width}, Height={childForm.ClientSize.Height}");
        Console.WriteLine($"  Chrome:            Width={chromeWidth}, Height={chromeHeight}");
        Console.WriteLine();

        var state = new PanelState
        {
            Title = title,
            Url = url,
            ScriptPath = scriptPath,
            WebView = webView,
            HeaderLabel = null
        };

        // Double-click form title to copy URL to clipboard
        childForm.DoubleClick += (_, _) => CopyUrlToClipboard(state.Url);

        // Initialize WebView2 asynchronously on the UI thread
        async void InitializeWebViewAsync()
        {
            try
            {
                await webView.EnsureCoreWebView2Async(env);

                // Intercept F5 and F6 before they reach web content
                webView.CoreWebView2.Settings.AreBrowserAcceleratorKeysEnabled = true;
                webView.PreviewKeyDown += (s, e) =>
                {
                    var parentForm = (MdiMainForm)parent;
                    if (e.KeyCode == Keys.F5)
                    {
                        e.IsInputKey = true;
                        parentForm.HandleF5();
                    }
                    else if (e.KeyCode == Keys.F6)
                    {
                        e.IsInputKey = true;
                        parentForm.ToggleBorderless();
                    }
                };

                if (!string.IsNullOrWhiteSpace(state.ScriptPath))
                {
                    var fullScriptPath = Path.Combine(scriptDirectory, state.ScriptPath);
                    if (File.Exists(fullScriptPath))
                    {
                        var scriptContent = await File.ReadAllTextAsync(fullScriptPath);
                        webView.CoreWebView2.NavigationCompleted += (_, _) =>
                        {
                            try { _ = webView.CoreWebView2.ExecuteScriptAsync(scriptContent); }
                            catch { }
                        };
                    }
                }

                webView.CoreWebView2.SourceChanged += (_, _) => UpdateTitle(webView.Source?.ToString());
                webView.CoreWebView2.NavigationStarting += (_, args) => UpdateTitle(args.Uri);
                webView.CoreWebView2.NavigationCompleted += (_, _) => UpdateTitle(webView.Source?.ToString());

                // Handle new window requests (popups) by opening them in the same WebView2
                // This preserves authentication sessions
                webView.CoreWebView2.NewWindowRequested += (_, args) =>
                {
                    args.Handled = true;
                    if (!string.IsNullOrWhiteSpace(args.Uri))
                    {
                        webView.Source = new Uri(args.Uri);
                    }
                };

                webView.Source = new Uri(url);
                UpdateTitle(url);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to initialize WebView2 for {state.Title}: {ex.Message}", "Mission Control", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        void UpdateTitle(string? currentUrl)
        {
            var displayUrl = string.IsNullOrWhiteSpace(currentUrl) ? state.Url : currentUrl;
            state.Url = displayUrl;
            childForm.Text = $"{state.Title} - {displayUrl}";
        }

        InitializeWebViewAsync();
    }

    private static void CopyUrlToClipboard(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) { return; }
        try
        {
            Clipboard.SetText(url);
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}] Copied to clipboard: {url}");
        }
        catch { }
    }

    private static (double RootWidth, double RootHeight, List<LayoutItem> TopItems) LoadLayout(string yamlPath)
    {
        var defaultWidth = 2560d;
        var defaultHeight = 1440d;

        var deserializer = new DeserializerBuilder()
            .IgnoreUnmatchedProperties()
            .Build();

        var yaml = deserializer.Deserialize<object>(File.ReadAllText(yamlPath));

        var rootWidth = defaultWidth;
        var rootHeight = defaultHeight;

        object? layoutYaml = yaml;

        if (yaml is IDictionary<object, object> dict)
        {
            if (TryGetDouble(dict, "width", out var w)) { rootWidth = w; }
            if (TryGetDouble(dict, "height", out var h)) { rootHeight = h; }
            if (dict.ContainsKey("layout")) { layoutYaml = dict["layout"]; }
        }

        var topNodes = new List<LayoutItem>();

        if (layoutYaml is IList seq)
        {
            foreach (var node in seq)
            {
                var normalized = NormalizeYaml(node);
                if (normalized != null) { topNodes.Add(normalized); }
            }
        }
        else
        {
            var normalized = NormalizeYaml(layoutYaml);
            if (normalized != null) { topNodes.Add(normalized); }
        }

        return (rootWidth, rootHeight, topNodes);
    }

    private static LayoutItem? NormalizeYaml(object? node)
    {
        if (node is null) { return null; }

        if (node is IDictionary<object, object> map)
        {
            if (map.ContainsKey("hgroup"))
            {
                var children = NormalizeSequence(map["hgroup"]);
                return new LayoutItem { Type = "hgroup", Panels = children };
            }
            if (map.ContainsKey("vgroup"))
            {
                var children = NormalizeSequence(map["vgroup"]);
                return new LayoutItem { Type = "vgroup", Panels = children };
            }

            var title = map.ContainsKey("title") ? map["title"]?.ToString() : null;
            if (string.IsNullOrWhiteSpace(title)) { return null; }

            var item = new LayoutItem
            {
                Type = "panel",
                Title = title,
                Name = map.ContainsKey("name") ? map["name"]?.ToString() : title
            };

            if (map.ContainsKey("url")) { item.Url = map["url"]?.ToString(); }
            if (map.ContainsKey("script")) { item.Script = map["script"]?.ToString(); }
            if (map.ContainsKey("width") && TryToDouble(map["width"], out var w)) { item.Width = w; }

            return item;
        }

        if (node is IList list && list.Count > 0)
        {
            // Treat a top-level sequence as implicit hgroup
            var children = NormalizeSequence(list);
            return new LayoutItem { Type = "hgroup", Panels = children };
        }

        return null;
    }

    private static List<LayoutItem> NormalizeSequence(object? seqObj)
    {
        var results = new List<LayoutItem>();
        if (seqObj is IList seq)
        {
            foreach (var child in seq)
            {
                var normalized = NormalizeYaml(child);
                if (normalized != null) { results.Add(normalized); }
            }
        }
        return results;
    }

    private static bool TryGetDouble(IDictionary<object, object> dict, string key, out double value)
    {
        value = 0;
        if (!dict.ContainsKey(key)) { return false; }
        return TryToDouble(dict[key], out value);
    }

    private static bool TryToDouble(object? input, out double value)
    {
        value = 0;
        if (input is null) { return false; }
        var s = input.ToString();
        return double.TryParse(s, out value);
    }

    private static List<PanelRect> GetPanelRects(LayoutItem item, double left, double top, double width, double height)
    {
        var rects = new List<PanelRect>();
        switch (item.Type)
        {
            case "hgroup":
            {
                // Use outer panel dimensions to fill the available width; chrome is included in these widths.
                var children = item.Panels ?? new List<LayoutItem>();
                var totalConfig = children.Where(c => c.Width.HasValue).Sum(c => c.Width!.Value);
                var flexCount = children.Count(c => !c.Width.HasValue);
                var availableWidth = width; // outer width to consume fully

                // When nothing is flexible, scale configured widths to fill (or shrink to fit) the available space.
                var scale = flexCount == 0 && totalConfig > 0 ? availableWidth / totalConfig : 1;
                var flexWidth = flexCount > 0 ? Math.Max(0, availableWidth - totalConfig) / flexCount : 0;

                // Compute rounded outer widths that sum exactly to availableWidth to avoid overflow/gaps.
                var rawWidths = children
                    .Select(c => c.Width.HasValue ? c.Width.Value * scale : flexWidth)
                    .ToList();

                var roundedWidths = rawWidths.Select(w => (int)Math.Round(w)).ToList();
                var roundedSum = roundedWidths.Sum();
                var targetWidth = (int)Math.Round(availableWidth);
                var delta = targetWidth - roundedSum;
                if (roundedWidths.Count > 0 && delta != 0)
                {
                    roundedWidths[^1] += delta;  // adjust the last segment to consume any rounding drift
                }

                var x = (int)Math.Round(left);
                for (var i = 0; i < children.Count; i++)
                {
                    var w = roundedWidths[i];
                    rects.AddRange(GetPanelRects(children[i], x, (int)Math.Round(top), w, height));
                    x += w;  // advance by full outer width
                }
                break;
            }
            case "vgroup":
            {
                // Use outer panel dimensions to fill the available height; chrome is included in these heights.
                var vChildren = item.Panels ?? new List<LayoutItem>();
                if (vChildren.Count > 0)
                {
                    var availableHeight = height; // outer height to consume fully
                    var rawHeight = availableHeight / vChildren.Count;

                    // Round heights and keep total exact to avoid overflow/gaps.
                    var roundedHeights = Enumerable.Repeat((int)Math.Round(rawHeight), vChildren.Count).ToList();
                    var roundedSum = roundedHeights.Sum();
                    var targetHeight = (int)Math.Round(availableHeight);
                    var delta = targetHeight - roundedSum;
                    if (roundedHeights.Count > 0 && delta != 0)
                    {
                        roundedHeights[^1] += delta;  // adjust last child to absorb rounding error
                    }

                    var y = (int)Math.Round(top);
                    for (var i = 0; i < vChildren.Count; i++)
                    {
                        var h = roundedHeights[i];
                        rects.AddRange(GetPanelRects(vChildren[i], (int)Math.Round(left), y, width, h));
                        y += h;  // advance by full outer height
                    }
                }
                break;
            }
            default:
                rects.Add(new PanelRect(item, left, top, width, height));
                break;
        }

        return rects;
    }
}

internal sealed class LayoutItem
{
    public string Type { get; set; } = "panel";
    public string? Title { get; set; }
    public string? Name { get; set; }
    public string? Url { get; set; }
    public string? Script { get; set; }
    public double? Width { get; set; }
    public List<LayoutItem>? Panels { get; set; }
}

internal sealed record PanelRect(LayoutItem Item, double Left, double Top, double Width, double Height);

internal sealed class PanelState
{
    public string Title { get; set; } = "panel";
    public string Url { get; set; } = "about:blank";
    public string? ScriptPath { get; set; }
    public WebView2? WebView { get; set; }
    public Label? HeaderLabel { get; set; }
}
