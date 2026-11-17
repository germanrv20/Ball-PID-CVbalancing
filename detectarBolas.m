
function [centroBola, centroBase, radioBase, mmPorPixel, ...
          baseDetectada, bolaDetectada] = detectarBolas(imagen)

%% 1. PARAMETROS

cfg.paso      = 2;
cfg.plateH    = [0.55 0.75];
cfg.plateSmin = 0.40;
cfg.plateVmin = 0.15;
cfg.minArea   = 150;

margen = 6;

cfg.seC = strel('disk', 2);
cfg.seM = strel('disk', margen);
cfg.seO = strel('disk', 2);

% Diametro real de la plataforma
diametroPlataforma_mm = 150;
radioPlataforma_mm = diametroPlataforma_mm / 2;

%% 2. REDUCIR RESOLUCION

sub = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);

%% 3. CONVERTIR A HSV

hsv = rgb2hsv(im2single(sub));

% Detectar pixeles azules de la plataforma
azul = hsv(:,:,1) >= cfg.plateH(1) & ...
       hsv(:,:,1) <= cfg.plateH(2) & ...
       hsv(:,:,2) >= cfg.plateSmin & ...
       hsv(:,:,3) >= cfg.plateVmin;

%% 4. INICIALIZAR SALIDAS

centroBola = [NaN NaN];
centroBase = [NaN NaN];

radioBase = NaN;
mmPorPixel = NaN;

baseDetectada = false;
bolaDetectada = false;

%% 5. DETECTAR PLATAFORMA

base = bwareafilt(imclose(azul, cfg.seC), 1);

if any(base(:))

    baseDetectada = true;

    % Envolver la plataforma completa
    hull = bwconvhull(base);

    pl = regionprops(hull, 'Centroid', 'EquivDiameter');

    % Eliminar el borde de la plataforma
    roi = imerode(hull, cfg.seM);

    %% 6. CENTRO, RADIO Y ESCALA DE LA PLATAFORMA

    ccBase = pl(1).Centroid;

    centroBase = 1 + (ccBase - 1) * cfg.paso;

    radioBase = (pl(1).EquivDiameter / 2) * cfg.paso;

    % Conversion de pixeles a milimetros
    mmPorPixel = radioPlataforma_mm / radioBase;

    %% 7. DETECTAR UNA UNICA BOLA

    % Bola = interior de la plataforma que no es azul
    bolas = roi & ~azul;

    bolas = imopen(bolas, cfg.seO);
    bolas = bwareaopen(bolas, cfg.minArea);

    % Obtener las regiones detectadas
    stats = regionprops(bolas, 'Area', 'Centroid');

    if ~isempty(stats)

        % Seleccionar la region de mayor area
        [~, idx] = max([stats.Area]);

        % Centro de la unica bola detectada
        ccBola = stats(idx).Centroid;

        centroBola = 1 + (ccBola - 1) * cfg.paso;

        bolaDetectada = true;

    end

end

end
