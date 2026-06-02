import java.awt.*;
import java.awt.event.*;
import java.awt.geom.Ellipse2D;
import javax.swing.*;
import javax.swing.event.*;
import javax.sound.sampled.*;
import java.io.*;
import java.util.*;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * The Nuclear Life Simulator - Java Rewrite v2.0
 * Complete overhaul of the original Processing version.
 * Pure Java 21, no external dependencies beyond JDK.
 * Features overhauled neural nets (heritable + evolving), gas effects,
 * generation tracking, hard population caps, settings, empty world,
 * proper UI state management, camera controls, and more.
 */
public class NuclearLifeSimulator extends JFrame {
    private static final long serialVersionUID = 1L;

    // Application constants
    private static final String VERSION = "2.0 - Java Rewrite";
    private static final int WORLD_WIDTH = 4000;
    private static final int WORLD_HEIGHT = 4000;
    private static final int MAX_POPULATION = 280;
    private static final double BASE_ENERGY_DRAIN = 0.04;

    // UI / Window
    private static final int DEFAULT_WIDTH = 1280;
    private static final int DEFAULT_HEIGHT = 800;

    // States
    enum State {
        MAIN_MENU, WORLD_PARAMS, LOADING, SIMULATION, DESCRIPTION, CREDITS, SETTINGS
    }
    private State currentState = State.MAIN_MENU;

    // World parameters (from sliders / presets)
    private int initialPopulation = 25;
    private int radiationLevel = 45;
    private double oxygenLevel = 20.5;
    private double co2Level = 0.035;
    private double sulfurDioxideLevel = 0.012;

    // Simulation runtime state
    private List<Organism> population = new CopyOnWriteArrayList<>();
    private List<Food> foods = new CopyOnWriteArrayList<>();
    private List<Poop> poops = new CopyOnWriteArrayList<>();
    private List<MutationPool> mutationPools = new CopyOnWriteArrayList<>();

    private int generationCount = 0; // max generation reached
    private int births = 0;
    private int deaths = 0;
    private boolean isPaused = false;
    private double simulationSpeed = 1.0;
    private Organism selectedCreature = null;

    // Camera
    private double camX = WORLD_WIDTH / 2.0;
    private double camY = WORLD_HEIGHT / 2.0;
    private double zoom = 1.0;
    private int lastMouseX, lastMouseY;
    private boolean dragging = false;

    // UI Components
    private JPanel mainPanel;
    private SimCanvas simCanvas;
    private JPanel controlBar;
    private JLabel statsLabel;
    private JLabel selectedLabel;
    private JSlider speedSlider;

    // Live labels in new top/side UI (for pop etc)
    private JLabel topPopLabel;
    private JLabel topGenLabel;
    private JLabel sideEnvLabel;
    private JButton pauseBtn, restartBtn, nextTrackBtn, speedUpBtn, speedDownBtn;
    private JButton addFoodBtn, addPoolBtn, backToMenuBtn, spawnBtn;

    // World param controls (dynamic)
    private JPanel paramsPanel;
    private JSlider popSlider, radSlider;
    private JSlider o2Slider, co2Slider, so2Slider;
    private JLabel popVal, radVal, o2Val, co2Val, so2Val;

    // Audio
    private AudioManager audioManager;

    // History for live graphs (pop, gen, gases etc)
    private java.util.List<Integer> popHistory = new java.util.ArrayList<>();
    private java.util.List<Integer> genHistory = new java.util.ArrayList<>();
    private java.util.List<Double> o2History = new java.util.ArrayList<>();
    private java.util.List<Double> co2History = new java.util.ArrayList<>();
    private java.util.List<Double> so2History = new java.util.ArrayList<>();
    private java.util.List<Integer> radHistory = new java.util.ArrayList<>();
    private static final int MAX_HISTORY = 450;
    private int historyTick = 0;

    // UI for graphs + improved layout
    private StatsGraphPanel graphsPanel;
    private JPanel topBar;
    private JPanel sidePanel;

    // Loading
    private int loadProgress = 0;
    private javax.swing.Timer loadingTimer;
    private JProgressBar loadingProgressBar; // stored ref for reliable updates

    // Game loop timer (safe on EDT)
    private javax.swing.Timer gameTimer;
    private static final int FPS = 60;

    // Random
    private final Random rng = new Random();

    public NuclearLifeSimulator() {
        super("The Nuclear Life Simulator " + VERSION);
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(DEFAULT_WIDTH, DEFAULT_HEIGHT);
        setLocationRelativeTo(null);
        setResizable(true);
        setMinimumSize(new Dimension(900, 600));

        // Dark theme-ish
        getContentPane().setBackground(new Color(18, 18, 28));
        UIManager.put("Label.foreground", Color.WHITE);
        UIManager.put("Button.background", new Color(40, 44, 60));
        UIManager.put("Button.foreground", Color.WHITE);
        UIManager.put("Button.opaque", Boolean.TRUE);
        UIManager.put("Button.border", javax.swing.BorderFactory.createLineBorder(new Color(65, 75, 95), 1));
        UIManager.put("Button.select", new Color(30, 35, 50));
        UIManager.put("Button.focus", new Color(80, 140, 100));
        UIManager.put("Panel.background", new Color(25, 26, 38));
        UIManager.put("Slider.background", new Color(25, 26, 38));
        UIManager.put("Slider.foreground", Color.WHITE);

        // Readable fonts for main menu, params, sliders, HUD etc. (larger + consistent SansSerif for dark theme)
        Font uiLabelFont = new Font("SansSerif", Font.PLAIN, 14);
        Font uiButtonFont = new Font("SansSerif", Font.PLAIN, 15);
        UIManager.put("Label.font", uiLabelFont);
        UIManager.put("Button.font", uiButtonFont);
        UIManager.put("Slider.font", uiLabelFont);
        UIManager.put("ProgressBar.font", uiLabelFont);
        UIManager.put("TextArea.font", new Font("SansSerif", Font.PLAIN, 16));
        UIManager.put("TextField.font", uiLabelFont);
        UIManager.put("CheckBox.font", uiLabelFont);
        UIManager.put("RadioButton.font", uiLabelFont);

        audioManager = new AudioManager();
        audioManager.loadTracks();

        buildUI();

        // Start with main menu
        switchToState(State.MAIN_MENU);

        setVisible(true);

        // Keyboard shortcuts at frame level
        setupGlobalKeys();
    }

    private void buildUI() {
        mainPanel = new JPanel(new CardLayout());
        mainPanel.setBackground(new Color(18, 18, 28));

        // --- SIMULATION VIEW ---
        simCanvas = new SimCanvas();
        simCanvas.setPreferredSize(new Dimension(DEFAULT_WIDTH, DEFAULT_HEIGHT - 90));

        controlBar = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 6));
        controlBar.setBackground(new Color(22, 23, 34));
        controlBar.setBorder(BorderFactory.createEmptyBorder(4, 6, 4, 6));

        pauseBtn = new JButton("Pause");
        pauseBtn.addActionListener(e -> togglePause());

        restartBtn = new JButton("Restart");
        restartBtn.addActionListener(e -> restartSimulation());

        nextTrackBtn = new JButton("Next Track");
        nextTrackBtn.addActionListener(e -> audioManager.nextTrack());

        speedDownBtn = new JButton("Slow");
        speedDownBtn.addActionListener(e -> adjustSpeed(-0.25));

        speedUpBtn = new JButton("Fast");
        speedUpBtn.addActionListener(e -> adjustSpeed(0.25));

        addFoodBtn = new JButton("+Food");
        addFoodBtn.addActionListener(e -> addRandomFood(8));

        addPoolBtn = new JButton("+MutPool");
        addPoolBtn.addActionListener(e -> addRandomMutationPool());

        spawnBtn = new JButton("Spawn Life");
        spawnBtn.addActionListener(e -> spawnFounders(8));

        backToMenuBtn = new JButton("Main Menu");
        backToMenuBtn.addActionListener(e -> {
            stopSimulationLoop();
            switchToState(State.MAIN_MENU);
        });

        // Apply dark style so white fonts are visible on buttons (fixes white-on-white issue)
        applyDarkButtonStyle(pauseBtn);
        applyDarkButtonStyle(restartBtn);
        applyDarkButtonStyle(nextTrackBtn);
        applyDarkButtonStyle(speedDownBtn);
        applyDarkButtonStyle(speedUpBtn);
        applyDarkButtonStyle(addFoodBtn);
        applyDarkButtonStyle(addPoolBtn);
        applyDarkButtonStyle(spawnBtn);
        applyDarkButtonStyle(backToMenuBtn);

        speedSlider = new JSlider(25, 400, 100);
        speedSlider.setMajorTickSpacing(100);
        speedSlider.setMinorTickSpacing(25);
        speedSlider.setPaintTicks(true);
        speedSlider.setPaintLabels(false);
        speedSlider.setPreferredSize(new Dimension(160, 22));
        speedSlider.addChangeListener(e -> {
            simulationSpeed = speedSlider.getValue() / 100.0;
            updateStats();
        });
        speedSlider.setBackground(new Color(25, 26, 38));
        speedSlider.setForeground(Color.WHITE);
        speedSlider.setOpaque(true);

        statsLabel = new JLabel();
        statsLabel.setForeground(new Color(180, 200, 220));
        statsLabel.setFont(new Font("Monospaced", Font.PLAIN, 13));

        selectedLabel = new JLabel("No creature selected (click one)");
        selectedLabel.setForeground(new Color(220, 200, 150));
        selectedLabel.setFont(new Font("Monospaced", Font.PLAIN, 12));

        controlBar.add(pauseBtn);
        controlBar.add(restartBtn);
        controlBar.add(nextTrackBtn);
        controlBar.add(speedDownBtn);
        controlBar.add(speedSlider);
        controlBar.add(speedUpBtn);
        controlBar.add(addFoodBtn);
        controlBar.add(addPoolBtn);
        controlBar.add(spawnBtn);
        controlBar.add(backToMenuBtn);
        controlBar.add(Box.createHorizontalStrut(20));
        controlBar.add(statsLabel);
        controlBar.add(Box.createHorizontalStrut(10));
        controlBar.add(selectedLabel);

        // === REDONE SIM UI: top bar + canvas + east side inspector + bottom graphs ===
        // Serious layout upgrade for readability and utility (graphs, better grouping, contrast)
        topBar = createSimTopBar();
        sidePanel = createSimSidePanel();
        graphsPanel = new StatsGraphPanel();
        graphsPanel.setPreferredSize(new Dimension(100, 135));

        JPanel centerArea = new JPanel(new BorderLayout(4, 4));
        centerArea.setBackground(new Color(15, 17, 26));
        centerArea.add(simCanvas, BorderLayout.CENTER);
        centerArea.add(sidePanel, BorderLayout.EAST);

        JPanel simView = new JPanel(new BorderLayout(4, 4));
        simView.setBackground(new Color(15, 17, 26));
        simView.add(topBar, BorderLayout.NORTH);
        simView.add(centerArea, BorderLayout.CENTER);
        simView.add(graphsPanel, BorderLayout.SOUTH);
        // (old controlBar buttons moved into top/side for cleaner look)

        // --- MAIN MENU ---
        JPanel menuPanel = createMainMenuPanel();

        // --- WORLD PARAMS ---
        paramsPanel = createWorldParamsPanel();

        // --- LOADING ---
        JPanel loadingPanel = createLoadingPanel();

        // --- DESCRIPTION / CREDITS / SETTINGS ---
        JPanel descPanel = createInfoPanel("Description",
            "The Nuclear Life Simulator (Java v" + VERSION + ")\n\n" +
            "An evolutionary artificial life simulation set in a radioactive, post-nuclear environment.\n" +
            "Organisms possess a simple neural network brain that is inherited and mutated across generations.\n" +
            "They must adapt to fluctuating oxygen, CO2, sulfur dioxide, and radiation levels.\n\n" +
            "Controls:\n" +
            "\u2022 Mouse drag: Pan camera\n" +
            "\u2022 Mouse wheel: Zoom in/out\n" +
            "\u2022 Left click creature: Select & inspect\n" +
            "\u2022 SPACE: Pause/Resume\n" +
            "\u2022 R: Restart simulation\n" +
            "\u2022 N: Next music track\n" +
            "\u2022 +/- or ,/. : Adjust speed\n" +
            "\u2022 ESC: Return to main menu from sim\n\n" +
            "Watch evolution in action. Populations adapt their tolerances and behaviors over generations.");

        JPanel creditsPanel = createInfoPanel("Credits",
            "The Nuclear Life Simulator - Java Rewrite v" + VERSION + "\n\n" +
            "Original concept & Processing prototype: Christopher J Boardman\n" +
            "Music: Jake Rae & Christopher J Boardman\n\n" +
            "Java overhaul & improvements (2026):\n" +
            "- Standalone pure Java (no Processing required)\n" +
            "- Overhauled neural nets + heritable traits\n" +
            "- Gas & radiation environmental pressures\n" +
            "- Generation tracking + hard population cap\n" +
            "- Proper camera, selection, settings, empty world preset\n" +
            "- Modern Swing UI + reliable audio\n\n" +
            "Released into the public domain (Unlicense).");

        JPanel settingsPanel = createSettingsPanel();

        mainPanel.add(menuPanel, "MAIN_MENU");
        mainPanel.add(paramsPanel, "WORLD_PARAMS");
        mainPanel.add(loadingPanel, "LOADING");
        mainPanel.add(simView, "SIMULATION");
        mainPanel.add(descPanel, "DESCRIPTION");
        mainPanel.add(creditsPanel, "CREDITS");
        mainPanel.add(settingsPanel, "SETTINGS");

        setContentPane(mainPanel);
    }

    private JPanel createSimTopBar() {
        JPanel bar = new JPanel(new FlowLayout(FlowLayout.LEFT, 10, 4));
        bar.setBackground(new Color(18, 20, 30));
        bar.setBorder(BorderFactory.createEmptyBorder(3, 6, 3, 6));

        JLabel title = new JLabel("NUCLEAR LIFE");
        title.setFont(new Font("SansSerif", Font.BOLD, 14));
        title.setForeground(new Color(120, 200, 140));

        topPopLabel = new JLabel("Pop: 0");
        topPopLabel.setFont(new Font("SansSerif", Font.BOLD, 13));
        topPopLabel.setForeground(new Color(100, 220, 130));

        topGenLabel = new JLabel("Gen: 0");
        topGenLabel.setFont(new Font("SansSerif", Font.BOLD, 13));
        topGenLabel.setForeground(new Color(255, 210, 90));

        JButton pause = new JButton("Pause");
        pause.addActionListener(e -> togglePause());
        applyDarkButtonStyle(pause);
        pauseBtn = pause; // wire for toggle text update in old code path

        JButton rst = new JButton("Restart");
        rst.addActionListener(e -> restartSimulation());
        applyDarkButtonStyle(rst);

        JButton menu = new JButton("Menu");
        menu.addActionListener(e -> { stopSimulationLoop(); switchToState(State.MAIN_MENU); });
        applyDarkButtonStyle(menu);

        JButton spn = new JButton("+Life");
        spn.addActionListener(e -> spawnFounders(6));
        applyDarkButtonStyle(spn);

        bar.add(title);
        bar.add(Box.createHorizontalStrut(8));
        bar.add(topPopLabel);
        bar.add(topGenLabel);
        bar.add(Box.createHorizontalStrut(6));
        bar.add(pause);
        bar.add(rst);
        bar.add(spn);
        bar.add(menu);

        // speed slider inline
        JSlider sp = new JSlider(25, 400, 100);
        sp.setPreferredSize(new Dimension(120, 18));
        sp.addChangeListener(e -> { simulationSpeed = sp.getValue()/100.0; updateStats(); });
        sp.setBackground(new Color(25,26,38));
        bar.add(new JLabel("Speed"));
        bar.add(sp);

        return bar;
    }

    private JPanel createSimSidePanel() {
        JPanel side = new JPanel();
        side.setLayout(new BoxLayout(side, BoxLayout.Y_AXIS));
        side.setBackground(new Color(16, 18, 26));
        side.setBorder(BorderFactory.createEmptyBorder(4, 6, 4, 6));
        side.setPreferredSize(new Dimension(210, 100));

        JLabel ins = new JLabel("INSPECTOR");
        ins.setFont(new Font("SansSerif", Font.BOLD, 11));
        ins.setForeground(new Color(170, 180, 200));
        ins.setAlignmentX(Component.LEFT_ALIGNMENT);

        selectedLabel.setAlignmentX(Component.LEFT_ALIGNMENT);
        selectedLabel.setFont(new Font("Monospaced", Font.PLAIN, 10));

        sideEnvLabel = new JLabel("<html>Env<br>O2: -- CO2: --<br>SO2: -- Rad: --%</html>");
        sideEnvLabel.setFont(new Font("SansSerif", Font.PLAIN, 10));
        sideEnvLabel.setForeground(new Color(150, 200, 220));
        sideEnvLabel.setAlignmentX(Component.LEFT_ALIGNMENT);

        JButton food = new JButton("+Food");
        applyDarkButtonStyle(food);
        food.addActionListener(e -> addRandomFood(5));

        JButton pool = new JButton("+MutPool");
        applyDarkButtonStyle(pool);
        pool.addActionListener(e -> addRandomMutationPool());

        side.add(ins);
        side.add(Box.createVerticalStrut(2));
        side.add(selectedLabel);
        side.add(Box.createVerticalStrut(6));
        side.add(sideEnvLabel);
        side.add(Box.createVerticalStrut(8));
        side.add(food);
        side.add(Box.createVerticalStrut(3));
        side.add(pool);
        side.add(Box.createVerticalGlue());

        return side;
    }

    private JPanel createMainMenuPanel() {
        JPanel p = new JPanel();
        p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
        p.setBackground(new Color(18, 18, 28));
        p.setBorder(BorderFactory.createEmptyBorder(60, 40, 40, 40));

        JLabel title = new JLabel("THE NUCLEAR LIFE SIMULATOR");
        title.setFont(new Font("SansSerif", Font.BOLD, 34));
        title.setForeground(new Color(120, 200, 140));
        title.setAlignmentX(Component.CENTER_ALIGNMENT);

        JLabel ver = new JLabel(VERSION);
        ver.setFont(new Font("SansSerif", Font.PLAIN, 14));
        ver.setForeground(new Color(150, 150, 170));
        ver.setAlignmentX(Component.CENTER_ALIGNMENT);

        JButton startBtn = makeMenuButton("Start Simulation", () -> switchToState(State.WORLD_PARAMS));
        JButton emptyBtn = makeMenuButton("Start Empty World", () -> {
            initialPopulation = 0;
            radiationLevel = 75;
            oxygenLevel = 17.0;
            co2Level = 0.06;
            sulfurDioxideLevel = 0.025;
            switchToState(State.LOADING);
        });
        JButton descBtn = makeMenuButton("Description", () -> switchToState(State.DESCRIPTION));
        JButton settingsBtn = makeMenuButton("Settings", () -> switchToState(State.SETTINGS));
        JButton creditsBtn = makeMenuButton("Credits", () -> switchToState(State.CREDITS));
        JButton exitBtn = makeMenuButton("Exit", () -> System.exit(0));

        p.add(title);
        p.add(Box.createVerticalStrut(8));
        p.add(ver);
        p.add(Box.createVerticalStrut(48));
        p.add(startBtn);
        p.add(Box.createVerticalStrut(12));
        p.add(emptyBtn);
        p.add(Box.createVerticalStrut(12));
        p.add(descBtn);
        p.add(Box.createVerticalStrut(12));
        p.add(settingsBtn);
        p.add(Box.createVerticalStrut(12));
        p.add(creditsBtn);
        p.add(Box.createVerticalStrut(12));
        p.add(exitBtn);

        return p;
    }

    private JButton makeMenuButton(String text, Runnable action) {
        JButton b = new JButton(text);
        b.setFont(new Font("SansSerif", Font.PLAIN, 20));
        b.setAlignmentX(Component.CENTER_ALIGNMENT);
        b.setMaximumSize(new Dimension(300, 50));
        b.setMargin(new Insets(8, 16, 8, 16));
        b.setFocusPainted(false);
        b.addActionListener(e -> action.run());
        applyDarkButtonStyle(b);
        return b;
    }

    /** Ensures dark button bg so white text (fonts) is always visible, overrides L&F quirks. */
    private void applyDarkButtonStyle(JButton b) {
        Color bg = new Color(38, 44, 58);
        Color fg = Color.WHITE;
        Color borderCol = new Color(70, 82, 105);
        b.setBackground(bg);
        b.setForeground(fg);
        b.setOpaque(true);
        b.setBorder(javax.swing.BorderFactory.createCompoundBorder(
            javax.swing.BorderFactory.createLineBorder(borderCol, 1),
            javax.swing.BorderFactory.createEmptyBorder(5, 12, 5, 12)
        ));
        b.setFocusPainted(false);
        // simple hover for better feel
        b.addMouseListener(new java.awt.event.MouseAdapter() {
            @Override public void mouseEntered(java.awt.event.MouseEvent e) { b.setBackground(new Color(52, 60, 78)); }
            @Override public void mouseExited(java.awt.event.MouseEvent e) { b.setBackground(bg); }
        });
    }

    private JPanel createWorldParamsPanel() {
        JPanel p = new JPanel();
        p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
        p.setBackground(new Color(18, 18, 28));
        p.setBorder(BorderFactory.createEmptyBorder(30, 60, 30, 60));

        JLabel title = new JLabel("World Parameters");
        title.setFont(new Font("SansSerif", Font.BOLD, 26));
        title.setForeground(new Color(180, 210, 140));
        title.setAlignmentX(Component.CENTER_ALIGNMENT);

        JLabel hint = new JLabel("Adjust starting conditions. Higher radiation increases mutation & pressure.");
        hint.setFont(new Font("SansSerif", Font.PLAIN, 13));
        hint.setForeground(Color.LIGHT_GRAY);
        hint.setAlignmentX(Component.CENTER_ALIGNMENT);

        // Sliders
        popSlider = makeParamSlider(5, 120, initialPopulation, val -> {
            initialPopulation = val;
            popVal.setText(String.valueOf(val));
        });
        radSlider = makeParamSlider(0, 100, radiationLevel, val -> {
            radiationLevel = val;
            radVal.setText(val + "%");
        });
        o2Slider = makeParamSlider(10, 30, (int) oxygenLevel, val -> {
            oxygenLevel = val;
            o2Val.setText(String.format("%.1f", (double) val));
        });
        co2Slider = makeParamSlider(1, 12, (int) (co2Level * 100), val -> {
            co2Level = val / 100.0;
            co2Val.setText(String.format("%.3f", co2Level));
        });
        so2Slider = makeParamSlider(0, 6, (int) (sulfurDioxideLevel * 100), val -> {
            sulfurDioxideLevel = val / 100.0;
            so2Val.setText(String.format("%.3f", sulfurDioxideLevel));
        });

        popVal = new JLabel(String.valueOf(initialPopulation));
        radVal = new JLabel(radiationLevel + "%");
        o2Val = new JLabel(String.format("%.1f", oxygenLevel));
        co2Val = new JLabel(String.format("%.3f", co2Level));
        so2Val = new JLabel(String.format("%.3f", sulfurDioxideLevel));
        Font paramValFont = new Font("SansSerif", Font.PLAIN, 13);
        popVal.setFont(paramValFont);
        radVal.setFont(paramValFont);
        o2Val.setFont(paramValFont);
        co2Val.setFont(paramValFont);
        so2Val.setFont(paramValFont);

        JPanel grid = new JPanel(new GridLayout(0, 3, 12, 8));
        grid.setOpaque(false);
        grid.setMaximumSize(new Dimension(620, 260));

        addSliderRow(grid, "Initial Population", popSlider, popVal);
        addSliderRow(grid, "Radiation Level", radSlider, radVal);
        addSliderRow(grid, "Oxygen Level (%)", o2Slider, o2Val);
        addSliderRow(grid, "CO2 Level", co2Slider, co2Val);
        addSliderRow(grid, "Sulfur Dioxide Level", so2Slider, so2Val);

        // Presets
        JPanel presets = new JPanel(new FlowLayout(FlowLayout.CENTER, 10, 4));
        presets.setOpaque(false);
        presets.add(makePresetButton("Balanced", 25, 45, 20.5, 0.035, 0.012));
        presets.add(makePresetButton("Radioactive", 18, 82, 16.0, 0.07, 0.028));
        presets.add(makePresetButton("Lush", 40, 12, 24.0, 0.018, 0.005));
        presets.add(makePresetButton("Toxic Wastes", 12, 65, 14.5, 0.09, 0.04));

        JButton back = new JButton("Back");
        back.setFont(new Font("SansSerif", Font.PLAIN, 14));
        back.addActionListener(e -> switchToState(State.MAIN_MENU));
        applyDarkButtonStyle(back);

        JButton confirm = new JButton("Begin Simulation");
        confirm.setFont(new Font("SansSerif", Font.BOLD, 15));
        confirm.addActionListener(e -> switchToState(State.LOADING));
        applyDarkButtonStyle(confirm);

        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.CENTER, 20, 10));
        buttons.setOpaque(false);
        buttons.add(back);
        buttons.add(confirm);

        p.add(title);
        p.add(Box.createVerticalStrut(8));
        p.add(hint);
        p.add(Box.createVerticalStrut(18));
        p.add(grid);
        p.add(Box.createVerticalStrut(12));
        JLabel presetsLabel = new JLabel("Presets:");
        presetsLabel.setFont(new Font("SansSerif", Font.PLAIN, 14));
        p.add(presetsLabel);
        p.add(presets);
        p.add(Box.createVerticalStrut(20));
        p.add(buttons);

        return p;
    }

    private void addSliderRow(JPanel grid, String label, JSlider slider, JLabel value) {
        JLabel l = new JLabel(label);
        l.setFont(new Font("SansSerif", Font.PLAIN, 13));
        grid.add(l);
        grid.add(slider);
        grid.add(value);
    }

    private JSlider makeParamSlider(int min, int max, int init, java.util.function.IntConsumer onChange) {
        JSlider s = new JSlider(min, max, init);
        s.setMajorTickSpacing(Math.max(5, (max - min) / 5));
        s.setPaintTicks(true);
        s.setOpaque(false);
        s.addChangeListener(e -> onChange.accept(s.getValue()));
        return s;
    }

    private JButton makePresetButton(String name, int pop, int rad, double o2, double co2, double so2) {
        JButton b = new JButton(name);
        b.setFont(new Font("SansSerif", Font.PLAIN, 13));
        b.setMargin(new Insets(4, 8, 4, 8));
        applyDarkButtonStyle(b);  // ensure visible text
        b.addActionListener(e -> {
            initialPopulation = pop;
            radiationLevel = rad;
            oxygenLevel = o2;
            co2Level = co2;
            sulfurDioxideLevel = so2;
            // sync sliders
            popSlider.setValue(pop);
            radSlider.setValue(rad);
            o2Slider.setValue((int) o2);
            co2Slider.setValue((int) (co2 * 100));
            so2Slider.setValue((int) (so2 * 100));
            popVal.setText(String.valueOf(pop));
            radVal.setText(rad + "%");
            o2Val.setText(String.format("%.1f", o2));
            co2Val.setText(String.format("%.3f", co2));
            so2Val.setText(String.format("%.3f", so2));
        });
        return b;
    }

    private JPanel createLoadingPanel() {
        JPanel p = new JPanel();
        p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
        p.setBackground(new Color(18, 18, 28));
        p.setBorder(BorderFactory.createEmptyBorder(120, 60, 60, 60));

        JLabel title = new JLabel("Seeding the Wasteland...");
        title.setFont(new Font("SansSerif", Font.BOLD, 22));
        title.setForeground(new Color(140, 180, 120));
        title.setAlignmentX(Component.CENTER_ALIGNMENT);

        JProgressBar bar = new JProgressBar(0, 100);
        bar.setMaximumSize(new Dimension(420, 28));
        bar.setStringPainted(true);
        bar.setAlignmentX(Component.CENTER_ALIGNMENT);

        p.add(title);
        p.add(Box.createVerticalStrut(30));
        p.add(bar);

        loadingProgressBar = bar;  // keep reference

        // The loading logic starts the timer when state changes
        return p;
    }

    private JPanel createInfoPanel(String titleText, String body) {
        JPanel p = new JPanel(new BorderLayout());
        p.setBackground(new Color(18, 18, 28));
        p.setBorder(BorderFactory.createEmptyBorder(30, 50, 30, 50));

        JLabel title = new JLabel(titleText);
        title.setFont(new Font("SansSerif", Font.BOLD, 24));
        title.setForeground(new Color(170, 200, 130));

        JTextArea text = new JTextArea(body);
        text.setFont(new Font("SansSerif", Font.PLAIN, 15));
        text.setForeground(new Color(210, 210, 220));
        text.setBackground(new Color(22, 23, 34));
        text.setEditable(false);
        text.setLineWrap(true);
        text.setWrapStyleWord(true);
        text.setBorder(BorderFactory.createEmptyBorder(16, 16, 16, 16));

        JScrollPane sp = new JScrollPane(text);
        sp.setPreferredSize(new Dimension(700, 420));
        sp.setBorder(null);

        JButton back = new JButton("Back to Menu");
        back.addActionListener(e -> switchToState(State.MAIN_MENU));
        applyDarkButtonStyle(back);

        JPanel south = new JPanel(new FlowLayout(FlowLayout.CENTER));
        south.setOpaque(false);
        south.add(back);

        p.add(title, BorderLayout.NORTH);
        p.add(sp, BorderLayout.CENTER);
        p.add(south, BorderLayout.SOUTH);
        return p;
    }

    private JPanel createSettingsPanel() {
        JPanel p = new JPanel();
        p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
        p.setBackground(new Color(18, 18, 28));
        p.setBorder(BorderFactory.createEmptyBorder(40, 80, 40, 80));

        JLabel title = new JLabel("Settings");
        title.setFont(new Font("SansSerif", Font.BOLD, 26));
        title.setForeground(new Color(180, 190, 210));
        title.setAlignmentX(Component.CENTER_ALIGNMENT);

        // Volume
        JPanel volRow = new JPanel(new FlowLayout(FlowLayout.LEFT));
        volRow.setOpaque(false);
        JLabel volL = new JLabel("Master Volume: ");
        volL.setForeground(Color.WHITE);
        JSlider volSlider = new JSlider(0, 100, 65);
        volSlider.setPreferredSize(new Dimension(220, 24));
        JLabel volVal = new JLabel("65%");
        volSlider.addChangeListener(e -> {
            int v = volSlider.getValue();
            volVal.setText(v + "%");
            audioManager.setVolume(v / 100.0f);
        });
        volRow.add(volL);
        volRow.add(volSlider);
        volRow.add(volVal);

        // Window size presets
        JPanel sizeRow = new JPanel(new FlowLayout(FlowLayout.LEFT));
        sizeRow.setOpaque(false);
        sizeRow.add(new JLabel("Window Size: "));
        sizeRow.add(makeSizeButton("1280x800", 1280, 800));
        sizeRow.add(makeSizeButton("1600x900", 1600, 900));
        sizeRow.add(makeSizeButton("1920x1080", 1920, 1080));
        JButton fsBtn = new JButton("Toggle Maximized");
        fsBtn.addActionListener(e -> {
            int state = getExtendedState();
            if ((state & JFrame.MAXIMIZED_BOTH) != 0) {
                setExtendedState(JFrame.NORMAL);
            } else {
                setExtendedState(JFrame.MAXIMIZED_BOTH);
            }
        });
        sizeRow.add(fsBtn);

        JButton keyBtn = new JButton("Show Keybindings");
        keyBtn.addActionListener(e -> showKeybindingsDialog());

        JButton back = new JButton("Back");
        back.addActionListener(e -> switchToState(State.MAIN_MENU));
        applyDarkButtonStyle(back);

        p.add(title);
        p.add(Box.createVerticalStrut(30));
        p.add(volRow);
        p.add(Box.createVerticalStrut(16));
        p.add(sizeRow);
        p.add(Box.createVerticalStrut(20));
        p.add(keyBtn);
        p.add(Box.createVerticalStrut(30));
        p.add(back);
        return p;
    }

    private JButton makeSizeButton(String label, int w, int h) {
        JButton b = new JButton(label);
        b.addActionListener(e -> {
            setSize(w, h);
            setLocationRelativeTo(null);
        });
        return b;
    }

    private void showKeybindingsDialog() {
        String msg = "Keyboard Shortcuts (when in simulation):\n\n" +
                "SPACE - Pause / Resume\n" +
                "R     - Restart simulation\n" +
                "N     - Next soundtrack track\n" +
                "+ / = - Speed up\n" +
                "- / _ - Slow down\n" +
                "ESC   - Return to Main Menu\n\n" +
                "Mouse:\n" +
                "Drag  - Pan camera across the world\n" +
                "Wheel - Zoom (0.3x - 4.0x)\n" +
                "Click - Select a creature to inspect its genes & state";
        JOptionPane.showMessageDialog(this, msg, "Controls", JOptionPane.INFORMATION_MESSAGE);
    }

    private void setupGlobalKeys() {
        KeyboardFocusManager.getCurrentKeyboardFocusManager().addKeyEventDispatcher(e -> {
            if (e.getID() != KeyEvent.KEY_PRESSED) return false;
            if (currentState != State.SIMULATION) {
                if (e.getKeyCode() == KeyEvent.VK_ESCAPE && currentState != State.MAIN_MENU) {
                    switchToState(State.MAIN_MENU);
                    return true;
                }
                return false;
            }
            switch (e.getKeyCode()) {
                case KeyEvent.VK_SPACE:
                    togglePause();
                    return true;
                case KeyEvent.VK_R:
                    restartSimulation();
                    return true;
                case KeyEvent.VK_N:
                    audioManager.nextTrack();
                    return true;
                case KeyEvent.VK_PLUS:
                case KeyEvent.VK_EQUALS:
                    adjustSpeed(0.2);
                    return true;
                case KeyEvent.VK_MINUS:
                case KeyEvent.VK_UNDERSCORE:
                    adjustSpeed(-0.2);
                    return true;
                case KeyEvent.VK_ESCAPE:
                    stopSimulationLoop();
                    switchToState(State.MAIN_MENU);
                    return true;
            }
            return false;
        });
    }

    private void switchToState(State newState) {
        stopSimulationLoop();
        if (loadingTimer != null) loadingTimer.stop();

        currentState = newState;
        CardLayout cl = (CardLayout) mainPanel.getLayout();

        switch (newState) {
            case MAIN_MENU:
                audioManager.stopAll();
                cl.show(mainPanel, "MAIN_MENU");
                break;

            case WORLD_PARAMS:
                cl.show(mainPanel, "WORLD_PARAMS");
                // sliders already reflect fields
                break;

            case LOADING:
                cl.show(mainPanel, "LOADING");
                startLoadingSequence();
                break;

            case SIMULATION:
                initializeSimulation();
                cl.show(mainPanel, "SIMULATION");
                simCanvas.requestFocusInWindow();
                startSimulationLoop();
                audioManager.playTrack(0);
                break;

            case DESCRIPTION:
                cl.show(mainPanel, "DESCRIPTION");
                break;
            case CREDITS:
                cl.show(mainPanel, "CREDITS");
                break;
            case SETTINGS:
                cl.show(mainPanel, "SETTINGS");
                break;
        }
        updateStats();
    }

    private void startLoadingSequence() {
        loadProgress = 0;
        loadingTimer = new javax.swing.Timer(28, null);
        loadingTimer.addActionListener(e -> {
            loadProgress += rng.nextInt(3) + 1;
            if (loadProgress > 100) loadProgress = 100;
            if (loadingProgressBar != null) loadingProgressBar.setValue(loadProgress);
            if (loadProgress >= 100) {
                loadingTimer.stop();
                // small delay so user sees 100%
                javax.swing.Timer delay = new javax.swing.Timer(180, ev -> switchToState(State.SIMULATION));
                delay.setRepeats(false);
                delay.start();
            }
        });
        loadingTimer.start();
    }

    // ==================== SIMULATION ====================

    private void initializeSimulation() {
        population.clear();
        foods.clear();
        poops.clear();
        mutationPools.clear();
        selectedCreature = null;
        generationCount = 0;
        births = 0;
        deaths = 0;
        isPaused = false;
        simulationSpeed = 1.0;
        if (speedSlider != null) speedSlider.setValue(100);

        camX = WORLD_WIDTH / 2.0;
        camY = WORLD_HEIGHT / 2.0;
        zoom = 1.0;

        // clear graph histories for fresh run
        popHistory.clear(); genHistory.clear();
        o2History.clear(); co2History.clear(); so2History.clear(); radHistory.clear();
        historyTick = 0;
        if (graphsPanel != null) graphsPanel.clear();

        // Spawn initial food & mutation pools
        for (int i = 0; i < 110; i++) {
            foods.add(new Food(rng.nextDouble() * WORLD_WIDTH, rng.nextDouble() * WORLD_HEIGHT));
        }
        for (int i = 0; i < 4; i++) {
            mutationPools.add(new MutationPool(
                rng.nextDouble() * WORLD_WIDTH,
                rng.nextDouble() * WORLD_HEIGHT,
                80 + rng.nextDouble() * 90
            ));
        }

        // Spawn initial organisms (guarantee a few founders even for "empty world" preset so sim has life to evolve)
        int toSpawn = initialPopulation;
        if (toSpawn <= 0) toSpawn = 3;
        for (int i = 0; i < toSpawn; i++) {
            Organism o = new Organism();
            population.add(o);
            generationCount = Math.max(generationCount, o.generation);
        }
        updateStats();
    }

    private void startSimulationLoop() {
        if (gameTimer != null) gameTimer.stop();

        gameTimer = new javax.swing.Timer(1000 / FPS, e -> {
            if (!isPaused && currentState == State.SIMULATION) {
                int steps = Math.max(1, (int) Math.round(simulationSpeed));
                for (int s = 0; s < steps; s++) {
                    simulationStep();
                }
            }
            simCanvas.repaint();
            updateStats();
        });
        gameTimer.start();
    }

    private void stopSimulationLoop() {
        if (gameTimer != null) {
            gameTimer.stop();
            gameTimer = null;
        }
    }

    private void simulationStep() {
        // Environmental dynamics (slow changes)
        manageEnvironment();

        // Replenish food
        if (foods.size() < 95 && rng.nextDouble() < 0.6) {
            foods.add(new Food(rng.nextDouble() * WORLD_WIDTH, rng.nextDouble() * WORLD_HEIGHT));
        }

        // Update mutation pools (they affect nearby)
        for (MutationPool pool : mutationPools) {
            pool.affect(population, rng);
        }

        // Update organisms (reverse to safely remove)
        for (int i = population.size() - 1; i >= 0; i--) {
            Organism o = population.get(i);
            o.update(simulationSpeed, this);
            if (o.isDead) {
                deaths++;
                population.remove(i);
                if (selectedCreature == o) selectedCreature = null;
            }
        }

        // Update & decay poop (emits sulfur)
        for (int i = poops.size() - 1; i >= 0; i--) {
            Poop p = poops.get(i);
            p.update();
            if (p.isDecayed()) {
                poops.remove(i);
            }
        }

        // Hard cap enforcement (oldest/lowest energy die first if over)
        enforcePopulationCap();

        // Occasionally spawn a little extra food if pop is healthy
        if (population.size() > 8 && foods.size() < 70 && rng.nextInt(12) == 0) {
            foods.add(new Food(rng.nextDouble() * WORLD_WIDTH, rng.nextDouble() * WORLD_HEIGHT));
        }

        // Record history for graphs (throttled)
        historyTick++;
        if (historyTick % 2 == 0) {  // ~30 samples/sec at 60fps
            popHistory.add(population.size());
            genHistory.add(generationCount);
            o2History.add(oxygenLevel);
            co2History.add(co2Level);
            so2History.add(sulfurDioxideLevel);
            radHistory.add(radiationLevel);
            while (popHistory.size() > MAX_HISTORY) {
                popHistory.remove(0);
                genHistory.remove(0);
                o2History.remove(0);
                co2History.remove(0);
                so2History.remove(0);
                radHistory.remove(0);
            }
        }
    }

    private void manageEnvironment() {
        // Slow natural regulation
        if (sulfurDioxideLevel > 0.009) sulfurDioxideLevel -= 0.00008;
        if (co2Level > 0.032) co2Level -= 0.00003;
        if (oxygenLevel < 21.5) oxygenLevel += 0.0006;

        // Poop already adds SO2 while decaying

        // Radiation slowly fluctuates a bit
        if (rng.nextDouble() < 0.008) {
            radiationLevel = Math.max(0, Math.min(100, radiationLevel + rng.nextInt(3) - 1));
        }

        // Constrain
        sulfurDioxideLevel = Math.max(0.001, Math.min(0.12, sulfurDioxideLevel));
        co2Level = Math.max(0.005, Math.min(0.18, co2Level));
        oxygenLevel = Math.max(12.0, Math.min(32.0, oxygenLevel));
    }

    private void enforcePopulationCap() {
        while (population.size() > MAX_POPULATION) {
            // Kill the weakest (lowest energy, oldest)
            Organism weakest = null;
            double worst = Double.MAX_VALUE;
            for (Organism o : population) {
                double score = o.energy + (300 - Math.min(o.age, 300)) * 0.1;
                if (score < worst) {
                    worst = score;
                    weakest = o;
                }
            }
            if (weakest != null) {
                weakest.isDead = true;
                deaths++;
                if (selectedCreature == weakest) selectedCreature = null;
            }
        }
    }

    private void updateStats() {
        if (statsLabel == null) return;
        String s = String.format(
            "Pop: %d/%d  Gen: %d  Food: %d  Rad: %d%%  O2: %.1f  CO2: %.3f  SO2: %.3f  Speed: %.2fx",
            population.size(), MAX_POPULATION, generationCount, foods.size(),
            radiationLevel, oxygenLevel, co2Level, sulfurDioxideLevel, simulationSpeed
        );
        statsLabel.setText(s);

        if (topPopLabel != null) topPopLabel.setText("Pop: " + population.size());
        if (topGenLabel != null) topGenLabel.setText("Gen: " + generationCount);

        if (sideEnvLabel != null) {
            sideEnvLabel.setText(String.format("<html>ENV<br/>O2: %.1f  CO2: %.3f<br/>SO2: %.3f  Rad: %d%%</html>",
                oxygenLevel, co2Level, sulfurDioxideLevel, radiationLevel));
        }

        if (selectedLabel != null) {
            if (selectedCreature != null && !selectedCreature.isDead) {
                Organism o = selectedCreature;
                selectedLabel.setText(String.format(
                    "<html>Gen%d<br/>E:%.0f Sz:%.2f<br/>O2T:%.1f<br/>CO2T:%.3f SO2T:%.3f</html>",
                    o.generation, o.energy, o.sizeFactor, o.oxygenTolerance, o.co2Tolerance, o.sulfurTolerance
                ));
            } else {
                selectedLabel.setText("Click creature to inspect");
                if (selectedCreature != null) selectedCreature = null;
            }
        }

        if (graphsPanel != null) graphsPanel.repaint();
    }

    private void togglePause() {
        isPaused = !isPaused;
        if (pauseBtn != null) pauseBtn.setText(isPaused ? "Resume" : "Pause");
    }

    private void restartSimulation() {
        stopSimulationLoop();
        initializeSimulation();
        startSimulationLoop();
        audioManager.playTrack(audioManager.currentTrackIndex);
        selectedCreature = null;
    }

    private void adjustSpeed(double delta) {
        simulationSpeed = Math.max(0.25, Math.min(6.0, simulationSpeed + delta));
        if (speedSlider != null) speedSlider.setValue((int) Math.round(simulationSpeed * 100));
        updateStats();
    }

    private void addRandomFood(int count) {
        for (int i = 0; i < count; i++) {
            foods.add(new Food(rng.nextDouble() * WORLD_WIDTH, rng.nextDouble() * WORLD_HEIGHT));
        }
    }

    private void addRandomMutationPool() {
        mutationPools.add(new MutationPool(
            rng.nextDouble() * WORLD_WIDTH,
            rng.nextDouble() * WORLD_HEIGHT,
            70 + rng.nextDouble() * 110
        ));
    }

    private void spawnFounders(int count) {
        for (int i = 0; i < count; i++) {
            if (population.size() >= MAX_POPULATION) break;
            Organism o = new Organism();
            // place near center for visibility
            o.x = camX + (rng.nextDouble() - 0.5) * 300;
            o.y = camY + (rng.nextDouble() - 0.5) * 200;
            o.energy = 70 + rng.nextDouble() * 40;
            population.add(o);
            generationCount = Math.max(generationCount, o.generation);
        }
        updateStats();
        simCanvas.repaint();
    }

    // ==================== INNER: SIM CANVAS ====================

    class SimCanvas extends JPanel {
        private static final long serialVersionUID = 1L;

        public SimCanvas() {
            setBackground(new Color(8, 14, 26));
            setFocusable(true);
            addMouseListener(new MouseAdapter() {
                @Override
                public void mousePressed(MouseEvent e) {
                    if (currentState != State.SIMULATION) return;
                    lastMouseX = e.getX();
                    lastMouseY = e.getY();
                    dragging = true;

                    if (e.getButton() == MouseEvent.BUTTON1) {
                        // Try to select creature
                        Organism hit = findOrganismAtScreen(e.getX(), e.getY());
                        if (hit != null) {
                            selectedCreature = hit;
                            updateStats();
                        }
                    }
                }

                @Override
                public void mouseReleased(MouseEvent e) {
                    dragging = false;
                }
            });
            addMouseMotionListener(new MouseMotionAdapter() {
                @Override
                public void mouseDragged(MouseEvent e) {
                    if (!dragging || currentState != State.SIMULATION) return;
                    double dx = (e.getX() - lastMouseX) / zoom;
                    double dy = (e.getY() - lastMouseY) / zoom;
                    camX -= dx;
                    camY -= dy;
                    lastMouseX = e.getX();
                    lastMouseY = e.getY();
                    clampCamera();
                }
            });
            addMouseWheelListener(e -> {
                if (currentState != State.SIMULATION) return;
                double factor = (e.getPreciseWheelRotation() < 0) ? 1.12 : 0.88;
                double oldZoom = zoom;
                zoom = Math.max(0.28, Math.min(4.2, zoom * factor));
                // zoom toward mouse
                double mx = (e.getX() - getWidth() / 2.0) / oldZoom + camX;
                double my = (e.getY() - getHeight() / 2.0) / oldZoom + camY;
                camX = mx - (e.getX() - getWidth() / 2.0) / zoom;
                camY = my - (e.getY() - getHeight() / 2.0) / zoom;
                clampCamera();
            });
        }

        private Organism findOrganismAtScreen(int sx, int sy) {
            double closestDist = 18 / zoom + 4;
            Organism best = null;
            for (Organism o : population) {
                double sx2 = (o.x - camX) * zoom + getWidth() / 2.0;
                double sy2 = (o.y - camY) * zoom + getHeight() / 2.0;
                double d = Math.hypot(sx - sx2, sy - sy2);
                if (d < closestDist) {
                    closestDist = d;
                    best = o;
                }
            }
            return best;
        }

        private void clampCamera() {
            double margin = 120;
            camX = Math.max(-margin, Math.min(WORLD_WIDTH + margin, camX));
            camY = Math.max(-margin, Math.min(WORLD_HEIGHT + margin, camY));
        }

        @Override
        protected void paintComponent(Graphics g) {
            super.paintComponent(g);
            Graphics2D g2 = (Graphics2D) g.create();
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);

            int w = getWidth();
            int h = getHeight();

            if (currentState != State.SIMULATION) {
                g2.setColor(new Color(18, 18, 28));
                g2.fillRect(0, 0, w, h);
                g2.setColor(new Color(120, 140, 160));
                g2.setFont(new Font("SansSerif", Font.PLAIN, 16));
                g2.drawString("Simulation view active only during run", w / 2 - 140, h / 2);
                g2.dispose();
                return;
            }

            // Background
            g2.setColor(new Color(6, 12, 22));
            g2.fillRect(0, 0, w, h);

            // Optional subtle grid for sense of scale
            g2.setColor(new Color(25, 32, 48));
            double step = 200 * zoom;
            if (step > 8) {
                double startX = ((int) ((camX - w / zoom) / 200) * 200 - camX) * zoom + w / 2.0;
                double startY = ((int) ((camY - h / zoom) / 200) * 200 - camY) * zoom + h / 2.0;
                for (double x = startX; x < w + 40; x += step) {
                    g2.drawLine((int) x, 0, (int) x, h);
                }
                for (double y = startY; y < h + 40; y += step) {
                    g2.drawLine(0, (int) y, w, (int) y);
                }
            }

            // Draw mutation pools (background layer)
            for (MutationPool pool : mutationPools) {
                double sx = (pool.x - camX) * zoom + w / 2.0;
                double sy = (pool.y - camY) * zoom + h / 2.0;
                double r = pool.radius * zoom;
                if (sx + r < 0 || sx - r > w || sy + r < 0 || sy - r > h) continue;
                g2.setColor(new Color(255, 195, 40, 38));
                g2.fill(new Ellipse2D.Double(sx - r, sy - r, r * 2, r * 2));
                g2.setColor(new Color(255, 210, 70, 130));
                g2.setStroke(new BasicStroke(1.5f));
                g2.draw(new Ellipse2D.Double(sx - r, sy - r, r * 2, r * 2));
            }

            // Foods
            g2.setColor(new Color(40, 170, 60));
            for (Food f : foods) {
                double sx = (f.x - camX) * zoom + w / 2.0;
                double sy = (f.y - camY) * zoom + h / 2.0;
                if (sx < -4 || sx > w + 4 || sy < -4 || sy > h + 4) continue;
                double r = Math.max(2.2, 3.8 * zoom);
                g2.fill(new Ellipse2D.Double(sx - r, sy - r, r * 2, r * 2));
            }

            // Poops
            g2.setColor(new Color(110, 72, 48, 210));
            for (Poop p : poops) {
                double sx = (p.x - camX) * zoom + w / 2.0;
                double sy = (p.y - camY) * zoom + h / 2.0;
                if (sx < -3 || sx > w + 3 || sy < -3 || sy > h + 3) continue;
                double r = Math.max(1.8, 2.6 * zoom);
                g2.fill(new Ellipse2D.Double(sx - r, sy - r, r * 2, r * 2));
            }

            // Organisms
            for (Organism o : population) {
                double sx = (o.x - camX) * zoom + w / 2.0;
                double sy = (o.y - camY) * zoom + h / 2.0;
                if (sx < -12 || sx > w + 12 || sy < -12 || sy > h + 12) continue;

                float sz = (float) (o.sizeFactor * zoom);
                Color base = o.getDisplayColor();
                g2.setColor(base);
                g2.fill(new Ellipse2D.Double(sx - sz * 3.2, sy - sz * 3.2, sz * 6.4, sz * 6.4));

                // outline
                g2.setColor(new Color(255, 255, 255, 120));
                g2.setStroke(new BasicStroke(Math.max(0.8f, 1.2f * (float) zoom)));
                g2.draw(new Ellipse2D.Double(sx - sz * 3.6, sy - sz * 3.6, sz * 7.2, sz * 7.2));

                // "eye" direction indicator
                g2.setColor(Color.BLACK);
                double ex = sx + o.vx * sz * 1.6;
                double ey = sy + o.vy * sz * 1.6;
                double es = Math.max(1.1, 1.8 * zoom);
                g2.fill(new Ellipse2D.Double(ex - es, ey - es, es * 2, es * 2));

                // highlight if selected
                if (o == selectedCreature) {
                    g2.setColor(new Color(255, 240, 80, 200));
                    g2.setStroke(new BasicStroke(1.6f));
                    g2.draw(new Ellipse2D.Double(sx - sz * 4.3, sy - sz * 4.3, sz * 8.6, sz * 8.6));
                }
            }

            // HUD overlay (mini help)
            g2.setColor(new Color(220, 230, 240, 200));
            g2.setFont(new Font("SansSerif", Font.PLAIN, 13));
            g2.drawString("Drag to pan \u2022 Wheel to zoom \u2022 Click to select \u2022 SPACE pause \u2022 R restart", 14, h - 14);

            // Radiation tint overlay (stronger at high rad)
            float radAlpha = Math.min(0.22f, radiationLevel / 420f);
            if (radAlpha > 0.01f) {
                g2.setColor(new Color(180, 60, 30, (int) (radAlpha * 255)));
                g2.fillRect(0, 0, w, h);
            }

            g2.dispose();
        }
    }

    // ==================== ENTITY CLASSES ====================

    class Food {
        double x, y;
        double energy = 28 + rng.nextDouble() * 32;

        Food(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }

    class Poop {
        double x, y;
        int decay = 380 + rng.nextInt(260);

        Poop(double x, double y) {
            this.x = x;
            this.y = y;
        }

        void update() {
            if (decay > 0) {
                decay--;
                // emit sulfur
                sulfurDioxideLevel = Math.min(0.095, sulfurDioxideLevel + 0.000018);
            }
        }

        boolean isDecayed() {
            return decay <= 0;
        }
    }

    class MutationPool {
        double x, y, radius;

        MutationPool(double x, double y, double radius) {
            this.x = x;
            this.y = y;
            this.radius = radius;
        }

        void affect(List<Organism> orgs, Random r) {
            for (Organism o : orgs) {
                double dx = o.x - x;
                double dy = o.y - y;
                if (dx * dx + dy * dy < radius * radius) {
                    o.mutate(r, 0.65); // stronger mutate inside pools
                }
            }
        }
    }

    class NeuralNetwork {
        // 6 inputs, 6 hidden, 4 outputs (overhauled from original 5-5-3)
        // Inputs: foodDist, energy, ageNorm, reproDrive, size, radNorm
        // Outputs: moveSpeed, turnBias, reproUrge, eatBias
        float[][] w1 = new float[6][6];
        float[][] w2 = new float[4][6];

        NeuralNetwork() {
            randomize();
        }

        void randomize() {
            for (int i = 0; i < 6; i++)
                for (int j = 0; j < 6; j++)
                    w1[i][j] = (rng.nextFloat() - 0.5f) * 2.2f;
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 6; j++)
                    w2[i][j] = (rng.nextFloat() - 0.5f) * 2.0f;
        }

        float[] process(float[] in) {
            float[] h = new float[6];
            for (int i = 0; i < 6; i++) {
                float sum = 0;
                for (int j = 0; j < 6; j++) sum += in[j] * w1[i][j];
                h[i] = (float) Math.tanh(sum * 0.9);
            }
            float[] out = new float[4];
            for (int i = 0; i < 4; i++) {
                float sum = 0;
                for (int j = 0; j < 6; j++) sum += h[j] * w2[i][j];
                out[i] = (float) (1.0 / (1.0 + Math.exp(-sum * 1.1))); // sigmoid 0..1
            }
            return out;
        }

        void mutate(Random r, double strength) {
            float str = (float) strength;
            for (int i = 0; i < 6; i++)
                for (int j = 0; j < 6; j++)
                    if (r.nextDouble() < 0.18 * strength)
                        w1[i][j] += (r.nextFloat() - 0.5f) * 0.28f * str;
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 6; j++)
                    if (r.nextDouble() < 0.18 * strength)
                        w2[i][j] += (r.nextFloat() - 0.5f) * 0.26f * str;
        }

        NeuralNetwork copyAndMutate(Random r, double strength) {
            NeuralNetwork n = new NeuralNetwork();
            for (int i = 0; i < 6; i++) System.arraycopy(w1[i], 0, n.w1[i], 0, 6);
            for (int i = 0; i < 4; i++) System.arraycopy(w2[i], 0, n.w2[i], 0, 6);
            n.mutate(r, strength);
            return n;
        }
    }

    class Organism {
        double x, y;
        double vx, vy;
        NeuralNetwork brain = new NeuralNetwork();
        double energy = 55 + rng.nextDouble() * 55;
        double sizeFactor = 1.0 + rng.nextDouble() * 0.9;
        double oxygenTolerance = 15 + rng.nextDouble() * 14;
        double co2Tolerance = 0.01 + rng.nextDouble() * 0.055;
        double sulfurTolerance = 0.003 + rng.nextDouble() * 0.022;
        double radResistance = 0.6 + rng.nextDouble() * 1.4;

        int generation = 0;
        int age = 0;
        double desire = 0.0; // internal repro drive accumulator
        boolean isDead = false;
        Color cachedColor;

        Organism() {
            x = rng.nextDouble() * WORLD_WIDTH;
            y = rng.nextDouble() * WORLD_HEIGHT;
            double ang = rng.nextDouble() * Math.PI * 2;
            vx = Math.cos(ang) * (0.9 + rng.nextDouble());
            vy = Math.sin(ang) * (0.9 + rng.nextDouble());
            cachedColor = new Color(
                55 + rng.nextInt(140),
                95 + rng.nextInt(95),
                130 + rng.nextInt(95)
            );
        }

        Color getDisplayColor() {
            // slight tint based on tolerances
            int r = cachedColor.getRed();
            int g = cachedColor.getGreen();
            int b = cachedColor.getBlue();
            if (sulfurTolerance > 0.018) r = Math.min(255, r + 35);
            if (oxygenTolerance > 26) g = Math.min(255, g + 22);
            return new Color(r, g, b);
        }

        void update(double speed, NuclearLifeSimulator sim) {
            if (isDead || energy <= 0) {
                isDead = true;
                return;
            }

            // Inputs to brain (normalized)
            double closestFood = closestFoodDist();
            float[] inputs = new float[]{
                (float) Math.min(1.0, closestFood / 420.0),
                (float) Math.min(1.0, energy / 120.0),
                (float) Math.min(1.0, age / 420.0),
                (float) Math.min(1.0, desire),
                (float) Math.min(1.8, sizeFactor),
                (float) Math.min(1.0, sim.radiationLevel / 95.0)
            };
            float[] out = brain.process(inputs);

            double move = out[0] * 1.85 * speed;
            double turn = (out[1] - 0.5) * 0.9;
            double reproUrge = out[2];
            // out[3] eat bias (not heavily used, seekFood always tries)

            // Apply steering
            double spd = Math.hypot(vx, vy);
            if (spd < 0.3) spd = 0.3;
            double dir = Math.atan2(vy, vx) + turn * 0.6;
            vx = Math.cos(dir) * spd;
            vy = Math.sin(dir) * spd;

            // Behavior
            if (reproUrge > 0.72 && energy > 48 && sim.population.size() < MAX_POPULATION - 3) {
                desire += 0.085 * speed;
                findMateOrReproduce(sim);
            } else if (energy < 32 || closestFood < 95) {
                seekFood(sim);
            }

            // Movement
            x += vx * move;
            y += vy * move;
            wrapOrClamp(); // soft world bounds

            age++;
            double baseDrain = BASE_ENERGY_DRAIN * speed;

            // Gas & radiation stress (overhauled environmental pressure)
            double stress = 0.0;
            if (sim.oxygenLevel < oxygenTolerance - 4.5) stress += 0.55;
            if (sim.oxygenLevel > oxygenTolerance + 5.5) stress += 0.35;
            if (sim.co2Level > co2Tolerance + 0.018) stress += 0.9;
            if (sim.sulfurDioxideLevel > sulfurTolerance + 0.004) stress += 1.6;

            double radStress = (sim.radiationLevel / 100.0) * (1.15 / Math.max(0.4, radResistance)) * 0.55;
            stress += radStress;

            energy -= baseDrain + stress * 0.12 * speed;

            // Natural energy from size (bigger costs more)
            energy -= (sizeFactor - 0.9) * 0.011 * speed;

            // Age death chance
            if (age > 520 && rng.nextDouble() < 0.0018) {
                isDead = true;
                return;
            }

            // Auto reproduce at very high energy
            if (energy > 118 && sim.population.size() < MAX_POPULATION - 2) {
                reproduce(sim);
            }

            // Random mutation over long life + radiation influence
            double mutChance = 0.0012 + (sim.radiationLevel / 1100.0);
            if (age > 180 && rng.nextDouble() < mutChance) {
                mutate(rng, 0.9);
            }

            desire = Math.max(0, desire * 0.982 - 0.006);
            if (energy <= 0) isDead = true;
        }

        private double closestFoodDist() {
            double best = 9999;
            for (Food f : foods) {
                double d = Math.hypot(x - f.x, y - f.y);
                if (d < best) best = d;
            }
            return best;
        }

        private void seekFood(NuclearLifeSimulator sim) {
            Food target = null;
            double best = 9999;
            for (Food f : foods) {
                double d = Math.hypot(x - f.x, y - f.y);
                if (d < best) {
                    best = d;
                    target = f;
                }
            }
            if (target == null) return;
            if (best < 11 * sizeFactor) {
                // eat
                energy += target.energy * (0.75 + Math.min(0.6, sizeFactor * 0.2));
                foods.remove(target);
                sim.poops.add(new Poop(x + (rng.nextDouble() - 0.5) * 6, y + (rng.nextDouble() - 0.5) * 6));
                desire *= 0.4;
            } else {
                // steer toward
                double dx = target.x - x;
                double dy = target.y - y;
                double len = Math.max(0.001, Math.hypot(dx, dy));
                vx = vx * 0.6 + (dx / len) * 1.35;
                vy = vy * 0.6 + (dy / len) * 1.35;
            }
        }

        private void findMateOrReproduce(NuclearLifeSimulator sim) {
            // Prefer sexual if good mate nearby, else budding
            Organism mate = null;
            double best = 68;
            for (Organism other : sim.population) {
                if (other == this || other.isDead || other.desire < 0.65) continue;
                double d = Math.hypot(x - other.x, y - other.y);
                if (d < best) {
                    best = d;
                    mate = other;
                }
            }
            if (mate != null && best < 15 * sizeFactor) {
                reproduceWith(mate, sim);
            } else if (best > 50 && rng.nextDouble() < 0.6) {
                reproduce(sim);
            }
        }

        private void reproduce(NuclearLifeSimulator sim) {
            if (sim.population.size() >= MAX_POPULATION) return;
            Organism child = new Organism();
            child.x = x + (rng.nextDouble() - 0.5) * 22;
            child.y = y + (rng.nextDouble() - 0.5) * 22;
            child.generation = generation + 1;
            child.brain = brain.copyAndMutate(rng, 1.0 + (sim.radiationLevel / 140.0));
            child.sizeFactor = sizeFactor * (0.93 + rng.nextDouble() * 0.14);
            child.oxygenTolerance = oxygenTolerance * (0.91 + rng.nextDouble() * 0.18);
            child.co2Tolerance = co2Tolerance * (0.90 + rng.nextDouble() * 0.20);
            child.sulfurTolerance = sulfurTolerance * (0.89 + rng.nextDouble() * 0.22);
            child.radResistance = radResistance * (0.92 + rng.nextDouble() * 0.16);
            child.energy = energy * 0.42;
            child.generation = Math.max(child.generation, generation);
            energy *= 0.48;
            sim.population.add(child);
            sim.births++;
            sim.generationCount = Math.max(sim.generationCount, child.generation);
            desire = 0;
        }

        private void reproduceWith(Organism mate, NuclearLifeSimulator sim) {
            if (sim.population.size() >= MAX_POPULATION) return;
            Organism child = new Organism();
            child.x = (x + mate.x) * 0.5 + (rng.nextDouble() - 0.5) * 18;
            child.y = (y + mate.y) * 0.5 + (rng.nextDouble() - 0.5) * 18;
            child.generation = Math.max(generation, mate.generation) + 1;

            // blended + mutated brain (sexual recombination simplified)
            child.brain = brain.copyAndMutate(rng, 0.75);
            // small chance to take some weights from mate
            if (rng.nextDouble() < 0.45) {
                for (int i = 0; i < 6; i++) {
                    if (rng.nextDouble() < 0.3)
                        System.arraycopy(mate.brain.w1[i], 0, child.brain.w1[i], 0, 6);
                }
            }
            child.brain.mutate(rng, 0.9 + sim.radiationLevel / 160.0);

            child.sizeFactor = (sizeFactor + mate.sizeFactor) * 0.5 * (0.94 + rng.nextDouble() * 0.12);
            child.oxygenTolerance = (oxygenTolerance + mate.oxygenTolerance) * 0.5 * (0.92 + rng.nextDouble() * 0.16);
            child.co2Tolerance = (co2Tolerance + mate.co2Tolerance) * 0.5 * (0.91 + rng.nextDouble() * 0.18);
            child.sulfurTolerance = (sulfurTolerance + mate.sulfurTolerance) * 0.5 * (0.90 + rng.nextDouble() * 0.20);
            child.radResistance = (radResistance + mate.radResistance) * 0.5 * (0.93 + rng.nextDouble() * 0.14);

            double split = 0.32;
            child.energy = (energy + mate.energy) * split;
            energy *= (1 - split);
            mate.energy *= (1 - split);
            mate.desire = 0;
            desire = 0;

            sim.population.add(child);
            sim.births++;
            sim.generationCount = Math.max(sim.generationCount, child.generation);
        }

        void mutate(Random r, double strength) {
            sizeFactor *= (0.93 + r.nextDouble() * 0.14);
            oxygenTolerance *= (0.90 + r.nextDouble() * 0.20);
            co2Tolerance *= (0.89 + r.nextDouble() * 0.22);
            sulfurTolerance *= (0.88 + r.nextDouble() * 0.24);
            radResistance *= (0.91 + r.nextDouble() * 0.18);
            energy += (r.nextDouble() - 0.5) * 11 * strength;
            brain.mutate(r, strength);
            // slight color shift
            cachedColor = new Color(
                Math.max(30, Math.min(235, cachedColor.getRed() + r.nextInt(11) - 5)),
                Math.max(40, Math.min(225, cachedColor.getGreen() + r.nextInt(11) - 5)),
                Math.max(70, Math.min(250, cachedColor.getBlue() + r.nextInt(11) - 5))
            );
        }

        private void wrapOrClamp() {
            // Soft bounds with bounce
            if (x < 40) { x = 40; vx = Math.abs(vx) * 0.6 + 0.1; }
            if (x > WORLD_WIDTH - 40) { x = WORLD_WIDTH - 40; vx = -Math.abs(vx) * 0.6 - 0.1; }
            if (y < 40) { y = 40; vy = Math.abs(vy) * 0.6 + 0.1; }
            if (y > WORLD_HEIGHT - 40) { y = WORLD_HEIGHT - 40; vy = -Math.abs(vy) * 0.6 - 0.1; }
        }
    }

    // ==================== LIVE GRAPHS (population + etc) ====================
    // Pure Java 2D, no external libs. Redrawn live from history buffers.

    class StatsGraphPanel extends JPanel {
        private final Color bg = new Color(10, 12, 18);
        private final Color gridCol = new Color(30, 35, 48);
        private final Color popCol = new Color(80, 220, 120);
        private final Color genCol = new Color(255, 200, 80);
        private final Color o2Col = new Color(100, 180, 255);
        private final Color co2Col = new Color(255, 140, 100);
        private final Color so2Col = new Color(200, 180, 80);
        private final Color radCol = new Color(180, 100, 220);

        public StatsGraphPanel() {
            setBackground(bg);
            setBorder(javax.swing.BorderFactory.createEmptyBorder(2, 4, 2, 4));
            setToolTipText("Live history: Population (green), Max Gen (yellow), Gases & Radiation");
        }

        @Override
        protected void paintComponent(Graphics g) {
            super.paintComponent(g);
            Graphics2D g2 = (Graphics2D) g.create();
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            int w = getWidth();
            int h = getHeight();
            g2.setColor(bg);
            g2.fillRect(0, 0, w, h);

            if (popHistory.isEmpty()) {
                g2.setColor(new Color(140, 150, 160));
                g2.setFont(new Font("SansSerif", Font.PLAIN, 11));
                g2.drawString("Graphs will appear as the simulation runs...", 10, h/2);
                g2.dispose();
                return;
            }

            int n = popHistory.size();
            int chartH1 = h * 55 / 100; // pop/gen
            int chartH2 = h - chartH1 - 4; // gases

            drawTimeSeries(g2, 0, chartH1, w, chartH1, popHistory, genHistory, "Pop / Gen", popCol, genCol, true);
            drawTimeSeries(g2, 0, chartH1 + 4, w, chartH2, o2History, co2History, so2History, radHistory,
                           "O2 / CO2 / SO2 / Rad", o2Col, co2Col, so2Col, radCol);

            g2.dispose();
        }

        private void drawTimeSeries(Graphics2D g2, int x, int y, int w, int h,
                                    java.util.List<? extends Number> a, java.util.List<? extends Number> b,
                                    String title, Color ca, Color cb, boolean integerScale) {
            g2.setColor(gridCol);
            g2.drawRect(x, y, w-1, h-1);
            // light grid
            for (int i=1; i<4; i++) {
                int gy = y + i * h / 4;
                g2.drawLine(x, gy, x+w-1, gy);
            }

            g2.setColor(new Color(160,170,180));
            g2.setFont(new Font("SansSerif", Font.PLAIN, 10));
            g2.drawString(title, x + 4, y + 12);

            int n = a.size();
            if (n < 2) return;

            // find ranges
            double minA = Double.MAX_VALUE, maxA = -Double.MAX_VALUE;
            double minB = Double.MAX_VALUE, maxB = -Double.MAX_VALUE;
            for (int i=0; i<n; i++) {
                double va = a.get(i).doubleValue();
                double vb = b.get(i).doubleValue();
                minA = Math.min(minA, va); maxA = Math.max(maxA, va);
                minB = Math.min(minB, vb); maxB = Math.max(maxB, vb);
            }
            if (maxA - minA < 1) { maxA = minA + 1; }
            if (maxB - minB < 1) { maxB = minB + 1; }

            int px = x + 2;
            int py = y + h - 2;
            int pw = w - 4;
            int ph = h - 16;

            // plot A
            g2.setColor(ca);
            for (int i=1; i<n; i++) {
                double va0 = a.get(i-1).doubleValue();
                double va1 = a.get(i).doubleValue();
                int x0 = px + (i-1) * pw / (n-1);
                int x1 = px + i * pw / (n-1);
                int y0 = py - (int)((va0 - minA) / (maxA - minA) * ph);
                int y1 = py - (int)((va1 - minA) / (maxA - minA) * ph);
                g2.drawLine(x0, y0, x1, y1);
            }

            // plot B (second series)
            g2.setColor(cb);
            for (int i=1; i<n; i++) {
                double vb0 = b.get(i-1).doubleValue();
                double vb1 = b.get(i).doubleValue();
                int x0 = px + (i-1) * pw / (n-1);
                int x1 = px + i * pw / (n-1);
                int y0 = py - (int)((vb0 - minB) / (maxB - minB) * ph);
                int y1 = py - (int)((vb1 - minB) / (maxB - minB) * ph);
                g2.drawLine(x0, y0, x1, y1);
            }

            // current values
            g2.setColor(Color.WHITE);
            int last = n-1;
            g2.drawString(String.format("%d", a.get(last).intValue()), px + pw - 30, y + 12);
        }

        // overload for 4 series gases/rad (rad scaled 0-100)
        private void drawTimeSeries(Graphics2D g2, int x, int y, int w, int h,
                                    java.util.List<? extends Number> a, java.util.List<? extends Number> b,
                                    java.util.List<? extends Number> c, java.util.List<? extends Number> d,
                                    String title, Color ca, Color cb, Color cc, Color cd) {
            g2.setColor(gridCol);
            g2.drawRect(x, y, w-1, h-1);
            for (int i=1; i<4; i++) {
                int gy = y + i * h / 4;
                g2.drawLine(x, gy, x+w-1, gy);
            }
            g2.setColor(new Color(160,170,180));
            g2.setFont(new Font("SansSerif", Font.PLAIN, 10));
            g2.drawString(title, x + 4, y + 11);

            int n = a.size();
            if (n < 2) return;

            double minA=1e9,maxA=-1e9, minB=1e9,maxB=-1e9, minC=1e9,maxC=-1e9, minD=0,maxD=100;
            for (int i=0;i<n;i++) {
                double va=a.get(i).doubleValue(), vb=b.get(i).doubleValue(), vc=c.get(i).doubleValue(), vd=d.get(i).doubleValue();
                minA=Math.min(minA,va);maxA=Math.max(maxA,va);
                minB=Math.min(minB,vb);maxB=Math.max(maxB,vb);
                minC=Math.min(minC,vc);maxC=Math.max(maxC,vc);
            }
            if (maxA-minA<0.1) maxA=minA+0.1;
            if (maxB-minB<0.001) maxB=minB+0.001;
            if (maxC-minC<0.001) maxC=minC+0.001;

            int px = x+2, py=y+h-2, pw=w-4, ph=h-14;

            // O2
            g2.setColor(ca);
            for (int i=1;i<n;i++) {
                int x0=px+(i-1)*pw/(n-1), x1=px+i*pw/(n-1);
                int y0 = py - (int)((a.get(i-1).doubleValue()-minA)/(maxA-minA)*ph);
                int y1 = py - (int)((a.get(i).doubleValue()-minA)/(maxA-minA)*ph);
                g2.drawLine(x0,y0,x1,y1);
            }
            // CO2
            g2.setColor(cb);
            for (int i=1;i<n;i++) {
                int x0=px+(i-1)*pw/(n-1), x1=px+i*pw/(n-1);
                int y0 = py - (int)((b.get(i-1).doubleValue()-minB)/(maxB-minB)*ph);
                int y1 = py - (int)((b.get(i).doubleValue()-minB)/(maxB-minB)*ph);
                g2.drawLine(x0,y0,x1,y1);
            }
            // SO2
            g2.setColor(cc);
            for (int i=1;i<n;i++) {
                int x0=px+(i-1)*pw/(n-1), x1=px+i*pw/(n-1);
                int y0 = py - (int)((c.get(i-1).doubleValue()-minC)/(maxC-minC)*ph);
                int y1 = py - (int)((c.get(i).doubleValue()-minC)/(maxC-minC)*ph);
                g2.drawLine(x0,y0,x1,y1);
            }
            // Rad (fixed 0-100)
            g2.setColor(cd);
            for (int i=1;i<n;i++) {
                int x0=px+(i-1)*pw/(n-1), x1=px+i*pw/(n-1);
                int y0 = py - (int)((d.get(i-1).doubleValue()-minD)/(maxD-minD)*ph);
                int y1 = py - (int)((d.get(i).doubleValue()-minD)/(maxD-minD)*ph);
                g2.drawLine(x0,y0,x1,y1);
            }

            g2.setColor(Color.WHITE);
            g2.drawString(String.format("%.1f", a.get(n-1).doubleValue()), px+pw-28, y+10);
        }

        public void clear() {
            // called from init
            repaint();
        }
    }

    // ==================== AUDIO ====================

    static class AudioManager {
        private final Clip[] tracks = new Clip[4];
        private int currentTrackIndex = 0;
        private float volume = 0.65f;

        void loadTracks() {
            // Use classpath resources so it works from loose classes, JAR, or jpackage app-image bundle
            String[] resPaths = {
                "/audio/track1.wav",
                "/audio/track2.wav",
                "/audio/track3.wav",
                "/audio/track4.wav"
            };
            for (int i = 0; i < 4; i++) {
                try {
                    InputStream in = NuclearLifeSimulator.class.getResourceAsStream(resPaths[i]);
                    if (in == null) {
                        System.err.println("Audio resource missing: " + resPaths[i]);
                        continue;
                    }
                    try (InputStream bin = new BufferedInputStream(in)) {
                        AudioInputStream ais = AudioSystem.getAudioInputStream(bin);
                        tracks[i] = AudioSystem.getClip();
                        tracks[i].open(ais);
                        setClipVolume(tracks[i], volume);
                    }
                } catch (Exception ex) {
                    System.err.println("Failed to load audio " + resPaths[i] + ": " + ex.getMessage());
                }
            }
        }

        void setVolume(float v) {
            volume = Math.max(0f, Math.min(1f, v));
            if (tracks[currentTrackIndex] != null && tracks[currentTrackIndex].isRunning()) {
                setClipVolume(tracks[currentTrackIndex], volume);
            }
        }

        private void setClipVolume(Clip clip, float vol) {
            if (clip == null) return;
            try {
                FloatControl gain = (FloatControl) clip.getControl(FloatControl.Type.MASTER_GAIN);
                float dB = (float) (Math.log10(Math.max(0.0001, vol)) * 20.0);
                gain.setValue(dB);
            } catch (Exception ignored) {}
        }

        void playTrack(int idx) {
            stopAll();
            if (idx < 0 || idx >= tracks.length || tracks[idx] == null) {
                currentTrackIndex = 0;
                return;
            }
            currentTrackIndex = idx;
            Clip c = tracks[idx];
            c.setFramePosition(0);
            setClipVolume(c, volume);
            c.loop(Clip.LOOP_CONTINUOUSLY);
        }

        void nextTrack() {
            int next = (currentTrackIndex + 1) % 4;
            playTrack(next);
        }

        void stopAll() {
            for (Clip c : tracks) {
                if (c != null && c.isRunning()) {
                    c.stop();
                }
            }
        }
    }

    // ==================== MAIN ====================

    public static void main(String[] args) {
        // Run on EDT
        SwingUtilities.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            } catch (Exception ignored) {}
            new NuclearLifeSimulator();
        });
    }
}
