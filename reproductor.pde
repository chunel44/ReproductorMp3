import controlP5.*;
import ddf.minim.*;
import java.util.concurrent.TimeUnit;
import ddf.minim.effects.*;
import ddf.minim.analysis.*;

import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;

// Constantes para referir al nombre del indice y el tipo
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";
static int height2 = 400;
Client client;
Node node;
ScrollableList list;

Minim cadena;
FFT fft;
HighPassSP hpf;
LowPassFS lpf;
BandPass bpf;
PImage seeker;
PImage seeker2;
boolean Pause = true;
int mBand = 0;
float maxValBand = 0;
float maxAmp;
float vol2 = 0, temp = 100;
Slider prog, volu;
Knob volu2, HPF, LPF, BPF;
Button play, stop, pause, select;
ControlP5 cp5;
AudioPlayer cancion;
int time;
//float sliderValue = 0;
float valor=100;
//int slide = 100;
void setup() {
  
  frameRate(30);
  size(880, 400, P3D);
  noStroke();
  time = millis();
  Settings.Builder settings = Settings.settingsBuilder();
  // Esta carpeta se encontrara dentro de la carpeta del Processing
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);

  // Inicializacion del nodo de ElasticSearch
  node = NodeBuilder.nodeBuilder()
          .settings(settings)
          .clusterName("mycluster4")
          .data(true)
          .local(true)
          .node();

  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();
  
  seeker = loadImage("scrollbar.png");
  seeker2 = loadImage("scroll.png");

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if(!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }
  
  cadena = new Minim(this);
  //cancion = cadena.loadFile("cancion2.mp3", 1024);
  cp5 = new ControlP5(this);
  
  
  play = cp5.addButton("play")
    .setValue(vol2)
    .setImages(loadImage("play.png"),loadImage("play1.png"))
    .setPosition(50, 300)
    .setSize(50, 50)
    .updateSize();
  
  stop = cp5.addButton("stop")
    .setValue(0)
    .setPosition(150, 300)
    .setSize(50, 50);
  
 pause = cp5.addButton("pause")
    .setValue(0)
    .setPosition(250, 300)
    .setSize(50, 50);
  
 select = cp5.addButton("Select")
    .setValue(0)
    .setPosition(350, 300)
    .setSize(50, 50);
  
  volu2 = cp5.addKnob("Vol")
    .setPosition(450, 295)
    .setSize(50,50)
    .setRange(-40, 0)
    .setValue(128);
    
    HPF = cp5.addKnob("hpf")
    .setPosition(450, 190)
    .setSize(50,50)
    .setRange(1000, 14000)
    .setValue(0);
    
    LPF = cp5.addKnob("lpf")
    .setPosition(350, 190)
    .setSize(50,50)
    .setRange(60, 2000)
    .setValue(2000);
    
    BPF = cp5.addKnob("bpf")
    .setPosition(250, 190)
    .setSize(50,50)
    .setRange(100, 10000)
    .setValue(temp);
    
    list = cp5.addScrollableList("playlist")
            .setPosition(595, 45)
            .setSize(275, 400)
            .setBarHeight(20)
            .setItemHeight(20)
            .setType(ScrollableList.LIST);
 

  HPF.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {  
     valor = int(theEvent.getController().getValue());
     println("hpf: "+valor);
     //hpf.setFreq(valor);
    }
  }
  );
  LPF.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {  
     valor = int(theEvent.getController().getValue());
     println("lpf: "+valor);
   // lpf.setFreq(valor);
    }
  }
  );
  
  BPF.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {  
     valor = int(theEvent.getController().getValue());
     temp = valor;
     println("bpf: "+valor);
    bpf.setFreq(valor);
   bpf.setBandWidth(valor);
    }
  }
  );
  
  loadFiles();

}

void draw() {
  background(0);
  if(cancion != null){
    eqs();
     AudioMetaData meta = cancion.getMetaData();
    String title = meta.title();
    String autor = meta.author();
    long time2 = meta.length();
    int timeLeft = cancion.position()-cancion.length();
    
  String timeLeftStr = String.format("%02d:%02d", -timeLeft/1000/60, -timeLeft/1000%60);
  //text( timeLeftStr, 580/2, 80);
    //textFont(createFont("Serif",12));
    
    int seconds = (int) ((time2 / 1000) % 60);
    int minutes = (int) ((time2 / 1000) / 60);
    fill(random(255), random(255), random(255));
    textSize(21);
    textAlign(CENTER);
    text(autor + " - " +title+ "  "+timeLeftStr,580/2,30);
    
  }
  if (frameCount % 30 == 0) {
    thread("moveBar");
  }
fill(random(255), random(255), random(255));
    textSize(21);
    textAlign(CENTER);
  
  separador();
}

void moveBar(){
  prog.setValue(cancion.position());
}

void separador(){
 stroke(255);
 strokeWeight(4);  // Thicker
line(580, 0, 580, height); 
}


public void play() {
 // println(height);
  cancion.play();
 // println("play");
  play.setValue(vol2);
}


public void stop() {

  cancion.pause();
  cancion.rewind();
  //println("stop");
}

public void pause() {
  pause.setValue(vol2);
  cancion.pause();
 // println("pause");
}

/*public void Select() {
  
  
selectInput("Select a file to process:", "fileSelected");
  //println("select");
  BPF.setValue(temp); //<>//
    cancion.pause();
  cancion.rewind();
  
}*/

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    cancion = cadena.loadFile(selection.getAbsolutePath(), 1024);
     //<>//
     fft = new FFT(cancion.bufferSize(), cancion.sampleRate());
     fft.logAverages(22, 3);
      bpf = new BandPass(100, 100, cancion.sampleRate());
      cancion.addEffect(bpf);
      lpf = new LowPassFS(100, cancion.sampleRate());
    //cancion.addEffect(lpf);
     hpf = new HighPassSP(1000, cancion.sampleRate());
     //cancion.addEffect(hpf);
     rectMode(CORNERS);
   // println("User selected " + selection.getAbsolutePath());
     cp5 = new ControlP5(this);
  prog = cp5.addSlider("prog")
    .setPosition(40, 260)
    .setLabel("")
    .setValueLabel("")
    .setSize(500, 20)
    .setRange(0, cancion.length())
    .setValue(128);
  }
  prog.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {  
      if(theEvent.getAction()==ControlP5.ACTION_PRESSED){
          //println(prog.isUpdate());
          float sliderValue = 0;
          sliderValue = theEvent.getController().getValue();
         // println(prog.getValue());
          println("Event fired");
          println(sliderValue);
          cancion.rewind();
          cancion.skip((int)sliderValue);
          cancion.play();
          prog.setValue(sliderValue);
         // prog.scrolled((int)theEvent.getController().getValue());
      }
    }
  }
  );
}
/*
public void setVolume(float value) {
  value = valor;
}
*/
void eqs(){
  /*
  background(0);
  stroke(255);
  fill(0);
  fft.forward(cancion.mix);
  stroke(random(255), random(255), random(255),128);
  mBand = 0;
   
  float j;
  for(int i = 0; i < fft.specSize();i++){
    j = fft.getBand(i);
    int w = int(580/fft.specSize());
    line(i*w, height2/2.2, i, height2/2.2 - j);
    maxValBand = fft.getBand(mBand);
    if(j>maxValBand){
       mBand = i; 
    }   
  }*/
  //background(0);
  
  noStroke();
  fill(random(255),0, random(255));
  // perform a forward FFT on the samples in jingle's mix buffer
  // note that if jingle were a MONO file, this would be the same as using jingle.left or jingle.right
  fft.forward(cancion.mix);
  // avgWidth() returns the number of frequency bands each average represents
  // we'll use it as the width of our rectangles
  // width = 580
  int w = int(580/fft.avgSize());
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // draw a rectangle for each average, multiply the value by 5 so we can see it better
   rect(i*w, height2/2.2, i*w + w, height2/2.2 - fft.getAvg(i)*3);
    //ellipse(i*w, height, i*w + w, height - fft.getAvg(i)*1);
  }
}

void controlEvent (ControlEvent evento) // se activa el evento
{
  String nombre = evento.getController().getName(); // recoje el nombre del slider y lo convierte en String
  valor = int(evento.getController().getValue()); // recoje el valor del slider y lo convierte en entero
  //serial.write(nombre + ":" + valor + "johan"); // envia por el puerto serial el nombre y el valor
  //valor = valor-40;
  println(nombre + ":" + valor); // imprime por pantalla el nombre y el valor

 // cancion.setPan( cancion.getPan() + valor);

if(valor <= 0){
  cancion.unmute();
  cancion.setGain(valor); 
  vol2 = valor;
  println("vol2: "+vol2);
 if(valor <= -40){
   cancion.mute();
   vol2 = valor;
 }
}
  

 // cancion.getVolume();
  //cancion.setGain(-10);
}

void keyReleased()
{
 if ( key == 'b' ) cancion.shiftBalance(-1, 1, 2000);
 if ( key == 'p' ) cancion.shiftPan(1, -1, 2000);
}

void Select(){
  SwingUtilities.invokeLater(new Runnable(){
    public void run(){
      try{
        JFileChooser jfc = new JFileChooser();
 // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  jfc.showOpenDialog(null);
  
   for(File f : jfc.getSelectedFiles()) {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if(response.isExists()) {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    println(f.getAbsolutePath());
    cancion = cadena.loadFile(f.getAbsolutePath());
    AudioMetaData meta = cancion.getMetaData();
    
     fft = new FFT(cancion.bufferSize(), cancion.sampleRate());
     fft.logAverages(22, 3);
      bpf = new BandPass(100, 100, cancion.sampleRate());
      cancion.addEffect(bpf);
      lpf = new LowPassFS(100, cancion.sampleRate());
    //cancion.addEffect(lpf);
     hpf = new HighPassSP(1000, cancion.sampleRate());
     //cancion.addEffect(hpf);
     rectMode(CORNERS);
   // println("User selected " + selection.getAbsolutePath());
     cp5 = new ControlP5(reproductor.this);
  prog = cp5.addSlider("prog")
    .setPosition(40, 260)
    .setLabel("")
    .setValueLabel("")
    .setSize(500, 20)
    .setRange(0, cancion.length())
    .setValue(128);
    
    prog.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {  
      if(theEvent.getAction()==ControlP5.ACTION_PRESSED){
          //println(prog.isUpdate());
          float sliderValue = 0;
          sliderValue = theEvent.getController().getValue();
         // println(prog.getValue());
          println("Event fired");
          println(sliderValue);
          cancion.rewind();
          cancion.skip((int)sliderValue);
          cancion.play();
          prog.setValue(sliderValue);
         // prog.scrolled((int)theEvent.getController().getValue());
      }
    }
  }
  );
    
    //cancion.play();
    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      // Le decimos a ElasticSearch que guarde e indexe el objeto
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();

      // Agregamos el archivo a la lista
      addItem(doc);
      // List l = Arrays.asList(f.getAbsolutePath());
     // list.setItems(l);
    } catch(Exception e) {
      e.printStackTrace();
    }
  }
      }catch (Exception e){
       e.printStackTrace(); 
      }
    }
  });
 
}



// Al hacer click en algun elemento de la lista, se ejecuta este metodo
void playlist(int n) {
String[] o = list.getItem(n).get("value").toString().split(","); //<>//
String path = o[0].substring(6);
//println(path);
stop();
  cancion = cadena.loadFile(path);
play();
//cancion = cadena.loadFile(path);
 
}

void loadFiles() {
  try {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for(SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } catch(Exception e) {
    e.printStackTrace();
  }
}

// Metodo auxiliar para no repetir codigo
void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}

String path(Map<String, Object> doc){
   return doc.get("path").toString(); 
}


void eliminar(File f){
 
DeleteResponse response = client.prepareDelete(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).execute().actionGet();
}