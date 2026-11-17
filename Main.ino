#include <Servo.h>

Servo servo1;
Servo servo2;

const int pinServo1 = 9;
const int pinServo2 = 10;

// Limites de pulso utilizados por la libreria Servo
const int PULSO_MIN = 544;
const int PULSO_MAX = 2400;

// Posicion inicial
float q1 = 90.0;
float q2 = 90.0;


// Convierte grados a microsegundos.
// Esto permite conservar los decimales calculados por MATLAB.
int gradosAPulso(float q)
{
  q = constrain(q, 0.0, 180.0);

  return round(
    PULSO_MIN +
    (q / 180.0) * (PULSO_MAX - PULSO_MIN)
  );
}


void setup()
{
  Serial.begin(115200);

  servo1.attach(pinServo1);
  servo2.attach(pinServo2);

  // Plataforma horizontal al arrancar
  servo1.writeMicroseconds(gradosAPulso(90.0));
  servo2.writeMicroseconds(gradosAPulso(90.0));

  delay(1000);

  Serial.println("READY");
}


void loop()
{
  if (Serial.available() > 0)
  {
    String mensaje = Serial.readStringUntil('\n');

    mensaje.trim();

    int coma = mensaje.indexOf(',');

    if (coma > 0)
    {
      q1 = mensaje.substring(0, coma).toFloat();
      q2 = mensaje.substring(coma + 1).toFloat();

      // Seguridad
      q1 = constrain(q1, 0.0, 180.0);
      q2 = constrain(q2, 0.0, 180.0);

      // Actualizar los dos servos en la misma iteracion
      servo1.writeMicroseconds(gradosAPulso(q1));
      servo2.writeMicroseconds(gradosAPulso(q2));
    }
  }
}