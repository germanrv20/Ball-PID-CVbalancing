% 1. Prueba del eje X (+3°): debe levantar el lado derecho (+X) y hacer rodar la bola a la izquierda
moverPlataforma(3, 0, puerto);
pause(2);
moverPlataforma(0, 0, puerto);
pause(1);

% 2. Prueba del eje Y (+3°): debe levantar el lado superior (+Y) y hacer rodar la bola hacia abajo
moverPlataforma(0, -3, puerto);
pause(2);
moverPlataforma(0, 0, puerto);