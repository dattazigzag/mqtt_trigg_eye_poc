/**
 * UserInterface class manages the application's UI components and console.
 */
class UserInterface {
  // References and positioning
  //private PApplet parent;
  private int x, y, width, height;
  private ControlP5 cp5;
  Textarea console;

  // UI Colors
  private final color BG_COLOR = color(25);
  private final color TEXT_COLOR = color(220);
  private final color INSTRUCTION_COLOR = color(125);
  //private final color DISABLED_COLOR = color(15);
  //private final color DIMMED_TEXT_COLOR = color(120);

  // Layout constants
  private final int PADDING = 12;
  //private final int ELEMENT_HEIGHT = 20;
  //private final int BUTTON_WIDTH = 80;
  private final int ROW_HEIGHT = 38;

  /**
   * Constructor for the UserInterface
   *
   * @param parent   Parent PApplet reference
   * @param x        X-coordinate position
   * @param y        Y-coordinate position
   * @param width    Width of the UI area
   * @param height   Height of the UI area
   */
  UserInterface(PApplet parent, int x, int y, int width, int height) {
    //this.parent = parent;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;

    // Initialize ControlP5
    cp5 = new ControlP5(parent);

    // Setup controls
    setupControls();
  }

  /**
   * Render the UI elements
   */
  void render() {
    // Draw the background for the UI area
    fill(BG_COLOR);
    rect(x, y, width, height);

    // Draw divider line before settings
    stroke(TEXT_COLOR, 100); // Semi-transparent color
    strokeWeight(0.25);
    line(x, y + PADDING + ROW_HEIGHT*2, x + width, y + PADDING + ROW_HEIGHT*2);
    noStroke();

    // Display MQTT information
    renderMqttStatus();

    // Display control instructions
    renderControlInstructions();
  }

  /**
   * Render MQTT status information
   */
  private void renderMqttStatus() {
    // MQTT connection details
    fill(TEXT_COLOR);
    String brokerDetails = "MQTT BROKER: " + "mqtt://" + BROKER_IP + ":" + BROKER_PORT;
    text(brokerDetails, 12, CANVAS_HEIGHT + 20);

    String clientStateLabel = "MQTT STATE: ";
    text(clientStateLabel, 12, CANVAS_HEIGHT + 38);

    // Display MQTT connection status with appropriate color
    if (!mqttState) {
      fill(255, 135, 76); // Orange/red for disconnected
      text("DISCONNECTED", 12 + 80, CANVAS_HEIGHT + 38);
    } else {
      fill(76, 135, 255); // Blue for connected
      text("CONNECTED", 12 + 80, CANVAS_HEIGHT + 38);
    }

    fill(TEXT_COLOR);
    String syphonStateLabel = "SYPHON STATE: ";
    text(syphonStateLabel, 12 + 220, CANVAS_HEIGHT + 38);

    // Display SYPHON status with appropriate color
    if (!enableSyphon) {
      fill(255, 135, 76); // Orange/red for disconnected
      text("NOT RUNNING", 12 + 220 + 100, CANVAS_HEIGHT + 38);
    } else {
      fill(76, 135, 255); // Blue for connected
      text("SHARING", PADDING + 220 + 100, CANVAS_HEIGHT + 38);

      noStroke();
      fill(100, 50);
      rect(0, CANVAS_HEIGHT-PADDING*2, width, CANVAS_HEIGHT-PADDING*2);
      fill(76, 135, 255); // Blue for connected
      String leftSyhonServerLabel = "LEFT SYPHON SERVER: " + "\"" +leftSyphonServer + "\"";
      String rightSyhonServerLabel = "RIGHT SYPHON SERVER: " + "\""  + rightSyphonServer + "\"";
      text(leftSyhonServerLabel, PADDING, CANVAS_HEIGHT-PADDING/2);
      text(rightSyhonServerLabel, SINGLE_CANVAS_WIDTH + PADDING, CANVAS_HEIGHT-PADDING/2);
    }

    // Dividers
    stroke(100);
    strokeWeight(0.5);
    line(0, CANVAS_HEIGHT + 38 + 10, SKETCH_WIDTH, CANVAS_HEIGHT + 38 + 10);
    line(0, CANVAS_HEIGHT + 38 + 80, SKETCH_WIDTH, CANVAS_HEIGHT + 38 + 80);
  }

  /**
   * Render control instructions
   */
  private void renderControlInstructions() {
    fill(INSTRUCTION_COLOR);
    text("PRESS 'd'/'D' to enable/disable DEBUG VIEW", 12, CANVAS_HEIGHT + 38 + 25);
    text("PRESS 'm'/'M' to mirror/sync PUPILS", 12, CANVAS_HEIGHT + 38 + 25 + 15);
    text("PRESS 's'/'S' to enable/disable Syphon", 12, CANVAS_HEIGHT + 38 + 25 + 15*2);
    text("PRESS '1'/'2'/'3'/'4' to make PUPILS go to extreme corners", 12, CANVAS_HEIGHT + 38 + 25 + 15*3);
  }

  /**
   * Set up the UI controls
   */
  private void setupControls() {
    // Control styles
    cp5.setColorForeground(color(50));
    cp5.setColorBackground(color(50));
    cp5.setColorActive(color(57, 184, 213));

    // Create and configure console
    setupConsole();
  }

  /**
   * Set up the console area
   */
  private void setupConsole() {
    // Create console in the highlighted area
    int consoleX = PADDING;
    int consoleY = y + PADDING + ROW_HEIGHT*2 + 35;
    int consoleWidth = width - PADDING*2;
    int consoleHeight = 100;

    // Create a textarea to serve as console
    console = cp5.addTextarea("console")
      .setPosition(consoleX, consoleY)
      .setSize(consoleWidth, consoleHeight)
      .setLineHeight(14)
      .setColor(color(200))  // Text color
      .setColorForeground(color(255, 100))  // Scroll bar color
      .scroll(1.0)                    // Enable scrolling
      .showScrollbar();               // Show scrollbar

    // Remove caption text
    console.getCaptionLabel().setText("");

    // Set console as global reference
    appConsole = console;

    // Welcome message
    console.clear();
    printToConsole("MQTT EYE ANIM APPLET POC");
    printToConsole("-------------------------------");
  }

  /**
   * Print a message to the console
   *
   * @param message The message to print
   */
  void printToConsole(String message) {
    String formattedMessage = message + "\n";
    console.append(formattedMessage);

    // Scroll to bottom to ensure newest messages are visible
    console.scroll(1.0);

    // Auto-clear if buffer exceeds limit
    if (countLines(console.getText()) > CONSOLE_BUFFER_LIMIT) {
      console.clear();
      console.append("Console buffer limit reached. Cleared.\n");
    }
  }

  /**
   * Count the number of lines in a text string
   *
   * @param text Text to count lines in
   * @return Number of lines
   */
  private int countLines(String text) {
    if (text == null || text.isEmpty()) return 0;
    return text.split("\n").length;
  }
}
