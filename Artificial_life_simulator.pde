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
float co2Level = 0.04;
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

int currentTrack = 0;  // To track which audio is currently playing
String[] trackFiles = {
    "data/Reflection of Times v1.wav",
    "data/Reflection of Times v2.wav",
    "data/The Nuclear Life Track 1 Fade InOut.wav",
    "data/The Nuclear Life Track 2 Fade InOut.wav"
};

PVector lastMousePos;

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
            displayWorldStats(); // Display world stats during simulation
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

    hideWorldParameterSliders();
}

void displayWorldParameterScreen() {
    fill(255);
    textAlign(CENTER);
    textSize(24);
    text("World Parameters", width / 2, height / 2 - 120);
    showWorldParameterSliders();
}

// Show and hide sliders
void showWorldParameterSliders() {
    cp5.getController("Initial Population").show();
    cp5.getController("Initial Food Level").show();
    cp5.getController("Radiation Level").show();
    cp5.getController("Temperature Level").show();
    cp5.getController("Oxygen Level").show();
    cp5.getController("CO2 Level").show();
}

void hideWorldParameterSliders() {
    cp5.getController("Initial Population").hide();
    cp5.getController("Initial Food Level").hide();
    cp5.getController("Radiation Level").hide();
    cp5.getController("Temperature Level").hide();
    cp5.getController("Oxygen Level").hide();
    cp5.getController("CO2 Level").hide();
}

void setupSimulationControls() {
    cp5.addButton("Pause")
        .setPosition(20, height - 50)
        .setSize(80, 30)
        .onClick(e -> isPaused = !isPaused);

    cp5.addButton("Speed +")
        .setPosition(110, height - 50)
        .setSize(80, 30)
        .onClick(e -> simulationSpeed = constrain(simulationSpeed + 0.2, 0.5, 2.0));

    cp5.addButton("Speed -")
        .setPosition(200, height - 50)
        .setSize(80, 30)
        .onClick(e -> simulationSpeed = constrain(simulationSpeed - 0.2, 0.5, 2.0));

    cp5.addButton("Next Track")
        .setPosition(290, height - 50)
        .setSize(100, 30)
        .onClick(e -> switchToNextTrack());

    cp5.addButton("Reset Simulation")
        .setPosition(400, height - 50)
        .setSize(120, 30)
        .onClick(e -> initializeSimulation());
}

void switchToNextTrack() {
    // Stop all sounds
    for (SoundFile track : tracks) {
        if (track != null && track.isPlaying()) {
            track.stop();
        }
    }

    // Increment track index and loop back if needed
    currentTrack = (currentTrack + 1) % tracks.length;

    // Play the next track
    if (tracks[currentTrack] != null) {
        tracks[currentTrack].loop();
    }
}

// Food initialization
void initializeFood(int amount) {
    foods.clear();
    for (int i = 0; i < amount; i++) {
        foods.add(new Food(random(worldWidth), random(worldHeight)));
    }
}

// Mutation pool initialization
void initializeMutationPools(int numPools) {
    mutationPools.clear();
    for (int i = 0; i < numPools; i++) {
        mutationPools.add(new MutationPool(random(worldWidth), random(worldHeight), 100));
    }
}

void replenishFood() {
    if (foods.size() < 100) {
        for (int i = 0; i < 5; i++) {
            foods.add(new Food(random(worldWidth), random(worldHeight)));
        }
    }
}

void initializeSimulation() {
    population.clear();
    for (int i = 0; i < initialPopulation; i++) {
        population.add(new Organism());
    }
    isPaused = false;
}

void startLoading() {
    loadProgress = 0;
    thread("loadingProcess");
}

void loadingProcess() {
    for (int i = 0; i <= 100; i++) {
        delay(30);
        loadProgress = i;
        if (i == 100) {
            currentState = STATE_SIMULATION;
        }
    }
}

void displayLoadingScreen() {
    fill(255);
    textAlign(CENTER);
    textSize(20);
    text("Loading... " + int(loadProgress) + "%", width / 2, height / 2);
}

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

// Organism class
class Organism {
    PVector position, velocity;
    float energy;
    int age = 0;
    boolean isDead = false;
    NeuralNetwork brain;
    float sizeFactor;
    int reproductionThreshold = 5;
    color organismColor;
    float temperatureTolerance;
    float foodPreference;
    float agility;
    float visionRange;
    int foodEaten = 0;
    boolean needsOxygen = random(1) < 0.5;
    float geneticInstability = 0;
    boolean hasMembrane = true;  // Ensure organisms always have a membrane
    boolean hasEye = true;

    Organism() {
        position = new PVector(random(worldWidth), random(worldHeight));
        velocity = PVector.random2D().mult(random(1, 3));
        energy = 100 + random(50, 100);
        brain = new NeuralNetwork(4, 5);
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

        if (needsOxygen && oxygenLevel > 0.1) {
            oxygenLevel -= 0.001 * simulationSpeed;
            energy += 0.2;
        } else if (!needsOxygen && co2Level > 0.01) {
            co2Level -= 0.0005 * simulationSpeed;
            energy += 0.1;
        } else {
            energy -= 0.5;
        }

        float[] inputs = {closestFoodDistance(), energy / 100, temperatureTolerance, agility};
        float moveSpeed = brain.process(inputs) * agility * 3.0;
        energy -= 0.1 * simulationSpeed;
        position.add(velocity.copy().mult(moveSpeed * simulationSpeed));

        // Handle wall collisions
        if (position.x < 0 || position.x > worldWidth) {
            velocity.x *= -1;
            position.x = constrain(position.x, 0, worldWidth);
        }
        if (position.y < 0 || position.y > worldHeight) {
            velocity.y *= -1;
            position.y = constrain(position.y, 0, worldHeight);
        }

        age++;

        if (energy < 120) seekFood();
        if (foodEaten >= reproductionThreshold) reproduce();
        if (age > 300 && random(1) < 0.002) mutate();
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
            velocity = direction.mult(1.5 * agility);
        }
    }

    void eat(Food food) {
        energy += food.energy;
        foods.remove(food);
        foodEaten++;
    }

    void reproduce() {
        if (population.size() < maxPopulation) {
            Organism offspring = new Organism();
            offspring.brain = brain.copy();
            offspring.sizeFactor = sizeFactor * random(0.95, 1.05);
            offspring.organismColor = color(
                red(organismColor) * random(0.95, 1.05),
                green(organismColor) * random(0.95, 1.05),
                blue(organismColor) * random(0.95, 1.05)
            );
            offspring.position = PVector.add(position, PVector.random2D().mult(sizeFactor * 10));
            population.add(offspring);
            energy /= 2;
            foodEaten = 0;
        }
    }

    void mutate() {
        velocity.mult(1 + random(-0.1, 0.1));
        energy += random(-10, 10);
        brain.mutate();
        sizeFactor *= random(0.95, 1.05);
        temperatureTolerance += random(-1, 1);
        foodPreference += random(-0.1, 0.1);
        agility *= random(0.95, 1.05);
        visionRange *= random(0.95, 1.05);
        geneticInstability = max(0, geneticInstability - random(0, 5));
    }

    void display() {
        float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
        float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;

        // Draw membrane
        if (hasMembrane) {
            fill(255, 200, 200, 150);
            ellipse(displayX, displayY, 12 * sizeFactor * zoomLevel, 12 * sizeFactor * zoomLevel);
        }

        // Draw organism body
        fill(organismColor);
        ellipse(displayX, displayY, 10 * sizeFactor * zoomLevel, 10 * sizeFactor * zoomLevel);

        // Draw eye
        if (hasEye) {
            fill(0);
            float eyeSize = map(sizeFactor, 1.0, 2.0, 1.5, 3.5) * zoomLevel;
            float eyeX = displayX + (velocity.x * 0.5);
            float eyeY = displayY + (velocity.y * 0.5);
            ellipse(eyeX, eyeY, eyeSize, eyeSize);
        }
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
}

// NeuralNetwork class
class NeuralNetwork {
    int numInputs, numHidden;
    float[] inputWeights, hiddenWeights;

    NeuralNetwork(int numInputs, int numHidden) {
        this.numInputs = numInputs;
        this.numHidden = numHidden;
        inputWeights = new float[numInputs * numHidden];
        hiddenWeights = new float[numHidden];
        initializeWeights();
    }

    void initializeWeights() {
        for (int i = 0; i < inputWeights.length; i++) inputWeights[i] = random(-1, 1);
        for (int i = 0; i < hiddenWeights.length; i++) hiddenWeights[i] = random(-1, 1);
    }

    float process(float[] inputs) {
        float[] hiddenLayer = new float[numHidden];
        for (int i = 0; i < numHidden; i++) {
            float sum = 0;
            for (int j = 0; j < numInputs; j++) {
                sum += inputs[j] * inputWeights[j + i * numInputs];
            }
            hiddenLayer[i] = tanh(sum);
        }

        float output = 0;
        for (int i = 0; i < numHidden; i++) {
            output += hiddenLayer[i] * hiddenWeights[i];
        }
        return constrain(output, 0, 1);
    }

    NeuralNetwork copy() {
        NeuralNetwork clone = new NeuralNetwork(numInputs, numHidden);
        arrayCopy(inputWeights, clone.inputWeights);
        arrayCopy(hiddenWeights, clone.hiddenWeights);
        return clone;
    }

    void mutate() {
        int index = (int) random(inputWeights.length);
        inputWeights[index] += random(-0.1, 0.1);
        index = (int) random(hiddenWeights.length);
        hiddenWeights[index] += random(-0.1, 0.1);
    }
}

float tanh(float x) {
    float exp2x = exp(2 * x);
    return (exp2x - 1) / (exp2x + 1);
}

// Run simulation function
void runSimulation() {
    replenishFood();

    for (Food food : foods) {
        food.display();
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

// Display world stats
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
}

// Mouse controls for zoom and drag
void mouseWheel(MouseEvent event) {
    float e = event.getCount();
    zoomLevel = constrain(zoomLevel - e * 0.1, 0.5, 3.0);
}

void mousePressed() {
    lastMousePos = new PVector(mouseX, mouseY);
}

void mouseDragged() {
    float dx = mouseX - lastMousePos.x;
    float dy = mouseY - lastMousePos.y;
    cameraPos.x -= dx / zoomLevel;
    cameraPos.y -= dy / zoomLevel;
    lastMousePos.set(mouseX, mouseY);
}
