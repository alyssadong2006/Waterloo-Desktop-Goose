namespace DesktopGoose;

/// Draws the exact same character grids used by the macOS build.
internal static class PixelRenderer
{
    internal const float Scale = 1.5f;
    private const int CanvasWidth = 96, LogicalHeight = 58, TopPad = 28, BottomPad = 18, SidePad = 16;
    private static readonly Dictionary<char, SolidBrush> Brushes = PixelArt.Palette.ToDictionary(p => p.Key, p => new SolidBrush(p.Value));

    private sealed class Canvas(int width, int height, int offsetY = 0)
    {
        internal readonly int Width = width, Height = height, OffsetY = offsetY;
        internal readonly char[] Cells = Enumerable.Repeat('.', width * height).ToArray();

        internal void Set(int x, int y, char value)
        {
            y += OffsetY;
            if (x >= 0 && y >= 0 && x < Width && y < Height) Cells[y * Width + x] = value;
        }

        internal void Stamp(string name, int x, int y)
        {
            string[] sprite = PixelArt.Sprites[name];
            for (int row = 0; row < sprite.Length; row++)
                for (int col = 0; col < sprite[row].Length; col++)
                    if (sprite[row][col] != '.') Set(x + col, y + row, sprite[row][col]);
        }
    }

    internal static void DrawGoose(Graphics g, float baseX, float baseY, float direction,
        GooseAction action, double phase, double clock, bool angry,
        float headOffsetX, float headOffsetY, float bodyOffsetX, float bodyOffsetY)
    {
        var canvas = new Canvas(CanvasWidth, LogicalHeight + TopPad + BottomPad, TopPad);
        bool walking = action is GooseAction.Walk or GooseAction.Run;
        bool tucked = action == GooseAction.Air;
        bool dangling = action == GooseAction.Held;
        int walkFrame = (int)(phase / .5) % 4;
        int bodyDx = (int)MathF.Round(bodyOffsetX * direction / Scale);
        int bodyDy = (int)MathF.Round(bodyOffsetY / Scale);
        int headDx = (int)MathF.Round(headOffsetX * direction / Scale);
        int headDy = (int)MathF.Round(headOffsetY / Scale);

        if (tucked) canvas.Stamp("legTuck", SidePad + 20 + bodyDx, 50 + bodyDy);
        else if (dangling)
        {
            int wriggle = (int)Math.Round(Math.Sin(clock * 11));
            canvas.Stamp("legDangle", SidePad + 20 + wriggle * 2 + bodyDx, 50 + bodyDy);
        }
        else if (walking)
        {
            string[] frames = ["legStand", "legWalkA", "legStand", "legWalkB"];
            canvas.Stamp(frames[walkFrame], SidePad + 20 + bodyDx, 52 + bodyDy);
        }
        else canvas.Stamp("legStand", SidePad + 20 + bodyDx, 52 + bodyDy);

        int bodyX = SidePad + 14 + bodyDx, bodyY = 30 + bodyDy;
        int headX = SidePad + 30 + headDx, headY = headDy;
        if (action == GooseAction.Honk) headY -= 2;
        if (action == GooseAction.Peck) { headX += 6; headY += 24; }

        // Pixel-thick neck connecting independently moving body and head.
        float ax = bodyX + 18, ay = bodyY + 8, bx = headX + 8, by = headY + 12;
        int steps = (int)Math.Max(Math.Abs(bx - ax), Math.Abs(by - ay));
        for (int i = 0; i <= Math.Max(1, steps); i++)
        {
            float t = i / (float)Math.Max(1, steps);
            int px = (int)MathF.Round(ax + (bx - ax) * t), py = (int)MathF.Round(ay + (by - ay) * t);
            canvas.Set(px - 5, py, 'K'); canvas.Set(px + 5, py, 'K');
            for (int n = -4; n <= 4; n++) canvas.Set(px + n, py, 'N');
        }

        canvas.Stamp("body", bodyX, bodyY);
        canvas.Stamp("tail", bodyX - 6, bodyY + 6);
        canvas.Stamp("tag", bodyX + 2, bodyY + 3);
        string wing = dangling ? (Math.Sin(clock * 14) > 0 ? "wingUp" : "wingDown") : "wingFold";
        if (dangling) canvas.Stamp(wing, bodyX + 8, bodyY - (wing == "wingUp" ? 8 : 0));
        else canvas.Stamp(wing, bodyX + 13, bodyY + 9);

        canvas.Stamp(angry ? "headAngry" : "head", headX, headY);
        int beakX = headX + 17, beakY = headY + 8;
        if (action == GooseAction.Honk)
        {
            canvas.Stamp("beakUpper", beakX, beakY - 4);
            canvas.Stamp("beakLower", beakX, beakY + 7);
        }
        else canvas.Stamp("beak", beakX, beakY);

        DrawCanvas(g, canvas, baseX - CanvasWidth * Scale / 2,
            baseY - (LogicalHeight - 1 + TopPad) * Scale, direction < 0);
    }

    internal static void DrawFish(Graphics g, float x, float y, bool flip, double clock, bool held, float velocity)
    {
        string frame = Math.Sin(clock * (held ? 15 : Math.Abs(velocity) > 40 ? 11 : 5)) > 0 ? "fishA" : "fishB";
        DrawSprite(g, frame, x - 28 * Scale / 2, y - 18 * Scale / 2, flip);
    }

    internal static void DrawEgg(Graphics g, float x, float y, bool cracking)
        => DrawSprite(g, cracking ? "eggCrack" : "egg", x - 10 * Scale / 2, y - 13 * Scale / 2, false);

    internal static void DrawChick(Graphics g, float x, float feetY, bool flip, double phase, bool held)
    {
        string frame = held ? (Math.Sin(phase * 17) > 0 ? "chickA" : "chickB")
                            : ((int)(phase / .5) % 2 == 0 ? "chickA" : "chickB");
        DrawSprite(g, frame, x - 9 * Scale, feetY - 17 * Scale, flip);
    }

    internal static void DrawMagic(Graphics g, float x, float y, float scale, float opacity = 1)
        => DrawSprite(g, "magic", x - 12 * Scale * scale, y - 12 * Scale * scale, false, scale, opacity);

    internal static void DrawHeart(Graphics g, float x, float y, float opacity = 1)
        => DrawSprite(g, "heart", x - 5 * Scale, y - 5 * Scale, false, 1, opacity);

    internal static void DrawWizardHat(Graphics g, float x, float feetY, bool flip, float opacity)
        => DrawSprite(g, "wizardHat", x - 5.5f * Scale, feetY - 49, flip, 1, opacity);

    internal static void DrawCoyote(Graphics g, float x, float feetY, bool flip, double phase, float hatOpacity)
    {
        const float scale = 1.65f;
        string frame = (int)(phase / .5) % 2 == 0 ? "coyoteA" : "coyoteB";
        float left = x - 36 * scale, top = feetY - 39 * scale;
        DrawSprite(g, frame, left, top, flip, scale / Scale);

        // Draw the crest independently so it can be smaller than the fur pixels
        // and sit toward the rump instead of in the middle of the torso.
        const float tagCell = scale * .72f;
        float tagCenterX = x + (flip ? 12 : -12);
        float tagCenterY = feetY - 27.225f;
        DrawSprite(g, "torontoTag", tagCenterX - 8.5f * tagCell,
            tagCenterY - 8.5f * tagCell, flip, tagCell / Scale);
        if (hatOpacity > 0)
        {
            const float hatCell = 2.145f; // 30% larger than the coyote's pixels
            float headCenter = x + (flip ? -33 : 33);
            DrawSprite(g, "wizardHat", headCenter - 5.5f * hatCell, feetY - 79, flip,
                hatCell / Scale, hatOpacity);
        }
    }

    private static void DrawCanvas(Graphics g, Canvas canvas, float x, float y, bool flip)
    {
        for (int row = 0; row < canvas.Height; row++)
            for (int col = 0; col < canvas.Width; col++)
            {
                char value = canvas.Cells[row * canvas.Width + col];
                if (value == '.' || !Brushes.TryGetValue(value, out var brush)) continue;
                int drawCol = flip ? canvas.Width - 1 - col : col;
                g.FillRectangle(brush, x + drawCol * Scale, y + row * Scale, Scale, Scale);
            }
    }

    private static void DrawSprite(Graphics g, string name, float x, float y, bool flip, float scale = 1, float opacity = 1)
    {
        string[] sprite = PixelArt.Sprites[name];
        float cell = Scale * scale;
        for (int row = 0; row < sprite.Length; row++)
            for (int col = 0; col < sprite[row].Length; col++)
            {
                char value = sprite[row][col];
                if (value == '.' || !PixelArt.Palette.TryGetValue(value, out Color color)) continue;
                int drawCol = flip ? sprite[row].Length - 1 - col : col;
                using var faded = opacity < 1 ? new SolidBrush(Color.FromArgb((int)(255 * opacity), color)) : null;
                g.FillRectangle(faded ?? Brushes[value], x + drawCol * cell, y + row * cell, cell, cell);
            }
    }
}
