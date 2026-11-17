
function [centroBolas, centroBase, radioBase, mmPorPixel, ...
          baseDetectada, bolaDetectada] = detectarBolas(imagen)

%% 1. PARAMETROS

cfg.paso      = 2;
cfg.plateH    = [0.55 0.75];
cfg.plateSmin = 0.40;
cfg.plateVmin = 0.15;
cfg.minArea   = 150;

diametroPlataforma_mm = 150;
radioPlataforma_mm = diametroPlataforma_mm / 2;

margen = 6;

cfg.seC = strel('disk', 2);
cfg.seM = strel('disk', margen);
cfg.seO = strel('disk', 2);

%% 2. REDUCIR RESOLUCION

sub = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);

%% 3. CONVERTIR A HSV

hsv = rgb2hsv(im2single(sub));

azul = hsv(:,:,1) >= cfg.plateH(1) & ...
       hsv(:,:,1) <= cfg.plateH(2) & ...
       hsv(:,:,2) >= cfg.plateSmin & ...
       hsv(:,:,3) >= cfg.plateVmin;

%% 4. INICIALIZAR SALIDAS

centroBolas = zeros(0,2);
centroBase  = [NaN NaN];
radioBase   = NaN;
mmPorPixel  = NaN;

baseDetectada = false;
bolaDetectada = false;

%% 5. DETECTAR PLATAFORMA

base = bwareafilt(imclose(azul, cfg.seC), 1);

if any(base(:))

    baseDetectada = true;

    hull = bwconvhull(base);

    pl = regionprops(hull, 'Centroid', 'EquivDiameter');

    roi = imerode(hull, cfg.seM);

    %% 6. DETECTAR BOLAS

    bolas = roi & ~azul;

    bolas = imopen(bolas, cfg.seO);
    bolas = bwareaopen(bolas, cfg.minArea);

    %% 7. CENTRO, RADIO Y ESCALA DE LA PLATAFORMA

    ccBase = pl(1).Centroid;

    centroBase = 1 + (ccBase - 1) * cfg.paso;

    radioBase = pl(1).EquivDiameter / 2 * cfg.paso;

    % Conversion de milimetros a pixeles
    mmPorPixel = radioPlataforma_mm / radioBase;

    %% 8. CENTROS DE LAS BOLAS

    st = regionprops(bolas, 'Centroid');

    if ~isempty(st)

        ccBolas = vertcat(st.Centroid);

        centroBolas = 1 + (ccBolas - 1) * cfg.paso;

        bolaDetectada = true;

    end

end

end
