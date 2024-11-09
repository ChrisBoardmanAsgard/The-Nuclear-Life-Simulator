import controlP5.*;
import processing.sound.*;
import java.util.ArrayList;
import processing.core.PVector;

// Global variables
ControlP5 cp5;
SoundFile[] tracks = new SoundFile[4];
ArrayList<Organism> population = new ArrayList<>();
ArrayList<Food> foods = new ArrayList<>();
ArrayList<MutationPool> mutationPools = new ArrayList<>();
float simulationSpeed = 1.0;
boolean isPaused = false;
int radiationLevel = 50;
int temperatureLevel = 20;
float oxygenLevel = 21.0;
float co2Level = 0.04f;
float sulfurDioxideLevel = 0.01f;
int maxPopulation = 200;
int initialPopulation = 20;

int worldWidth = 3000;
int worldHeight = 3000;
PVector cameraPos = new PVector(worldWidth / 2, worldHeight / 2);
float zoomLevel = 1.0;
float loadProgress = 0;

final int STATE_MAIN_MENU = 0;
final int STATE_WORLD_PARAMS = 1;
final int STATE_LOADING = 2;
final int STATE_SIMULATION = 3;
final int STATE_DESCRIPTION = 4;
final int STATE_CREDITS = 5;
int currentState = STATE_MAIN_MENU;

int currentTrack = 0;
String[] trackFiles = {
  "data/Reflection of Times v1.wav",
  "data/Reflection of Times v2.wav",
  "data/The Nuclear Life Track 1 Fade InOut.wav",
  "data/The Nuclear Life Track 2 Fade InOut.wav"
};


// Setup and initialization methods
void settings() {
  fullScreen(P2D);
  smooth(4);
}

void setup() {
  cp5 = new ControlP5(this);
  frameRate(60);
  initializeSound();
  setupMainMenu();
  setupWorldParameterScreen();
  setupSimulationControls();
  initializeFood(100);
  initializeMutationPools(3);
  initializeSimulation();
}

void draw() {
  switch (currentState) {
    case STATE_MAIN_MENU:
      background(30, 30, 30);
      displayMainMenu();
      break;
    case STATE_WORLD_PARAMS:
      background(50, 50, 80);
      displayWorldParameterScreen();
      break;
    case STATE_LOADING:
      background(40, 40, 40);
      displayLoadingScreen();
      break;
    case STATE_SIMULATION:
      background(10, 30, 60);
      runSimulation();
      displayWorldStats();
      break;
    case STATE_DESCRIPTION:
      background(20, 40, 60);
      displayDescriptionScreen();
      break;
    case STATE_CREDITS:
      background(20, 40, 60);
      displayCreditsScreen();
      break;
  }
}

// Sound initialization
void initializeSound() {
  for (int i = 0; i < trackFiles.length; i++) {
    tracks[i] = new SoundFile(this, trackFiles[i]);
    if (tracks[i] != null) {
      if (i == 0) {
        tracks[i].loop();
      }
    } else {
      println("Error: Sound file " + trackFiles[i] + " not found or failed to load.");
    }
  }
}

// Main menu setup
void setupMainMenu() {
  cp5.addButton("Start Simulation")
    .setPosition(width / 2 - 100, height / 2)
    .setSize(200, 40)
    .onClick(e -> {
      currentState = STATE_WORLD_PARAMS;
      hideMainMenu();
      showWorldParameterSliders();
    });

  cp5.addButton("Description")
    .setPosition(width / 2 - 100, height / 2 + 60)
    .setSize(200, 40)
    .onClick(e -> {
      currentState = STATE_DESCRIPTION;
      hideMainMenu();
    });

  cp5.addButton("Credits")
    .setPosition(width / 2 - 100, height / 2 + 120)
    .setSize(200, 40)
    .onClick(e -> {
      currentState = STATE_CREDITS;
      hideMainMenu();
    });

  cp5.addButton("Exit")
    .setPosition(width / 2 - 100, height / 2 + 180)
    .setSize(200, 40)
    .onClick(e -> exit());
}

void showMainMenu() {
  cp5.getController("Start Simulation").show();
  cp5.getController("Description").show();
  cp5.getController("Credits").show();
  cp5.getController("Exit").show();
}

void hideMainMenu() {
  cp5.getController("Start Simulation").hide();
  cp5.getController("Description").hide();
  cp5.getController("Credits").hide();
  cp5.getController("Exit").hide();
}

void displayMainMenu() {
  fill(255);
  textAlign(CENTER);
  textSize(32);
  text("The Nuclear Life Simulator", width / 2, height / 2 - 100);
}

// World parameter setup
void setupWorldParameterScreen() {
  cp5.addButton("Back")
    .setPosition(width / 2 - 50, height - 60)
    .setSize(100, 30)
    .onClick(e -> {
      currentState = STATE_MAIN_MENU;
      hideWorldParameterSliders();
      showMainMenu();
    });

  cp5.addButton("Confirm")
    .setPosition(width / 2 - 50, height - 100)
    .setSize(100, 30)
    .onClick(e -> {
      currentState = STATE_LOADING;
      hideWorldParameterSliders();
      startLoading();
    });

  cp5.addSlider("Initial Population")
    .setPosition(width / 2 - 100, height / 2 - 80)
    .setSize(200, 20)
    .setRange(10, maxPopulation)
    .setValue(initialPopulation)
    .onRelease(e -> initialPopulation = (int) e.getController().getValue());

  cp5.addSlider("Initial Food Level")
    .setPosition(width / 2 - 100, height / 2 - 50)
    .setSize(200, 20)
    .setRange(50, 500)
    .setValue(100)
    .onRelease(e -> initializeFood((int) e.getController().getValue()));

  cp5.addSlider("Radiation Level")
    .setPosition(width / 2 - 100, height / 2 - 20)
    .setSize(200, 20)
    .setRange(0, 100)
    .setValue(radiationLevel)
    .onRelease(e -> radiationLevel = (int) e.getController().getValue());

  cp5.addSlider("Temperature Level")
    .setPosition(width / 2 - 100, height / 2 + 10)
    .setSize(200, 20)
    .setRange(-20, 50)
    .setValue(temperatureLevel)
    .onRelease(e -> temperatureLevel = (int) e.getController().getValue());

  cp5.addSlider("Oxygen Level")
    .setPosition(width / 2 - 100, height / 2 + 40)
    .setSize(200, 20)
    .setRange(0, 100)
    .setValue(oxygenLevel)
    .onRelease(e -> oxygenLevel = e.getController().getValue());

  cp5.addSlider("CO2 Level")
    .setPosition(width / 2 - 100, height / 2 + 70)
    .setSize(200, 20)
    .setRange(0, 100)
    .setValue(co2Level)
    .onRelease(e -> co2Level = e.getController().getValue());

  cp5.addSlider("Sulfur Dioxide Level")
    .setPosition(width / 2 - 100, height / 2 + 100)
    .setSize(200, 20)
    .setRange(0, 100)
    .setValue(sulfurDioxideLevel)
    .onRelease(e -> sulfurDioxideLevel = e.getController().getValue());

  hideWorldParameterSliders();
}

void showWorldParameterSliders() {
  cp5.getController("Initial Population").show();
  cp5.getController("Initial Food Level").show();
  cp5.getController("Radiation Level").show();
  cp5.getController("Temperature Level").show();
  cp5.getController("Oxygen Level").show();
  cp5.getController("CO2 Level").show();
  cp5.getController("Sulfur Dioxide Level").show();
}

void hideWorldParameterSliders() {
  cp5.getController("Initial Population").hide();
  cp5.getController("Initial Food Level").hide();
  cp5.getController("Radiation Level").hide();
  cp5.getController("Temperature Level").hide();
  cp5.getController("Oxygen Level").hide();
  cp5.getController("CO2 Level").hide();
  cp5.getController("Sulfur Dioxide Level").hide();
}

void displayWorldParameterScreen() {
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("World Parameters", width / 2, height / 2 - 120);
}

// Display description and credits screens
void displayDescriptionScreen() {
  fill(255);
  textAlign(CENTER);
  textSize(18);
  text("The Nuclear Life Simulator", width / 2, height / 2 - 40);
  text("Observe the evolution of organisms in a radioactive environment.", width / 2, height / 2);
  text("Each creature adapts based on its genetic traits,", width / 2, height / 2 + 20);
  text("with factors like radiation, temperature, and food availability", width / 2, height / 2 + 40);
  text("influencing survival, reproduction, and mutation.", width / 2, height / 2 + 60);
}

void displayCreditsScreen() {
  fill(255);
  textAlign(CENTER);
  textSize(18);
  text("Credits", width / 2, height / 2 - 40);
  text("Developed by Christopher J Boardman", width / 2, height / 2);
  text("Music by Jake Rae & Christopher J Boardman", width / 2, height / 2 + 40);
}

// Initialize simulation state and population
void initializeSimulation() {
  population.clear();
  for (int i = 0; i < initialPopulation; i++) {
    population.add(new Organism());
  }
  isPaused = false;
}

// Start the loading process for the simulation
void startLoading() {
  loadProgress = 0;
  thread("loadingProcess");
}

// Simulate loading screen with progress
void loadingProcess() {
  for (int i = 0; i <= 100; i++) {
    delay(30); // Simulate loading delay
    loadProgress = i;
    if (i == 100) {
      currentState = STATE_SIMULATION;
    }
  }
}

// Display loading screen with progress indicator
void displayLoadingScreen() {
  fill(255);
  textAlign(CENTER);
  textSize(20);
  text("Loading... " + int(loadProgress) + "%", width / 2, height / 2);
}

// Set up simulation-specific controls
void setupSimulationControls() {
  cp5.addButton("Pause/Resume")
    .setPosition(20, height - 50)
    .setSize(100, 30)
    .onClick(e -> isPaused = !isPaused);

  cp5.addButton("Restart")
    .setPosition(130, height - 50)
    .setSize(100, 30)
    .onClick(e -> initializeSimulation());
}

// Run the simulation and update elements
void runSimulation() {
  if (!isPaused) {
    replenishFood();
    for (Food food : foods) {
      food.display();
    }
    for (MutationPool pool : mutationPools) {
      pool.display();
      pool.affectOrganisms(population);
    }
    for (int i = population.size() - 1; i >= 0; i--) {
      Organism organism = population.get(i);
      organism.update();
      if (!organism.isDead) {
        organism.display();
      } else {
        population.remove(i);
      }
    }
  }
}

// Ensure food supply remains stable in the ecosystem
void replenishFood() {
  if (foods.size() < 100) {
    for (int i = 0; i < 5; i++) {
      foods.add(new Food(random(worldWidth), random(worldHeight)));
    }
  }
}

// Display world statistics on screen
void displayWorldStats() {
  fill(255);
  textAlign(LEFT);
  textSize(16);
  text("Population: " + population.size(), 20, 30);
  text("Food Count: " + foods.size(), 20, 50);
  text("Radiation Level: " + radiationLevel, 20, 70);
  text("Temperature Level: " + temperatureLevel, 20, 90);
  text("Oxygen Level: " + oxygenLevel, 20, 110);
  text("CO2 Level: " + co2Level, 20, 130);
  text("Sulfur Dioxide Level: " + sulfurDioxideLevel, 20, 150);
}

// Initialize food in the simulation
void initializeFood(int foodCount) {
  foods.clear();
  for (int i = 0; i < foodCount; i++) {
    foods.add(new Food(random(worldWidth), random(worldHeight)));
  }
}

// Initialize mutation pools in the simulation
void initializeMutationPools(int poolCount) {
  mutationPools.clear();
  for (int i = 0; i < poolCount; i++) {
    float x = random(worldWidth);
    float y = random(worldHeight);
    float radius = random(50, 150);
    mutationPools.add(new MutationPool(x, y, radius));
  }
}

// Organism class
class Organism {
  PVector position, velocity;
  float energy;
  int age = 0;
  boolean isDead = false;
  NeuralNetwork brain;
  float sizeFactor;
  color organismColor;
  float temperatureTolerance;
  float foodPreference;
  float agility;
  float visionRange;
  boolean hasMembrane = true;
  boolean hasEye = true;
  float desireToReproduce = 0;

  Organism() {
    position = new PVector(random(worldWidth), random(worldHeight));
    velocity = PVector.random2D().mult(random(1, 3));
    energy = 100 + random(50, 100);
    brain = new NeuralNetwork(5, 5, 3); // Adjusted input count to match inputs
    sizeFactor = random(1.0, 2.0);
    organismColor = color(random(50, 255), random(50, 150), random(50, 150));
    temperatureTolerance = random(15, 30);
    foodPreference = random(0, 1);
    agility = random(0.5, 1.5);
    visionRange = random(50, 150);
  }

  void update() {
    if (isPaused || isDead || energy <= 0) {
      isDead = true;
      return;
    }

    float[] inputs = {closestFoodDistance() / visionRange, energy / 100, age / 100.0, desireToReproduce, visionRange / 150};
    float[] outputs = brain.process(inputs);

    float moveSpeed = outputs[0] * agility * 3.0;
    float reproductiveDrive = outputs[1];
    float avoidOthers = outputs[2];

    if (reproductiveDrive > 0.8 && energy > 150) {
      desireToReproduce += 0.1;
      findMate();
    } else if (energy < 120) {
      seekFood();
    }

    if (avoidOthers > 0.5) {
      position.add(velocity.copy().mult(moveSpeed * simulationSpeed).rotate(PI / 4));
    } else {
      position.add(velocity.copy().mult(moveSpeed * simulationSpeed));
    }

    if (position.x < 0 || position.x > worldWidth) velocity.x *= -1;
    if (position.y < 0 || position.y > worldHeight) velocity.y *= -1;

    age++;
    energy -= 0.1; // Energy consumption

    if (energy > 180) reproduce();
    if (age > 300 && random(1) < 0.002) mutate();
  }

  void findMate() {
    Organism mate = null;
    float closestDist = visionRange;
    for (Organism other : population) {
      if (other != this && !other.isDead) {
        float dist = PVector.dist(position, other.position);
        if (dist < closestDist && other.desireToReproduce > 0.8) {
          closestDist = dist;
          mate = other;
        }
      }
    }

    if (mate != null && closestDist < 15) {
      energy -= 50;
      mate.energy -= 50;
      reproduceWith(mate);
      desireToReproduce = 0;
      mate.desireToReproduce = 0;
    }
  }

  void reproduceWith(Organism mate) {
    if (population.size() < maxPopulation) {
      Organism offspring = new Organism();
      offspring.brain = brain.copy();
      offspring.brain.mutate();
      offspring.sizeFactor = (sizeFactor + mate.sizeFactor) / 2 * random(0.95f, 1.05f);
      offspring.organismColor = color(
        (red(organismColor) + red(mate.organismColor)) / 2 * random(0.95f, 1.05f),
        (green(organismColor) + green(mate.organismColor)) / 2 * random(0.95f, 1.05f),
        (blue(organismColor) + blue(mate.organismColor)) / 2 * random(0.95f, 1.05f)
      );
      offspring.position = PVector.add(position, PVector.random2D().mult(sizeFactor * 10));
      offspring.energy = energy / 2;  // Share energy with offspring
      energy /= 2;  // Reduce parent's energy
      population.add(offspring);
    }
  }

  void reproduce() {
    if (population.size() < maxPopulation) {
      Organism offspring = new Organism();
      offspring.brain = brain.copy();
      offspring.brain.mutate();
      offspring.sizeFactor = sizeFactor * random(0.95f, 1.05f);
      offspring.organismColor = color(
        red(organismColor) * random(0.95f, 1.05f),
        green(organismColor) * random(0.95f, 1.05f),
        blue(organismColor) * random(0.95f, 1.05f)
      );
      offspring.position = PVector.add(position, PVector.random2D().mult(sizeFactor * 10));
      offspring.energy = energy / 2;  // Share energy with offspring
      energy /= 2;  // Reduce parent's energy
      population.add(offspring);
    }
  }

  void seekFood() {
    Food closestFood = null;
    float closestDist = visionRange;
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
      velocity = direction.mult(1.5f * agility);
    }
  }

  float closestFoodDistance() {
    float closestDist = visionRange;
    for (Food food : foods) {
      float dist = PVector.dist(position, food.position);
      if (dist < closestDist) {
        closestDist = dist;
      }
    }
    return closestDist;
  }

  void eat(Food food) {
    energy += food.energy + 20;
    foods.remove(food);
  }

  void display() {
    float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
    float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;

    if (hasMembrane) {
      fill(255, 200, 200, 150);
      ellipse(displayX, displayY, 12 * sizeFactor * zoomLevel, 12 * sizeFactor * zoomLevel);
    }

    fill(organismColor);
    ellipse(displayX, displayY, 10 * sizeFactor * zoomLevel, 10 * sizeFactor * zoomLevel);

    if (hasEye) {
      fill(0);
      float eyeSize = map(sizeFactor, 1.0f, 2.0f, 1.5f, 3.5f) * zoomLevel;
      float eyeX = displayX + (velocity.x * 0.5f);
      float eyeY = displayY + (velocity.y * 0.5f);
      ellipse(eyeX, eyeY, eyeSize, eyeSize);
    }
  }

  void mutate() {
    sizeFactor *= random(0.9f, 1.1f);
    energy += random(-10, 10);
    temperatureTolerance += random(-1, 1);
    agility *= random(0.9f, 1.1f);
    visionRange *= random(0.9f, 1.1f);
    brain.mutate();
  }
}

// Food class
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
    fill(0, 180, 0);
    ellipse(displayX, displayY, 8 * zoomLevel, 8 * zoomLevel);
  }
}

// MutationPool class
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
    stroke(255, 200, 50, 150);
    ellipse(displayX, displayY, radius * 2 * zoomLevel, radius * 2 * zoomLevel);
  }

  void affectOrganisms(ArrayList<Organism> organisms) {
    for (Organism org : organisms) {
      float dist = PVector.dist(org.position, position);
      if (dist < radius) {
        org.mutate();
        if (random(1) < 0.05f) {
          org.energy *= random(0.8f, 1.2f);
          org.sizeFactor *= random(0.9f, 1.1f);
        }
      }
    }
  }
}

// NeuralNetwork class
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

  void mutate() {
    int i = (int) random(numHidden);
    int j = (int) random(numInputs);
    inputWeights[i][j] += random(-0.1f, 0.1f);

    i = (int) random(numOutputs);
    j = (int) random(numHidden);
    hiddenWeights[i][j] += random(-0.1f, 0.1f);
  }
}

// Activation function for the neural network
float tanh(float x) {
  return (float) Math.tanh(x);
}
// Mouse variables for panning
PVector lastMousePos;
boolean isDragging = false;

// Handle mouse dragging for panning
void mousePressed() {
  lastMousePos = new PVector(mouseX, mouseY); // Capture initial mouse position
  isDragging = true;
}

void mouseDragged() {
  if (isDragging) {
    PVector currentMousePos = new PVector(mouseX, mouseY);
    PVector delta = PVector.sub(currentMousePos, lastMousePos); // Calculate movement delta
    cameraPos.x -= delta.x / zoomLevel; // Adjust camera position based on delta and zoom
    cameraPos.y -= delta.y / zoomLevel;
    lastMousePos = currentMousePos; // Update last position for continuous drag
  }
}

void mouseReleased() {
  isDragging = false; // Stop dragging when the mouse is released
}

// Handle mouse wheel for zooming in and out
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  float zoomFactor = 1.1; // Set the zoom factor (1.1 for zooming in/out by 10%)
  
  if (e > 0) { // Scroll down to zoom out
    zoomLevel /= zoomFactor;
  } else if (e < 0) { // Scroll up to zoom in
    zoomLevel *= zoomFactor;
  }
  
  // Constrain zoom level to avoid extreme zooming
  zoomLevel = constrain(zoomLevel, 0.5, 3.0); // Adjust min and max as desired
}
