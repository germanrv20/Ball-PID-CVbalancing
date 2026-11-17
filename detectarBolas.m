
function [centroBolas, centroBase, radioBase] = detectarBolas()

clc;

%% 1. PARAMETROS

cfg.paso      = 2;              % Reduccion de resolucion
cfg.plateH    = [0.55 0.75];    % Matiz del plato azul
cfg.plateSmin = 0.40;           % Saturacion minima
cfg.plateVmin = 0.15;           % Brillo minimo
cfg.minArea   = 150;            % Area minima de una bola

margen = 6;                     % Margen respecto al borde

% Elementos estructurantes
cfg.seC = strel('disk', 2);
cfg.seM = strel('disk', margen);
cfg.seO = strel('disk', 2);

%% 2. BUSCAR Y SELECCIONAR CAMARA

listaCamaras = webcamlist;

if isempty(listaCamaras)
    error('No se ha encontrado ninguna webcam.');
end

fprintf('Camaras disponibles:\n');

for k = 1:numel(listaCamaras)
    fprintf('%d -> %s\n', k, listaCamaras{k});
end

if numel(listaCamaras) == 1
    indiceCamara = 1;
else
    indiceCamara = input('\nSelecciona numero de camara: ');
end

if indiceCamara < 1 || indiceCamara > numel(listaCamaras) ...
        || indiceCamara ~= floor(indiceCamara)
    error('Indice de camara no valido.');
end

cam = webcam(indiceCamara);

%% 3. CONFIGURAR RESOLUCION

resList = cam.AvailableResolutions;

px = cellfun(@(s) prod(sscanf(s, '%dx%d')), resList);

[~, iMin] = min(px);

cam.Resolution = resList{iMin};

% Calentar camara
for k = 1:5
    snapshot(cam);
end

%% 4. VISUALIZACION (DESACTIVADA)

% Para activar la visualizacion, descomentar este apartado
%
% imagen = snapshot(cam);
% sub = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);
% vacio = false(size(sub,1), size(sub,2));
%
% fig = figure('Name', 'Deteccion de bolas', ...
%              'NumberTitle', 'off');
%
% ax1 = subplot(1,3,1);
% hOv = imshow(sub);
% title('Original + deteccion');
% hold(ax1, 'on');
%
% hBolasPts = plot(ax1, nan, nan, 'g+', ...
%                  'MarkerSize', 14, 'LineWidth', 2);
%
% hPlatoPt = plot(ax1, nan, nan, 'rx', ...
%                 'MarkerSize', 14, 'LineWidth', 2);
%
% subplot(1,3,2);
% hBase = imshow(vacio);
% title('Plato binarizado');
%
% subplot(1,3,3);
% hBol = imshow(vacio);
% title('Bolas binarizadas');

%% 5. INICIALIZAR SALIDAS

centroBolas = zeros(0,2);
centroBase = [NaN NaN];
radioBase = NaN;

%% 6. BUCLE DE DETECCION EN TIEMPO REAL

while true

    % Capturar imagen
    imagen = snapshot(cam);

    % Reducir resolucion
    sub = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);

    % Convertir a HSV
    hsv = rgb2hsv(im2single(sub));

    % Detectar pixeles azules del plato
    azul = hsv(:,:,1) >= cfg.plateH(1) & ...
           hsv(:,:,1) <= cfg.plateH(2) & ...
           hsv(:,:,2) >= cfg.plateSmin & ...
           hsv(:,:,3) >= cfg.plateVmin;

    % Inicializar mascaras
    bolas = false(size(azul));
    base = false(size(azul));

    ccBolas = zeros(0,2);
    ccBase = [NaN NaN];

    centroBolas = zeros(0,2);
    centroBase = [NaN NaN];
    radioBase = NaN;

    %% DETECTAR PLATO

    base = bwareafilt(imclose(azul, cfg.seC), 1);

    if any(base(:))

        % Envolver el plato completo
        hull = bwconvhull(base);

        pl = regionprops(hull, 'Centroid', 'EquivDiameter');

        % Eliminar borde del plato
        roi = imerode(hull, cfg.seM);

        %% DETECTAR BOLAS

        % Bola = interior del plato que no es azul
        bolas = roi & ~azul;

        % Limpiar deteccion
        bolas = imopen(bolas, cfg.seO);
        bolas = bwareaopen(bolas, cfg.minArea);

        %% CENTRO Y RADIO DEL PLATO

        ccBase = pl(1).Centroid;

        centroBase = 1 + (ccBase - 1) * cfg.paso;

        radioBase = pl(1).EquivDiameter / 2 * cfg.paso;

        %% CENTROS DE LAS BOLAS

        st = regionprops(bolas, 'Centroid');

        if ~isempty(st)

            ccBolas = vertcat(st.Centroid);

            centroBolas = 1 + (ccBolas - 1) * cfg.paso;

        end

    end

    %% 7. VISUALIZACION EN TIEMPO REAL (DESACTIVADA)

    % Para activar, descomentar este apartado y el apartado 4
    %
    % set(hOv, 'CData', sub);
    % set(hBase, 'CData', base);
    % set(hBol, 'CData', bolas);
    %
    % set(hBolasPts, ...
    %     'XData', ccBolas(:,1), ...
    %     'YData', ccBolas(:,2));
    %
    % set(hPlatoPt, ...
    %     'XData', ccBase(1), ...
    %     'YData', ccBase(2));
    %
    % drawnow limitrate;

end

%% 8. LIBERAR CAMARA

clear cam;

end
