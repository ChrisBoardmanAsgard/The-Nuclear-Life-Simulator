import controlP5.*;
import processing.sound.*;
import java.util.ArrayList;
import processing.core.PVector;

// Control, Sound, and Data Variables
ControlP5 cp5;
SoundFile[] tracks;
ArrayList<Organism> population = new ArrayList<>();
ArrayList<Food> foods = new ArrayList<>();
ArrayList<Poop> poops = new ArrayList<>();
ArrayList<MutationPool> mutationPools = new ArrayList<>();

float simulationSpeed = 1.0;
boolean isPaused = false;
int radiationLevel = 50;
float oxygenLevel = 21.0;
float co2Level = 0.04f;
float sulfurDioxideLevel = 0.01f;
int initialPopulation = 20;
int currentTrack = 0;

int worldWidth = 3000;
int worldHeight = 3000;
PVector cameraPos = new PVector(worldWidth / 2, worldHeight / 2);
float zoomLevel = 1.0;
float loadProgress = 0;

// UI States
final int STATE_MAIN_MENU = 0, STATE_WORLD_PARAMS = 1, STATE_LOADING = 2, STATE_SIMULATION = 3, STATE_DESCRIPTION = 4, STATE_CREDITS = 5;
int currentState = STATE_MAIN_MENU;

// Track Files
String[] trackFiles = {
  "/data/Reflection of Times v1.wav", 
  "/data/Reflection of Times v2.wav", 
  "/data/The Nuclear Life Track 1 Fade InOut.wav", 
  "/data/The Nuclear Life Track 2 Fade InOut.wav"
};

// Fullscreen mode setup
void settings() { 
  fullScreen(P2D); 
  smooth(8); 
}

void setup() { 
  cp5 = new ControlP5(this); 
  frameRate(60);
  initializeSound(); 
  setupMainMenu(); 
  setupWorldParameterScreen(); 
  setupSimulationControls(); 
  initializeSimulation(); 
}

// Initialize Sound
void initializeSound() {
  tracks = new SoundFile[trackFiles.length];
  for (int i = 0; i < trackFiles.length; i++) {
    try {
      tracks[i] = new SoundFile(this, trackFiles[i]);
      if (i == 0) tracks[i].loop(); // Start first track on loop
    } catch (Exception e) {
      println("Error initializing sound file: " + trackFiles[i] + ", " + e.getMessage());
      tracks[i] = null; // Set to null if initialization fails
    }
  }
}

// Play specific track
void playTrack(int trackIndex) {
  if (trackIndex >= 0 && trackIndex < tracks.length && tracks[trackIndex] != null) {
    stopAllTracks(); 
    tracks[trackIndex].loop();
  }
}

// Stop all tracks
void stopAllTracks() {
  for (SoundFile track : tracks) {
    if (track != null) track.stop();
  }
}

// Move to the next track
void nextTrack() {
  currentTrack = (currentTrack + 1) % tracks.length;
  playTrack(currentTrack);
}

// Main Menu Setup
void setupMainMenu() {
  cp5.addButton("Start Simulation")
     .setPosition(width / 2 - 100, height / 2 - 60)
     .setSize(200, 40)
     .onClick(e -> { 
       currentState = STATE_WORLD_PARAMS; 
       hideMainMenu(); 
       showWorldParameterSliders(); 
     });
  
  cp5.addButton("Description")
     .setPosition(width / 2 - 100, height / 2)
     .setSize(200, 40)
     .onClick(e -> currentState = STATE_DESCRIPTION);
     
  cp5.addButton("Credits")
     .setPosition(width / 2 - 100, height / 2 + 60)
     .setSize(200, 40)
     .onClick(e -> currentState = STATE_CREDITS);
     
  cp5.addButton("Exit")
     .setPosition(width / 2 - 100, height / 2 + 120)
     .setSize(200, 40)
     .onClick(e -> exit());
}

void displayMainMenu() {
  fill(255); 
  textAlign(CENTER); 
  textSize(32); 
  text("The Nuclear Life Simulator", width / 2, height / 2 - 100);
}

void hideMainMenu() { 
  cp5.getController("Start Simulation").hide(); 
  cp5.getController("Description").hide(); 
  cp5.getController("Credits").hide(); 
  cp5.getController("Exit").hide(); 
}

void showMainMenu() {
  cp5.getController("Start Simulation").show(); 
  cp5.getController("Description").show(); 
  cp5.getController("Credits").show(); 
  cp5.getController("Exit").show();
}

// World Parameters Screen Setup
void setupWorldParameterScreen() {
  cp5.addButton("Back").setPosition(width / 2 - 50, height - 60).setSize(100, 30).onClick(e -> { currentState = STATE_MAIN_MENU; hideWorldParameterSliders(); showMainMenu(); });
  cp5.addButton("Confirm").setPosition(width / 2 - 50, height - 100).setSize(100, 30).onClick(e -> { currentState = STATE_LOADING; hideWorldParameterSliders(); startLoading(); });
  cp5.addSlider("Initial Population").setPosition(width / 2 - 100, height / 2 - 80).setSize(200, 20).setRange(10, 200).setValue(initialPopulation).onRelease(e -> initialPopulation = (int) e.getController().getValue());
  cp5.addSlider("Radiation Level").setPosition(width / 2 - 100, height / 2 - 20).setSize(200, 20).setRange(0, 100).setValue(radiationLevel).onRelease(e -> radiationLevel = (int) e.getController().getValue());
  cp5.addSlider("Oxygen Level").setPosition(width / 2 - 100, height / 2 + 40).setSize(200, 20).setRange(0, 30).setValue(oxygenLevel).onRelease(e -> oxygenLevel = e.getController().getValue());
  cp5.addSlider("CO2 Level").setPosition(width / 2 - 100, height / 2 + 100).setSize(200, 20).setRange(0, 0.1).setValue(co2Level).onRelease(e -> co2Level = e.getController().getValue());
  cp5.addSlider("Sulfur Dioxide Level").setPosition(width / 2 - 100, height / 2 + 160).setSize(200, 20).setRange(0, 0.05).setValue(sulfurDioxideLevel).onRelease(e -> sulfurDioxideLevel = e.getController().getValue());
}

void showWorldParameterSliders() { 
  cp5.getController("Initial Population").show(); 
  cp5.getController("Radiation Level").show(); 
  cp5.getController("Oxygen Level").show(); 
  cp5.getController("CO2 Level").show(); 
  cp5.getController("Sulfur Dioxide Level").show(); 
}

void hideWorldParameterSliders() { 
  cp5.getController("Initial Population").hide(); 
  cp5.getController("Radiation Level").hide(); 
  cp5.getController("Oxygen Level").hide(); 
  cp5.getController("CO2 Level").hide(); 
  cp5.getController("Sulfur Dioxide Level").hide(); 
}

// Loading Screen
void startLoading() {
  loadProgress = 0; 
  thread("loadingProcess");
}

void loadingProcess() {
  for (int i = 0; i <= 100; i++) {
    delay(30); 
    loadProgress = i;
    if (i == 100) currentState = STATE_SIMULATION;
  }
}

// Simulation Control with Speed Controls and Next Track
void setupSimulationControls() {
  cp5.addButton("Pause/Resume").setPosition(20, height - 50).setSize(100, 30).onClick(e -> isPaused = !isPaused);
  cp5.addButton("Restart").setPosition(130, height - 50).setSize(100, 30).onClick(e -> initializeSimulation());
  cp5.addButton("Next Track").setPosition(240, height - 50).setSize(100, 30).onClick(e -> nextTrack());
  cp5.addButton("Speed Up").setPosition(350, height - 50).setSize(100, 30).onClick(e -> simulationSpeed *= 1.5);
  cp5.addButton("Slow Down").setPosition(460, height - 50).setSize(100, 30).onClick(e -> simulationSpeed /= 1.5);
}

// Initialize Simulation
void initializeSimulation() {
  population.clear(); 
  foods.clear(); 
  poops.clear();
  initializeFood(100); 
  initializeMutationPools(3);
  for (int i = 0; i < initialPopulation; i++) population.add(new Organism());
  isPaused = false;
}

// Food and Mutation Pool Initialization
void initializeFood(int foodCount) {
  foods.clear(); 
  for (int i = 0; i < foodCount; i++) foods.add(new Food(random(worldWidth), random(worldHeight)));
}

void initializeMutationPools(int poolCount) {
  mutationPools.clear(); 
  for (int i = 0; i < poolCount; i++) mutationPools.add(new MutationPool(random(worldWidth), random(worldHeight), random(50, 150)));
}

// Display screens and control visibility
void draw() {
  background(30);
  switch (currentState) {
    case STATE_MAIN_MENU:
      displayMainMenu();
      showMainMenu();
      hideWorldParameterSliders();
      break;
    case STATE_WORLD_PARAMS:
      displayWorldParameterScreen();
      showWorldParameterSliders();
      hideMainMenu();
      break;
    case STATE_LOADING:
      displayLoadingScreen();
      hideWorldParameterSliders();
      break;
    case STATE_SIMULATION:
      runSimulation();
      break;
    case STATE_DESCRIPTION:
      displayDescriptionScreen();
      hideWorldParameterSliders();
      hideMainMenu();
      break;
    case STATE_CREDITS:
      displayCreditsScreen();
      hideWorldParameterSliders();
      hideMainMenu();
      break;
  }
}

// Additional display and helper functions can be added here (e.g., displayDescriptionScreen, displayCreditsScreen, displayLoadingScreen)

// Simulation Execution
void runSimulation() {
  background(10, 30, 60); // Set simulation background color
  
  // Update and manage environmental gas levels
  manageGasLevels();
  
  if (!isPaused) {
    // Replenish food supply and process poop decay if the simulation is active
    replenishFood();
    processPoopDecay();

    // Display and update each food item in the simulation
    for (Food food : foods) {
      food.display();
    }

    // Display and update each poop item in the simulation
    for (int i = poops.size() - 1; i >= 0; i--) {
      Poop poop = poops.get(i);
      poop.update();
      poop.display();

      // Remove poop if it has decayed fully
      if (poop.isDecayed()) {
        poops.remove(i);
      }
    }

    // Display each mutation pool in the simulation
    for (MutationPool pool : mutationPools) {
      pool.display();
      // Affect organisms within the radius of the mutation pool
      pool.affectOrganisms(population);
    }

    // Update, display, and manage organisms
    for (int i = population.size() - 1; i >= 0; i--) {
      Organism organism = population.get(i);
      organism.update(simulationSpeed);

      // Remove organism if it has died
      if (organism.isDead) {
        population.remove(i);
      } else {
        organism.display();
      }
    }
  }

  // Display real-time simulation statistics on the screen
  displayWorldStats();
}

// Manage Environmental Gas Levels
void manageGasLevels() {
  // Adjust gas levels over time to simulate atmospheric dynamics
  if (sulfurDioxideLevel > 0.01) sulfurDioxideLevel -= 0.001; // Slow decay of sulfur dioxide
  if (co2Level > 0.04) co2Level -= 0.0001;                    // Gradual decrease of CO2
  if (oxygenLevel < 21.0) oxygenLevel += 0.005;               // Oxygen replenishes

  // Constrain gas levels within defined environmental limits
  sulfurDioxideLevel = constrain(sulfurDioxideLevel, 0.01, 10.0);
  co2Level = constrain(co2Level, 0.01, 5.0);
  oxygenLevel = constrain(oxygenLevel, 15.0, 30.0);
}

// Ensure food supply remains stable in the ecosystem
void replenishFood() {
  // Maintain a minimum food count by adding new food particles if needed
  if (foods.size() < 100) { // Threshold for replenishment
    for (int i = 0; i < 5; i++) {
      foods.add(new Food(random(worldWidth), random(worldHeight)));
    }
  }
}

// Update the decay state of poop particles and sulfur emissions
void processPoopDecay() {
  // Iterate through poop list to update each poop's decay and emit sulfur dioxide
  for (int i = poops.size() - 1; i >= 0; i--) {
    Poop poop = poops.get(i);
    poop.update();

    // If poop is fully decayed, remove it from the list
    if (poop.isDecayed()) {
      poops.remove(i);
    }
  }
}

// Display real-time world statistics on the screen
void displayWorldStats() {
  fill(255); // Set text color to white
  textAlign(LEFT); // Align text to the left
  textSize(16); // Set font size
  
  // Display various statistics on the top left of the screen
  text("Population: " + population.size(), 20, 30);
  text("Food Count: " + foods.size(), 20, 50);
  text("Radiation Level: " + radiationLevel, 20, 70);
  text("Oxygen Level: " + oxygenLevel, 20, 90);
  text("CO2 Level: " + co2Level, 20, 110);
  text("Sulfur Dioxide Level: " + sulfurDioxideLevel, 20, 130);
}

// Organism, Food, Poop, MutationPool, and NeuralNetwork classes as already provided

// Additional display functions
void displayLoadingScreen() {
  fill(255);
  textAlign(CENTER);
  textSize(20);
  text("Loading... " + int(loadProgress) + "%", width / 2, height / 2);
}

void displayDescriptionScreen() {
  background(30);
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("The Nuclear Life Simulator", width / 2, 100);

  textSize(16);
  text("Observe and interact with a simulated ecosystem of organisms adapting to a radioactive environment.", width / 2, 150);
  text("Organisms respond to environmental changes, genetic mutations, and fluctuating levels of gases.", width / 2, 180);
  text("The simulation includes evolution, reproduction, and adaptation to various environmental pressures.", width / 2, 210);
  text("Use the controls to start, pause, adjust speed, and observe the simulation in real-time.", width / 2, 240);
}

void displayCreditsScreen() {
  background(30);
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Credits", width / 2, 100);

  textSize(18);
  text("Developed by Christopher J Boardman", width / 2, 150);
  text("Music Composed by Jake Rae & Christopher J Boardman", width / 2, 180);
  text("Thank you for using The Nuclear Life Simulator!", width / 2, 240);
}
// Food Class
class Food {
  PVector position;
  float energy;

  Food(float x, float y) {
    position = new PVector(x, y);
    energy = random(20, 50);
  }

  void display() {
    float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
    float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;
    fill(0, 180, 0); // Green color for food particles
    noStroke();
    ellipse(displayX, displayY, 8 * zoomLevel, 8 * zoomLevel);
  }
}

// Poop Class
class Poop {
  PVector position;
  int decayTime;
  float sulfurEmission = 0.001; // Amount of sulfur dioxide emitted over time

  Poop(float x, float y) {
    position = new PVector(x, y);
    decayTime = (int) random(300, 600); // Decay time in frames
  }

  void update() {
    if (decayTime > 0) {
      decayTime--;
      sulfurDioxideLevel = constrain(sulfurDioxideLevel + sulfurEmission, 0, 0.05);
    }
  }

  boolean isDecayed() {
    return decayTime <= 0;
  }

  void display() {
    float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
    float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;
    fill(165, 42, 42, 200); // Brown color with transparency for poop particles
    noStroke();
    ellipse(displayX, displayY, 6 * zoomLevel, 6 * zoomLevel);
  }
}

// MutationPool Class
class MutationPool {
  PVector position;
  float radius;

  MutationPool(float x, float y, float r) {
    position = new PVector(x, y);
    radius = r;
  }

  void display() {
    float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
    float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;
    noFill();
    stroke(255, 200, 50, 150); // Yellow outline for mutation pool
    strokeWeight(2);
    ellipse(displayX, displayY, radius * 2 * zoomLevel, radius * 2 * zoomLevel);
  }

  void affectOrganisms(ArrayList<Organism> organisms) {
    for (Organism org : organisms) {
      float dist = PVector.dist(org.position, position);
      if (dist < radius) {
        org.mutate();
      }
    }
  }
}

// NeuralNetwork Class
class NeuralNetwork {
  int numInputs, numHidden, numOutputs;
  float[][] inputWeights;
  float[][] hiddenWeights;

  NeuralNetwork(int numInputs, int numHidden, int numOutputs) {
    this.numInputs = numInputs;
    this.numHidden = numHidden;
    this.numOutputs = numOutputs;
    inputWeights = new float[numHidden][numInputs];
    hiddenWeights = new float[numOutputs][numHidden];
    initializeWeights();
  }

  void initializeWeights() {
    for (int i = 0; i < numHidden; i++) {
      for (int j = 0; j < numInputs; j++) {
        inputWeights[i][j] = random(-1, 1);
      }
    }
    for (int i = 0; i < numOutputs; i++) {
      for (int j = 0; j < numHidden; j++) {
        hiddenWeights[i][j] = random(-1, 1);
      }
    }
  }

  float[] process(float[] inputs) {
    float[] hiddenLayer = new float[numHidden];
    float[] outputs = new float[numOutputs];

    for (int i = 0; i < numHidden; i++) {
      float sum = 0;
      for (int j = 0; j < numInputs; j++) {
        sum += inputs[j] * inputWeights[i][j];
      }
      hiddenLayer[i] = tanh(sum);
    }

    for (int i = 0; i < numOutputs; i++) {
      float sum = 0;
      for (int j = 0; j < numHidden; j++) {
        sum += hiddenLayer[j] * hiddenWeights[i][j];
      }
      outputs[i] = constrain(tanh(sum), 0, 1);
    }
    return outputs;
  }

  void mutate() {
    int i = (int) random(numHidden);
    int j = (int) random(numInputs);
    inputWeights[i][j] += random(-0.1f, 0.1f);

    i = (int) random(numOutputs);
    j = (int) random(numHidden);
    hiddenWeights[i][j] += random(-0.1f, 0.1f);
  }

  NeuralNetwork copy() {
    NeuralNetwork clone = new NeuralNetwork(numInputs, numHidden, numOutputs);
    for (int i = 0; i < numHidden; i++) {
      System.arraycopy(inputWeights[i], 0, clone.inputWeights[i], 0, numInputs);
    }
    for (int i = 0; i < numOutputs; i++) {
      System.arraycopy(hiddenWeights[i], 0, clone.hiddenWeights[i], 0, numHidden);
    }
    return clone;
  }
}

// Utility activation function
float tanh(float x) {
  return (float) Math.tanh(x);
}

class Organism {
  PVector position, velocity;
  NeuralNetwork brain;
  float energy, sizeFactor, oxygenTolerance, co2Tolerance, sulfurTolerance;
  color organismColor;
  boolean isDead = false;
  int age = 0;
  float desireToReproduce = 0;

  Organism() {
    position = new PVector(random(worldWidth), random(worldHeight));
    velocity = PVector.random2D().mult(random(1, 3));
    brain = new NeuralNetwork(5, 5, 3);
    energy = random(50, 100);
    sizeFactor = random(1.0, 2.0);
    oxygenTolerance = random(15, 30);
    co2Tolerance = random(0.01, 0.05);
    sulfurTolerance = random(0.005, 0.02);
    organismColor = color(random(50, 255), random(100, 200), random(150, 250));
  }

  void update(float speed) {
    if (isDead || energy <= 0) {
      isDead = true;
      return;
    }

    float[] inputs = {closestFoodDistance() / 100, energy / 100, age / 100.0, desireToReproduce, sizeFactor};
    float[] outputs = brain.process(inputs);

    float moveSpeed = outputs[0] * 2.0 * speed;
    float reproductionDrive = outputs[1];

    if (reproductionDrive > 0.8 && energy > 50) {
      desireToReproduce += 0.1;
      findMate();
    } else if (energy < 30) {
      seekFood();
    }

    position.add(velocity.copy().mult(moveSpeed));
    age++;
    energy -= 0.05 * speed;

    if (energy > 100) reproduce();
    if (age > 300 && random(1) < 0.002) mutate();
  }

  void display() {
    float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
    float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;

    fill(organismColor, 180);
    stroke(organismColor);
    strokeWeight(2);
    ellipse(displayX, displayY, 10 * sizeFactor * zoomLevel, 10 * sizeFactor * zoomLevel);

    noFill();
    stroke(255, 200);
    ellipse(displayX, displayY, 12 * sizeFactor * zoomLevel, 12 * sizeFactor * zoomLevel);

    fill(0);
    float eyeSize = map(sizeFactor, 1.0f, 2.0f, 1.5f, 3.5f) * zoomLevel;
    ellipse(displayX + velocity.x * sizeFactor * zoomLevel, displayY + velocity.y * sizeFactor * zoomLevel, eyeSize, eyeSize);
  }

  float closestFoodDistance() {
    float closestDist = 100;
    for (Food food : foods) {
      float dist = PVector.dist(position, food.position);
      if (dist < closestDist) closestDist = dist;
    }
    return closestDist;
  }

  void seekFood() {
    Food closestFood = null;
    float closestDist = 100;
    for (Food food : foods) {
      float dist = PVector.dist(position, food.position);
      if (dist < closestDist) {
        closestDist = dist;
        closestFood = food;
      }
    }
    if (closestFood != null && closestDist < 20) {
      eat(closestFood);
    } else if (closestFood != null) {
      PVector direction = PVector.sub(closestFood.position, position).normalize();
      velocity = direction.mult(1.5f);
    }
  }

  void eat(Food food) {
    energy += food.energy;
    foods.remove(food);
    poops.add(new Poop(position.x, position.y));
  }

  void reproduce() {
    if (population.size() < 200) {
      Organism offspring = new Organism();
      offspring.brain = brain.copy();
      offspring.brain.mutate();
      offspring.sizeFactor = sizeFactor * random(0.95f, 1.05f);
      offspring.oxygenTolerance = oxygenTolerance * random(0.9f, 1.1f);
      offspring.co2Tolerance = co2Tolerance * random(0.9f, 1.1f);
      offspring.sulfurTolerance = sulfurTolerance * random(0.9f, 1.1f);
      offspring.position = PVector.add(position, PVector.random2D().mult(sizeFactor * 10));
      offspring.energy = energy / 2;
      energy /= 2;
      population.add(offspring);
    }
  }

  void findMate() {
    Organism mate = null;
    float closestDist = 50;
    for (Organism other : population) {
      if (other != this && !other.isDead && other.desireToReproduce > 0.8) {
        float dist = PVector.dist(position, other.position);
        if (dist < closestDist) {
          closestDist = dist;
          mate = other;
        }
      }
    }
    if (mate != null && closestDist < 15) {
      reproduceWith(mate);
    }
  }

  void reproduceWith(Organism mate) {
    if (population.size() < 200) {
      Organism offspring = new Organism();
      offspring.brain = brain.copy();
      offspring.brain.mutate();
      offspring.sizeFactor = (sizeFactor + mate.sizeFactor) / 2 * random(0.95f, 1.05f);
      offspring.oxygenTolerance = (oxygenTolerance + mate.oxygenTolerance) / 2 * random(0.9f, 1.1f);
      offspring.co2Tolerance = (co2Tolerance + mate.co2Tolerance) / 2 * random(0.9f, 1.1f);
      offspring.sulfurTolerance = (sulfurTolerance + mate.sulfurTolerance) / 2 * random(0.9f, 1.1f);
      offspring.position = PVector.add(position, PVector.random2D().mult(sizeFactor * 10));
      offspring.energy = (energy + mate.energy) / 4;
      energy /= 2;
      mate.energy /= 2;
      population.add(offspring);
    }
  }

  void mutate() {
    sizeFactor *= random(0.9f, 1.1f);
    energy += random(-10, 10);
    oxygenTolerance *= random(0.9f, 1.1f);
    co2Tolerance *= random(0.9f, 1.1f);
    sulfurTolerance *= random(0.9f, 1.1f);
    brain.mutate();
  }
}

void displayWorldParameterScreen() {
  background(30);
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Adjust World Parameters", width / 2, 100);
  
  textSize(16);
  text("Use the sliders below to configure the initial conditions of the simulation.", width / 2, 130);
  
  // Instructions for each slider
  textSize(14);
  textAlign(LEFT);
  text("Initial Population: Adjust the starting number of organisms.", width / 2 - 100, height / 2 - 90);
  text("Radiation Level: Adjust the ambient radiation level.", width / 2 - 100, height / 2 - 30);
  text("Oxygen Level: Adjust the oxygen level in the environment.", width / 2 - 100, height / 2 + 30);
  text("CO2 Level: Adjust the carbon dioxide level.", width / 2 - 100, height / 2 + 90);
  text("Sulfur Dioxide Level: Adjust the sulfur dioxide level.", width / 2 - 100, height / 2 + 150);
}
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  // Zoom in or out with constraints
  zoomLevel += e * -0.05;
  zoomLevel = constrain(zoomLevel, 0.5, 3.0); // Set zoom limits, adjust as necessary
}
void mouseDragged() {
  // Calculate the distance the mouse has been dragged
  float dx = (mouseX - pmouseX) / zoomLevel;
  float dy = (mouseY - pmouseY) / zoomLevel;
  
  // Update the camera position for panning
  cameraPos.x -= dx;
  cameraPos.y -= dy;

  // Optional: Constrain camera position within world boundaries
  cameraPos.x = constrain(cameraPos.x, 0, worldWidth);
  cameraPos.y = constrain(cameraPos.y, 0, worldHeight);
}
