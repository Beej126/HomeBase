using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace HomeBase;

internal sealed class AboutDialog : Form
{
    public AboutDialog(Icon? appIcon, Image? logoImage)
    {
        Text = $"About {AppInfo.AppName}";
        StartPosition = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = false;
        BackColor = Color.FromArgb(45, 45, 50);
        ForeColor = Color.White;
        ClientSize = new Size(750, 450);

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 3,
            Padding = new Padding(20),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 338));
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));          // info row
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));       // spacer row fills remaining
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));          // buttons row

        var picture = new PictureBox
        {
            Dock = DockStyle.Fill,
            SizeMode = PictureBoxSizeMode.Zoom,
            Image = logoImage ?? appIcon?.ToBitmap() ?? SystemIcons.Application.ToBitmap(),
            Margin = new Padding(0, 0, 12, 0),
            BackColor = Color.FromArgb(45, 45, 50)
        };

        var infoPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        infoPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        infoPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        infoPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var titleLabel = new Label
        {
            Text = AppInfo.AppName,
            AutoSize = true,
            Font = new Font("Segoe UI", 11F, FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 6)
        };

        var authorLabel = new Label
        {
            Text = $"Author: {AppInfo.Author}",
            AutoSize = true,
            Font = new Font("Segoe UI", 9F, FontStyle.Regular),
            Margin = new Padding(0, 0, 0, 4)
        };

        var linkLabel = new LinkLabel
        {
            Text = AppInfo.GitHubUrl,
            AutoSize = true,
            LinkColor = Color.DeepSkyBlue,
            ActiveLinkColor = Color.White,
            VisitedLinkColor = Color.SkyBlue,
            Margin = new Padding(0)
        };
        linkLabel.LinkClicked += (_, _) => OpenLink(AppInfo.GitHubUrl);

        infoPanel.Controls.Add(titleLabel, 0, 0);
        infoPanel.Controls.Add(authorLabel, 0, 1);
        infoPanel.Controls.Add(linkLabel, 0, 2);

        var buttonsPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Right,
            FlowDirection = FlowDirection.RightToLeft,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            Margin = new Padding(0)
        };

        var okButton = new Button
        {
            Text = "OK",
            DialogResult = DialogResult.OK,
            AutoSize = true,
            Padding = new Padding(12, 4, 12, 4),
            BackColor = Color.FromArgb(70, 70, 70),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Margin = new Padding(0)
        };
        okButton.FlatAppearance.BorderColor = Color.FromArgb(90, 90, 90);

        buttonsPanel.Controls.Add(okButton);

        root.Controls.Add(picture, 0, 0);
        root.SetRowSpan(picture, 3);
        root.Controls.Add(infoPanel, 1, 0);
        // row 1 is spacer to push buttons down
        root.Controls.Add(new Panel { Dock = DockStyle.Fill }, 1, 1);
        root.Controls.Add(buttonsPanel, 1, 2);

        Controls.Add(root);
        AcceptButton = okButton;
    }

    private static void OpenLink(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) { return; }

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            };
            Process.Start(psi);
        }
        catch
        {
            // ignore
        }
    }
}
