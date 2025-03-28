import de.looksgood.ani.*;
import mqtt.*;
import processing.data.JSONObject;
import controlP5.*;

// ===================== CONFIGURATION CONSTANTS =====================
// Canvas and sizing constants
final int SKETCH_WIDTH = 640;
final int SKETCH_HEIGHT = 550;
final int CANVAS_WIDTH = 640;
final int CANVAS_HEIGHT = 320;
final int RESERVED_HEIGHT = 230;
final int SINGLE_CANVAS_WIDTH = 320;
final int ROWS_OF_PIXELS = 8;
final int COLS_OF_PIXELS = 8;


// MQTT configuration
final String BROKER_IP = "127.0.0.1";
final String BROKER_PORT = "1883";
final String CLIENT_ID = "Processing_MQTT_EYE_Client";
final int CONNECTION_RETRY_INTERVAL = 2000; // Try every 2 seconds

// Console configuration
final int CONSOLE_BUFFER_LIMIT = 100;

// ===================== COLOR DEFINITIONS =====================
final color NORMAL_PIXEL_COLOR = color(255, 255, 255);
final color ACTIVE_PIXEL_COLOR = color(0);
final color BLACKOUT_PIXEL_COLOR = color(0);
final color BOUNDARY_PIXEL_COLOR = color(255, 135, 78);
final color DEBUG_COLOR_TYPE1 = color(255, 204, 0);
final color DEBUG_COLOR_TYPE2 = color(255, 54, 255);

// ===================== PIXEL CONFIGURATION =====================
// Pixels that are always black (corners, etc.)
final int[] BACKOUT_PIXEL_IDS = {0, 1, 6, 7, 8, 15, 48, 55, 56, 57, 62, 63};
IntList backoutSet = new IntList();

// Boundary pixels for visual formatting
final int[] BOUNDARY_PIXEL_IDS = {2, 3, 4, 5, 9, 14, 16, 23, 24, 31, 32, 39, 40, 47, 49, 54, 58, 59, 60, 61};
IntList boundarySet = new IntList();

// ===================== STATE VARIABLES =====================
// Eye pixel arrays
ArrayList<Pixel> leftCanvasPixels = new ArrayList<Pixel>();
ArrayList<Pixel> rightCanvasPixels = new ArrayList<Pixel>();

// Tracking active pixels
int leftCurrentId = 0;
int leftLastId = 0;
int rightCurrentId = 0;
int rightLastId = 0;
boolean leftHit = false;
boolean rightHit = false;

// Mode settings
boolean enableP3D = true;
boolean debug = false;
int frameRate = 20;
boolean syncSameDirection = true;   // Sync movement in left and right, in same dir
boolean syncMirroredDirection = false; // Sync movement in left and right, but in opp dir

// Animation variables
float cellXCurrent;
float cellYCurrent;
boolean isAnimating = false;

// MQTT state
MQTTClient mqttClient;
boolean mqttConnected = false; // for business logic: for launch checking of broker
boolean mqttState = true;      // for UI display of connection state
int lastConnectionAttempt = 0;

// UI reference
UserInterface ui;
Textarea appConsole;

void settings() {
  if (!enableP3D) {
    size(SKETCH_WIDTH, SKETCH_HEIGHT);  // Default renderer
    println("[setting]\tUsing default renderer");
  } else {
    size(SKETCH_WIDTH, SKETCH_HEIGHT, P3D);  // P3D renderer
    println("[setting]\tUsing P3D renderer");
  }
  smooth();
}


void setup() {
  background(0);
  frameRate(frameRate);

  // Apply P3D optimizations if enabled
  if (enableP3D) {
    println("[setup]\tUsing P3D hint optimizations");
    hint(DISABLE_DEPTH_TEST);
    hint(DISABLE_TEXTURE_MIPMAPS);
  } else {
    println("[setup]\tNot using P3D optimizations");
  }

  // The below always makes the window stay on top of other windows
  surface.setAlwaysOnTop(true);

  // Initialize UI
  ui = new UserInterface(this, 0, CANVAS_HEIGHT, SKETCH_WIDTH, RESERVED_HEIGHT);

  // Initialize pixel grids
  initializePixelGrids();

  // Initialize special pixel sets
  initializeSpecialPixelSets();

  // Initialize animation
  initializeAnimation();

  // Initialize MQTT client
  initializeMqtt();
}


// Initialize both eye pixel grids
void initializePixelGrids() {
  int pixelWidth = SINGLE_CANVAS_WIDTH / COLS_OF_PIXELS;
  int pixelHeight = CANVAS_HEIGHT / ROWS_OF_PIXELS;

  // Create left canvas pixels
  for (int y = 0; y < CANVAS_HEIGHT; y += pixelHeight) {
    for (int x = 0; x < SINGLE_CANVAS_WIDTH; x += pixelWidth) {
      leftCanvasPixels.add(new Pixel(x, y, pixelWidth, pixelHeight));
    }
  }

  // Create right canvas pixels
  for (int y = 0; y < CANVAS_HEIGHT; y += pixelHeight) {
    for (int x = SINGLE_CANVAS_WIDTH; x < CANVAS_WIDTH; x += pixelWidth) {
      rightCanvasPixels.add(new Pixel(x, y, pixelWidth, pixelHeight));
    }
  }
}


// Initialize blackout and boundary pixel sets
void initializeSpecialPixelSets() {
  // Initialize blackout set (pixels that are always black)
  for (int pixelId : BACKOUT_PIXEL_IDS) {
    backoutSet.append(pixelId);
  }

  // Initialize boundary set (pixels that define the eye shape)
  for (int pixelId : BOUNDARY_PIXEL_IDS) {
    boundarySet.append(pixelId);
  }
}


// Initialize animation settings
void initializeAnimation() {
  Ani.init(this);
  Ani.setDefaultTimeMode(Ani.FRAMES);

  // Set initial cell position
  cellXCurrent = leftCurrentId % COLS_OF_PIXELS;
  cellYCurrent = leftCurrentId / COLS_OF_PIXELS;
}


// Initialize MQTT client
void initializeMqtt() {
  mqttClient = new MQTTClient(this);
  connectMQTT();
}




void draw() {
  background(0);

  // Check MQTT reconnection if needed
  // Simple MQTT reconnection check - exactly as in the original
  if (!mqttConnected && millis() - lastConnectionAttempt > CONNECTION_RETRY_INTERVAL) {
    connectMQTT();
  }

  if (enableP3D) {
    // Set appropriate rendering state for 2D content
    hint(DISABLE_DEPTH_TEST);
  }

  // Draw all pixels for both canvases
  renderAllPixels();

  // Handle active pixel display based on which canvas is active
  if (leftHit && !rightHit) {
    handlePixelActivation(leftCurrentId, true);
  } else if (rightHit && !leftHit) {
    handlePixelActivation(rightCurrentId, false);
  }

  // Draw separator line between left and right canvases
  stroke(100);
  strokeWeight(0.5);
  line(SINGLE_CANVAS_WIDTH, 0, SINGLE_CANVAS_WIDTH, CANVAS_HEIGHT);

  // Render UI
  ui.render();
}


// Render all base pixels for both eyes
void renderAllPixels() {
  // Render left canvas pixels
  color leftColor = debug ? DEBUG_COLOR_TYPE1 : NORMAL_PIXEL_COLOR;
  for (int i = 0; i < leftCanvasPixels.size(); i++) {
    leftCanvasPixels.get(i).display(leftColor, debug, i);

    // Apply special colors for boundary and blackout pixels
    if (debug && boundarySet.hasValue(i)) {
      leftCanvasPixels.get(i).display(BOUNDARY_PIXEL_COLOR, debug, i);
    }
    if (backoutSet.hasValue(i)) {
      leftCanvasPixels.get(i).display(BLACKOUT_PIXEL_COLOR, debug, i);
    }
  }

  // Render right canvas pixels
  color rightColor = debug ? DEBUG_COLOR_TYPE2 : NORMAL_PIXEL_COLOR;
  for (int i = 0; i < rightCanvasPixels.size(); i++) {
    rightCanvasPixels.get(i).display(rightColor, debug, i);

    // Apply special colors for boundary and blackout pixels
    if (debug && boundarySet.hasValue(i)) {
      rightCanvasPixels.get(i).display(BOUNDARY_PIXEL_COLOR, debug, i);
    }
    if (backoutSet.hasValue(i)) {
      rightCanvasPixels.get(i).display(BLACKOUT_PIXEL_COLOR, debug, i);
    }
  }
}



void keyPressed() {
  switch(key) {
  case 'd':
  case 'D':
    debug = !debug;
    log("DEBUG MODE: " + (debug ? "Enabled" : "Disabled"));
    break;

  case 's':
  case 'S':
    syncSameDirection = !syncSameDirection;
    syncMirroredDirection = !syncSameDirection;
    log("EYE SYNC (Same Direction): " + (syncSameDirection ? "Enabled" : "Disabled"));
    break;

  case 'm':
  case 'M':
    syncMirroredDirection = !syncMirroredDirection;
    syncSameDirection = !syncMirroredDirection;
    log("EYE SYNC (Mirrored): " + (syncMirroredDirection ? "Enabled" : "Disabled"));
    break;

  case '1':
    int targetCell1 = (random(1) > 0.5) ? 10 : 17;
    log("Animating to top-left position (cell " + targetCell1 + ")");
    animateToCell(targetCell1);
    break;

  case '2':
    int targetCell2 = (random(1) > 0.5) ? 13 : 22;
    log("Animating to top-right position (cell " + targetCell2 + ")");
    animateToCell(targetCell2);
    break;

  case '3':
    int targetCell3 = (random(1) > 0.5) ? 53 : 46;
    log("Animating to bottom-right position (cell " + targetCell3 + ")");
    animateToCell(targetCell3);
    break;

  case '4':
    int targetCell4 = (random(1) > 0.5) ? 50 : 41;
    log("Animating to bottom-left position (cell " + targetCell4 + ")");
    animateToCell(targetCell4);
    break;
  }
}


int left_curr_id = 0;
int left_last_id = 0;
int right_curr_id = 0;
int right_last_id = 0;


void mouseMoved() {
  // First check left canvas pixels
  boolean pixelFound = checkCanvasPixels(leftCanvasPixels, true);

  // If no pixel found in left canvas, check right canvas
  if (!pixelFound) {
    checkCanvasPixels(rightCanvasPixels, false);
  }
}


// Helper function to check if mouse is over pixels in a canvas
boolean checkCanvasPixels(ArrayList<Pixel> canvasPixels, boolean isLeftCanvas) {
  for (int i = 0; i < canvasPixels.size(); i++) {
    Pixel pixel = canvasPixels.get(i);
    int[] position = pixel.getPosition();
    int[] size = pixel.getSize();

    // Check if mouse is over this pixel
    if (mouseX >= position[0] && mouseX <= position[0] + size[0] &&
      mouseY >= position[1] && mouseY <= position[1] + size[1]) {

      // Skip if it's a blackout or boundary pixel
      if (backoutSet.hasValue(i) || boundarySet.hasValue(i)) {
        return true; // We found a pixel, but it's invalid
      }

      // Update state based on which canvas we're in
      if (isLeftCanvas) {
        leftHit = true;
        rightHit = false;

        // Only log if the pixel has changed
        if (leftCurrentId != i) {
          logPixelMovement(i, leftCurrentId, true, syncMirroredDirection);
          leftLastId = leftCurrentId;
          leftCurrentId = i;
        }
      } else {
        rightHit = true;
        leftHit = false;

        // Only log if the pixel has changed
        if (rightCurrentId != i) {
          logPixelMovement(i, rightCurrentId, false, syncMirroredDirection);
          rightLastId = rightCurrentId;
          rightCurrentId = i;
        }
      }

      return true; // Pixel found and processed
    }
  }

  return false; // No pixel found
}


// Helper function for displaying pixels with specific settings
void displayPixel(ArrayList<Pixel> pixelArray, int pixelId, color pixelColor, boolean debugMode) {
  if (pixelId >= 0 && pixelId < pixelArray.size()) {
    pixelArray.get(pixelId).display(pixelColor, debugMode, pixelId);
  }
}


// Helper function calculates the 4 cell IDs that form a 2x2 block around the active cell.
int[] get2x2BlockIds(int activeId) {
  // Check if the active ID is in backout or boundary list
  if (backoutSet.hasValue(activeId) || boundarySet.hasValue(activeId)) {
    return new int[0];
  }

  int[] blockIds = new int[4];

  // Calculate row and column of active cell
  int row = activeId / COLS_OF_PIXELS;
  int col = activeId % COLS_OF_PIXELS;

  // Define four possible positions for the 2x2 block
  int[][] possiblePositions = {
    {row, col}, // Current cell as top-left
    {row, col-1}, // Left cell as top-left
    {row-1, col}, // Above cell as top-left
    {row-1, col-1}    // Diagonal cell as top-left
  };

  int bestPosition = 0;
  int lowestInvalidCells = 4; // Start with worst case scenario

  // Find position with fewest invalid cells (backout OR boundary)
  for (int i = 0; i < possiblePositions.length; i++) {
    int testRow = possiblePositions[i][0];
    int testCol = possiblePositions[i][1];

    // Skip if outside grid boundaries
    if (testRow < 0 || testRow >= ROWS_OF_PIXELS-1 ||
      testCol < 0 || testCol >= COLS_OF_PIXELS-1) {
      continue;
    }

    // Count invalid cells in this configuration
    int invalidCount = 0;
    int[] testIds = new int[4];

    // Calculate the 4 cell IDs for this potential block position
    testIds[0] = testRow * COLS_OF_PIXELS + testCol;               // Top-left
    testIds[1] = testRow * COLS_OF_PIXELS + (testCol + 1);         // Top-right
    testIds[2] = (testRow + 1) * COLS_OF_PIXELS + testCol;         // Bottom-left
    testIds[3] = (testRow + 1) * COLS_OF_PIXELS + (testCol + 1);   // Bottom-right

    // Count how many cells would be invalid in this configuration
    for (int id : testIds) {
      if (backoutSet.hasValue(id) || boundarySet.hasValue(id)) {
        invalidCount++;
      }
    }

    // If this position has fewer invalid cells, choose it
    if (invalidCount < lowestInvalidCells) {
      lowestInvalidCells = invalidCount;
      bestPosition = i;

      // Perfect position with no invalid cells - stop searching
      if (invalidCount == 0) {
        break;
      }
    }
  }

  // Use the best position found
  int topLeftRow = possiblePositions[bestPosition][0];
  int topLeftCol = possiblePositions[bestPosition][1];

  // Calculate the final block IDs
  blockIds[0] = topLeftRow * COLS_OF_PIXELS + topLeftCol;               // Top-left
  blockIds[1] = topLeftRow * COLS_OF_PIXELS + (topLeftCol + 1);         // Top-right
  blockIds[2] = (topLeftRow + 1) * COLS_OF_PIXELS + topLeftCol;         // Bottom-left
  blockIds[3] = (topLeftRow + 1) * COLS_OF_PIXELS + (topLeftCol + 1);   // Bottom-right

  return blockIds;
}


// Helper function to calculate the mirrored pixel ID for a given pixel.
int getMirroredPixelId(int id) {
  // Calculate row and column from ID
  int row = id / COLS_OF_PIXELS;
  int col = id % COLS_OF_PIXELS;

  // Mirror the column position (horizontal mirroring)
  // For example, in an 8-column grid:
  // Col 0 becomes col 7, col 1 becomes col 6, etc.
  int mirroredCol = (COLS_OF_PIXELS - 1) - col;

  // Convert row and mirrored column back to a pixel ID
  return (row * COLS_OF_PIXELS) + mirroredCol;
}


// Helper function to display a 2x2 block of pixels
void display2x2Block(ArrayList<Pixel> pixelArray, int[] blockIds, color pixelColor, boolean debugMode) {
  for (int id : blockIds) {
    if (id >= 0 && id < pixelArray.size() && !backoutSet.hasValue(id)) {
      pixelArray.get(id).display(pixelColor, debugMode, id);
    }
  }
}

// Helper function to handle activation of pixels in different modes
void handlePixelActivation(int activeId, boolean isLeftCanvas) {
  ArrayList<Pixel> primaryCanvas = isLeftCanvas ? leftCanvasPixels : rightCanvasPixels;
  ArrayList<Pixel> secondaryCanvas = isLeftCanvas ? rightCanvasPixels : leftCanvasPixels;

  // Skip if it's a blackout or boundary pixel
  if (backoutSet.hasValue(activeId) || boundarySet.hasValue(activeId)) {
    return;
  }

  int[] blockIds = get2x2BlockIds(activeId);

  // No sync mode - only activate on the primary canvas
  if (!syncSameDirection && !syncMirroredDirection) {
    if (blockIds.length > 0) {
      display2x2Block(primaryCanvas, blockIds, ACTIVE_PIXEL_COLOR, debug);
    } else {
      displayPixel(primaryCanvas, activeId, ACTIVE_PIXEL_COLOR, debug);
    }
  }
  // Sync same mode - activate same pixels on both canvases
  else if (syncSameDirection) {
    if (blockIds.length > 0) {
      display2x2Block(primaryCanvas, blockIds, ACTIVE_PIXEL_COLOR, debug);
      display2x2Block(secondaryCanvas, blockIds, ACTIVE_PIXEL_COLOR, debug);
    } else {
      displayPixel(primaryCanvas, activeId, ACTIVE_PIXEL_COLOR, debug);
      displayPixel(secondaryCanvas, activeId, ACTIVE_PIXEL_COLOR, debug);
    }
  }
  // Mirror mode - activate mirrored pixels on secondary canvas
  else if (syncMirroredDirection) {
    if (blockIds.length > 0) {
      // Primary canvas block
      display2x2Block(primaryCanvas, blockIds, ACTIVE_PIXEL_COLOR, debug);

      // Secondary canvas mirrored block
      for (int id : blockIds) {
        int mirroredId = getMirroredPixelId(id);
        if (mirroredId >= 0 && mirroredId < secondaryCanvas.size() && !backoutSet.hasValue(mirroredId)) {
          secondaryCanvas.get(mirroredId).display(ACTIVE_PIXEL_COLOR, debug, mirroredId);
        }
      }
    } else {
      // Just use single pixels
      displayPixel(primaryCanvas, activeId, ACTIVE_PIXEL_COLOR, debug);
      int mirroredId = getMirroredPixelId(activeId);
      displayPixel(secondaryCanvas, mirroredId, ACTIVE_PIXEL_COLOR, debug);
    }
  }
}

// Helper function to log pixel movements with relevant information
void logPixelMovement(int currentId, int lastId, boolean isLeftCanvas, boolean isMirrored) {
  if (currentId == lastId) {
    return; // Don't log if no change
  }

  if (syncSameDirection) {
    log("[SYNCED] Current " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + currentId);
    log("[SYNCED] Matching " + (isLeftCanvas ? "Right" : "Left") + " Pixel id: " + currentId);
    log("[SYNCED] Last " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + lastId);
    log("[SYNCED] Matching Last " + (isLeftCanvas ? "Right" : "Left") + " Pixel id: " + lastId);
    log("");
  } else if (syncMirroredDirection) {
    int mirroredId = getMirroredPixelId(currentId);
    int mirroredLastId = getMirroredPixelId(lastId);

    log("[MIRROR] Current " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + currentId);
    log("[MIRROR] Mirrored " + (isLeftCanvas ? "Right" : "Left") + " Pixel id: " + mirroredId);
    log("[MIRROR] Last " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + lastId);
    log("[MIRROR] Mirrored Last " + (isLeftCanvas ? "Right" : "Left") + " Pixel id: " + mirroredLastId);
    log("");
  } else {
    log("Current " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + currentId);
    log("Last " + (isLeftCanvas ? "Left" : "Right") + " Pixel id: " + lastId);
    log("");
  }
}


// Enhanced animation function with validation
void animateToCell(int targetCellId) {
  // Skip invalid cells
  if (backoutSet.hasValue(targetCellId) || boundarySet.hasValue(targetCellId)) {
    log("Cannot animate to cell " + targetCellId + " (blackout or boundary cell)");
    return;
  }

  // Calculate target position
  float targetRow = targetCellId / COLS_OF_PIXELS;
  float targetCol = targetCellId % COLS_OF_PIXELS;

  // Set current position
  cellXCurrent = leftCurrentId % COLS_OF_PIXELS;
  cellYCurrent = leftCurrentId / COLS_OF_PIXELS;

  // Start animation
  isAnimating = true;
  log("Animating from (" + cellXCurrent + "," + cellYCurrent + ") to (" +
    targetCol + "," + targetRow + ") - Cell ID: " + targetCellId);

  Ani.to(this, 20.0f, "cellXCurrent", targetCol, Ani.BACK_OUT, "onUpdate:updateCell");
  Ani.to(this, 20.0f, "cellYCurrent", targetRow, Ani.BACK_OUT, "onEnd:animationComplete");
}

// Animation callback for cell updates
void updateCell() {
  // Convert floating point position to cell index
  int row = constrain(int(cellYCurrent), 0, ROWS_OF_PIXELS - 1);
  int col = constrain(int(cellXCurrent), 0, COLS_OF_PIXELS - 1);
  int cellId = row * COLS_OF_PIXELS + col;

  // Only update if it's a valid cell
  if (!backoutSet.hasValue(cellId) && !boundarySet.hasValue(cellId)) {
    leftCurrentId = cellId;
    leftLastId = cellId;
    leftHit = true;
    rightHit = false;
  }
}

// Animation completion callback
void animationComplete() {
  isAnimating = false;
  log("Animation completed");
}


// Improved MQTT connection function with better error handling
void connectMQTT() {
  lastConnectionAttempt = millis();

  try {
    log("Attempting to connect to MQTT broker...");
    mqttClient.connect("mqtt://" + BROKER_IP + ":" + BROKER_PORT, CLIENT_ID);

    mqttConnected = true;
    mqttState = true;
  }
  catch (Exception e) {
    mqttConnected = false;
    mqttState = false;
    log("Failed to connect to MQTT broker: " + e.getMessage());
    log("Will retry in " + (CONNECTION_RETRY_INTERVAL/1000) + " seconds");
  }
}

// Called when MQTT client successfully connects
void clientConnected() {
  mqttState = true;
  log("MQTT client connected");
  log("Subscribing to messages ...");
  log("\tmicrophones/left");
  log("\tmicrophones/right");
  log("\tmicrophones/status");
  mqttClient.subscribe("microphones/left");
  mqttClient.subscribe("microphones/right");
  mqttClient.subscribe("microphones/status");
}


// Process incoming MQTT messages
void messageReceived(String topic, byte[] payload) {
  log("New MQTT message: " + topic + " - " + new String(payload));

  // Check if it's one of the microphone topics
  if (topic.equals("microphones/left") || topic.equals("microphones/right")) {
    try {
      // Convert payload to string and parse JSON
      String jsonString = new String(payload);
      JSONObject json = parseJSONObject(jsonString);

      // Extract the state value
      int state = json.getInt("state");

      // Now you can take action based on topic and state
      if (state == 1) {  // Active state
        if (topic.equals("microphones/left")) {
          // Left microphone is active
          log("Left microphone active!");
          // animate eye pupil to bottom left
          int targetCell = (random(1) > 0.5) ? 50 : 41;
          animateToCell(targetCell);
        } else {  // microphones/right
          // Right microphone is active
          log("Right microphone active!");
          // animate eye pupil to bottom right
          int targetCell = (random(1) > 0.5) ? 53 : 46;
          animateToCell(targetCell);
        }
      }
    }
    catch (Exception e) {
      log("Error parsing JSON: " + e.getMessage());
    }
  }
}

// MQTT connection lost handler
void connectionLost() {
  mqttState = false;
  log("MQTT connection lost");
}


//---------------------------- //
// Helper method to print to console with proper logging
void log(String message) {
  println(message);  // Still print to Processing console

  // Check if UI and console are initialized before using them
  if (ui != null && ui.console != null) {
    ui.printToConsole(message);
  }
}
