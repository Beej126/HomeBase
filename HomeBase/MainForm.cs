using System.Drawing;

namespace HomeBase;

public partial class MainForm : Form
{
    public MainForm()
    {
        InitializeComponent();
        SetIconFromResource();
    }

    private void SetIconFromResource()
    {
        var assembly = typeof(MainForm).Assembly;
        using var iconStream = assembly.GetManifestResourceStream("HomeBase.logo.ico");
        if (iconStream == null)
        {
            return;
        }

        Icon = new Icon(iconStream);
    }
}
