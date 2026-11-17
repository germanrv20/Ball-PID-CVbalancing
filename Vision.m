clc; clear; close all;

%% 1. PARAMETROS
cfg.paso      = 2;              % reduccion de resolucion (2 = mitad)
cfg.plateH    = [0.55 0.75];    % matiz (H) del plato azul
cfg.plateSmin = 0.40;           % saturacion minima del plato
cfg.plateVmin = 0.15;           % brillo minimo
cfg.minArea   = 150;            % area minima de una bola (px reducidos)
margen        = 6;              % px que se recortan del borde del plato

% Elementos estructurantes (se crean una sola vez)
cfg.seC = strel('disk', 2);          % cierre
cfg.seM = strel('disk', margen);     % erosion del borde
cfg.seO = strel('disk', 2);          % apertura

%% 2. CAMARA
listaCamaras = webcamlist;
if isempty(listaCamaras), error('No se ha encontrado ninguna webcam.'); end
for k = 1:numel(listaCamaras), fprintf('%d -> %s\n', k, listaCamaras{k}); end

if numel(listaCamaras) == 1
    indiceCamara = 1;
else
    indiceCamara = input('\nSelecciona numero de camara: ');
end
cam = webcam(indiceCamara);

resList = cam.AvailableResolutions;
px = cellfun(@(s) prod(sscanf(s, '%dx%d')), resList);
[~, iMin] = min(px);
cam.Resolution = resList{iMin};

for k = 1:5, snapshot(cam); end          % calentar la camara

%% 3. FIGURA
imagen = snapshot(cam);
sub    = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);
vacio  = false(size(sub,1), size(sub,2));

fig = figure('Name', 'Deteccion de bolas', 'NumberTitle', 'off');

ax1 = subplot(1,3,1);
hOv = imshow(sub); title('Original + deteccion');
hold(ax1, 'on');
hBolasPts = plot(ax1, nan, nan, 'g+', 'MarkerSize', 14, 'LineWidth', 2);
hPlatoPt  = plot(ax1, nan, nan, 'rx', 'MarkerSize', 14, 'LineWidth', 2);

subplot(1,3,2); hBase = imshow(vacio); title('Base (plato) binarizada');
subplot(1,3,3); hBol  = imshow(vacio); title('Bolas binarizadas');

%% 4. BUCLE EN TIEMPO REAL
while ishandle(fig)

    imagen = snapshot(cam);

    % ---- LLAMADA A LA FUNCION ----
    [centroBolas, centroBase, radioBase, dbg] = detectarBolas(imagen, cfg);

    % >>> AQUI USAS centroBolas, centroBase y radioBase EN TU CONTROL <<<

    % ---- Dibujo ----
    set(hOv,       'CData', dbg.sub);
    set(hBase,     'CData', dbg.base);
    set(hBol,      'CData', dbg.bolas);
    set(hBolasPts, 'XData', dbg.ccBolas(:,1), 'YData', dbg.ccBolas(:,2));
    set(hPlatoPt,  'XData', dbg.ccBase(1),    'YData', dbg.ccBase(2));
    drawnow limitrate nocallbacks;
end

clear cam;