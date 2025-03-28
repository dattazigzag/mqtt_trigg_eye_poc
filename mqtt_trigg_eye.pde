import de.looksgood.ani.*;
import mqtt.*;
import processing.data.JSONObject;
// ControlP5 for UI controls
import controlP5.*;

// MQTT realted
MQTTClient client;
String BROKER_IP = "127.0.0.1";
String BROKER_PORT = "1883";
String CLIENT_ID = "Processing_MQTT_EYE_Client";
boolean mqttConnected = false; // for Business logic: for on launch checking of broker
boolean mqttState = true; // to be used as a var for tracking state
int lastConnectionAttempt = 0;
int connectionRetryInterval = 2000; // Try every 2 seconds


// Global settings
boolean enableP3D = true;
boolean debug = false;
int fr = 20;  // framerate
boolean syncS = true; // Sync movement in left and right, in same dir
boolean syncM = false; // Sync movement in left and right, but in opp dir

final int SKETCH_WIDTH = 640;
final int SKETCH_HEIGHT = 550;
final int CANVAS_WIDTH = 640;  // Using full width of the sketch
final int CANVAS_HEIGHT = 320;
final int RESERVED_HEIGHT = 230;
final int SINGLE_CANVAS_WIDTH = 320; // Each canvas gets half of the total width
final int ROWS_OF_PIXELS = 8;
final int COLS_OF_PIXELS = 8;


color normalPixel = color(255, 255, 255);
color activePixelCol = color(0);
color blackoutPixelCol = color(0);
color boundaryPixelCol = color(255, 135, 78);
color debugColType1 = color(255, 204, 0);
color debugColType2 = color(255, 54, 255);

int[] backout_list_px_ids = {0, 1, 6, 7, 8, 15, 48, 55, 56, 57, 62, 63};
IntList backoutSet = new IntList();
int[] boundary_px_ids_list = {2, 3, 4, 5, 9, 14, 16, 23, 24, 31, 32, 39, 40, 47, 49, 54, 58, 59, 60, 61};
IntList boundarySet = new IntList();


ArrayList<Pixel> left_canvas_pixels = new ArrayList<Pixel>();
ArrayList<Pixel> right_canvas_pixels = new ArrayList<Pixel>();


// Global variables for animation
float cellXCurrent;
float cellYCurrent;
boolean isAnimating = false;

// UI realated
// Console configuration
final int CONSOLE_BUFFER_LIMIT = 100; // Maximum number of lines in console before auto-clearing
// Global reference to the console for easy access
Textarea appConsole;

UserInterface ui;


void settings() {
  if (!enableP3D) {
    size(640, 550);  // Default renderer
    println("[setting]\tUsing default renderer");
  } else {
    size(640, 550, P3D);  // P3D renderer
    println("[setting]\tUsing P3D renderer");
  }
  smooth();
}


void setup() {
  background(0);

  // Important for P3D mode - set hint to improve 2D rendering performance where appropriate
  if (enableP3D) {
    println("[setup]\tUsing P3D hint optimizations");
    hint(DISABLE_DEPTH_TEST);
    hint(DISABLE_TEXTURE_MIPMAPS);
  } else {
    println("[setup]\tNot using P3D hint optimizations");
  }

  // Initialize UI
  ui = new UserInterface(this, 0, CANVAS_HEIGHT, SKETCH_WIDTH, RESERVED_HEIGHT);


  // Pixel stuff
  int pixel_width = int(SINGLE_CANVAS_WIDTH/ROWS_OF_PIXELS);
  int pixel_height = int(CANVAS_HEIGHT/COLS_OF_PIXELS);

  // Spawnleft canvas pixels
  for (int y = 0; y < CANVAS_HEIGHT; y += pixel_height) {
    for (int x = 0; x < SINGLE_CANVAS_WIDTH; x += pixel_width) {
      left_canvas_pixels.add(new Pixel(x, y, pixel_width, pixel_height));
    }
  }

  // Spawn right canvas pixels
  for (int y = 0; y < CANVAS_HEIGHT; y += pixel_height) {
    for (int x = SINGLE_CANVAS_WIDTH; x < SKETCH_WIDTH; x += pixel_width) {
      right_canvas_pixels.add(new Pixel(x, y, pixel_width, pixel_height));
    }
  }

  // Fill in the backout set
  for (int i=0; i<backout_list_px_ids.length; i++) {
    backoutSet.append(backout_list_px_ids[i]);
  }

  // Fill in the boundary set
  for (int i=0; i<boundary_px_ids_list.length; i++) {
    boundarySet.append(boundary_px_ids_list[i]);
  }

  Ani.init(this);
  Ani.setDefaultTimeMode(Ani.FRAMES);

  // Set initial cell position
  cellXCurrent = left_curr_id % COLS_OF_PIXELS;
  cellYCurrent = left_curr_id / COLS_OF_PIXELS;


  // MQTT stuff ...
  client = new MQTTClient(this);
  // Initial connection attempt (non-blocking)
  connectMQTT();
}



void draw() {
  background(0);

  // Check if we need to attempt reconnection
  if (!mqttConnected && millis() - lastConnectionAttempt > connectionRetryInterval) {
    connectMQTT();
  }

  if (enableP3D) {
    // Set appropriate rendering state for 2D content
    hint(DISABLE_DEPTH_TEST);
  }

  color c = normalPixel;
  if (debug) {
    c = debugColType1;
  }
  for (int i = 0; i < left_canvas_pixels.size(); i++) {
    left_canvas_pixels.get(i).display(c, debug, i);

    if (debug && boundarySet.hasValue(i)) {
      left_canvas_pixels.get(i).display(boundaryPixelCol, debug, i);
    }

    // for the left eye, keep some pixels always black
    if (backoutSet.hasValue(i)) {
      left_canvas_pixels.get(i).display(blackoutPixelCol, debug, i);
    }
  }


  c = normalPixel;
  if (debug) {
    c = debugColType2;
  }
  for (int i = 0; i < right_canvas_pixels.size(); i++) {
    right_canvas_pixels.get(i).display(c, debug, i);

    if (debug && boundarySet.hasValue(i)) {
      right_canvas_pixels.get(i).display(boundaryPixelCol, debug, i);
    }

    // for the right eye, keep some pixels always black
    if (backoutSet.hasValue(i)) {
      right_canvas_pixels.get(i).display(blackoutPixelCol, debug, i);
    }
  }



  // No sync mode with leftHit only
  if (!syncS && !syncM && !rightHit && leftHit) {
    if (!backoutSet.hasValue(left_curr_id) && !boundarySet.hasValue(left_curr_id)) {
      int[] blockIds = get2x2BlockIds(left_curr_id);
      if (blockIds.length > 0) {
        for (int id : blockIds) {
          if (id >= 0 && id < left_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            left_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }
      } else {
        // Fallback to just the current cell
        left_canvas_pixels.get(left_curr_id).display(activePixelCol, debug, left_curr_id);
      }
    }
  }

  // No sync mode with rightHit only
  else if (!syncS && !syncM && rightHit && !leftHit) {
    if (!backoutSet.hasValue(right_curr_id) && !boundarySet.hasValue(right_curr_id)) {
      int[] blockIds = get2x2BlockIds(right_curr_id);
      if (blockIds.length > 0) {
        for (int id : blockIds) {
          if (id >= 0 && id < right_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            right_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }
      } else {
        // Fallback to just the current cell
        right_canvas_pixels.get(right_curr_id).display(activePixelCol, debug, right_curr_id);
      }
    }
  }

  // Sync same mode with leftHit
  else if (syncS && leftHit && !rightHit) {
    if (!backoutSet.hasValue(left_curr_id) && !boundarySet.hasValue(left_curr_id)) {
      int[] blockIds = get2x2BlockIds(left_curr_id);
      if (blockIds.length > 0) {
        for (int id : blockIds) {
          // Left side
          if (id >= 0 && id < left_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            left_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
          // Right side - same position
          if (id >= 0 && id < right_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            right_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }
      } else {
        // Fallback to just the current cells
        left_canvas_pixels.get(left_curr_id).display(activePixelCol, debug, left_curr_id);
        if (left_curr_id < right_canvas_pixels.size() && !backoutSet.hasValue(left_curr_id)) {
          right_canvas_pixels.get(left_curr_id).display(activePixelCol, debug, left_curr_id);
        }
      }
    }
  }

  // Sync same mode with rightHit
  else if (syncS && rightHit && !leftHit) {
    if (!backoutSet.hasValue(right_curr_id) && !boundarySet.hasValue(right_curr_id)) {
      int[] blockIds = get2x2BlockIds(right_curr_id);
      if (blockIds.length > 0) {
        for (int id : blockIds) {
          // Right side
          if (id >= 0 && id < right_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            right_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
          // Left side - same position
          if (id >= 0 && id < left_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            left_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }
      } else {
        // Fallback to just the current cells
        right_canvas_pixels.get(right_curr_id).display(activePixelCol, debug, right_curr_id);
        if (right_curr_id < left_canvas_pixels.size() && !backoutSet.hasValue(right_curr_id)) {
          left_canvas_pixels.get(right_curr_id).display(activePixelCol, debug, right_curr_id);
        }
      }
    }
  }

  // Mirror mode with leftHit
  else if (syncM && leftHit && !rightHit) {
    if (!backoutSet.hasValue(left_curr_id) && !boundarySet.hasValue(left_curr_id)) {
      int[] blockIds = get2x2BlockIds(left_curr_id);
      if (blockIds.length > 0) {
        // Left side block
        for (int id : blockIds) {
          if (id >= 0 && id < left_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            left_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }

        // Right side mirrored block
        for (int id : blockIds) {
          int mirroredId = getMirroredPixelId(id);
          if (mirroredId >= 0 && mirroredId < right_canvas_pixels.size() && !backoutSet.hasValue(mirroredId)) {
            right_canvas_pixels.get(mirroredId).display(activePixelCol, debug, mirroredId);
          }
        }
      } else {
        // Fallback to just the current cell and its mirror
        left_canvas_pixels.get(left_curr_id).display(activePixelCol, debug, left_curr_id);
        int mirroredId = getMirroredPixelId(left_curr_id);
        if (mirroredId >= 0 && mirroredId < right_canvas_pixels.size() && !backoutSet.hasValue(mirroredId)) {
          right_canvas_pixels.get(mirroredId).display(activePixelCol, debug, mirroredId);
        }
      }
    }
  }

  // Mirror mode with rightHit
  else if (syncM && rightHit && !leftHit) {
    if (!backoutSet.hasValue(right_curr_id) && !boundarySet.hasValue(right_curr_id)) {
      int[] blockIds = get2x2BlockIds(right_curr_id);
      if (blockIds.length > 0) {
        // Right side block
        for (int id : blockIds) {
          if (id >= 0 && id < right_canvas_pixels.size() && !backoutSet.hasValue(id)) {
            right_canvas_pixels.get(id).display(activePixelCol, debug, id);
          }
        }

        // Left side mirrored block
        for (int id : blockIds) {
          int mirroredId = getMirroredPixelId(id);
          if (mirroredId >= 0 && mirroredId < left_canvas_pixels.size() && !backoutSet.hasValue(mirroredId)) {
            left_canvas_pixels.get(mirroredId).display(activePixelCol, debug, mirroredId);
          }
        }
      } else {
        // Fallback to just the current cell and its mirror
        right_canvas_pixels.get(right_curr_id).display(activePixelCol, debug, right_curr_id);
        int mirroredId = getMirroredPixelId(right_curr_id);
        if (mirroredId >= 0 && mirroredId < left_canvas_pixels.size() && !backoutSet.hasValue(mirroredId)) {
          left_canvas_pixels.get(mirroredId).display(activePixelCol, debug, mirroredId);
        }
      }
    }
  }


  // Left & Right Separator line
  stroke(100);
  strokeWeight(0.5);
  line(SINGLE_CANVAS_WIDTH, 0, SINGLE_CANVAS_WIDTH, CANVAS_HEIGHT);

  // Render UI
  ui.render();
}


// Helper function to calculate the mirrored pixel ID
int getMirroredPixelId(int id) {
  // Calculate row and column from ID
  int row = id / COLS_OF_PIXELS;
  int col = id % COLS_OF_PIXELS;
  // Mirror the column (horizontal mirroring)
  int mirroredCol = (COLS_OF_PIXELS - 1) - col;
  // Convert back to ID
  return (row * COLS_OF_PIXELS) + mirroredCol;
}


// Helper function to calculate the 4 cell IDs that form a 2x2 block (with backout list considerations)
// Modified function to consider both backout and boundary cells
int[] get2x2BlockIds(int activeId) {
  // Check if the active ID is in backout or boundary list
  if (backoutSet.hasValue(activeId) || boundarySet.hasValue(activeId)) {
    return new int[0];
  }

  int[] blockIds = new int[4];

  // Calculate row and column of active cell
  int row = activeId / COLS_OF_PIXELS;
  int col = activeId % COLS_OF_PIXELS;

  // Try different positions for 2x2 block
  int[][] possiblePositions = {
    {row, col}, // Current as top-left
    {row, col-1}, // Left as top-left
    {row-1, col}, // Above as top-left
    {row-1, col-1}     // Diagonal as top-left
  };

  int bestPosition = 0;
  int lowestInvalidCells = 4; // Start with worst case

  // Find position with fewest invalid cells (backout OR boundary)
  for (int i = 0; i < possiblePositions.length; i++) {
    int testRow = possiblePositions[i][0];
    int testCol = possiblePositions[i][1];

    // Skip if outside grid
    if (testRow < 0 || testRow >= ROWS_OF_PIXELS-1 ||
      testCol < 0 || testCol >= COLS_OF_PIXELS-1) {
      continue;
    }

    // Count invalid cells in this configuration
    int invalidCount = 0;
    int[] testIds = new int[4];
    testIds[0] = testRow * COLS_OF_PIXELS + testCol;
    testIds[1] = testRow * COLS_OF_PIXELS + (testCol + 1);
    testIds[2] = (testRow + 1) * COLS_OF_PIXELS + testCol;
    testIds[3] = (testRow + 1) * COLS_OF_PIXELS + (testCol + 1);

    for (int id : testIds) {
      if (backoutSet.hasValue(id) || boundarySet.hasValue(id)) {
        invalidCount++;
      }
    }

    // If better position, choose it
    if (invalidCount < lowestInvalidCells) {
      lowestInvalidCells = invalidCount;
      bestPosition = i;

      // Perfect position with no invalid cells
      if (invalidCount == 0) {
        break;
      }
    }
  }

  // Use best position
  int topLeftRow = possiblePositions[bestPosition][0];
  int topLeftCol = possiblePositions[bestPosition][1];

  blockIds[0] = topLeftRow * COLS_OF_PIXELS + topLeftCol;
  blockIds[1] = topLeftRow * COLS_OF_PIXELS + (topLeftCol + 1);
  blockIds[2] = (topLeftRow + 1) * COLS_OF_PIXELS + topLeftCol;
  blockIds[3] = (topLeftRow + 1) * COLS_OF_PIXELS + (topLeftCol + 1);

  return blockIds;
}




void keyPressed() {
  if (key == 'd' || key == 'D') {
    debug = !debug;
    //println("DEBUG MODE: " + (debug ? "Enabled" : "Disabled"));
    log("DEBUG MODE: " + (debug ? "Enabled" : "Disabled"));
  } else if (key == 's' || key == 'S') {
    syncS = !syncS;
    syncM = !syncS;
    log("EYE Sync: " + (syncS ? "Enabled" : "Disabled"));
  } else if (key == 'm' || key == 'M') {
    syncM = !syncM;
    syncS = !syncM;
    log("EYE Sync but Mirror: " + (syncM ? "Enabled" : "Disabled"));
  }

  // Hotkeys for jumping to specific cells
  else if (key == '1') {
    int targetCell = (random(1) > 0.5) ? 10 : 17;
    animateToCell(targetCell);
  } else if (key == '2') {
    int targetCell = (random(1) > 0.5) ? 13 : 22;
    animateToCell(targetCell);
  } else if (key == '3') {
    int targetCell = (random(1) > 0.5) ? 53 : 46;
    animateToCell(targetCell);
  } else if (key == '4') {
    int targetCell = (random(1) > 0.5) ? 50 : 41;
    animateToCell(targetCell);
  }
}


// Ani callback functions
void updateCell() {
  // Convert floating point position to cell index
  int row = constrain(int(cellYCurrent), 0, ROWS_OF_PIXELS - 1);
  int col = constrain(int(cellXCurrent), 0, COLS_OF_PIXELS - 1);
  int cellId = row * COLS_OF_PIXELS + col;

  // Only update if it's a valid cell
  if (!backoutSet.hasValue(cellId) && !boundarySet.hasValue(cellId)) {
    left_curr_id = cellId;
    left_last_id = cellId;
    leftHit = true;
    rightHit = false;
  }
}


void animationComplete() {
  isAnimating = false;
  log("Animation complete");
}


void animateToCell(int targetCellId) {
  if (backoutSet.hasValue(targetCellId) || boundarySet.hasValue(targetCellId)) {
    return; // Don't animate to invalid cells
  }

  // Calculate target position
  float targetRow = targetCellId / COLS_OF_PIXELS;
  float targetCol = targetCellId % COLS_OF_PIXELS;

  // Set current position
  cellXCurrent = left_curr_id % COLS_OF_PIXELS;
  cellYCurrent = left_curr_id / COLS_OF_PIXELS;

  // Start animation with correct parameter types
  isAnimating = true;

  // Note: duration must be float, target values must be float, and we need an easing
  Ani.to(this, 20.0f, "cellXCurrent", targetCol, Ani.BACK_OUT, "onUpdate:updateCell");
  Ani.to(this, 20.0f, "cellYCurrent", targetRow, Ani.BACK_OUT, "onEnd:animationComplete");

  log("Animating to cell ID: " + targetCellId);
}


int left_curr_id = 0;
int left_last_id = 0;
int right_curr_id = 0;
int right_last_id = 0;
boolean leftHit = false;
boolean rightHit = false;


void mouseMoved() {
  boolean foundNewValidPosition = false;

  // Check left canvas
  for (int i = 0; i < left_canvas_pixels.size(); i++) {
    int cur_pixel_x = left_canvas_pixels.get(i).getPosition()[0];
    int cur_pixel_y = left_canvas_pixels.get(i).getPosition()[1];
    int cur_pixel_w = left_canvas_pixels.get(i).getSize()[0];
    int cur_pixel_h = left_canvas_pixels.get(i).getSize()[1];

    if (mouseX >= cur_pixel_x && mouseX <= cur_pixel_x+cur_pixel_w &&
      mouseY >= cur_pixel_y && mouseY <= cur_pixel_y+cur_pixel_h) {
      // We found the cell the mouse is over on the left canvas

      // Only update if it's a valid cell (not in backout or boundary)
      if (!backoutSet.hasValue(i) && !boundarySet.hasValue(i)) {
        foundNewValidPosition = true;
        left_curr_id = i;
        leftHit = true;
        rightHit = false;

        if (left_curr_id != left_last_id) {
          // Print debug info as appropriate based on the mode
          if (syncS) {
            log("[SYNCED] Current Left Pixel id: " + left_curr_id);
            log("[SYNCED] Matching Right Pixel id: " + left_curr_id);
            log("[SYNCED] Last Left Pixel id: " + left_last_id);
            log("[SYNCED] Matching Last Right Pixel id: " + left_last_id);
            log("");
          } else if (syncM) {
            int mirroredId = getMirroredPixelId(left_curr_id);
            int mirroredLastId = getMirroredPixelId(left_last_id);

            log("[MIRROR] Current Left Pixel id: " + left_curr_id);
            log("[MIRROR] Mirrored Right Pixel id: " + mirroredId);
            log("[MIRROR] Last Left Pixel id: " + left_last_id);
            log("[MIRROR] Mirrored Last Right Pixel id: " + mirroredLastId);
            log("");
          } else {
            log("Current Left Pixel id: " + left_curr_id);
            log("Last Left Pixel id: " + left_last_id);
            log("");
          }
          left_last_id = left_curr_id;
        }
      }
      break;
    }
  }

  // Check right canvas if we didn't find a valid position on the left
  if (!foundNewValidPosition) {
    for (int i = 0; i < right_canvas_pixels.size(); i++) {
      int cur_pixel_x = right_canvas_pixels.get(i).getPosition()[0];
      int cur_pixel_y = right_canvas_pixels.get(i).getPosition()[1];
      int cur_pixel_w = right_canvas_pixels.get(i).getSize()[0];
      int cur_pixel_h = right_canvas_pixels.get(i).getSize()[1];

      if (mouseX >= cur_pixel_x && mouseX <= cur_pixel_x+cur_pixel_w &&
        mouseY >= cur_pixel_y && mouseY <= cur_pixel_y+cur_pixel_h) {
        // We found the cell the mouse is over on the right canvas

        // Only update if it's a valid cell (not in backout or boundary)
        if (!backoutSet.hasValue(i) && !boundarySet.hasValue(i)) {
          foundNewValidPosition = true;
          right_curr_id = i;
          rightHit = true;
          leftHit = false;

          if (right_curr_id != right_last_id) {
            // Print debug info as appropriate
            if (syncS) {
              log("[SYNCED] Current Right Pixel id: " + right_curr_id);
              log("[SYNCED] Matching Left Pixel id: " + right_curr_id);
              log("[SYNCED] Last Right Pixel id: " + right_last_id);
              log("[SYNCED] Matching Last Left Pixel id: " + right_last_id);
              log("");
            } else if (syncM) {
              int mirroredId = getMirroredPixelId(right_curr_id);
              int mirroredLastId = getMirroredPixelId(right_last_id);

              log("[MIRROR] Current Right Pixel id: " + right_curr_id);
              log("[MIRROR] Mirrored Left Pixel id: " + mirroredId);
              log("[MIRROR] Last Right Pixel id: " + right_last_id);
              log("[MIRROR] Mirrored Last Left Pixel id: " + mirroredLastId);
              log("");
            } else {
              log("Current Right Pixel id: " + right_curr_id);
              log("Last Right Pixel id: " + right_last_id);
              log("");
            }
            right_last_id = right_curr_id;
          }
        }
        break;
      }
    }
  }

  // Important: If we didn't find a new valid position, we don't update
  // leftHit and rightHit, which creates the "sticky" behavior.
  // They will retain their previous values.
}




void connectMQTT() {
  lastConnectionAttempt = millis();

  try {
    log("Attempting to connect to MQTT broker...");
    client.connect("mqtt://" + BROKER_IP + ":" + BROKER_PORT, CLIENT_ID);

    mqttConnected = true;
    mqttState = true;
  }
  catch (Exception e) {
    mqttConnected = false;
    mqttState = false;
    log("Failed to connect to MQTT broker: " + e.getMessage());
    log("Will retry in " + (connectionRetryInterval/1000) + " seconds");
  }
}

void clientConnected() {
  mqttState = true;
  log("MQTT client connected");
  log("Subscribing to messages ...");
  log("\tmicrophones/left");
  log("\tmicrophones/right");
  log("\tmicrophones/status");
  //log("\tmicrophones/ping");
  client.subscribe("microphones/left");
  client.subscribe("microphones/right");
  client.subscribe("microphones/status");
  //client.subscribe("microphones/ping");
}

void messageReceived(String topic, byte[] payload) {
  log("new MQTT message: " + topic + " - " + new String(payload));

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
