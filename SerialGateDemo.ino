// Example code for SerialGate.
// This plogram tested on Arduino micro.

int value1 = 0;
int value2 = 0;
int value3 = 0;
int led = 13;

void setup() {
  pinMode(led, OUTPUT);
  Serial.begin(9600);
  randomSeed(analogRead(0));
}

void loop() {
  if (Serial.available() > 0) {
    byte v = Serial.read();
    if (v == 0x31) {
      digitalWrite(led, HIGH);
      value3 = 1;
    } else {
      value3 = 0;
      digitalWrite(led, LOW);
    }
  }
  value1 = random(20);
  value2 = random(20);
  Serial.print(value1);
  Serial.print(",");
  Serial.print(value2);
  Serial.print(",");
  Serial.println(value3);
  delay(200);
}
