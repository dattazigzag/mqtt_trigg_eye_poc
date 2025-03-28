/**
 * Pixel class represents a single cell in the eye grid.
 * It handles its own rendering and state management.
 */
class Pixel {
  private int x, y;           // Position of the pixel
  private int width, height;  // Dimensions of the pixel

  /**
   * Constructor to create a new pixel
   *
   * @param x      X-coordinate position
   * @param y      Y-coordinate position
   * @param width  Width of the pixel
   * @param height Height of the pixel
   */
  Pixel(int x, int y, int width, int height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  /**
   * Display the pixel with the specified color
   *
   * @param pixelColor Color to fill the pixel with
   * @param debug      Whether to show debug information
   * @param id         Pixel ID to display in debug mode
   * ** NOTE: Unused but keeping it here for reference 
   */
  void display(color pixelColor, boolean debug, int id) {
    noStroke();
    if (debug) {
      strokeWeight(0.5);
      stroke(0);
    }

    fill(pixelColor);
    rect(x, y, width, height);
    // Draw the ID in debug mode
    if (debug) {
      fill(255);
      textAlign(CENTER, CENTER);
      //text(id, x + 10, y + 10);
      text(id, x + width/2, y + height/2);
    }
  }

  /**
   * Display the pixel on a PGraphics object
   *
   * @param pg         The PGraphics object to draw on
   * @param pixelColor Color to fill the pixel with
   * @param debug      Whether to show debug information
   * @param id         Pixel ID to display in debug mode
   */
  void displayOnPGraphics(PGraphics pg, color pixelColor, boolean debug, int id) {
    pg.noStroke();
    if (debug) {
      pg.strokeWeight(0.5);
      pg.stroke(0);
    }
    pg.fill(pixelColor);
    pg.rect(x, y, width, height);

    // Draw the ID in debug mode
    if (debug) {
      pg.fill(255);
      pg.textAlign(CENTER, CENTER);
      pg.text(id, x + width/2, y + height/2);
    }
  }

  /**
   * Get the pixel's position
   *
   * @return Array containing [x, y] coordinates
   */
  int[] getPosition() {
    return new int[]{x, y};
  }

  /**
   * Get the pixel's dimensions
   *
   * @return Array containing [width, height] values
   */
  int[] getSize() {
    return new int[]{width, height};
  }

  /**
   * Set the pixel's color (used for immediate rendering)
   *
   * @param pixelColor The color to set
   */
  void setColor(color pixelColor) {
    fill(pixelColor);
  }
}
