// User Interface class to manage all controls
class UserInterface {
  PApplet parent;
  int x, y, width, height;
  ControlP5 cp5;
  Textarea console;

  // Colors
  color bgColor = color(25);
  color textColor = color(220);
  color disabledColor = color(15);
  color dimmedTextColor = color(120); // Dimmed text color for disabled fields

  // Control dimensions
  int padding = 12;
  int elementHeight = 20;
  int buttonWidth = 80;
  int rowHeight = 38;


  UserInterface(PApplet parent, int x, int y, int width, int height) {
    this.parent = parent;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;

    // Initialize ControlP5
    cp5 = new ControlP5(parent);

    // Setup controls
    setupControls();
  }

  void render() {
    // Draw the background for the UI area
    fill(bgColor);
    rect(x, y, width, height);

    // Draw divider line before settings
    stroke(textColor, 100); // Semi-transparent color
    strokeWeight(0.25);
    line(x, y + padding + rowHeight*2, x + width, y + padding + rowHeight*2);
    noStroke();


    // MQTT details
    fill(ui.textColor);
    String broker_details = "MQTT BROKER: " + "mqtt://" + BROKER_IP + ":" + BROKER_PORT;
    text(broker_details, 12, CANVAS_HEIGHT + 20);
    String client_stst_label = "MQTT STATE: ";
    text(client_stst_label, 12, CANVAS_HEIGHT + 38);

    String stat = "";
    if (!mqttState) {
      fill(255, 135, 76);
      stat = "DISCONNECTED";
    } else {
      fill(76, 135, 255);
      stat = "CONNECTED";
    }
    text(stat, 12 + 80, CANVAS_HEIGHT + 38);
    // dividers
    stroke(100);
    strokeWeight(0.5);
    line(0, CANVAS_HEIGHT + 38 + 10, SKETCH_WIDTH, CANVAS_HEIGHT + 38 + 10);
    line(0, CANVAS_HEIGHT + 38 + 80, SKETCH_WIDTH, CANVAS_HEIGHT + 38 + 80);
    
    // control instructions
    fill(ui.textColor);
    text("PRESS 'd'/'D' to enable/disable DEBUG VIEW", 12, CANVAS_HEIGHT + 38 + 25);
    text("PRESS 'm'/'M' to mirror/sync PUPILS", 12, CANVAS_HEIGHT + 38 + 25 + 15);
    text("PRESS '1'/'2'/'3'/'4' to make PUPILS go to extreme corners", 12, CANVAS_HEIGHT + 38 + 25 + 15 + 15);
  }

  void setupControls() {
    // Control styles
    cp5.setColorForeground(color(50));
    cp5.setColorBackground(color(50));
    cp5.setColorActive(color(57, 184, 213));

    // Create and configure console
    setupConsole();
  }

  void setupConsole() {
    // Create console in the highlighted area
    int consoleX = padding;  // Right side of UI
    int consoleY = y + padding + rowHeight*2 + 35;  // Below ARTNET DMX SETTINGS label
    int consoleWidth = width - padding*2;
    int consoleHeight = 100;  // Adjust as needed to fit the area

    // Create a textarea to serve as console
    console = cp5.addTextarea("console")
      .setPosition(consoleX, consoleY)
      .setSize(consoleWidth, consoleHeight)
      //.setFont(createFont("", 10))
      .setLineHeight(14)
      .setColor(color(200))  // Text color
      //.setColorBackground(color(150, 50))    // Same as UI background
      .setColorForeground(color(255, 100))  // Scroll bar color - semi-transparent magenta
      .scroll(1.0)                    // Enable scrolling
      .showScrollbar();               // Show scrollbar

    // Add a thin magenta border - ControlP5 Textarea doesn't support borders directly,
    // but we can use styling to make it look like it has one
    console.getCaptionLabel().setText("");  // No caption text

    // Set console as global reference
    appConsole = console;

    // Welcome message
    console.clear();
    printToConsole("MQTT EYE ANIM APPLET POC");
    printToConsole("-------------------------------");
  }

  void printToConsole(String message) {
    String formattedMessage = message + "\n";
    console.append(formattedMessage);
    // Scroll to bottom - this ensures newest messages are visible
    console.scroll(1.0);
    // Auto-clear if buffer exceeds limit
    if (countLines(console.getText()) > CONSOLE_BUFFER_LIMIT) {
      console.clear();
      //console.append("[" + timestamp + "] Console buffer limit reached. Cleared.\n");
      console.append("Console buffer limit reached. Cleared.\n");
    }
  }

  int countLines(String text) {
    if (text == null || text.isEmpty()) return 0;
    return text.split("\n").length;
  }
}
