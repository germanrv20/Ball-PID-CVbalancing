% Codigo de prueba para detectar la base en movimiento y bola
img = undistortImage(snapshot(cam), cameraParams);

fig = figure('Name', 'Control PD por Error de Posición', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) delete(src));

xcPrev = xc;
ycPrev = yc;
RxPrev = R;
RyPrev = R;

imshow(img);
hold on;
%[xc, yc, rx, ry] = detectarBase(img, xcPrev, ycPrev, RxPrev, RyPrev);
rectangle('Position', [xc - rx, yc - ry, 2*rx, 2*ry], ...
    'Curvature', [1, 1], 'EdgeColor', 'b', 'LineWidth', 1);
plot(xc, yc, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
hBola = plot(NaN, NaN, 'r+', 'MarkerSize', 12, 'LineWidth', 2);

axis image;
drawnow;
hold off;

[xPrev, yPrev, errXAnt, errYAnt] = deal(NaN);
