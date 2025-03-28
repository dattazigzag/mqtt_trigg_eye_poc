class Pixel {
  int x, y, w, h;
  Pixel (int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void display(color c, boolean debug, int id) {
    noStroke();
    if (debug) {
      strokeWeight(0.5);
      stroke(0);
    }
    fill(c);
    pushMatrix();
    translate(x, y);
    rect(0, 0, w, h);
    if (debug) {
      fill(255);
      text(id, w/2-5, h/2+5);
    }
    popMatrix();
  }

  int[] getPosition() {
    int[] position = {x, y};
    return (position);
  }

  int[] getSize() {
    int[] size = {w, h};
    return (size);
  }
  
  void setColor(color c){
    fill(c);
  }
}
