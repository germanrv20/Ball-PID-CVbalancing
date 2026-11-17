function [centroBolas, centroBase, radioBase, dbg] = detectarBolas(imagen, cfg)
% DETECTARBOLAS  Detecta el plato azul y las bolas que hay dentro de el.
%
% ENTRADAS
%   imagen : fotograma RGB (uint8) tal como sale de snapshot(cam)
%   cfg    : struct con parametros (ver script principal)
%
% SALIDAS (todo en PIXELES de la imagen ORIGINAL)
%   centroBolas : N x 2  [x y] de cada bola   (0 x 2 si no hay bolas)
%   centroBase  : 1 x 2  [x y] del centro del plato  ([NaN NaN] si no se ve)
%   radioBase   : escalar, radio del plato en px     (NaN si no se ve)
%   dbg         : (opcional) imagenes intermedias para dibujar

p = cfg.paso;

% --- Reduccion de resolucion ---
sub = imagen(1:p:end, 1:p:end, :);

% --- HSV y pixeles azules ---
hsv  = rgb2hsv(im2single(sub));
azul = hsv(:,:,1) >= cfg.plateH(1) & hsv(:,:,1) <= cfg.plateH(2) ...
    & hsv(:,:,2) >= cfg.plateSmin & hsv(:,:,3) >= cfg.plateVmin;

% --- Valores por defecto (si no se ve el plato) ---
centroBolas = zeros(0, 2);
centroBase  = [nan nan];
radioBase   = nan;
bolas   = false(size(azul));
ccBolas = [nan nan];             % coords en imagen reducida (solo para dibujar)
ccBase  = [nan nan];

% --- Plato: mancha azul mas grande ---
base = bwareafilt(imclose(azul, cfg.seC), 1);

if any(base(:))
    % Disco completo del plato (tapa los huecos de las bolas)
    hull = bwconvhull(base);
    pl   = regionprops(hull, 'Centroid', 'EquivDiameter');
    roi  = imerode(hull, cfg.seM);          % sin el borde

    % Bola = dentro del plato y NO azul
    bolas = roi & ~azul;
    bolas = imopen(bolas, cfg.seO);
    bolas = bwareaopen(bolas, cfg.minArea);

    % Plato: centro y radio, pasados a pixeles originales
    ccBase     = pl(1).Centroid;
    centroBase = 1 + (ccBase - 1) * p;
    radioBase  = pl(1).EquivDiameter / 2 * p;

    % Bolas: centroides, pasados a pixeles originales
    st = regionprops(bolas, 'Centroid');
    if ~isempty(st)
        ccBolas     = vertcat(st.Centroid);
        centroBolas = 1 + (ccBolas - 1) * p;
    end
end

% --- Datos para dibujar (solo si se piden) ---
if nargout > 3
    dbg = struct('sub', sub, 'base', base, 'bolas', bolas, ...
        'ccBolas', ccBolas, 'ccBase', ccBase);
end
end