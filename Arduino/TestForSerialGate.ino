const int LED_PIN = 13;
boolean flag = false;

void setup() {
  Serial.begin(9600);
  Serial.setTimeout(1000);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  String input = Serial.readString();
  if (input.compareTo("ON") == 0) {
    flag = true;
    digitalWrite(LED_PIN, HIGH);
  } else if (input.compareTo("OFF") == 0) {
    flag = false;
    digitalWrite(LED_PIN, LOW);
  } else if (input.length() > 0) {
    Serial.println(input);
  } else {
    if (flag) {
      Serial.println("ON");
    } else {
      Serial.println("OFF");
    }
  }
}
