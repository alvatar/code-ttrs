module cellular;
import qd, std.stdio, std.string, tools.base;

const real K=1024, M=1024*K, G=1024*M, T=1024*G;

string fc(real what, string label) {
  if (what>T) return format(1.0*what/T, "Tc", label);
  if (what>G) return format(1.0*what/G, "Gc", label);
  if (what>M) return format(1.0*what/M, "Mc", label);
  if (what>K) return format(1.0*what/K, "Kc", label);
  return format(what, "c", label);
}

import tools.array2d;

void swap(T)(ref T a, ref T b) { T x=a; a=b; b=x; }

size_t newline(string s) { size_t count; while (count<s.length && s[count]!='\n') ++count; return count;  }

/**
 * transform a list of rules (CTRBLI, sorted) into a tree of if statements
 * AT COMPILE TIME ... DUN DUN DUN
 * NOTE: 
 *   gdc already optimizes the if tree.
 *   no need to calculate the symmetries manually.
**/
string rules_transform(string _file) {
  string res;
  for (int symmetry=0; symmetry<4; ++symmetry) {
    string sup, sright, sdown, sleft;
    switch (symmetry) {
      case 0: sup="up"; sright="right"; sdown="down"; sleft="left"; break;
      case 1: sup="right"; sright="down"; sdown="left"; sleft="up"; break;
      case 2: sup="down"; sright="left"; sdown="up"; sleft="right"; break;
      case 3: sup="left"; sright="up"; sdown="right"; sleft="down"; break;
      default: assert(false);
    }
    auto file=_file;
    int cur_me=-1, cur_up, cur_right, cur_down, cur_left;
    while (file.length) {
      auto line=file[0..newline(file)];
      file=file[newline(file)+1..$];
      if (line[0]=='#') continue;
      auto me=line[0]-'0', up=line[1]-'0', right=line[2]-'0',
        down=line[3]-'0', left=line[4]-'0', to=line[5]-'0';
      if (cur_me!=me) {
        if (cur_me!=-1) res~="} } } } }";
        cur_me=me; cur_up=up; cur_right=right; cur_down=down; cur_left=left;
        res~="if (me=="~ctToString(me)~") {
          if ("~sup~"=="~ctToString(up)~") {
            if ("~sright~"=="~ctToString(right)~") {
              if ("~sdown~"=="~ctToString(down)~") {
                if ("~sleft~"=="~ctToString(left)~") {
                  return "~ctToString(to)~"; ";
      } else {
        if (cur_up!=up) {
          cur_up=up; cur_right=right; cur_down=down; cur_left=left;
          res~="} } } } if ("~sup~"=="~ctToString(up)~") {
            if ("~sright~"=="~ctToString(right)~") {
              if ("~sdown~"=="~ctToString(down)~") {
                if ("~sleft~"=="~ctToString(left)~") {
                  return "~ctToString(to)~"; ";
        } else {
          if (cur_right!=right) {
            cur_right=right; cur_down=down; cur_left=left;
            res~="} } } if ("~sright~"=="~ctToString(right)~") {
              if ("~sdown~"=="~ctToString(down)~") {
                if ("~sleft~"=="~ctToString(left)~") {
                  return "~ctToString(to)~"; ";
          } else {
            if (cur_down!=down) {
              cur_down=down; cur_left=left;
              res~="} } if ("~sdown~"=="~ctToString(down)~") {
                if ("~sleft~"=="~ctToString(left)~") {
                  return "~ctToString(to)~"; ";
            } else {
              if (cur_left!=left) {
                cur_left=left;
                res~="} if ("~sleft~"=="~ctToString(left)~") {
                  return "~ctToString(to)~"; ";
              } else assert(false, "Duplicate state");
            }
          }
        }
      }
    }
    res~="} } } } }";
  }
  return res;
}

import living_space;
final class ChouReggia : Space!(Neumann) {
  this(int b, int o, bool w, int[][] s=null) { super(b, o, w, s); }
  final ubyte eval(ubyte me, ubyte up, ubyte right, ubyte down, ubyte left) {
    mixin(rules_transform(import("ChouReggia.r")));
    return me;
  }
}

final class Byl : Space!(Neumann) {
  this(int b, int o, bool w, int[][] s=null) { super(b, o, w, s); }
  final ubyte eval(ubyte me, ubyte up, ubyte right, ubyte down, ubyte left) {
    mixin(rules_transform(import("byl.r")));
    return me;
  }
}

final class Evoloop : Space!(Neumann) {
  this(int b, int o, bool w, int[][] s=null) { super(b, o, w, s); }
  final ubyte eval(ubyte me, ubyte up, ubyte right, ubyte down, ubyte left) {
    bool see(ubyte which) {
      return (up == which || right == which || down == which || left == which);
    }
    mixin(rules_transform(import("evoloop.r")));
    if (me==8) return 0;
    if (see(8)) {
      if ((me==0) || (me==1)) {
        if (see(2) || see(3) || see(4) || see(5) || see(6) || see(7)) return 8;
        else return me;
      }
      if ((me==2) || (me==3) || (me==5)) return 0;
      if ((me==4) || (me==6) || (me==7)) return 1;
    }
    if (!me) return 0;
    return 8;
  }
}

ubyte urand(ubyte and=255) { return cast(ubyte)(rand()&and); }

import std.random;
final class Life : Space!(Moore) {
  bool[] sustain, births;
  this(int b, int o, bool w, int[] sust, int[] birth, int[][] s=null) {
    sustain=new bool[9]; foreach (entry; sust) sustain[entry]=true;
    births=new bool[9]; foreach (entry; birth) births[entry]=true;
    super(b, o, w, s);
    cols=[Black, White, Black~White~Black, White~Black~White];
    if (!s) foreach (ref cell; state) cell=urand(1);
  }
  final ubyte eval(ubyte a, ubyte b, ubyte c, ubyte d, ubyte e, ubyte f, ubyte g, ubyte h, ubyte i) {
    int sum=(a&1)+(b&1)+(c&1)
           +(d&1)      +(f&1)
           +(g&1)+(h&1)+(i&1);
    if (e&1) {
      if (sustain[sum]) return 3;
      return 2;
    } else {
      if (births[sum]) return 1; // Any dead cell with exactly three live neighbours comes to life.
      return 0;
    }
  }
}

template rule(int a, int b, int c, int d, int e, string WHUT) {
  const string rule=Replace!("if (me==$a) {
    if (
      (($b==-1)?true:( up ==$b)) && (($c==-1)?true:( left ==$c)) && (($d==-1)?true:( down ==$d)) && (($e==-1)?true:( right ==$e)) ||
      (($b==-1)?true:( left ==$b)) && (($c==-1)?true:( down ==$c)) && (($d==-1)?true:( right ==$d)) && (($e==-1)?true:( up ==$e)) ||
      (($b==-1)?true:( down ==$b)) && (($c==-1)?true:( right ==$c)) && (($d==-1)?true:( up ==$d)) && (($e==-1)?true:( left ==$e)) ||
      (($b==-1)?true:( right ==$b)) && (($c==-1)?true:( up ==$c)) && (($d==-1)?true:( left ==$d)) && (($e==-1)?true:( down ==$e))
    ) $W;
  }", "$a", ctToString(a), "$b", ctToString(b), "$c", ctToString(c), "$d", ctToString(d), "$e", ctToString(e), "$W", WHUT);
}

const string WireEval="
  final ubyte eval(ubyte a, ubyte b, ubyte c, ubyte d, ubyte e, ubyte f, ubyte g, ubyte h, ubyte i) {
    switch (e) {
      case 0: return 0; break;
      case 2: return 3; break;
      case 3: return 1; break;
      case 1:
        ubyte heads;
        if (a==2) ++heads; if (b==2) ++heads; if (c==2) ++heads;
        if (d==2) ++heads;                    if (f==2) ++heads;
        if (g==2) ++heads; if (h==2) ++heads; if (i==2) ++heads;
        if ((heads==1) || (heads==2)) return 2;
        return 1;
        break;
    }
  }";
final class Wireworld : Space!(Moore, WireEval) {
  this(int b, int o, int[][] s=null) { super(b, o, true, s); cols=[Black, Yellow, Blue~White~Blue, Red~White~Red]; }
}

import std.c.time, tools.functional;
static import std.file;

void main() {
  screen(640, 960);
  flip=false;
  // cannot reproduce sexyloop
  // ask authors?
  auto g = new Evoloop(1, 0, true, (string text) {
    auto lines = text.split("\n");
    auto res = new int[][lines.length];
    int maxlen;
    foreach (line; lines) if (line.length > maxlen) maxlen = line.length;
    foreach (i, line; lines) {
      res[i] = new int[maxlen];
      foreach (k, ch; line)
        if (ch == ' ') res[i][k] = 0;
        else res[i][k] = ch - '0';
    }
    return res;
  }("
     222222222222222
    27017017017011115
    21222222222222212
    202           212
    272           212
    212           212
    202           212
    272           212
    212           212
    202           212
    272           272
    212           202    22222
    202           212   2111112
    272           272   2122212
    21222222222222202   212 212
    20710710710410412   212 272
     222222222222222    2122202
                        2111112
                         22222
     "));
  /*auto g=new Life(2, 0, [2, 3], [3], [
    [1,1,1,0,1],
    [1,0,0,0,0],
    [0,0,0,1,1],
    [0,1,1,0,1],
    [1,0,1,0,1]
  ]);*/
  /*auto g=new Life(4, 0, true, [2, 3], [3], [
    "                        x           ",
    "                      x x           ",
    "            xx      xx            xx",
    "           x   x    xx            x ",
    "xx        x     x   xx              ",
    "xx        x   x xx    x x           ",
    "          x     x       x           ",
    "           x   x                    ",
    "            xx                      "
  ] /map/ (string s) { return s /map/ ex!("f -> (f==' ')?0:1"); });*/
  /*auto g=new Life(2, 0, true, [2, 3], [3], [
    "  x ",
    "   x",
    " xxx"
  ] /Map!("return $ /Map!(\"return ($==' ')?0:1\")"));*/
  //auto g=new Life(2, 0, [2, 5], [3, 4]);
  /*auto g=new Wireworld(4, 1, "
   ->oooooooooooooooo                            oooooooo
  o                  ooooooo                    oooooooo
   ooooooooooooooo  o       o                  o
                  o o       o             oo  o oooooooo
   ooooooooooooooo  o       o            o  o o  oooooooo
  o                 o       o            o ooo
   ooooooooooooooooo       ooo           o  o
                            o            ooo
                           o oooooooooooo
                           o o
                          ooo
                           o
                           o
   ->ooooo                 o
  o       ooooooooooooooooo
   ooooooo
".split("\n") /Map!(" return $ /Map!(\"if (($=='>') || ($=='<')) return 2; if ($=='-') return 3; if ($=='o') return 1; return 0\")"));*/
  /*auto wf=cast(char[])std.file.read("primes.wi");
  //auto wf=cast(char[])std.file.read("test.wi");
  screen(640, 960);
  auto g=new Wireworld(1, 0, wf.split("\n") /map/ (string s) {
    return s /map/ (char c) {
      if (c=='~') return 3; else
      if (c=='@') return 2; else
      if (c=='#') return 1; else
      return 0;
    };
  });*/
  //auto g=new Byl(1, 0, true, [[0, 2, 2], [2, 3, 1, 2], [2, 3, 4, 2], [0, 2, 5]]);
  //auto g=new Test(4, 1, true, [[1]]);
  //auto g=new Life(5, 0, true, [0], [2], [[1, 1], [1, 1]]);
  real sum=0; long secs, isum;
  alias std.c.linux.linux.time time;
  auto now=time(null); long ips;
  bool fastmode=false, step=false, returnPressed=false;
  int stepsize=1;
  int delay=1;
  bool mouseBtn[5];
  
  void changeStepsize(int n) { auto on=stepsize; stepsize=n; writefln("Stepsize: ", on, " -> ", n); }
  void changeDelay(int n) { auto on=delay; delay=n; writefln("Delay: ", on, " -> ", n); }
  void handleEvents() {
    events((ushort key, bool pressed) {
      if (!pressed) return;
      switch (key) {
        case 13: step=true; fastmode=false; break;
        case ' ': fastmode=!fastmode; break;
        case 93, 270: /*fastmode=true;*/ if (delay>1) changeDelay(delay/2); else changeStepsize(stepsize*2); break;
        case 47, 269: /*fastmode=true;*/ if (stepsize>1) changeStepsize(stepsize/2); else changeDelay(delay*2); break;
        default: break;
      }
    }, (int x, int y, ubyte button, int pressed) {
      if (pressed==1) mouseBtn[button-1]=true;
      if (pressed==-1) mouseBtn[button-1]=false;
      if (mouseBtn[0]) {
        x/=g.boxsize; y/=g.boxsize;
        logln("State: ", g.state[x, y]);
      }
    });
  }
  ulong cps, iterations; bool worked;
  while (true) {
    if(now != time(null)) {
      sum += cps;
      if (worked) { worked = false; secs ++; }
      isum += ips;
      writefln(fc(cps, "ps"), ", avg ", fc(sum/secs, "ps"), "; ", iterations, " iterations done, ", ips, " iterations per second, ", 1f*isum / secs, " average");
      now=time(null); ips=cps=0;
    }
    if (!(iterations&(stepsize-1))) {
      g.render;
      flip;
      handleEvents;
    }
    if (fastmode || step) {
      ++ips; ++iterations;
      worked = true;
      g.step;
      cps ++;
      step=false;
    }
    handleEvents;
  }
}
