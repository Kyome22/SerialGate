// Example code for SerialGate.
// This plogram tested on Arduino micro.

int value = 0;
int flag = 0;
int led = 13;

void setup() {
  pinMode(led, OUTPUT);
  Serial.begin(9600);
  randomSeed(analogRead(0));
}

void loop() {
  if (Serial.available() > 0) {
    byte v = Serial.read();
    if (v == 0x31) { // "1"
      flag = 1;
      digitalWrite(led, HIGH);
    } else {
      flag = 0;
      digitalWrite(led, LOW);
    }
  }
  value = random(10);
  char buf[20] = "";
  sprintf(buf, "Hello World\n%d,%d\n", value, flag);
  Serial.print(buf);
  Serial.flush();
  delay(50);
}
