module living_space;

// von Neumann == TLRB, Moore == 12346789, Serial=Left, Right, Wraparound +1/-1
typedef ubyte SpaceType;
const SpaceType Neumann=0, Moore=1;

void dumpESP() { void* res = void; asm { mov res, ESP; } writefln(res); }

import tools.mersenne, tools.array2d, tools.threads, qd, std.stdio, tools.base;
class Space(SpaceType H, string EVAL="") {
  int boxsize, border;
  bool wrap;
  Array2D!(ubyte) state, state2;
  Array2D!(bool) changed, changed2;
  const ubyte xsize=2, xshift=1, ysize=2, yshift=1;
  rgb[] cols;
  void stamp(int[][] what, int xpos=0, int ypos=0) {
    auto h=what.length;
    auto w=0; foreach (wh; what) if (wh.length>w) w=wh.length;
    
    if (h>state.height) throw new Exception("Pattern too high to stamp: "~.toString(h)~"!");
    if (w>state.width) throw new Exception("Pattern too wide to stamp: "~.toString(w)~"!");
    foreach (iy, row; what) {
      foreach (ix, cell; row) {
        auto x=ix+(state.width-w)/2+(w+4)*xpos, y=iy+(state.height-h)/2+(h+4)*ypos;
        switch (cell) {
          case -1: break;
          case -2: state[x, y]=[cast(ubyte) 1, 4, 7][rand()%3]; break;
          default: state[x, y]=cast(ubyte) cell;
        }
      }
    }
  }
  this(int b, int o, bool w, int[][] init) {
    boxsize=b; border=o; wrap=w;
    state = typeof(state) (screen.width/boxsize, screen.height/boxsize);
    
    changed = Array2D!(bool)(state.width>>xshift, state.height>>yshift);
    changed2 = changed.dup;
    
    assert((state.width%xsize)==0, "Width must be multiple of changesize!");
    assert((state.height%ysize)==0, "Height must be multiple of changesize!");
    
    changed = true;
    
    if (init) stamp(init);
    state2 = state.dup;
    //      0      1    2      3        4       5            6        7        8           9          10
    cols=[Black, Blue, Red, Red~Blue, Green, Red~White, Green~Blue, White, Red~Black, Yellow, Blue~Black];
  }
  void render() {
    auto active_cols = new rgb[cols.length], inactive_cols = active_cols.dup;
    foreach (i, col; cols) { active_cols[i] = col~Green~col~col; inactive_cols[i] = col~Red~col~col; }
    foreach (x, y, value; state) {
      typeof(cols[0]) c;
      if (changed[x>>xshift, y>>yshift])
        c=active_cols[value];
      else
        c=inactive_cols[value];
      if (boxsize==1) {
        pset(x, y, c);
      } else {
        line(x*boxsize, y*boxsize, (x+1)*boxsize-border, (y+1)*boxsize-border, Fill=c);
        if (border) line(x*boxsize-1, y*boxsize-1, (x+1)*boxsize-1, (y+1)*boxsize-1, Box=White~Black~Black~Black~Black);
      }
    }
  }
  static if (EVAL.length) mixin(EVAL);
  else {
    static if (H==Neumann) abstract ubyte eval(ubyte me, ubyte up, ubyte right, ubyte down, ubyte left);
    static if (H==Moore) abstract ubyte eval(ubyte, ubyte, ubyte, ubyte, ubyte, ubyte, ubyte, ubyte, ubyte);
  }
  uint calcLine(int y) {
    uint res;
    auto width = state.width;
    const size_t ymask=ysize-1;
    auto yd=y>>yshift, ym=y&ymask;
    
    auto
      changed_cur=changed2.h_iter(yd),
      changed_above=changed2.h_iter(yd-1),
      changed_below=changed2.h_iter(yd+1),
      changed_is=changed.h_iter(yd);
    
    auto resline = state2.h_iter(y);
    auto myline = state.h_iter(y), above = state.h_iter(y-1), below = state.h_iter(y+1);
    
    static if (H==Moore) ubyte a=void, b=void, c=void, d=void, e=void, f=void, g=void, h=void, i=void;
    else ubyte prev=void, cur=void, next=void;
    
    size_t x=0;
    void reset() {
      resline.pos=x; myline.pos=x; above.pos=x; below.pos=x;
      static if (H==Moore) {
        a=above.prev;  b=above();  c=above.next;
        d=myline.prev; e=myline(); f=myline.next;
        g=below.prev;  h=below();  i=below.next;
      } else { prev=myline.prev(); cur=myline(); next=myline.next(); }
    }
    void changed() {
      auto xs = x >> xshift;
      changed_above.pos  = changed_cur.pos = changed_below.pos = xs;
      auto xm = x & (xsize-1);
      void x_changed(typeof(changed_cur) ch) {
        if (!xm) ch.prev = true;
        ch = true;
        if (xm == xsize-1) ch.next = true;
      }
      if (!ym) x_changed(changed_above);
      x_changed(changed_cur);
      if (ym == ysize-1) x_changed(changed_below);
    }
    bool skipped=true;
    while (x<width) {
      changed_is.pos=x >> xshift;
      if (!changed_is() && !changed_is.done) {
        skipped = true;
        do changed_is ++;
        while (!changed_is() && !changed_is.done);
      }
      if (changed_is.done && !changed_is()) break;
      if (skipped) { x = changed_is.pos << xshift; reset(); skipped=false; }
      else {
        static if (H != Moore) { prev=cur; cur=next; next=myline.next(); }
      }
      static if (H==Moore) {
        if (x && x < width-3) {
          myline += 3; above += 3; below += 3; res += 3;
          // we know that x is nowhere near the border .. use nowrap versions
          if ((resline=eval(a, b, c, d, e, f, g, h, i))!=e) changed();
          a = above.prev_nowrap; d = myline.prev_nowrap; g = below.prev_nowrap; resline ++; x ++;
          if ((resline=eval(b, c, a, e, f, d, h, i, g))!=f) changed();
          b = above(); e = myline(); h = below(); resline ++; x ++;
          if ((resline=eval(c, a, b, f, d, e, i, g, h))!=d) changed();
          c = above.next_nowrap; f = myline.next_nowrap; i = below.next_nowrap; resline ++; x ++;
        } else {
          if ((resline=eval(a, b, c, d, e, f, g, h, i))!=e) changed();
          if (x<width-1) {
            resline++; myline++; above++; below++;
            a = b; b = c; c = above.next();
            d = e; e = f; f = myline.next();
            g = h; h = i; i = below.next();
          }
          x++; res++;
        }
      } else {
        auto ncur=eval(cur, myline.aboveValue, next, myline.belowValue, prev);
        resline=ncur;
        if (ncur!=cur) changed();
        resline++;
        myline++;
        res++;
        x++;
      }
    }
    return res;
  }
  void step() {
    auto height = state.height;
    changed2 = false;
    for (int y = 0; y < height; y++) {
      calcLine(y);
    }
    swap(changed, changed2);
    swap(state, state2);
  }
}
