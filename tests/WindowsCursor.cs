using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;

// Run the input generator independently of AutoHotkey. This window is the only
// target; native modifier, arrow and letter events pass through the installed hook.
class WindowsCursor : Form
{
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] static extern short GetKeyState(int key);
    readonly TextBox box = new TextBox { Multiline = true, WordWrap = false, Dock = DockStyle.Fill };
    readonly string mode, log;
    const string Sample = "alpha bravo charlie\r\nsecond line here\r\nthird line here";
    const byte Caps = 20, LeftAlt = 164, RightAlt = 165, Ctrl = 162;

    WindowsCursor(string mode, string log)
    {
        this.mode = mode; this.log = log;
        Text = "ArrowKeys cursor test"; Width = 640; Height = 200;
        Controls.Add(box);
        Shown += async delegate {
            try {
                Activate(); SetForegroundWindow(Handle); box.Focus();
                await Task.Delay(250);
                await Check();
                Trace("Passed " + mode);
            } catch (Exception e) { Trace(e.Message); Environment.ExitCode = 1; }
            Close();
        };
    }

    protected override void WndProc(ref Message m)
    {
        // Editors with a menu may activate it on an isolated Alt key-up.
        if (m.Msg == 0x112 && (m.WParam.ToInt64() & 0xfff0) == 0xf100) return;
        base.WndProc(ref m);
    }

    void Trace(string s) { File.AppendAllText(log, s + Environment.NewLine); }
    async Task Key(byte key, bool up)
    {
        if (GetForegroundWindow() != Handle || !box.Focused) throw new Exception("The cursor probe lost focus.");
        bool extended = (key >= 35 && key <= 40) || key == RightAlt;
        keybd_event(key, 0, (up ? 2u : 0u) | (extended ? 1u : 0u), UIntPtr.Zero);
        await Task.Delay(45);
    }
    async Task<int> Move(byte modifier, byte key)
    {
        box.SelectionStart = 27;
        box.SelectionLength = 0;
        if (modifier != 0) await Key(modifier, false);
        await Key(key, false); await Key(key, true);
        if (modifier != 0) await Key(modifier, true);
        await Task.Delay(75);
        return box.SelectionStart;
    }
    async Task Check()
    {
        box.Text = Sample;
        if (mode == "removed") {
            if ((GetKeyState(Caps) & 1) != 0) { await Key(Caps, false); await Key(Caps, true); }
            await Key(Caps, false); await Key(Caps, true);
            await Move(0, 74);
            await Key(Caps, false); await Key(Caps, true);
            if (box.Text != Sample.Insert(27, "J") || (GetKeyState(Caps) & 1) != 0) throw new Exception("Normal Caps Lock typing did not return");
            foreach (byte letter in new byte[] {74,75,76,73,85,79,72,186}) {
                box.Text = Sample;
                await Move(LeftAlt, letter);
                if (box.SelectionStart != 27 || box.Text != Sample)
                    throw new Exception("ArrowKeys navigation survived uninstall for VK " + letter);
            }
            if (await Move(0, 37) != 26) throw new Exception("Native left arrow stopped working");
            if (await Move(Ctrl, 37) >= 27) throw new Exception("Native previous-word navigation stopped working");
            Trace("All eight former shortcuts, Caps Lock, normal arrows and Ctrl+Left passed after removal");
            return;
        }
        byte[,] directions = {{74,37,0},{75,40,0},{76,39,0},{73,38,0},
                              {85,36,0},{79,35,0},{72,37,Ctrl},{186,39,Ctrl}};
        for (int i = 0; i < directions.GetLength(0); i++) {
            byte key = directions[i,0];
            int expected = await Move(directions[i,2], directions[i,1]);
            if (expected == 27) throw new Exception("Native reference movement failed for VK " + key);
            foreach (byte modifier in new byte[] {Caps,LeftAlt,RightAlt}) {
                int actual = await Move(modifier, key);
                if (actual != expected || box.Text != Sample)
                    throw new Exception("VK " + modifier + "+" + key + " moved to " + actual + ", expected " + expected);
            }
        }
        await Move(0, 74);
        if (box.Text != Sample.Insert(27, "j") || (GetKeyState(Caps) & 1) != 0) throw new Exception("Ordinary typing failed after navigation");
        Trace("All 24 cursor movements and ordinary typing passed");
    }
    [STAThread] static int Main(string[] args)
    {
        Application.Run(new WindowsCursor(args[0], args[1]));
        return Environment.ExitCode;
    }
}
