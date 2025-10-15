/**
 * Virtual Aquarium — Two Screens + HUD + Bottom Buttons + Help(X)
 * + Random Coral + Rising Bubbles (no sound)
 * ---------------------------------------------------------------
 * Screens:
 *   - WELCOME: title + Start
 *   - PLAY: aquarium simulation
 *
 * Bottom buttons (on the yellow sand):
 *   - Help: toggles help overlay (also 'h')
 *   - Home: returns to Welcome (fade), resets fish/food
 *
 * Other controls:
 *   - Click: drop food
 *   - d: day/night    t: trails    c: clear food    r: reset fish
 */

ArrayList<Fish> fishes;
ArrayList<Food> foods;
ArrayList<Coral> corals;      // decorative coral clusters
ArrayList<Bubble> bubbles;    // rising bubble particles
int NUM_FISH = 20;

// Visual toggles
boolean isNight = false;
boolean trails = false;
boolean showHelp = false;

// Gradient colors + mix (0=day, 1=night)
color dayTop = #7CD6F5, dayBottom = #1BA3D8;
color nightTop = #13253A, nightBottom = #061421;
float bgMix = 0;

// --- App state ---
final int WELCOME = 0;
final int PLAY    = 1;
int appState = WELCOME;

// Fade overlay (for transitions)
float fadeA = 255; // start covered, fade in

// Welcome start button
int btnW = 220, btnH = 56;

// Help overlay close button bounds (computed each frame)
int helpCloseX = 0, helpCloseY = 0, helpCloseSize = 24;

void settings() {
  size(900, 560);
  smooth(8);
}

void setup() {
  fishes  = new ArrayList<Fish>();
  foods   = new ArrayList<Food>();
  corals  = new ArrayList<Coral>();
  bubbles = new ArrayList<Bubble>();

  populateFish(NUM_FISH);
  generateCorals(6, 10);  // between 6 and 10 coral clusters
}

void draw() {
  if (appState == WELCOME) {
    drawWelcome();
  } else if (appState == PLAY) {
    drawPlay();
  }

  // Global fade
  if (fadeA > 0) {
    noStroke();
    fill(0, fadeA);
    rect(0, 0, width, height);
    fadeA = max(0, fadeA - 12);
  }
}

/* ===================== WELCOME + PLAY ===================== */

void drawWelcome() {
  float target = isNight ? 1 : 0;
  bgMix = lerp(bgMix, target, 0.05);
  drawGradientBackground(bgMix);
  drawSand();
  drawCorals();                // behind fish
  spawnAmbientBubbles();       // gentle ambient
  updateAndDrawBubbles(true);  // true = draw behind fish

  // idle fish
  for (Fish f : fishes) {
    f.applyBehaviors(new ArrayList<Food>());
    f.update();
    f.edges();
    f.render();
  }

  // title card
  textAlign(CENTER, CENTER);
  noStroke();
  fill(255, 230);
  rect(width/2 - 360, 92, 720, 124, 16);

  fill(20);
  textSize(36);
  text("Virtual Aquarium", width/2, 130);
  textSize(14);
  text("Feed fish (click) • Scare with mouse • d: day/night • t: trails", width/2, 172);

  // Start button
  boolean hover = overStartButton();
  float y = height/2 + 40;
  fill(hover ? color(255, 245) : color(255, 225));
  stroke(120);
  rect(width/2 - btnW/2, y - btnH/2, btnW, btnH, 14);

  fill(20);
  noStroke();
  textSize(18);
  text("Start", width/2, y);

  // hint
  textSize(12);
  fill(255);
  text("Press ENTER to start  •  Press D here to preview Day/Night", width/2, y + 60);
}

void drawPlay() {
  float target = isNight ? 1 : 0;
  bgMix = lerp(bgMix, target, 0.05);

  if (!trails) {
    drawGradientBackground(bgMix);
    drawSand();
  } else {
    noStroke();
    fill(0, 40);
    rect(0, 0, width, height);
  }

  drawCorals();                 // draw before fish
  spawnAmbientBubbles();        // random & coral-driven
  updateAndDrawBubbles(true);   // bubbles behind fish first

  // food
  for (int i = foods.size()-1; i >= 0; i--) {
    Food f = foods.get(i);
    f.update();
    f.render();
    if (f.isExpired()) foods.remove(i);
  }

  // fish
  for (Fish fish : fishes) {
    fish.applyBehaviors(foods);
    fish.update();
    fish.edges();
    fish.render();
  }

  // foreground bubbles (some pop “in front” look)
  updateAndDrawBubbles(false);

  drawTopBar();
  if (showHelp) drawHelpOverlay();

  // bottom sand buttons
  drawBottomButtons();
}

/* ===================== BUBBLE SYSTEM ===================== */

// Emit bubbles from sand + coral tips with occasional randomness.
// Day vs Night slightly changes rate/size.
void spawnAmbientBubbles() {
  // base spawn
  float baseRate = isNight ? 0.001 : 0.003; // probability/frame
  if (random(1) < baseRate) {
    // random sand emitter
    float x = random(30, width - 30);
    bubbles.add(makeSandBubble(x, height - 70));
  }

  // coral emitters (lighter rate, spawn near tips)
  for (Coral c : corals) {
    if (random(1) < 0.01) {
      PVector tip = c.tipPosition();
      bubbles.add(makeCoralBubble(tip.x + random(-6, 6), tip.y + random(-4, 2)));
    }
  }
}

// Update and draw all bubbles. If behind==true, draw only background layer.
// We split draw passes so some bubbles can appear in front of fish for depth.
void updateAndDrawBubbles(boolean behind) {
  for (int i = bubbles.size()-1; i >= 0; i--) {
    Bubble b = bubbles.get(i);
    b.update();
    if (b.dead()) {
      bubbles.remove(i);
      continue;
    }
    // simple z-order via a flag in the bubble
    if (b.drawBehind == behind) b.render();
  }
}

/* ===================== UI COMPONENTS ===================== */

void drawTopBar() {
  int pad = 12;
  int barW = width - pad*2;
  int barH = 70;

  noStroke();
  fill(255, 215);
  rect(pad, pad, barW, barH, 12);

  fill(20);
  textAlign(LEFT, TOP);

  textSize(16);
  text("Virtual Aquarium", pad + 14, pad + 10);

  textSize(12);
  String status = "Fish: " + fishes.size() + "    Food: " + foods.size() +
    "    Day/Night: " + (isNight ? "Night" : "Day") +
    "    Trails: " + (trails ? "On" : "Off") +
    "    FPS: " + nf(frameRate, 1, 0);
  text(status, pad + 14, pad + 32);

  String controls = "Click = food  |  d = day/night  |  t = trails  |  c = clear food  |  r = reset  |  h = help  |  ENTER = Start (Welcome)";
  text(controls, pad + 14, pad + 48);
}

void drawBottomButtons() {
  int y = height - 55; // on the sand
  int w = 100;
  int h = 35;
  int spacing = 20;
  int xHelp = width/2 - w - spacing/2;
  int xHome = width/2 + spacing/2;

  // Help
  boolean overHelp = (mouseX > xHelp && mouseX < xHelp + w && mouseY > y && mouseY < y + h);
  fill(overHelp ? color(255, 250) : color(255, 230));
  stroke(120);
  rect(xHelp, y, w, h, 10);
  fill(0);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Help", xHelp + w/2, y + h/2);

  // Home
  boolean overHome = (mouseX > xHome && mouseX < xHome + w && mouseY > y && mouseY < y + h);
  fill(overHome ? color(255, 250) : color(255, 230));
  stroke(120);
  rect(xHome, y, w, h, 10);
  fill(0);
  text("Home", xHome + w/2, y + h/2);
}

void drawHelpOverlay() {
  // dim
  noStroke();
  fill(0, 160);
  rect(0, 0, width, height);

  // centered card
  int cardW = min(560, width - 80);
  int cardH = min(320, height - 120);
  int x = (width - cardW)/2;
  int y = (height - cardH)/2;

  fill(255);
  rect(x, y, cardW, cardH, 16);

  // Close "X" in top-right of card
  helpCloseSize = 24;
  helpCloseX = x + cardW - helpCloseSize - 10;
  helpCloseY = y + 10;
  boolean overClose = (mouseX >= helpCloseX && mouseX <= helpCloseX + helpCloseSize &&
    mouseY >= helpCloseY && mouseY <= helpCloseY + helpCloseSize);
  fill(overClose ? color(235) : color(245));
  stroke(160);
  rect(helpCloseX, helpCloseY, helpCloseSize, helpCloseSize, 6);
  stroke(80);
  strokeWeight(2);
  line(helpCloseX + 6, helpCloseY + 6, helpCloseX + helpCloseSize - 6, helpCloseY + helpCloseSize - 6);
  line(helpCloseX + helpCloseSize - 6, helpCloseY + 6, helpCloseX + 6, helpCloseY + helpCloseSize - 6);
  strokeWeight(1);

  // content
  fill(20);
  textAlign(LEFT, TOP);
  textSize(18);
  text("Help & Controls", x + 18, y + 16);

  textSize(12);
  int tx = x + 18;
  int ty = y + 46;
  int tw = cardW - 36;
  textLeading(18);

  String[] lines = {
    "• Click anywhere to drop food pellets. Fish will seek and eat them.",
    "• Move the mouse near fish to scare them (predator effect).",
    "• d = day/night    t = trails (motion blur)",
    "• c = clear all food      r = reset fish",
    "• h = toggle this help panel    Home button returns to Welcome."
  };
  for (String s : lines) {
    drawWrappedText(s, tx, ty, tw, 18);
    ty += 18;
  }
}

void drawWrappedText(String s, int x, int y, int w, int lh) {
  if (textWidth(s) <= w) {
    text(s, x, y);
    return;
  }
  String cur = "";
  String[] words = splitTokens(s, " ");
  int yy = y;
  for (int i = 0; i < words.length; i++) {
    String test = (cur.length()==0 ? words[i] : cur + " " + words[i]);
    if (textWidth(test) > w) {
      text(cur, x, yy);
      yy += lh;
      cur = words[i];
    } else cur = test;
  }
  if (cur.length() > 0) text(cur, x, yy);
}

/* ===================== INPUT ===================== */

void mousePressed() {
  if (appState == WELCOME) {
    if (overStartButton()) startGame();
    return;
  }

  // If help is open, check close "X"
  if (showHelp) {
    if (mouseX >= helpCloseX && mouseX <= helpCloseX + helpCloseSize &&
      mouseY >= helpCloseY && mouseY <= helpCloseY + helpCloseSize) {
      showHelp = false;
      return;
    }
  }

  // Bottom buttons (PLAY state)
  int y = height - 55, w = 100, h = 35, spacing = 20;
  int xHelp = width/2 - w - spacing/2;
  int xHome = width/2 + spacing/2;

  // Help button
  if (mouseX > xHelp && mouseX < xHelp + w && mouseY > y && mouseY < y + h) {
    showHelp = !showHelp;
    return;
  }

  // Home button
  if (mouseX > xHome && mouseX < xHome + w && mouseY > y && mouseY < y + h) {
    appState = WELCOME;
    fadeA = 255;
    foods.clear();
    populateFish(NUM_FISH);
    showHelp = false;
    return;
  }

  // otherwise drop food
  foods.add(new Food(mouseX, mouseY));
}

void keyPressed() {
  if (appState == WELCOME) {
    if (keyCode == ENTER || keyCode == RETURN) startGame();
    if (key == 'd' || key == 'D') isNight = !isNight; // preview
    return;
  }

  // PLAY keys
  if (key == 'd' || key == 'D') isNight = !isNight;
  if (key == 't' || key == 'T') trails = !trails;
  if (key == 'c' || key == 'C') foods.clear();
  if (key == 'r' || key == 'R') {
    foods.clear();
    populateFish(NUM_FISH);
  }
  if (key == 'h' || key == 'H') showHelp = !showHelp;
}

/* ===================== UTIL ===================== */

boolean overStartButton() {
  float x = width/2 - btnW/2;
  float y = height/2 + 40 - btnH/2;
  return mouseX >= x && mouseX <= x + btnW && mouseY >= y && mouseY <= y + btnH;
}

void startGame() {
  appState = PLAY;
  fadeA = 255;     // fade-in
  showHelp = false; // don't open help automatically
}

void populateFish(int n) {
  fishes.clear();
  for (int i = 0; i < n; i++) {
    float x = random(width);
    float y = random(100, height - 100);
    fishes.add(new Fish(x, y));
  }
}

void drawGradientBackground(float m) {
  color top = lerpColor(dayTop, nightTop, m);
  color bottom = lerpColor(dayBottom, nightBottom, m);
  noFill();
  for (int y = 0; y < height; y++) {
    float t = map(y, 0, height, 0, 1);
    stroke(lerpColor(top, bottom, t));
    line(0, y, width, y);
  }
}

void drawSand() {
  noStroke();
  fill(lerpColor(#E6D47A, #A7954E, bgMix));
  rect(0, height - 70, width, 70);
  fill(lerpColor(#8E8B84, #54524E, bgMix));
  ellipse(120, height - 40, 60, 26);
  ellipse(160, height - 35, 40, 18);
  ellipse(width-150, height - 30, 80, 32);
}

/* ===================== CORAL DECORATIONS ===================== */

void generateCorals(int minClusters, int maxClusters) {
  corals.clear();
  int n = (int)random(minClusters, maxClusters+1);
  for (int i = 0; i < n; i++) {
    float x = random(40, width - 40);
    float baseY = height - 70;              // sand top
    float h = random(30, 70);               // height of main stalk
    float sway = random(0.02, 0.05);        // sway speed
    color c = color(random(140, 255), random(80, 180), random(140, 255));
    corals.add(new Coral(x, baseY, h, sway, c));
  }
}

void drawCorals() {
  for (Coral c : corals) c.render();
}

/* ===================== CLASSES ===================== */

class Fish {
  PVector pos, vel, acc;
  float maxSpeedDay = 2.4, maxSpeedNight = 2.0, maxForce = 0.08;
  float baseSize = random(16, 26);
  color bodyCol;
  float hunger = random(0.4, 1.0);
  float hungerDecay = 0.0008;

  Fish(float x, float y) {
    pos = new PVector(x, y);
    float angle = random(TWO_PI);
    vel = new PVector(cos(angle), sin(angle)).mult(random(0.5, 2.0));
    acc = new PVector();
    color[] palette = { #FF6B6B, #FFD93D, #6BCB77, #4D96FF, #B781FF, #FF7EB6 };
    bodyCol = palette[(int)random(palette.length)];
  }

  void applyBehaviors(ArrayList<Food> pellets) {
    // flee mouse
    PVector fleeForce = new PVector(0, 0);
    if (dist(mouseX, mouseY, pos.x, pos.y) < 90) {
      fleeForce = flee(new PVector(mouseX, mouseY));
      fleeForce.mult(1.6);
    }

    // seek nearest food if hungry
    PVector seekForce = new PVector(0, 0);
    if (!pellets.isEmpty() && hunger < 0.95) {
      Food nearest = null;
      float best = Float.MAX_VALUE;
      for (Food f : pellets) {
        float d = PVector.dist(pos, f.pos);
        if (d < best) {
          best = d;
          nearest = f;
        }
      }
      if (nearest != null) {
        seekForce = seek(nearest.pos);
        if (best < 18) {
          hunger = min(1.0, hunger + 0.4);
          pellets.remove(nearest);
        }
      }
    }

    // wander
    PVector wanderForce = new PVector(random(-0.3, 0.3), random(-0.15, 0.15));

    applyForce(wanderForce);
    applyForce(seekForce.mult(1.0));
    applyForce(fleeForce);
  }

  void applyForce(PVector f) {
    acc.add(f);
  }

  PVector seek(PVector target) {
    PVector desired = PVector.sub(target, pos);
    float d = desired.mag();
    desired.normalize();

    float maxSpd = getMaxSpeed();
    if (d < 80) desired.mult(map(d, 0, 80, 0, maxSpd));
    else desired.mult(maxSpd);

    PVector steer = PVector.sub(desired, vel);
    steer.limit(maxForce);
    return steer;
  }

  PVector flee(PVector threat) {
    PVector desired = PVector.sub(pos, threat);
    desired.normalize();
    desired.mult(getMaxSpeed());
    PVector steer = PVector.sub(desired, vel);
    steer.limit(maxForce * 1.4);
    return steer;
  }

  float getMaxSpeed() {
    float base = lerp(maxSpeedDay, maxSpeedNight, bgMix);
    return constrain(map(hunger, 0, 1, base * 0.6, base * 1.15), 0.6, 3.2);
  }

  void update() {
    vel.add(acc);
    vel.limit(getMaxSpeed());
    pos.add(vel);
    acc.mult(0);
    hunger = max(0, hunger - hungerDecay);
  }

  void edges() {
    float m = baseSize * 0.5;
    if (pos.x < m) {
      pos.x = m;
      vel.x *= -1;
    }
    if (pos.x > width - m) {
      pos.x = width - m;
      vel.x *= -1;
    }
    if (pos.y < m) {
      pos.y = m;
      vel.y *= -1;
    }
    if (pos.y > height - 70 - m) {
      pos.y = height - 70 - m;
      vel.y *= -1;
    }
  }

  void render() {
    pushMatrix();
    translate(pos.x, pos.y);
    float angle = atan2(vel.y, vel.x);
    rotate(angle);

    float s = baseSize;
    color c = lerpColor(bodyCol, color(60), bgMix * 0.5);

    noStroke();
    fill(c);
    ellipse(0, 0, s*1.4, s*0.8);                  // body
    fill(lerpColor(c, color(0), 0.2));                      // tail
    triangle(-s*0.9, 0, -s*1.3, -s*0.35, -s*1.3, s*0.35);
    fill(lerpColor(c, color(255), 0.2));                    // fin
    triangle(-s*0.2, -s*0.2, s*0.3, -s*0.05, -s*0.05, s*0.05);

    fill(255);
    ellipse(s*0.55, -s*0.12, s*0.22, s*0.22);    // eye
    fill(0);
    ellipse(s*0.58, -s*0.12, s*0.11, s*0.11);
    popMatrix();

    drawHungerBar();
  }

  void drawHungerBar() {
    float w = baseSize * 1.2, h = 4;
    float x = pos.x - w/2, y = pos.y - baseSize * 0.9;

    stroke(0, 120);
    fill(0, 80);
    rect(x, y, w, h, 2);
    noStroke();
    int col = lerpColor(color(220, 60, 60), color(60, 200, 100), hunger);
    fill(col);
    rect(x, y, w * hunger, h, 2);
  }
}

class Food {
  PVector pos, vel;
  float r = 6;
  int ttl = 60 * 15; // ~15s

  Food(float x, float y) {
    pos = new PVector(x, y);
    vel = new PVector(random(-0.4, 0.4), random(0.2, 0.6));
  }

  void update() {
    pos.add(vel);
    vel.y = min(vel.y + 0.002, 0.8);
    if (pos.y > height - 75) {
      pos.y = height - 75;
      vel.mult(0);
    }
    ttl--;
  }

  boolean isExpired() {
    return ttl <= 0;
  }

  void render() {
    noStroke();
    fill(255, 230, 120, 230);
    ellipse(pos.x, pos.y, r, r);
    fill(255, 255, 255, 150);
    ellipse(pos.x - 1.5, pos.y - 1.5, r*0.35, r*0.35);
  }
}

/* Decorative coral with gentle sway */
class Coral {
  float baseX, baseY; // base on sand
  float h;            // stalk height
  float swaySpeed;    // radians per frame
  float phase;
  color col;

  Coral(float x, float y, float h, float speed, color c) {
    this.baseX = x;
    this.baseY = y;
    this.h = h;
    this.swaySpeed = speed;
    this.phase = random(TWO_PI);
    this.col = c;
  }
  void render() {
    float t = frameCount * swaySpeed + phase;
    float tipOffset = sin(t) * 10; // sway ±10px

    // stalk
    stroke(lerpColor(col, color(40), 0.4));
    strokeWeight(8);
    noFill();
    // simple curved stalk using bezier
    float cx1 = baseX - 10, cy1 = baseY - h*0.5;
    float cx2 = baseX + 18, cy2 = baseY - h*0.8;
    bezier(baseX, baseY, cx1, cy1, cx2, cy2, baseX + tipOffset, baseY - h);

    // branches (small ellipses)
    noStroke();
    fill(col);
    for (int i = 0; i < 5; i++) {
      float yy = baseY - map(i, 0, 4, h*0.2, h*0.95);
      float xx = baseX + tipOffset*map(i, 0, 4, 0.1, 1.0) + (i%2==0? -10: 10);
      ellipse(xx, yy, 14, 10);
    }

    // base rock
    fill(lerpColor(#8E8B84, #54524E, bgMix));
    ellipse(baseX, baseY + 6, 28, 12);
  }

  // Approximate animated tip position (for bubble emitters)
  PVector tipPosition() {
    float t = frameCount * swaySpeed + phase;
    float tipOffset = sin(t) * 10;
    return new PVector(baseX + tipOffset, baseY - h);
  }
}

Bubble makeSandBubble(float x, float y) {
  Bubble b = new Bubble();
  b.pos = new PVector(x, y);
  b.vel = new PVector(random(-0.25, 0.25), random(-1.6, -1.0));
  b.r = random(3, 7);
  b.maxLife = random(180, 260);
  b.life = b.maxLife;
  b.wobbleAmp = random(0.8, 2.2);
  b.wobbleFreq = random(0.02, 0.05);
  b.wobblePhase = random(TWO_PI);
  b.drawBehind = true; // most sand bubbles behind fish
  return b;
}

Bubble makeCoralBubble(float x, float y) {
  Bubble b = new Bubble();
  b.pos = new PVector(x, y);
  b.vel = new PVector(random(-0.2, 0.2), random(-1.8, -1.1));
  b.r = random(2.5, 6);
  b.maxLife = random(150, 220);
  b.life = b.maxLife;
  b.wobbleAmp = random(1.2, 2.8);
  b.wobbleFreq = random(0.025, 0.055);
  b.wobblePhase = random(TWO_PI);
  b.drawBehind = random(1) < 0.35 ? false : true; // some in front for depth
  return b;
}


/* Rising bubbles with gentle wobble & size/fade change */
class Bubble {
  PVector pos, vel;
  float r;            // radius
  float life, maxLife;
  float wobbleAmp, wobbleFreq, wobblePhase;
  boolean drawBehind; // draw order hint




  void update() {
    // wobble sideways
    float wobble = sin(frameCount * wobbleFreq + wobblePhase) * wobbleAmp;
    pos.x += wobble * 0.25;

    // rise
    pos.add(vel);

    // tiny drift based on "current"
    pos.x += map(noise(pos.y * 0.01), 0, 1, -0.15, 0.15);

    // shrink a bit as it rises, fade out near surface
    r *= 0.9995;
    life--;

    // pop at the surface
    if (pos.y < 30) life = 0;
  }

  boolean dead() {
    return life <= 0 || r < 1.2;
  }

  void render() {
    noFill();
    stroke(255, 130);
    ellipse(pos.x, pos.y, r, r);
    // small highlight
    stroke(255, 200);
    ellipse(pos.x - r*0.25, pos.y - r*0.25, r*0.35, r*0.35);
  }
}
