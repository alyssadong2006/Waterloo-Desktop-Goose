namespace DesktopGoose;

internal enum GooseAction { Idle, Walk, Run, Air, Held, Honk, Peck }
internal enum DragKind { None, Goose, Fish, Egg, Chick, Coyote }
internal sealed class Ledge(float y, float left, float right, bool ground = false)
{
    public float Y = y, Left = left, Right = right;
    public bool Ground = ground;
    public bool Contains(float x, float pad = 0) => x >= Left - pad && x <= Right + pad;
}
internal sealed class Prop(float x, float y)
{
    public float X = x, Y = y, Vx, Vy;
    public bool Resting, Cracking;
    public double Age;
    public Ledge? Support;
}
internal sealed class Chick(float x, float y)
{
    public float X = x, Y = y, Vx, Vy, Direction = 1, DestX, DestY;
    public int Health = 3;
    public bool Grounded, Jumped;
    public double Phase, StuckFor, Cast = -1, CastCool, WizardFade;
    public Ledge? Support;
}
internal sealed class Coyote(float x, float y)
{
    public float X = x, Y = y, Vx, Vy, Direction = 1, DestX, DestY, RetreatDirection;
    public int Health = 10;
    public bool Grounded, Jumped, Held;
    public double Phase, BiteCool, HurtCool, StuckFor, Cast = -1, CastCool, WizardFade;
    public Ledge? Support;
}
