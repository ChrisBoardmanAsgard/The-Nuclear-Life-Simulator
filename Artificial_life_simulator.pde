import controlP5.*;
import processing.sound.*;
import java.util.ArrayList;
import java.util.HashMap;
import processing.core.PVector;
import processing.event.MouseEvent;

// Global variables
ControlP5 cp5;
SoundFile reflectionSound;
ArrayList<Creature> creatures = new ArrayList<>();
ArrayList<Predator> predators = new ArrayList<>();
ArrayList<Food> foods = new ArrayList<>();
ArrayList<MutationPool> mutationPools = new ArrayList<>();
HashMap<String, SavedCreature> savedCreatures = new HashMap<>();
float simulationSpeed = 1.0;
boolean isPaused = false;
int radiationLevel = 50;
int maxPopulation = 100;
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
int currentState = STATE_MAIN_MENU;

ControlPanel mainMenuPanel, simulationPanel, setupPanel, descriptionPanel;
Slider popSlider, foodSlider, radiationSlider;

// Display setup
void settings() {
    fullScreen(P2D);
}

void setup() {
    cp5 = new ControlP5(this);
    frameRate(60);
    initializeSound();
    setupMainMenu();
    setupWorldParameterScreen();
    setupSimulationControls();
    setupDescriptionScreen();
    initializeFood(100);
    initializeMutationPools(3);
}
void initializeSound() {
    reflectionSound = new SoundFile(this, "Reflection of Times.wav");
    if (reflectionSound != null) {
        reflectionSound.loop();
    } else {
        println("Error: 'Reflection of Times.wav' not found in the 'data' folder.");
    }
}
// UI Elements: Main menu, world parameters, simulation controls, and description screen
void setupMainMenu() {
    mainMenuPanel = new ControlPanel();
    mainMenuPanel.addButton("Start Simulation", width / 2 - 100, height / 2, 200, 40, e -> {
        currentState = STATE_WORLD_PARAMS;
        mainMenuPanel.hide();
        setupPanel.show();
        showWorldParameterSliders();
    });
    mainMenuPanel.addButton("Description", width / 2 - 100, height / 2 + 60, 200, 40, e -> {
        currentState = STATE_DESCRIPTION;
        mainMenuPanel.hide();
        descriptionPanel.show();
    });
    mainMenuPanel.addButton("Exit", width / 2 - 100, height / 2 + 120, 200, 40, e -> exit());
    mainMenuPanel.show();
}

void setupWorldParameterScreen() {
    setupPanel = new ControlPanel();
    setupPanel.addButton("Back", width / 2 - 50, height - 60, 100, 30, e -> {
        setupPanel.hide();
        mainMenuPanel.show();
        currentState = STATE_MAIN_MENU;
        hideWorldParameterSliders();
    });
    setupPanel.addButton("Confirm", width / 2 - 50, height - 100, 100, 30, e -> {
        currentState = STATE_LOADING;
        setupPanel.hide();
        startLoading();
        hideWorldParameterSliders();
    });
    setupPanel.hide();

    popSlider = cp5.addSlider("Initial Population")
        .setPosition(width / 2 - 100, height / 2 - 80)
        .setSize(200, 20)
        .setRange(10, maxPopulation)
        .setValue(initialPopulation)
        .onRelease(e -> initialPopulation = (int) e.getController().getValue());

    foodSlider = cp5.addSlider("Initial Food Level")
        .setPosition(width / 2 - 100, height / 2 - 50)
        .setSize(200, 20)
        .setRange(50, 500)
        .setValue(100)
        .onRelease(e -> initializeFood((int) e.getController().getValue()));

    radiationSlider = cp5.addSlider("Radiation Level")
        .setPosition(width / 2 - 100, height / 2 - 20)
        .setSize(200, 20)
        .setRange(0, 100)
        .setValue(radiationLevel)
        .onRelease(e -> radiationLevel = (int) e.getController().getValue());

    hideWorldParameterSliders();
}

void showWorldParameterSliders() {
    popSlider.show();
    foodSlider.show();
    radiationSlider.show();
}

void hideWorldParameterSliders() {
    popSlider.hide();
    foodSlider.hide();
    radiationSlider.hide();
}

void setupSimulationControls() {
    simulationPanel = new ControlPanel();
    simulationPanel.addButton("Pause", 20, height - 50, 80, 30, e -> isPaused = !isPaused);
    simulationPanel.addButton("Speed +", 110, height - 50, 80, 30, e -> simulationSpeed = constrain(simulationSpeed + 0.2, 0.5, 2.0));
    simulationPanel.addButton("Speed -", 200, height - 50, 80, 30, e -> simulationSpeed = constrain(simulationSpeed - 0.2, 0.5, 2.0));
    simulationPanel.addButton("Reset", 290, height - 50, 80, 30, e -> initializeSimulation());
    simulationPanel.addButton("Main Menu", 380, height - 50, 100, 30, e -> {
        currentState = STATE_MAIN_MENU;
        mainMenuPanel.show();
        setupPanel.hide();
        simulationPanel.hide();
    });
    simulationPanel.hide();
}

void setupDescriptionScreen() {
    descriptionPanel = new ControlPanel();
    descriptionPanel.addButton("Back", width / 2 - 50, height - 60, 100, 30, e -> {
        descriptionPanel.hide();
        mainMenuPanel.show();
        currentState = STATE_MAIN_MENU;
    });
    descriptionPanel.hide();
}

// Loading process
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
            initializeSimulation();
            simulationPanel.show();
        }
    }
}

// Simulation setup
void initializeSimulation() {
    creatures.clear();
    predators.clear();
    for (int i = 0; i < initialPopulation; i++) {
        creatures.add(new Creature());
    }
    for (int i = 0; i < initialPopulation / 10; i++) {
        predators.add(new Predator());
    }
    isPaused = false;
}

void initializeFood(int amount) {
    foods.clear();
    for (int i = 0; i < amount; i++) {
        foods.add(new Food(random(worldWidth), random(worldHeight)));
    }
}

void initializeMutationPools(int numPools) {
    mutationPools.clear();
    for (int i = 0; i < numPools; i++) {
        mutationPools.add(new MutationPool(random(worldWidth), random(worldHeight), 100));
    }
}

// Replenish food
void replenishFood() {
    if (foods.size() < 100) {
        for (int i = 0; i < 5; i++) {
            foods.add(new Food(random(worldWidth), random(worldHeight)));
        }
    }
}

// Draw loop
void draw() {
    switch (currentState) {
        case STATE_MAIN_MENU:
            drawMainMenu();
            break;
        case STATE_WORLD_PARAMS:
            drawWorldParameterScreen();
            break;
        case STATE_LOADING:
            drawLoadingScreen();
            break;
        case STATE_SIMULATION:
            runSimulation();
            break;
        case STATE_DESCRIPTION:
            drawDescriptionScreen();
            break;
    }
}

// UI screens
void drawMainMenu() {
    background(100, 120, 180);
    textSize(36);
    fill(255);
    textAlign(CENTER);
    text("The Nuclear Life Simulator", width / 2, height / 4);

    textSize(18);
    fill(220);
    text("Developed by Christopher J Boardman", width / 2, height / 4 + 50);
    text("Instagram: @Wigan96", width / 2, height / 4 + 80);

    mainMenuPanel.show();
}

void drawWorldParameterScreen() {
    background(80, 100, 180);
    textSize(32);
    fill(255);
    textAlign(CENTER);
    text("Select World Parameters", width / 2, height / 4);
    setupPanel.show();
}

void drawLoadingScreen() {
    background(50);
    textSize(32);
    fill(255);
    textAlign(CENTER);
    text("Loading Simulation...", width / 2, height / 2 - 50);

    fill(100);
    rect(width / 4, height / 2, width / 2, 20);
    fill(0, 150, 0);
    rect(width / 4, height / 2, (width / 2) * (loadProgress / 100), 20);

    fill(255);
    textSize(16);
    text(int(loadProgress) + "%", width / 2, height / 2 + 50);
}

void runSimulation() {
    background(10, 30, 60);

    fill(255);
    textSize(14);
    textAlign(LEFT);
    text("FPS: " + int(frameRate), 10, 20);
    text("Simulation Speed: " + nf(simulationSpeed, 1, 2), 10, 40);
    text("Creature Count: " + creatures.size(), 10, 60);
    text("Predator Count: " + predators.size(), 10, 80);
    text("Food Count: " + foods.size(), 10, 100);
    text("Mutation Pools: " + mutationPools.size(), 10, 120);

    replenishFood();

    for (Food food : foods) food.display();
    for (MutationPool pool : mutationPools) pool.display();

    for (int i = creatures.size() - 1; i >= 0; i--) {
        Creature creature = creatures.get(i);
        creature.update();

        for (MutationPool pool : mutationPools) {
            if (pool.contains(creature) && random(100) < 10) {
                creature.mutate();
            }
        }

        if (!creature.isDead) creature.display();
        else creatures.remove(i);
    }

    for (Predator predator : predators) predator.updateAndHunt();
}

void drawDescriptionScreen() {
    background(60, 80, 150);
    textSize(32);
    fill(255);
    textAlign(CENTER);
    text("The Nuclear Life Simulator Description", width / 2, height / 4);

    textSize(18);
    fill(220);
    textAlign(LEFT);
    text("This simulation explores artificial life in a dynamic environment.", width / 4, height / 2 - 40);
    text("Creatures evolve, reproduce, and adapt based on their environment.", width / 4, height / 2);
    text("You can adjust parameters such as initial population, food levels,", width / 4, height / 2 + 40);
    text("and radiation to see how these factors influence evolution.", width / 4, height / 2 + 80);

    descriptionPanel.show();
}

// ControlPanel class for managing UI elements like buttons
class ControlPanel {
    HashMap<String, Button> buttons = new HashMap<>();

    void addButton(String label, int x, int y, int w, int h, CallbackListener callback) {
        Button button = cp5.addButton(label).setPosition(x, y).setSize(w, h).onClick(callback);
        buttons.put(label, button);
    }

    void show() { for (Button button : buttons.values()) button.show(); }
    void hide() { for (Button button : buttons.values()) button.hide(); }
}

// SavedCreature class to store attributes for saving and loading creatures
class SavedCreature {
    PVector position;
    float energy;
    int age;

    SavedCreature(Creature creature) {
        this.position = creature.position.copy();
        this.energy = creature.energy;
        this.age = creature.age;
    }
}

// MutationPool represents zones with a higher mutation chance
class MutationPool {
    PVector position;
    float radius;

    MutationPool(float x, float y, float r) {
        position = new PVector(x, y);
        radius = r;
    }

    boolean contains(Creature creature) {
        return PVector.dist(position, creature.position) < radius;
    }

    void display() {
        float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
        float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;
        noFill();
        stroke(255, 200, 50, 150);
        ellipse(displayX, displayY, radius * 2 * zoomLevel, radius * 2 * zoomLevel);
    }
}

// Creature class defines individual creatures with a neural network for behavior
class Creature {
    PVector position, velocity;
    float energy;
    int age = 0;
    boolean isDead = false;
    NeuralNetwork brain;
    float sizeFactor;
    int reproductionThreshold = 5;
    color creatureColor;
    float temperatureTolerance;
    float foodPreference;
    float agility;
    float visionRange;
    int foodEaten = 0;

    Creature() {
        position = new PVector(random(worldWidth), random(worldHeight));
        velocity = PVector.random2D().mult(random(1, 3));
        energy = 100 + random(50, 100);
        brain = new NeuralNetwork(4, 5);
        sizeFactor = random(1.0, 2.0);
        creatureColor = color(random(50, 255), random(50, 150), random(50, 150));
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

        float foodDistance = closestFoodDistance();
        float[] inputs = {foodDistance, energy / 100, temperatureTolerance, agility};
        float moveSpeed = brain.process(inputs) * agility * 3.0;

        energy -= 0.1 * simulationSpeed;
        position.add(velocity.copy().mult(moveSpeed * simulationSpeed));
        age++;

        if (position.x < 0 || position.x > worldWidth) velocity.x *= -1;
        if (position.y < 0 || position.y > worldHeight) velocity.y *= -1;

        if (energy < 120) seekFood();
        if (foodEaten >= reproductionThreshold) reproduce();
        if (age > 300 && random(1) < 0.002) mutate();
    }

    float closestFoodDistance() {
        float closestDist = visionRange;
        for (Food food : foods) {
            float dist = PVector.dist(position, food.position);
            if (dist < closestDist) closestDist = dist;
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
        if (creatures.size() < maxPopulation) {
            Creature offspring = new Creature();
            offspring.brain = brain.copy();
            if (random(100) < radiationLevel) offspring.brain.mutate();
            offspring.sizeFactor = sizeFactor * random(0.95, 1.05);
            offspring.creatureColor = color(
                red(creatureColor) * random(0.95, 1.05),
                green(creatureColor) * random(0.95, 1.05),
                blue(creatureColor) * random(0.95, 1.05)
            );
            offspring.temperatureTolerance = temperatureTolerance + random(-1, 1);
            offspring.foodPreference = foodPreference + random(-0.1, 0.1);
            offspring.agility = agility * random(0.95, 1.05);
            offspring.visionRange = visionRange * random(0.95, 1.05);
            creatures.add(offspring);
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
    }

    void display() {
        float displayX = (position.x - cameraPos.x) * zoomLevel + width / 2;
        float displayY = (position.y - cameraPos.y) * zoomLevel + height / 2;

        fill(creatureColor);
        noStroke();
        ellipse(displayX, displayY, 10 * sizeFactor * zoomLevel, 10 * sizeFactor * zoomLevel);
    }
}

// Predator class with hunting behavior
class Predator extends Creature {
    float strength;

    Predator() {
        super();
        strength = random(1.5, 3.0);
        creatureColor = color(200, 0, 0);
    }

    void updateAndHunt() {
        super.update();

        if (!isDead && !isPaused) {
            huntCreatures();
        }
    }

    void huntCreatures() {
        Creature closestPrey = null;
        float closestDist = visionRange;

        for (Creature prey : creatures) {
            float dist = PVector.dist(position, prey.position);
            if (dist < closestDist) {
                closestDist = dist;
                closestPrey = prey;
            }
        }

        if (closestPrey != null && closestDist < 20) {
            eat(closestPrey);
        } else if (closestPrey != null) {
            PVector direction = PVector.sub(closestPrey.position, position).normalize();
            velocity = direction.mult(1.5 * agility);
        }
    }

    void eat(Creature prey) {
        energy += prey.energy;
        creatures.remove(prey);
        if (energy > reproductionThreshold * 2) reproduce();
    }
}

// Food class for consumable resources
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
        noStroke();
        ellipse(displayX, displayY, 8 * zoomLevel, 8 * zoomLevel);
    }
}

// NeuralNetwork class for decision-making in creatures
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

// Mouse controls for zooming and panning
PVector lastMousePos;

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
