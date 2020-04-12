const int LED_PIN = 13;
boolean flag = false;

void setup() {
  Serial.begin(9600);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  if (Serial.available() > 0) {
    char input = Serial.read();
    if (input == '1') {
      flag = true;
      digitalWrite(LED_PIN, HIGH);
    } else {
      flag = false;
      digitalWrite(LED_PIN, LOW);
    }
  }
  if (flag) {
    Serial.println("ON");
  } else {
    Serial.println("OFF");
  }
  delay(100);
}
