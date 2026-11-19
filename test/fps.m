clc; clear cam;
listaCamaras = webcamlist;
disp(listaCamaras);
idx = input('Numero de camara Iriun Webcam: ');
cam = webcam(idx);

% Mostrar resoluciones disponibles y elegir la mas baja (idealmente 640x480)
disp('Resoluciones disponibles:');
disp(cam.AvailableResolutions);
if any(strcmp(cam.AvailableResolutions, '640x480'))
    cam.Resolution = '640x480';
end
fprintf('Resolucion activa: %s\n', cam.Resolution);

%% Test A: Medir dt real entre frames NUEVOS durante 5 segundos (sin mover plato)
fprintf('\n--- TEST A: Midiéndo fluidez de frames nuevos (5 s) ---\n');
imgAnt = snapshot(cam);
dts = [];
tic;
tAnt = toc;
while toc < 5.0
    img = snapshot(cam);
    % Comprobar si el frame cambio realmente respecto al anterior
    if any(img(1:10:end, 1:10:end, 1) ~= imgAnt(1:10:end, 1:10:end, 1), 'all')
        tNow = toc;
        dts(end+1) = (tNow - tAnt) * 1000; %#ok<SAGROW>
        tAnt = tNow;
        imgAnt = img;
    end
end
fprintf('Frames nuevos reales: %.1f FPS | dt medio: %.1f ms | dt min: %.1f ms | dt max: %.1f ms\n', ...
    1000/mean(dts), mean(dts), min(dts), max(dts));

%% Test B: Medir retardo real total (Arduino + Servos + Camara + detectarBolas)
% Coloca la bola quieta cerca del centro antes de pulsar Enter
input('\nColoca la bola quieta cerca del centro y pulsa ENTER para medir el retardo real...');

if ~exist('puerto', 'var')
    puerto = serialport("COM16", 115200);
    configureTerminator(puerto, "LF");
    pause(2);
end
moverPlataforma(0, 0, puerto);
pause(1.0);

% Capturar posicion inicial en reposo
img0 = snapshot(cam);
[bx0, by0, cx, cy, ~, mmPx, ~, ~] = detectarBolas(img0);
x0 = (bx0 - cx) * mmPx;
y0 = (cy - by0) * mmPx;

% Dar un escalon de +5 grados en X y cronometrar hasta que la bola se desplace > 2.5 mm
tic;
moverPlataforma(5.0, 0, puerto);
retardo_ms = NaN;

while toc < 1.5
    img = snapshot(cam);
    [bx, by, cx, cy, ~, mmPx, baseOk, bolaOk] = detectarBolas(img);
    if baseOk && bolaOk
        x = (bx - cx) * mmPx;
        y = (cy - by) * mmPx;
        if hypot(x - x0, y - y0) > 2.5
            retardo_ms = toc * 1000;
            break;
        end
    end
end
moverPlataforma(0, 0, puerto);

if isnan(retardo_ms)
    fprintf('No se detecto movimiento > 2.5 mm (revisa que la bola no estuviera pegada en un borde).\n');
else
    fprintf('>>> RETARDO TOTAL MEDIDO (Orden -> Servo -> Bola -> Camara -> MATLAB): %.1f ms <<<\n', retardo_ms);
end