using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Media;
using System.Runtime.InteropServices;

namespace DesktopGoose;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new GooseOverlay());
    }
}

internal sealed class GooseOverlay : Form
{
    private const int HotkeyToggle = 1, HotkeyFish = 2;
    private const int WmHotkey = 0x0312, WmNcHitTest = 0x0084;
    private const int HtTransparent = -1, HtClient = 1;
    private const uint ModAlt = 0x0001, ModControl = 0x0002;
    private const float Gravity = 2200, WalkSpeed = 60, RunSpeed = 180;
    private const double CoyoteCastCharge = .25, CoyoteCastJump = .65,
        CoyoteCastTotal = 1.05, CoyoteCastCool = 2.5, CoyoteStuckWait = .85;
    private const float CoyoteRetreatSpeed = 225; // just faster than mother's ~207 px/s charge
    private static readonly Color Key = Color.FromArgb(255, 1, 2);

    private readonly System.Windows.Forms.Timer timer = new() { Interval = 16 };
    private readonly Stopwatch stopwatch = Stopwatch.StartNew();
    private readonly Random random = new();
    private readonly NotifyIcon tray;
    private readonly ContextMenuStrip menu = new();
    private readonly Form controls;
    private CheckBox? stretchyCheck, followCheck, soundCheck;
    private Button? awakeButton;
    private Label? statusLabel;
    private readonly List<Ledge> ledges = [];
    private readonly List<Prop> eggs = [];
    private readonly List<Chick> chicks = [];

    private float gooseX, gooseY, gooseVx, gooseVy, direction = 1;
    private GooseAction action = GooseAction.Air;
    private double actionLeft, phase, clock, bubbleLeft, scanLeft, angry, nextHonk;
    private string bubble = "HONK!";
    private Ledge? gooseSupport;
    private Prop? fish;
    private Coyote? coyote;
    private double coyoteAttackCool;
    private bool paused, followCursor, sound = true, stretchy, holdingHead;
    private bool clickThrough = true;
    private float headStretchX, headStretchY, bodyStretchX, bodyStretchY;
    private float headStretchVx, headStretchVy, bodyStretchVx, bodyStretchVy;
    private int eaten;

    private DragKind dragging;
    private object? draggedObject;
    private PointF dragOffset, lastMouse, priorMouse;
    private long lastMouseTick;
    private Point mouseDown;
    private bool moved;

    public GooseOverlay()
    {
        var virtualScreen = SystemInformation.VirtualScreen;
        Bounds = virtualScreen;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        BackColor = Key;
        TransparencyKey = Key;
        DoubleBuffered = true;
        AutoScaleMode = AutoScaleMode.None;
        StartPosition = FormStartPosition.Manual;

        gooseX = virtualScreen.Left + virtualScreen.Width * .45f;
        gooseY = Screen.PrimaryScreen?.WorkingArea.Bottom - 10 ?? virtualScreen.Bottom - 50;
        BuildMenu();
        tray = new NotifyIcon
        {
            Icon = MakeIcon(),
            Text = "Desktop Goose",
            Visible = true,
            ContextMenuStrip = menu
        };
        tray.DoubleClick += (_, _) => ShowControls();
        controls = BuildControls();

        ScanLedges();
        timer.Tick += Tick;
        timer.Start();
        MouseDown += OnMouseDown;
        MouseMove += OnMouseMove;
        MouseUp += OnMouseUp;
        Shown += (_, _) => ShowControls();
        FormClosed += (_, _) => { controls.Dispose(); tray.Visible = false; tray.Dispose(); };
    }

    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams
    {
        get
        {
            const int WsExToolWindow = 0x80, WsExTransparent = 0x20, WsExNoActivate = 0x08000000;
            var cp = base.CreateParams;
            // HTTRANSPARENT alone only reliably forwards input to windows owned by
            // the same thread. WS_EX_TRANSPARENT makes the full-screen overlay
            // genuinely click-through to other applications and the taskbar.
            cp.ExStyle |= WsExToolWindow | WsExTransparent | WsExNoActivate;
            return cp;
        }
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RegisterHotKey(Handle, HotkeyToggle, ModControl | ModAlt, (uint)Keys.G);
        RegisterHotKey(Handle, HotkeyFish, ModControl | ModAlt, (uint)Keys.F);
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        UnregisterHotKey(Handle, HotkeyToggle);
        UnregisterHotKey(Handle, HotkeyFish);
        base.OnHandleDestroyed(e);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WmHotkey)
        {
            if (m.WParam.ToInt32() == HotkeyToggle) ToggleGoose();
            if (m.WParam.ToInt32() == HotkeyFish) DropFish();
            return;
        }
        if (m.Msg == WmNcHitTest)
        {
            int packed = unchecked((int)m.LParam.ToInt64());
            var p = new Point((short)(packed & 0xffff), (short)((packed >> 16) & 0xffff));
            m.Result = (IntPtr)(HitObject(p) is null ? HtTransparent : HtClient);
            return;
        }
        base.WndProc(ref m);
    }

    private void BuildMenu()
    {
        Add("Show controls", (_, _) => ShowControls());
        menu.Items.Add(new ToolStripSeparator());
        Add("Put goose away", (_, _) => ToggleGoose(), "toggle");
        Add("Honk", (_, _) => Honk());
        Add("Hop", (_, _) => Hop());
        Add("Fly somewhere", (_, _) => FlySomewhere());
        Add("Come here", (_, _) => { GetCursorPos(out var p); RunTo(p.X); });
        menu.Items.Add(new ToolStripSeparator());
        Add("Drop a fish   Ctrl+Alt+F", (_, _) => DropFish(), "fish");
        Add("Take the fish away", (_, _) => { fish = null; RefreshMenu(); });
        Add("Lay an egg", (_, _) => LayEgg());
        Add("Spawn coyote", (_, _) => ToggleCoyote(), "coyote");
        menu.Items.Add(new ToolStripSeparator());
        Add("Follow my cursor", (_, _) => SetFollow(!followCursor), "follow");
        Add("Stretchy mode", (_, _) => SetStretchy(!stretchy), "stretchy");
        Add("Honk sounds", (_, _) => SetSound(!sound), "sound").Checked = true;
        menu.Items.Add(new ToolStripSeparator());
        Add("Quit goose", (_, _) => Close());
        RefreshMenu();
    }

    private ToolStripMenuItem Add(string text, EventHandler click, string? name = null)
    {
        var item = new ToolStripMenuItem(text, null, click) { Name = name ?? "" };
        menu.Items.Add(item);
        return item;
    }

    private void RefreshMenu()
    {
        if (menu.Items["toggle"] is ToolStripMenuItem toggle) toggle.Text = paused ? "Let goose out   Ctrl+Alt+G" : "Put goose away   Ctrl+Alt+G";
        if (menu.Items["fish"] is ToolStripMenuItem fishItem) fishItem.Text = fish is null ? $"Drop a fish   Ctrl+Alt+F  (eaten: {eaten})" : $"Move fish here   Ctrl+Alt+F  (eaten: {eaten})";
        if (menu.Items["follow"] is ToolStripMenuItem follow) follow.Checked = followCursor;
        if (menu.Items["stretchy"] is ToolStripMenuItem stretch) stretch.Checked = stretchy;
        if (menu.Items["sound"] is ToolStripMenuItem sounds) sounds.Checked = sound;
        if (menu.Items["coyote"] is ToolStripMenuItem coyoteItem) coyoteItem.Text = coyote is null ? "Spawn coyote" : "Despawn coyote";
        if (awakeButton is not null) awakeButton.Text = paused ? "Let goose out" : "Put goose away";
        if (statusLabel is not null) statusLabel.Text = fish is null ? $"Fish eaten: {eaten}" : $"Fish is out  •  Eaten: {eaten}";
    }

    private Form BuildControls()
    {
        var f = new Form
        {
            Text = "Desktop Goose controls",
            ClientSize = new Size(270, 334),
            FormBorderStyle = FormBorderStyle.FixedSingle,
            MaximizeBox = false,
            MinimizeBox = true,
            ShowInTaskbar = true,
            StartPosition = FormStartPosition.Manual,
            Location = new Point((Screen.PrimaryScreen?.WorkingArea.Right ?? 1200) - 290,
                                 (Screen.PrimaryScreen?.WorkingArea.Bottom ?? 800) - 374)
        };
        f.FormClosing += (_, e) => {
            if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; f.Hide(); }
        };

        var title = new Label { Text = "🪿  Desktop Goose", Font = new Font("Segoe UI", 14, FontStyle.Bold), AutoSize = true, Location = new Point(16, 14) };
        statusLabel = new Label { AutoSize = true, Location = new Point(18, 48), ForeColor = Color.DimGray };
        f.Controls.Add(title); f.Controls.Add(statusLabel);

        Button MakeButton(string text, int x, int y, int width, Action action)
        {
            var b = new Button { Text = text, Location = new Point(x, y), Size = new Size(width, 34) };
            b.Click += (_, _) => action(); f.Controls.Add(b); return b;
        }
        awakeButton = MakeButton("Put goose away", 16, 74, 116, ToggleGoose);
        MakeButton("Honk", 140, 74, 54, Honk);
        MakeButton("Hop", 202, 74, 52, Hop);
        MakeButton("Come here", 16, 116, 116, () => RunTo(Cursor.Position.X));
        MakeButton("Drop / move fish", 140, 116, 114, DropFish);
        MakeButton("Lay an egg", 16, 158, 116, LayEgg);
        MakeButton("Fly somewhere", 140, 158, 114, FlySomewhere);
        MakeButton("Spawn / despawn coyote", 16, 200, 238, ToggleCoyote);

        followCheck = new CheckBox { Text = "Follow my cursor", AutoSize = true, Location = new Point(18, 249) };
        stretchyCheck = new CheckBox { Text = "Stretchy mode", AutoSize = true, Location = new Point(143, 249) };
        soundCheck = new CheckBox { Text = "Honk sounds", AutoSize = true, Location = new Point(18, 279), Checked = true };
        followCheck.CheckedChanged += (_, _) => { if (followCheck.Checked != followCursor) SetFollow(followCheck.Checked); };
        stretchyCheck.CheckedChanged += (_, _) => { if (stretchyCheck.Checked != stretchy) SetStretchy(stretchyCheck.Checked); };
        soundCheck.CheckedChanged += (_, _) => { if (soundCheck.Checked != sound) SetSound(soundCheck.Checked); };
        f.Controls.Add(followCheck); f.Controls.Add(stretchyCheck); f.Controls.Add(soundCheck);
        MakeButton("Hide controls", 140, 288, 114, f.Hide);
        RefreshMenu();
        return f;
    }

    private void ShowControls()
    {
        if (!controls.Visible) controls.Show();
        if (controls.WindowState == FormWindowState.Minimized) controls.WindowState = FormWindowState.Normal;
        controls.Activate();
    }

    private void SetFollow(bool value)
    {
        followCursor = value;
        if (followCheck is not null && followCheck.Checked != value) followCheck.Checked = value;
        RefreshMenu();
    }

    private void SetSound(bool value)
    {
        sound = value;
        if (soundCheck is not null && soundCheck.Checked != value) soundCheck.Checked = value;
        RefreshMenu();
    }

    private void SetStretchy(bool value)
    {
        stretchy = value;
        if (!value) ResetStretch();
        if (stretchyCheck is not null && stretchyCheck.Checked != value) stretchyCheck.Checked = value;
        RefreshMenu();
    }

    private void ToggleGoose()
    {
        paused = !paused;
        Visible = !paused;
        tray.Text = paused ? "Desktop Goose (away)" : "Desktop Goose";
        RefreshMenu();
    }

    private void Tick(object? sender, EventArgs e)
    {
        double dt = Math.Clamp(stopwatch.Elapsed.TotalSeconds, 0, .04);
        stopwatch.Restart();
        if (paused) return;
        clock += dt;
        scanLeft -= dt;
        if (scanLeft <= 0) { ScanLedges(); scanLeft = .9; }
        StepStretch(dt);
        StepGoose(dt);
        StepCoyote(dt);
        if (coyote?.Health <= 0) { coyote = null; RefreshMenu(); }
        chicks.RemoveAll(chick => chick.Health <= 0);
        StepFish(dt);
        StepEggs(dt);
        StepChicks(dt);
        bubbleLeft -= dt;
        UpdateClickThrough();
        Invalidate();
    }

    private void UpdateClickThrough()
    {
        bool shouldPassThrough = dragging == DragKind.None && HitObject(Cursor.Position) is null;
        if (shouldPassThrough == clickThrough || !IsHandleCreated) return;
        clickThrough = shouldPassThrough;
        nint style = GetWindowLongPtr(Handle, -20); // GWL_EXSTYLE
        const long WsExTransparent = 0x20;
        long next = clickThrough ? style.ToInt64() | WsExTransparent : style.ToInt64() & ~WsExTransparent;
        SetWindowLongPtr(Handle, -20, (nint)next);
    }

    private void StepStretch(double dt)
    {
        if (!stretchy) { ResetStretch(); return; }
        float t = (float)Math.Min(dt, .04);
        if (dragging == DragKind.Goose && holdingHead)
            headStretchX = headStretchY = headStretchVx = headStretchVy = 0;
        else
            IntegrateStretch(ref headStretchX, ref headStretchY, ref headStretchVx, ref headStretchVy, t);
        if (dragging == DragKind.Goose && !holdingHead)
            bodyStretchX = bodyStretchY = bodyStretchVx = bodyStretchVy = 0;
        else
            IntegrateStretch(ref bodyStretchX, ref bodyStretchY, ref bodyStretchVx, ref bodyStretchVy, t);
    }

    private static void IntegrateStretch(ref float x, ref float y, ref float vx, ref float vy, float dt)
    {
        const float spring = 52, damping = 9.5f;
        vx += (-spring * x - damping * vx) * dt; vy += (-spring * y - damping * vy) * dt;
        x += vx * dt; y += vy * dt;
        if (MathF.Sqrt(x * x + y * y) < .08f && MathF.Sqrt(vx * vx + vy * vy) < .3f) { x = y = vx = vy = 0; }
    }

    private void TugStretch(float dx, float dy)
    {
        if (!stretchy || dragging != DragKind.Goose) return;
        // Counter-move farther than the cursor moved so the loose end visibly
        // slings the other way rather than only lagging in the same direction.
        if (holdingHead) { bodyStretchX -= dx * 1.35f; bodyStretchY -= dy * 1.35f; LimitStretch(ref bodyStretchX, ref bodyStretchY); }
        else { headStretchX -= dx * 1.35f; headStretchY -= dy * 1.35f; LimitStretch(ref headStretchX, ref headStretchY); }
    }

    private static void LimitStretch(ref float x, ref float y)
    {
        float d = MathF.Sqrt(x * x + y * y);
        if (d > 26) { x *= 26 / d; y *= 26 / d; }
    }

    private void ResetStretch()
    {
        headStretchX = headStretchY = bodyStretchX = bodyStretchY = 0;
        headStretchVx = headStretchVy = bodyStretchVx = bodyStretchVy = 0;
    }

    private void StepGoose(double dt)
    {
        phase += Math.Abs(gooseVx) * dt * .08;
        if (angry > 0 && fish is null) angry = Math.Max(0, angry - dt * .25);
        if (action == GooseAction.Held) return;
        if (coyote is not null)
        {
            nextHonk -= dt;
            if (nextHonk <= 0) { nextHonk = 1 + random.NextDouble(); bubble = "HONK!!!"; bubbleLeft = 1.1; if (sound) SystemSounds.Exclamation.Play(); }
            if (ProtectChicks(dt)) return;
        }
        if (fish is not null && ChaseFish(dt)) return;
        if (action == GooseAction.Air)
        {
            float oldY = gooseY;
            gooseVy += Gravity * (float)dt;
            gooseX += gooseVx * (float)dt;
            gooseY += gooseVy * (float)dt;
            ClampHorizontal(ref gooseX, ref gooseVx, 34);
            if (gooseVy > 0)
            {
                Ledge? landing = FindLanding(oldY, gooseY, gooseX, 4);
                if (landing is not null) Land(landing);
            }
            return;
        }

        Point cursor = Cursor.Position;
        if (Math.Abs(cursor.X - gooseX) < 170) direction = cursor.X > gooseX ? 1 : -1;
        if (followCursor) RunTo(cursor.X);

        if (action is GooseAction.Walk or GooseAction.Run)
        {
            gooseVx = direction * (action == GooseAction.Run ? RunSpeed : WalkSpeed);
            gooseX += gooseVx * (float)dt;
            if (gooseSupport is not null && !gooseSupport.Contains(gooseX))
            {
                gooseSupport = null; action = GooseAction.Air; gooseVy = 20;
            }
        }
        else gooseVx = 0;

        actionLeft -= dt;
        if (actionLeft <= 0) ChooseAction();
        ClampHorizontal(ref gooseX, ref gooseVx, 34);
    }

    private bool ChaseFish(double dt)
    {
        if (fish is null) return false;
        float dx = fish.X - gooseX, dy = fish.Y - gooseY;
        angry = Math.Min(1, angry + dt / 11);
        direction = dx >= 0 ? 1 : -1;
        if (Math.Abs(dx) < 42 && Math.Abs(dy) < 75)
        {
            fish = null; eaten++; angry = 0;
            bubble = "YUM!"; bubbleLeft = 1.3;
            for (int i = 0; i < 3; i++) hearts.Add(new Heart(gooseX + random.Next(-25, 26), gooseY - 55 - i * 8));
            if (sound) SystemSounds.Asterisk.Play();
            RefreshMenu();
            return true;
        }
        if (dy < -70 && gooseSupport is not null)
        {
            float jump = MathF.Sqrt(2 * Gravity * Math.Min(260, -dy + 55));
            gooseVy = -jump; gooseVx = Math.Clamp(dx * 2.2f, -540, 540);
            gooseSupport = null; action = GooseAction.Air;
            return true;
        }
        action = GooseAction.Run;
        gooseVx = direction * RunSpeed * (1 + (float)angry * .5f);
        gooseX += gooseVx * (float)dt;
        if (gooseSupport is not null && !gooseSupport.Contains(gooseX)) { gooseSupport = null; action = GooseAction.Air; gooseVy = 10; }
        return true;
    }

    private void ChooseAction()
    {
        double n = random.NextDouble();
        if (n < .35) { action = GooseAction.Idle; actionLeft = .7 + random.NextDouble() * 1.8; }
        else if (n < .47) { action = GooseAction.Peck; actionLeft = .8; }
        else if (n < .58) Honk();
        else if (n < .68) Hop();
        else
        {
            action = random.NextDouble() < .2 ? GooseAction.Run : GooseAction.Walk;
            actionLeft = 1.2 + random.NextDouble() * 2.5;
            if (random.NextDouble() < .35) direction *= -1;
        }
    }

    private void Land(Ledge ledge)
    {
        gooseY = ledge.Y; gooseVy = gooseVx = 0; gooseSupport = ledge;
        action = GooseAction.Idle; actionLeft = .3 + random.NextDouble();
    }

    private void Hop()
    {
        if (gooseSupport is null) return;
        gooseVy = -650; gooseVx = direction * 100; gooseSupport = null; action = GooseAction.Air;
    }

    private void FlySomewhere()
    {
        var candidates = ledges.Where(l => Math.Abs(l.Y - gooseY) > 50 && l.Right - l.Left > 120).ToArray();
        if (candidates.Length == 0) { Hop(); return; }
        var target = candidates[random.Next(candidates.Length)];
        float tx = (target.Left + target.Right) / 2, dx = tx - gooseX, dy = target.Y - gooseY;
        float t = Math.Clamp(Math.Abs(dx) / 500 + .8f, .8f, 2f);
        gooseVx = dx / t;
        gooseVy = (dy - .5f * Gravity * t * t) / t;
        direction = gooseVx >= 0 ? 1 : -1; gooseSupport = null; action = GooseAction.Air;
    }

    private void RunTo(float x)
    {
        if (action == GooseAction.Air || action == GooseAction.Held) return;
        direction = x > gooseX ? 1 : -1; action = GooseAction.Run; actionLeft = .25;
    }

    private void Honk()
    {
        bubble = angry > .55 ? "HONK!!!" : random.Next(3) == 0 ? "HONK?" : "HONK!";
        bubbleLeft = 1.3; action = GooseAction.Honk; actionLeft = .65;
        if (sound) SystemSounds.Beep.Play();
    }

    private void DropFish()
    {
        GetCursorPos(out var p);
        fish = new Prop(p.X, p.Y) { Vy = 20 };
        RefreshMenu();
    }

    private void LayEgg()
    {
        if (eggs.Count >= 6) return;
        eggs.Add(new Prop(gooseX - direction * 25, gooseY - 25) { Vy = 20 });
    }

    private void ToggleCoyote()
    {
        if (coyote is not null) coyote = null;
        else
        {
            var floor = ledges.FirstOrDefault(l => l.Ground) ?? new Ledge(SystemInformation.WorkingArea.Bottom, SystemInformation.WorkingArea.Left, SystemInformation.WorkingArea.Right, true);
            float start = gooseX < (floor.Left + floor.Right) / 2 ? floor.Right - 120 : floor.Left + 120;
            coyote = new Coyote(start, floor.Y) { Grounded = true, Support = floor };
            bubble = "HONK!!!"; bubbleLeft = 1.4; if (sound) SystemSounds.Exclamation.Play();
        }
        RefreshMenu();
    }

    private bool ProtectChicks(double dt)
    {
        if (coyote is null || coyote.Health <= 0) return false;
        if (coyote.Held) { gooseVx = 0; action = GooseAction.Idle; return true; }
        coyoteAttackCool = Math.Max(0, coyoteAttackCool - dt);
        float dx = coyote.X - gooseX, dy = coyote.Y - gooseY;
        direction = dx >= 0 ? 1 : -1;
        if (coyote.Cast < 0 && Math.Abs(dx) < 58 && Math.Abs(dy) < 65 && coyoteAttackCool <= 0 && coyote.HurtCool <= 0)
        {
            coyote.Health--; coyote.HurtCool = .7; coyoteAttackCool = .75;
            coyote.Vx = direction * 180; coyote.Vy = -250; coyote.Grounded = false; coyote.Support = null;
            bubble = "HONK!!!"; bubbleLeft = 1.1; if (sound) SystemSounds.Exclamation.Play();
            return true;
        }
        if (gooseSupport is not null && dy < -45 && Math.Abs(dx) < 170)
        {
            gooseVy = -620; gooseVx = Math.Clamp(dx * 2, -520, 520); gooseSupport = null; action = GooseAction.Air;
            return true;
        }
        action = GooseAction.Run; gooseVx = direction * RunSpeed * 1.15f; gooseX += gooseVx * (float)dt;
        if (gooseSupport is not null && !gooseSupport.Contains(gooseX)) { gooseSupport = null; action = GooseAction.Air; gooseVy = 10; }
        return true;
    }

    private void StepCoyote(double dt)
    {
        if (coyote is null || coyote.Health <= 0 || coyote.Held) return;
        var c = coyote;
        c.BiteCool = Math.Max(0, c.BiteCool - dt); c.HurtCool = Math.Max(0, c.HurtCool - dt); c.CastCool = Math.Max(0, c.CastCool - dt);
        if (c.Cast >= 0)
        {
            c.Cast += dt;
            if (!c.Jumped && c.Cast >= CoyoteCastJump) { c.Jumped = true; c.X = c.DestX; c.Y = c.DestY; c.Vx = c.Vy = 0; c.Grounded = false; c.Support = null; }
            if (c.Cast >= CoyoteCastTotal) { c.Cast = -1; c.Jumped = false; c.CastCool = CoyoteCastCool; }
            return;
        }
        if (c.WizardFade > 0) c.WizardFade = Math.Max(0, c.WizardFade - dt / 3.5);
        var target = chicks.Where(ch => ch.Health > 0).OrderBy(ch => MathF.Sqrt((ch.X-c.X)*(ch.X-c.X)+(ch.Y-c.Y)*(ch.Y-c.Y))).FirstOrDefault();
        float gooseDistance = MathF.Sqrt((gooseX-c.X)*(gooseX-c.X)+(gooseY-c.Y)*(gooseY-c.Y));

        // Hold one retreat direction while there is no prey. Deriving it from
        // the actors' positions every frame made it flip whenever mother caught
        // up, so both animals jittered around the same point.
        var world = SystemInformation.VirtualScreen;
        if (target is not null) c.RetreatDirection = 0;
        else if (c.RetreatDirection == 0) c.RetreatDirection = c.X >= gooseX ? 1 : -1;
        float currentRetreatX = c.RetreatDirection > 0 ? world.Right - 50 : world.Left + 50;
        if (target is null && gooseDistance < 175 && c.CastCool <= 0 && Math.Abs(c.X-currentRetreatX) < 70)
            c.RetreatDirection *= -1;
        float retreatX = c.RetreatDirection > 0 ? world.Right - 50 : world.Left + 50;
        float tx = target?.X ?? retreatX;
        float ty = target?.Y ?? Screen.PrimaryScreen?.WorkingArea.Bottom ?? world.Bottom;
        float preyDx = tx - c.X, dy = ty - c.Y;
        bool motherBetween = target is not null && ((c.X < gooseX && gooseX < tx) || (tx < gooseX && gooseX < c.X)) && Math.Abs(gooseY-c.Y) < 120;
        bool threatened = gooseDistance < 175 || motherBetween;
        bool evading = target is null || threatened;
        if (threatened && c.CastCool <= 0)
        {
            float targetSide = tx >= gooseX ? 1 : -1;
            c.Cast = 0; c.Jumped = false; c.WizardFade = 1; c.StuckFor = 0;
            c.DestX = Math.Clamp(tx-targetSide*55, SystemInformation.VirtualScreen.Left+50, SystemInformation.VirtualScreen.Right-50);
            c.DestY = ty; return;
        }
        float away = target is null ? c.RetreatDirection : (c.X >= gooseX ? 1 : -1);
        float moveX = evading ? c.X + away * 400 : tx;
        float dx = moveX - c.X;
        if (Math.Abs(dx) > 5) c.Direction = dx > 0 ? 1 : -1;
        if (target is not null && Math.Abs(preyDx) < 56 && Math.Abs(dy) < 55 && c.BiteCool <= 0)
        {
            target.Health--; c.Health = Math.Min(10, c.Health + 1); c.BiteCool = 1.15; c.Vx = -c.Direction * 90;
        }
        bool unreachable = Math.Abs(preyDx) > 560 || Math.Abs(dy) > 150;
        c.StuckFor = unreachable ? c.StuckFor + dt : Math.Max(0, c.StuckFor - dt * 2);
        if (c.StuckFor > CoyoteStuckWait && c.CastCool <= 0)
        {
            c.StuckFor = 0; c.Cast = 0; c.Jumped = false; c.WizardFade = 1;
            c.DestX = tx - c.Direction * 65; c.DestY = ty; return;
        }
        if (c.Grounded)
        {
            float speed = target is null ? CoyoteRetreatSpeed : evading ? 310 : 265;
            c.Vx = c.Direction * speed; c.Phase += Math.Abs(c.Vx) * dt * .075; c.X += c.Vx * (float)dt;
            if (c.Support is not null && !c.Support.Contains(c.X)) { c.Grounded = false; c.Support = null; c.Vy = -30; }
            if (dy < -60 && Math.Abs(dx) < 150) { c.Grounded = false; c.Support = null; c.Vy = -560; }
        }
        else
        {
            float oldY = c.Y; c.Vy += Gravity * (float)dt * .9f; c.X += c.Vx * (float)dt; c.Y += c.Vy * (float)dt;
            if (c.Vy > 0)
            {
                var landing = FindLanding(oldY, c.Y, c.X, 4);
                if (landing is not null) { c.Y = landing.Y; c.Vy = 0; c.Support = landing; c.Grounded = true; }
            }
        }
        ClampHorizontal(ref c.X, ref c.Vx, 45);
    }

    private void StepFish(double dt)
    {
        if (fish is not null && !(dragging == DragKind.Fish && ReferenceEquals(draggedObject, fish))) StepProp(fish, dt, 16);
        for (int i = hearts.Count - 1; i >= 0; i--) { hearts[i].Y -= 30 * (float)dt; hearts[i].Life -= dt; if (hearts[i].Life <= 0) hearts.RemoveAt(i); }
    }

    private void StepEggs(double dt)
    {
        foreach (var egg in eggs.ToArray())
        {
            if (!(dragging == DragKind.Egg && ReferenceEquals(draggedObject, egg))) StepProp(egg, dt, 10);
            if (egg.Cracking)
            {
                egg.Age += dt;
                if (egg.Age > .9)
                {
                    chicks.Add(new Chick(egg.X, egg.Y + 8));
                    eggs.Remove(egg);
                }
            }
        }
    }

    private void StepProp(Prop prop, double dt, float halfHeight)
    {
        if (prop.Resting)
        {
            if (prop.Support is not null && (prop.Support.Ground || ledges.Any(l => Math.Abs(l.Y - prop.Support.Y) < 3 && l.Contains(prop.X)))) return;
            prop.Resting = false; prop.Support = null;
        }
        float oldBottom = prop.Y + halfHeight;
        prop.Vy += Gravity * (float)dt * .85f;
        prop.X += prop.Vx * (float)dt; prop.Y += prop.Vy * (float)dt;
        ClampHorizontal(ref prop.X, ref prop.Vx, 20);
        if (prop.Vy <= 0) return;
        var landing = FindLanding(oldBottom, prop.Y + halfHeight, prop.X, 2);
        if (landing is null) return;
        prop.Y = landing.Y - halfHeight;
        if (prop.Vy > 430) { prop.Vy *= -.3f; prop.Vx *= .7f; }
        else { prop.Vy = 0; prop.Vx *= .3f; prop.Resting = true; prop.Support = landing; }
    }

    private void StepChicks(double dt)
    {
        for (int index = 0; index < chicks.Count; index++)
        {
            var c = chicks[index];
            c.CastCool = Math.Max(0, c.CastCool - dt);
            if (c.Cast >= 0)
            {
                c.Cast += dt;
                if (!c.Jumped && c.Cast >= 1.5)
                {
                    c.Jumped = true; c.X = c.DestX; c.Y = c.DestY; c.Vx = c.Vy = 0;
                    c.Grounded = false; c.Support = null;
                }
                if (c.Cast >= 2.2) { c.Cast = -1; c.Jumped = false; c.CastCool = 6; }
                continue;
            }
            if (c.WizardFade > 0) c.WizardFade = Math.Max(0, c.WizardFade - dt / 3.5);
            if (dragging == DragKind.Chick && ReferenceEquals(draggedObject, c)) { c.StuckFor = 0; continue; }
            float targetX = gooseX - direction * (55 + index * 28);
            if (coyote is not null && MathF.Sqrt((coyote.X-c.X)*(coyote.X-c.X)+(coyote.Y-c.Y)*(coyote.Y-c.Y)) < 330)
            {
                float away = c.X >= coyote.X ? 1 : -1;
                targetX = Math.Clamp(c.X + away * 450, SystemInformation.VirtualScreen.Left + 20, SystemInformation.VirtualScreen.Right - 20);
            }
            float dx = targetX - c.X;
            c.Direction = dx >= 0 ? 1 : -1;
            float speed = Math.Abs(dx) > 220 ? 132 : 56;
            c.Vx = Math.Abs(dx) > 15 ? c.Direction * speed : 0;
            bool strandedOver = c.Y < gooseY - 120 && c.Grounded && (c.Support?.Contains(gooseX, 6) ?? false);
            bool unreachable = gooseY < c.Y - 70 || strandedOver || Math.Abs(dx) > 650;
            c.StuckFor = unreachable ? c.StuckFor + dt : Math.Max(0, c.StuckFor - dt * 2);
            if (c.StuckFor > 3.5 && c.CastCool <= 0)
            {
                c.StuckFor = 0; c.Cast = 0; c.Jumped = false; c.WizardFade = 1;
                c.DestX = targetX; c.DestY = gooseY;
                continue;
            }
            c.Vy += Gravity * (float)dt * .9f;
            float oldY = c.Y;
            c.X += c.Vx * (float)dt; c.Y += c.Vy * (float)dt; c.Phase += speed * dt * .08;
            c.Grounded = false;
            if (c.Vy > 0)
            {
                var landing = FindLanding(oldY, c.Y, c.X, 3);
                if (landing is not null) { c.Y = landing.Y; c.Vy = 0; c.Grounded = true; c.Support = landing; }
            }
            if (c.Grounded && gooseY < c.Y - 45 && Math.Abs(gooseX - c.X) < 120) { c.Vy = -520; c.Grounded = false; c.Support = null; }
            ClampHorizontal(ref c.X, ref c.Vx, 15);
        }
    }

    private void ScanLedges()
    {
        ledges.Clear();
        foreach (var screen in Screen.AllScreens)
            ledges.Add(new Ledge(screen.WorkingArea.Bottom, screen.Bounds.Left, screen.Bounds.Right, true));

        EnumWindows((h, _) =>
        {
            if (h == Handle || !IsWindowVisible(h) || IsIconic(h)) return true;
            if (GetWindow(h, 4) != IntPtr.Zero) return true; // owned/tool windows
            if (!GetWindowRect(h, out var r)) return true;
            float width = r.Right - r.Left, height = r.Bottom - r.Top;
            if (width >= 140 && height >= 60 && r.Top > SystemInformation.VirtualScreen.Top + 2)
                ledges.Add(new Ledge(r.Top, r.Left, r.Right));
            return true;
        }, IntPtr.Zero);

        if (gooseSupport is not null && !gooseSupport.Ground)
        {
            var replacement = ledges.FirstOrDefault(l => Math.Abs(l.Y - gooseSupport.Y) < 3 && l.Contains(gooseX));
            if (replacement is null) { gooseSupport = null; action = GooseAction.Air; gooseVy = 0; }
            else gooseSupport = replacement;
        }
    }

    /// Finds the topmost ledge crossed during downward movement. All actors and
    /// props use this so future collision fixes apply consistently.
    private Ledge? FindLanding(float previousY, float currentY, float x, float padding) =>
        ledges.Where(ledge => ledge.Y >= previousY
                           && ledge.Y <= currentY + 2
                           && ledge.Contains(x, padding))
               .OrderBy(ledge => ledge.Y)
               .FirstOrDefault();

    private void ClampHorizontal(ref float x, ref float vx, float margin)
    {
        var v = SystemInformation.VirtualScreen;
        if (x < v.Left + margin) { x = v.Left + margin; vx = Math.Abs(vx) * .4f; }
        if (x > v.Right - margin) { x = v.Right - margin; vx = -Math.Abs(vx) * .4f; }
    }

    private object? HitObject(Point screen)
    {
        if (paused) return null;
        if (fish is not null && Distance(screen, fish.X, fish.Y) < 34) return fish;
        foreach (var egg in eggs) if (Distance(screen, egg.X, egg.Y) < 22) return egg;
        foreach (var chick in chicks) if (Math.Abs(screen.X - chick.X) < 28 && screen.Y > chick.Y - 48 && screen.Y < chick.Y + 10) return chick;
        if (coyote is not null && Math.Abs(screen.X - coyote.X) < 68 && screen.Y > coyote.Y - 82 && screen.Y < coyote.Y + 8) return coyote;
        if (Math.Abs(screen.X - gooseX) < 64 && screen.Y > gooseY - 122 && screen.Y < gooseY + 20) return this;
        return null;
    }

    private static float Distance(Point p, float x, float y) => MathF.Sqrt((p.X - x) * (p.X - x) + (p.Y - y) * (p.Y - y));

    private void OnMouseDown(object? sender, MouseEventArgs e)
    {
        var screen = PointToScreen(e.Location);
        if (e.Button == MouseButtons.Right) { menu.Show(screen); return; }
        if (e.Button != MouseButtons.Left) return;
        object? hit = HitObject(screen);
        if (hit is null) return;
        mouseDown = screen; priorMouse = lastMouse = screen; lastMouseTick = Environment.TickCount64; moved = false;
        draggedObject = hit;
        if (ReferenceEquals(hit, this))
        {
            holdingHead = screen.Y < gooseY - 62;
            dragging = DragKind.Goose; dragOffset = new PointF(gooseX - screen.X, gooseY - screen.Y);
            action = GooseAction.Held; gooseSupport = null; Honk(); action = GooseAction.Held;
        }
        else if (ReferenceEquals(hit, fish)) { dragging = DragKind.Fish; dragOffset = new PointF(fish!.X - screen.X, fish.Y - screen.Y); fish.Resting = false; }
        else if (hit is Prop egg)
        {
            dragging = DragKind.Egg; dragOffset = new PointF(egg.X - screen.X, egg.Y - screen.Y);
        }
        else if (hit is Chick chick) { dragging = DragKind.Chick; dragOffset = new PointF(chick.X - screen.X, chick.Y - screen.Y); }
        else if (hit is Coyote animal)
        {
            dragging = DragKind.Coyote; dragOffset = new PointF(animal.X - screen.X, animal.Y - screen.Y);
            animal.Held = true; animal.Grounded = false; animal.Support = null; animal.Cast = -1; animal.Vx = animal.Vy = 0;
            bubble = "HEY!"; bubbleLeft = 1.1;
        }
        Capture = true;
    }

    private void OnMouseMove(object? sender, MouseEventArgs e)
    {
        if (dragging == DragKind.None) return;
        var p = PointToScreen(e.Location);
        moved |= Distance(p, mouseDown.X, mouseDown.Y) > 5;
        priorMouse = lastMouse; lastMouse = p; lastMouseTick = Environment.TickCount64;
        float x = p.X + dragOffset.X, y = p.Y + dragOffset.Y;
        if (dragging == DragKind.Goose)
        {
            TugStretch(lastMouse.X - priorMouse.X, lastMouse.Y - priorMouse.Y);
            gooseX = x; gooseY = y; direction = p.X >= priorMouse.X ? 1 : -1;
        }
        else if (draggedObject is Prop prop) { prop.X = x; prop.Y = y; prop.Vx = prop.Vy = 0; prop.Resting = false; }
        else if (draggedObject is Chick chick) { chick.X = x; chick.Y = y; chick.Vx = chick.Vy = 0; }
        else if (draggedObject is Coyote animal) { animal.X = x; animal.Y = y; animal.Vx = animal.Vy = 0; }
        Invalidate();
    }

    private void OnMouseUp(object? sender, MouseEventArgs e)
    {
        if (dragging == DragKind.None) return;
        double seconds = Math.Max(.016, (Environment.TickCount64 - lastMouseTick + 16) / 1000.0);
        float vx = (lastMouse.X - priorMouse.X) / (float)seconds, vy = (lastMouse.Y - priorMouse.Y) / (float)seconds;
        if (dragging == DragKind.Goose)
        {
            if (!moved)
            {
                gooseVx = gooseVy = 0;
                var clickedSupport = ledges.Where(l => Math.Abs(l.Y - gooseY) < 8 && l.Contains(gooseX)).FirstOrDefault();
                if (clickedSupport is not null) Land(clickedSupport);
                else { gooseSupport = null; action = GooseAction.Air; }
                actionLeft = 1;
                hearts.Add(new Heart(gooseX, gooseY - 65)); bubble = "♥"; bubbleLeft = 1.2;
            }
            else { gooseVx = Math.Clamp(vx, -1400, 1400); gooseVy = Math.Clamp(vy, -1400, 1400); action = GooseAction.Air; }
        }
        else if (draggedObject is Prop prop)
        {
            prop.Vx = Math.Clamp(vx, -1200, 1200); prop.Vy = Math.Clamp(vy, -1200, 1200);
            if (dragging == DragKind.Egg && !moved) prop.Cracking = true;
        }
        else if (draggedObject is Chick chick) { chick.Vx = Math.Clamp(vx, -1000, 1000); chick.Vy = Math.Clamp(vy, -1000, 1000); }
        else if (draggedObject is Coyote animal)
        {
            animal.Held = false; animal.Grounded = false; animal.Support = null;
            animal.Vx = Math.Clamp(vx, -1200, 1200); animal.Vy = Math.Clamp(vy, -1200, 1200);
        }
        dragging = DragKind.None; draggedObject = null; Capture = false;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.TranslateTransform(-Left, -Top);
        e.Graphics.SmoothingMode = SmoothingMode.None;
        DrawFish(e.Graphics);
        foreach (var egg in eggs) DrawEgg(e.Graphics, egg);
        if (coyote is not null) DrawCoyote(e.Graphics, coyote);
        foreach (var chick in chicks) DrawChick(e.Graphics, chick);
        DrawGoose(e.Graphics);
        foreach (var heart in hearts) PixelRenderer.DrawHeart(e.Graphics, heart.X, heart.Y, (float)Math.Min(1, heart.Life / .45));
    }

    private void DrawGoose(Graphics g)
    {
        PixelRenderer.DrawGoose(g, gooseX, gooseY, direction, action, phase,
            clock, angry > .55 || coyote is not null,
            headStretchX, headStretchY, bodyStretchX, bodyStretchY);
        if (bubbleLeft > 0) DrawBubble(g, gooseX + direction * 22 + headStretchX, gooseY - 112 + headStretchY, bubble);
    }

    private void DrawFish(Graphics g)
    {
        if (fish is null) return;
        PixelRenderer.DrawFish(g, fish.X, fish.Y, fish.Vx < -5, clock,
            dragging == DragKind.Fish && ReferenceEquals(draggedObject, fish), fish.Vx);
    }

    private static void DrawEgg(Graphics g, Prop egg) => PixelRenderer.DrawEgg(g, egg.X, egg.Y, egg.Cracking);

    private void DrawChick(Graphics g, Chick chick)
    {
        if (chick.Cast >= 0)
        {
            double t = chick.Cast;
            float nearGrow = (float)Math.Min(1, t / .8);
            float nearAlpha = t < 1.5 ? (float)Math.Min(1, t / .25) : (float)Math.Max(0, 1 - (t - 1.5) / .7);
            float farGrow = (float)Math.Clamp((t - .8) / .7, 0, 1);
            float farAlpha = t < .8 ? 0 : t < 1.5 ? Math.Min(1, farGrow * 1.6f) : (float)Math.Max(0, 1 - (t - 1.5) / .7);
            float nearY = chick.Y + (chick.Support?.Ground == true ? -18 : 5);
            float farY = chick.DestY + (gooseSupport?.Ground == true ? -18 : 5);
            PixelRenderer.DrawMagic(g, chick.X, nearY, .3f + .7f * nearGrow, nearAlpha);
            PixelRenderer.DrawMagic(g, chick.DestX, farY, .3f + .7f * farGrow, farAlpha);
        }
        PixelRenderer.DrawChick(g, chick.X, chick.Y, chick.Direction < 0, chick.Phase,
            dragging == DragKind.Chick && ReferenceEquals(draggedObject, chick));
        if (chick.WizardFade > 0)
            PixelRenderer.DrawWizardHat(g, chick.X, chick.Y, chick.Direction < 0, (float)chick.WizardFade);
        if (coyote is not null) DrawHealth(g, chick.X, chick.Y - 58, chick.Health, 3, 30);
    }

    private void DrawCoyote(Graphics g, Coyote animal)
    {
        if (animal.Cast >= 0)
        {
            double t = animal.Cast;
            float nearGrow = (float)Math.Min(1, t / CoyoteCastCharge);
            float nearAlpha = t < CoyoteCastJump ? (float)Math.Min(1, t / .15) : (float)Math.Max(0, 1-(t-CoyoteCastJump)/(CoyoteCastTotal-CoyoteCastJump));
            float farGrow = (float)Math.Clamp((t-CoyoteCastCharge)/(CoyoteCastJump-CoyoteCastCharge), 0, 1);
            float farAlpha = t < CoyoteCastCharge ? 0 : t < CoyoteCastJump ? Math.Min(1, farGrow*1.8f) : (float)Math.Max(0, 1-(t-CoyoteCastJump)/(CoyoteCastTotal-CoyoteCastJump));
            PixelRenderer.DrawMagic(g, animal.X, animal.Y + (animal.Support?.Ground == true ? -18 : 5), .3f+.7f*nearGrow, nearAlpha);
            PixelRenderer.DrawMagic(g, animal.DestX, animal.DestY + 5, .3f+.7f*farGrow, farAlpha);
        }
        PixelRenderer.DrawCoyote(g, animal.X, animal.Y, animal.Direction < 0, animal.Phase, (float)animal.WizardFade);
        DrawHealth(g, animal.X, animal.Y - 78, animal.Health, 10, 72);
    }

    private static void DrawHealth(Graphics g, float x, float y, int value, int maximum, float width)
    {
        float ratio = Math.Clamp(value / (float)maximum, 0, 1);
        g.FillRectangle(Brushes.Black, x-width/2-2, y-2, width+4, 9);
        using var fill = new SolidBrush(ratio > .5f ? Color.LimeGreen : ratio > .25f ? Color.Gold : Color.Red);
        g.FillRectangle(fill, x-width/2, y, width*ratio, 5);
    }

    private static void DrawBubble(Graphics g, float x, float y, string text)
    {
        using var font = new Font("Consolas", 11, FontStyle.Bold, GraphicsUnit.Pixel);
        SizeF size = g.MeasureString(text, font);
        var box = new RectangleF(x - size.Width / 2 - 7, y - 10, size.Width + 14, 25);
        g.FillRectangle(Brushes.White, box); g.DrawRectangle(Pens.DarkSlateGray, box.X, box.Y, box.Width, box.Height);
        g.DrawString(text, font, Brushes.Black, box.X + 7, box.Y + 6);
    }

    private static Icon MakeIcon()
    {
        using var bitmap = new Bitmap(32, 32);
        using var g = Graphics.FromImage(bitmap);
        g.Clear(Color.Transparent); g.FillEllipse(Brushes.SaddleBrown, 3, 14, 23, 13); g.FillEllipse(Brushes.Black, 16, 5, 12, 13); g.FillEllipse(Brushes.White, 22, 8, 3, 3);
        return Icon.FromHandle(bitmap.GetHicon());
    }

    private sealed class Heart(float x, float y) { public float X = x, Y = y; public double Life = 1.2; }
    private readonly List<Heart> hearts = [];

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct NativePoint { public int X, Y; }
    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint command);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out NativePoint point);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern nint GetWindowLongPtr(IntPtr hWnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] private static extern nint SetWindowLongPtr(IntPtr hWnd, int index, nint value);
}
