import krister.Ess.*;
import processing.serial.*;


/**
 * Arduino + Wii NunChuck
 */

final int BAUD_RATE = 19200;
float xrotate = 0.0;
float yrotate = 0.0;
float zrotate = 0.0;
final int X_AXIS_MIN = 300;
final int X_AXIS_MAX = 700;
final int Y_AXIS_MIN = 300;
final int Y_AXIS_MAX = 700;
final int Z_AXIS_MIN = 300;
final int Z_AXIS_MAX = 700;
final int MIN_SCALE = 5;
final int MAX_SCALE = 128;
final float MX = 2.0 / (X_AXIS_MAX - X_AXIS_MIN);
final float MY = 2.0 / (Y_AXIS_MAX - Y_AXIS_MIN);
final float MZ = 2.0 / (Z_AXIS_MAX - Z_AXIS_MIN);
final float BX = 1.0 - MX * X_AXIS_MAX;
final float BY = 1.0 - MY * Y_AXIS_MAX;
final float BZ = 1.0 - MZ * Z_AXIS_MAX;
final int LINE_FEED = 10;
final int MAX_SAMPLES = 16;
Serial arduinoPort;
SensorDataBuffer sensorData = new SensorDataBuffer(MAX_SAMPLES);

/***
 * Les Variables Globales.
 */
int roadSegmentSize = 5;
Player player; // Un joueur
Render render; // un moteur de rendu.
RoadParam roadParam = new RoadParam();
int numberOfSegmentPerColor = 4;
float lastDelta = 0;
ArrayList road; // La route
ArrayList buffer; // La route
PImage b; // le background photo du cnam 
PFont font;
PFont digit; 
// La voiture 
PImage sprt;
PImage gauche, droite, micro;
// le temps
int startTime; 

/**
 * Variable pour Ess
 */
AudioInput myInput;
FFT myFFT;
int bufferSize;
/**
 * Le speech 
 */
String[] speech= { 
  "Vrooooooooum ... ", "Le chemin vers le CNAM est vraiment long", "sinueux..", 
  "Mais finalement le conducteur c'est vous !", "Marc Camuzat pour RSX116"
};


/**
 * Initialisation 
 */
void setup() {
  size (500, 300);
  Ess.start(this);
  bufferSize=512;
  myInput=new AudioInput(bufferSize); // par def. Fe = 44100 Hz
  // set up our FFT
  myFFT=new FFT(bufferSize*2);
  render = new Render(width, height);
  // Initialisation des sprites 
  b = loadImage("cnam.jpg");
  sprt = loadImage("spritesheet.high.png");
  gauche = loadImage("gauche.png");
  droite = loadImage("droite.png");
  micro = loadImage("micro.png");
  font = loadFont("pixelade-26.vlw");
  digit = loadFont("digital-7-46.vlw");
  player = new Player();
  // Création de la route
  road = new ArrayList();
  buffer = new ArrayList();
  generateRoadfunction();

  // pas de trait
  noStroke();
  myInput.start();
  startTime=60000*minute()+1000*second()+millis();
  // decommentez les lignes pour le nunchuck.. 
  /*arduinoPort = new Serial(this, Serial.list()[0], BAUD_RATE);
   arduinoPort.bufferUntil(LINE_FEED);*/
}



/**
 * Fonction qui dessine un segment de route
 */
void drawSegment(float position1, float scale1, float offset1, float position2, float scale2, float offset2, boolean alternate, boolean finishStart) {
  int grass     = (alternate) ? #eeddaa : #ddcc99;
  int border    = (alternate) ? #ee0000 : #ffffff;
  int road      = (alternate) ? #999999 : #777777;
  int lane      = (alternate) ? #ffffff : #777777;


  // Au démarrage on veux une belle ligne blanche ..
  if (finishStart) {
    road = #ffffff;
    lane = #ffffff;
    border = #ffffff;
  }

  // On dessine le gazon 
  fill(color(grass));
  rect(0, position2, render.width, (position1-position2));

  // On rajoute la route 
  drawTrapez(position1, scale1, offset1, position2, scale2, offset2, -0.5, 0.5, road);

  //Le bord de la route en rouge ou blanc.
  drawTrapez(position1, scale1, offset1, position2, scale2, offset2, -0.5, -0.47, border);
  drawTrapez(position1, scale1, offset1, position2, scale2, offset2, 0.47, 0.5, border);

  // Enfin les lignes blanches (blanc ou couleur de la route)
 drawTrapez(position1, scale1, offset1, position2, scale2, offset2, -0.18, -0.15, lane);
 drawTrapez(position1, scale1, offset1, position2, scale2, offset2, 0.15, 0.18, lane);
}

void drawTrapez(float pos1, float scale1, float offset1, float pos2, float scale2, float offset2, float delta1, float delta2, int colour) {
  int demiWidth = width / 2;
  fill(color(colour));
  quad(demiWidth + delta1 * render.width * scale1 + offset1, pos1, 
  demiWidth + delta1 * render.width * scale2 + offset2, pos2, 
  demiWidth + delta2 * render.width * scale2 + offset2, pos2, 
  demiWidth + delta2 * render.width * scale1 + offset1, pos1);
}
void drawCar() {
  if ( player.state == 0) {
    image(sprt, 250, 250);
  }
  if ( player.state == 1) {
    image(droite, 260, 250);
  }
  if ( player.state == 2) {
    image(gauche, 240, 250);
  }
}

void drawMicro(float maximum) {
        fill(#eeeeee);
      
      rect(width-25 , 50, 25, 200);
      image(micro, width-15, 52, 10, 20);
      color from = color(204, 15, 15);
      color to = color(50, 204, 15);
      color interA = lerpColor(from, to, maximum/2);
      fill(interA);
      rect(width -20, 80, 10, 100*maximum);
 
}
/**
 * Dessine le fond d'écran.. il bouge en fonction de la position du conducteur
 */
void drawBackground(float position) {
  float first = position / 2 % (320);
  // on s'arrange pour quel l'image se reboucle sur elle-même
  image(b, first-320, 0, width*2, height/2);
  image(b, first+320, 0, width*2, height/2);
  image(b, first, 0, width*2, height/2);
}



// Génération automatique de la route. 
//  En 3 partie..
// 
void  generateRoadfunction() {
  // d'abard on génére la 'H'auteur
  int currentStateH = 0; //0 => plat 1=>  2=> bas
  // les transition possible plat->haut->bas
  //                         plat->haut->haut
  //                         plat->bas->bas
  // On souhaite ainsi eviter les séquence haut->bas->haut->bas qui pourrait arriver si on générait de façcon aléatoire.. 

  int[][] transitionH = {
    {
      0, 1, 2
    }
    , {
      0, 2, 2
    }
    , {
      0, 1, 1
    }
  };
  // d'abard on génére la 'C' courbure
  int currentStateC = 0; //0=straight 1=left 2= right
  int[][] transitionC = {
    {
      0, 1, 2
    }
    , {
      0, 2, 2
    }
    , {
      0, 1, 1
    }
  };

  float currentHeight = 0; //variable qui va nous permettre de garder la hauteur actuelle
  float currentCurve  = 0; // variable qui va nous permettre de garder la hauteur actuelle
  // nombre de zone à générer
  int zones = roadParam.length;
  while (zones--> 0) {
    float finalHeight=0; 
    switch(currentStateH) {
    case 0:
      finalHeight = 0; // si le terrain est plat pas besoin de changer la hauteur
      break;
    case 1:
      finalHeight = random(roadParam.maxHeight); // si on grimpe il faut augementer
      break;
    case 2:
      finalHeight = -random(roadParam.maxHeight); 
      break;
    }
    float finalCurve=0;
    switch(currentStateC) {
    case 0:
      finalCurve = 0; 
      break;
    case 1:
      finalCurve = -random(roadParam.maxCurve); 
      break;
    case 2:
      finalCurve = random(roadParam.maxCurve); 
      break;
    }
    // On a la courbure finale et la hauteur finale. On rajoute les troncons dans la mémoire

    for (int i=0; i < roadParam.zoneSize; i++) {



      road.add(new Segment(
      (float)(currentHeight+finalHeight / 2 * (1 + 1.0*Math.sin(i*1.0/roadParam.zoneSize * Math.PI-Math.PI/2))), 
      (float)(currentCurve+finalCurve / 2 * (1 + 1.0*Math.sin(i*1.0/roadParam.zoneSize * Math.PI-Math.PI/2))) 
      )
        );
    }

    // On ajoute le tout 
    currentHeight += finalHeight;
    currentCurve += finalCurve;
    // Maintenant il faut trouver la prochaine valeur
    // si on a une route tres montagneuses
    if (random(1) < roadParam.mountainy) {
      // On choisi un chiffre entre 0 et 2
      // puis suivant que l'on grimpe, descant, ou plat on choisit une des trois possibilité
      // par exemple On est horizontal currentStateH = 0
      // alors les transition possible sont 0 => restez horizontal 1=> monter 2=>descendre
      // par contre si on monte currentStateH = 1 alors les 3 possibilité 0 => redevenir horizontal, ou 1 et 2 continue à monter
      // tout cela se fait dans le but d'éviter le yoyo monter descendre
      currentStateH = transitionH[currentStateH][1+Math.round(random(1))];
    } 
    else {
      currentStateH = transitionH[currentStateH][0];
    }
    // Mème raisonnement pour gauche et droite
    if (random(1) < roadParam.curvy) {
      currentStateC = transitionC[currentStateC][1+Math.round(random(1))];
    } 
    else {
      currentStateC = transitionC[currentStateC][0];
    }
  }
  roadParam.length = roadParam.length * roadParam.zoneSize;
};


void draw() {
  if (!player.play) {
    image(sprt, 70, 50, 200, 100);
    textFont(font);
    text("CAMUZAT Marc", 300, 100);
    text("NSY 116 2012", 300, 150);
    text("Appuyer sur entrée ", 60, 300);
    textFont(digit);
    text("Sur la route du CNAM", 15, 200);
    text("Une Histoire de volonte", 15, 250);
    startTime=60000*minute()+1000*second()+millis();
    return;
  }
  // en quelque étape.
  // d'abord on néttoie l'écran
  background(#ddcc99);
  drawBackground(-player.posx);
  // Le jouer est à quel endroit ?
  int absoluteIndex = (int)Math.floor(player.position / roadSegmentSize);
  if (absoluteIndex >= roadParam.length-render.depthOfField-1) {
    textFont(digit);
    text("Bravo !!!", 100, 100);
    text("Bonne Courage", 100, 150);
    text("tout le monde", 100, 200);
  }
  else {

    int i = 0;
    float maximum=0;
    while (i ++ < 256)
    {

      //find maximum
      if (myFFT.spectrum[i]>maximum) {

        maximum = myFFT.spectrum[i];
      }
    }
    player.speed += maximum/10;  
    //si la route est en pente, on va moins vite..
    if (Math.abs(lastDelta) > 130) {
      if (player.speed > 3) {
        player.speed -= 0.2;
      }
    } 


    // forcement le joueur ralenti

    player.speed -= player.deceleration; //le chiffre est faible, mais on passe 30 fois par secondes

    // a force de ralentir on peux avoir une vitesse négative
    // à force d'accélerer on avoir une vitesse infini
    // quelque garde fous..
    player.speed = Math.max(player.speed, 0); //pas de vitesse négative
    player.speed = Math.min(player.speed, player.maxSpeed); //pas de vitesse meximum

    // On augmente la position.

    player.position += player.speed;

    // sur quel segment somme-nous ?
    int currentSegmentIndex    = (absoluteIndex - 2) % road.size();
    // a quel niveau du segment somme nous 
    float currentSegmentPosition = (absoluteIndex - 2) * roadSegmentSize - player.position;
    // allons chercher le segement ou nous somme 
    Segment currentSegment         = (Segment)road.get(currentSegmentIndex);

    float lastProjectedHeight   = 1000000000000000000.0; // Un chiffre enorme
    float probedDepth             = 0;

    // ce compteur va nous servir dans l'alternance de couleur; 
    int counter                 = absoluteIndex % (2 * numberOfSegmentPerColor);
    //on recupere la hauteur du segement
    float playerPosSegmentHeight     = ((Segment)road.get(absoluteIndex % road.size()))._height;
    // et le suivant
    float playerPosNextSegmentHeight = ((Segment)road.get(absoluteIndex+1 % road.size()))._height;
    // le joueur est a quel endorit sur le segment
    float playerPosRelative          = (player.position % roadSegmentSize) / roadSegmentSize;
    // alors le POV est situé 
    float  playerHeight               = render.camera_height + 
      playerPosSegmentHeight + 
      (playerPosNextSegmentHeight - playerPosSegmentHeight) * playerPosRelative;
    
    // On calcul la possition du segment en prenant en compte la courbure.
    float baseOffset     = (int)(currentSegment.curve +   
      ((Segment)road.get(currentSegmentIndex + 1)).curve
      - currentSegment.curve) * playerPosRelative;

    lastDelta = player.posx - baseOffset*2;

    // génére l'effet de profondeur 
    int iter = render.depthOfField;


    // voir le pdf joint pour l'algo en.
    while (iter--> 0) {
      // on affiche le 
      int nextSegmentIndex       = (currentSegmentIndex + 1) % road.size();
      Segment nextSegment            = (Segment)road.get(nextSegmentIndex);
      // On la position du joueur, on cherche la projection du segment 
      float startProjectedHeight = (float)Math.floor((playerHeight - currentSegment._height) * render.camera_distance / (render.camera_distance + currentSegmentPosition));
      // plus le segment est loin lus il doit etre petit
      float startScaling         = 30 / (render.camera_distance + currentSegmentPosition);

      // on fait le meme calcul pour le segment suivant
      float endProjectedHeight   = (float)Math.floor((playerHeight - nextSegment._height) * render.camera_distance / (render.camera_distance + currentSegmentPosition + roadSegmentSize));
      float endScaling           = 30 / (render.camera_distance + currentSegmentPosition + roadSegmentSize);

      // On obtient la taille courante
      float currentHeight        = Math.min(lastProjectedHeight, startProjectedHeight);
      float currentScaling       = startScaling;

      // Z-buffer si la taille est superieure sinon le segment est caché et cela ne vaux pas le coups de le dessinne
      if (currentHeight > endProjectedHeight) {
        drawSegment(
        render.height / 2 + currentHeight, // hauteur 1
        currentScaling, //
        currentSegment.curve - baseOffset - lastDelta * currentScaling, 
        render.height / 2 + endProjectedHeight, //hauteur2
        endScaling, 
        nextSegment.curve - baseOffset - lastDelta * endScaling, 
        counter < numberOfSegmentPerColor, 
        currentSegmentIndex == 2 || currentSegmentIndex == roadParam.length-render.depthOfField);
      }


      lastProjectedHeight    = currentHeight;

      probedDepth            = currentSegmentPosition;

      currentSegmentIndex    = nextSegmentIndex;
      currentSegment         = nextSegment;

      currentSegmentPosition += roadSegmentSize;

      counter = (counter + 1) % (2 * numberOfSegmentPerColor);

      // ajoute la voiture
      drawCar();

      // ajoute une barre de progession.. 
      fill(#ffffff);
      rect(50, 45, 5, 10);
      rect (50, 50, 400, 5);
      rect (450, 45, 5, 10);
      fill(#ffffff);
      
      println(((float)absoluteIndex/(roadParam.length-render.depthOfField)*450)+50);

      //récupère l'heure .. (il n'a pas de Date() en processing
      int now =60000*minute()+1000*second()+millis(); 

      // startTime est initialisé dans la boucle de début.. 
      int diff = now - startTime;
      int min = (int)Math.floor(diff / 60000);
      int sec = (int)Math.floor((diff - min * 60000) / 1000);
      int millis = (int)Math.floor((diff - min * 60000 - sec * 1000)/10);
      
      // on ne veux pas de 1:1:9 mais 01:01:09

      String stringSec = "";
      if (sec<10) {
        stringSec = "0"+sec;
      }
      else {
        stringSec = ""+sec;
      }
      String stringMin = "";
      if (min<10) {
        stringMin = "0"+min;
      } 
      else {
        stringMin = ""+min;
      }
      String stringMillis = "";
      if (millis<100) {
        stringMillis = "0"+millis;
      } 
      else {
        stringMillis = ""+millis;
      }
      if (millis<10) {
        stringMillis = "0"+millis;
      } 
      else {
        stringMillis = ""+millis;
      }
       fill(#22dd22);
      textFont(font);
      text(""+stringMin+":"+stringSec+":"+stringMillis, 20, 20);
      // Le compteur kilometrique
      textFont(digit);
      fill(#CC2222);
      int speed = Math.round(player.speed / player.maxSpeed * 200);
      String stringSpeed = "";
      if (speed<100) {
        stringSpeed = "0"+stringSpeed;
      } 
      if (speed<10) {
        stringSpeed = "0"+stringSpeed;
      } 
      stringSpeed = stringSpeed +speed;

      text(""+stringSpeed, 50, height);
      drawMicro(maximum);


      if (player.tempo > 0) {
        player.tempo --;
      } 
      else 
      {
        player.state = 0;
      }
    }
  }
}

/**
* Gestion du clavier
*/
void keyPressed() {
  if (keyCode == ENTER) { // 38 up
    player.play = true;
  } 
  if (keyCode == UP) { // 38 up
    //player.position += 0.1;
    player.speed += player.acceleration;
  } 
  else if (keyCode == DOWN) { // 40 down
    player.speed -= player.breaking;
  }
  if (keyCode==LEFT) {
    // 37 left
    if (player.speed > 0) {
      player.posx -= player.turning;
      player.state = 2;
      player.tempo = 600;
    }
  }  
  if (keyCode==RIGHT) {
    // 39 right
    if (player.speed > 0) {
      player.posx += player.turning;
      player.state = 1;
      player.tempo = 600;
    }
  }
}

/**
* Notre joueur
*/
class Player {
  public int position = 10;
  public float speed = 0;
  public float acceleration =  0.6;
  public float deceleration =  0.06;
  public float breaking =  0.6;
  public float turning =  5.0;
  public float posx =  0;
  public float maxSpeed =  15;
  public int state = 0;// 0 droit, 1 gauche, 2 droit
  public int tempo = 0; 
  public boolean play = false;
}

/**
* Pas vraiment documenté cette fonction est juste vitales pour Ess.
* elle est appellé en interne pour relier le micro et l'analyseur FFT
*/
public void audioInputData(AudioInput theInput) {
  myFFT.getSpectrum(myInput);
}

/**
* Pamametre de la route
*/
class RoadParam {
  public int maxHeight= 900;
  public int maxCurve= 400;
  public int length =  12;
  public float curvy = 0.8;
  public float mountainy=  0.8;
  public int zoneSize = 250;
}
/**
* Parametre de rendu
*/
class Render {
  int  width = 340;
  int  height = 240;
  int  depthOfField =  150;
  int  camera_distance =  30;
  int  camera_height =  100;
  Render(int width, int height) {
    this.width = width;
    this.height = height;
  }
}

/**
* Permet de stocker un segment de route 
*/
class Segment {
  public float _height; //Hauteur
  public float curve; // courbure
 
  Segment(float _height, float curve) {
    this._height = _height;
    this.curve = curve;

  }
}


/**
* Petit driver. il permet de faire la moyenne des valeurs du Nunchuck.
* sinon le controles serait juste epileptique
*/
class SensorDataBuffer {
  private int _maxSamples;
  private int _bufferIndex;
  private int[] _xBuffer;
  private int[] _yBuffer;
  private int[] _zBuffer;

  public SensorDataBuffer(final int maxSamples) { // <label id="code.nunchuk.sdb_constructor"/>
    _maxSamples = maxSamples;
    _bufferIndex = 0;
    _xBuffer = new int[_maxSamples];
    _yBuffer = new int[_maxSamples];
    _zBuffer = new int[_maxSamples];
  }

  public void addData(final int x, final int y, final int z) {
    if (_bufferIndex >= _maxSamples)
      _bufferIndex = 0;

    _xBuffer[_bufferIndex] = x;
    _yBuffer[_bufferIndex] = y;
    _zBuffer[_bufferIndex] = z;
    _bufferIndex++;
  }

  public int getX() {
    return getAverageValue(_xBuffer);
  }

  public int getY() {
    return getAverageValue(_yBuffer);
  }

  public int getZ() {
    return getAverageValue(_zBuffer);
  }

  private int getAverageValue(final int[] buffer) {
    int sum = 0;
    for (int i = 0; i < _maxSamples; i++)
      sum += buffer[i];
    return (int)(sum / _maxSamples);
  }
}


/**
* Arduino+Wii
*/
void serialEvent(Serial port) {
  final String arduinoData = port.readStringUntil(LINE_FEED);

  if (arduinoData != null) {
    final int[] data = int(split(trim(arduinoData), ' '));
    if (data.length == 7) {


      sensorData.addData(data[2], data[3], data[4]);

      final float gx = MX * sensorData.getX() + BX;
      final float gy = MY * sensorData.getY() + BY;
      final float gz = MZ * sensorData.getZ() + BZ;

      xrotate = atan2(gx, sqrt(gy * gy + gz * gz));
      yrotate = atan2(gy, sqrt(gx * gx + gz * gz));
      zrotate = atan2(sqrt(gx * gx + gy * gy), gz);
      if (xrotate> 0.5) {

        player.posx += player.turning;
        player.state = 1;
      }
      if (xrotate < -0.5) {
        player.posx -= player.turning;
        player.state = 2;
      }
    }
  }
}
 
