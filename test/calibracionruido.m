%% Comprobación rápida de detección y signos de cámara (Caso 2)
if ~exist('cam', 'var')
    lista = webcamlist;
    cam = webcam(2);
end
if exist('puerto', 'var')
    moverPlataforma(0, 0, puerto);
end

figTest = figure('Name', 'Test Visual Caso 2 (Cierra para salir)');
img = snapshot(cam);
hImg = imshow(img); hold on;
hBase = plot(NaN, NaN, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
hCirc = plot(NaN, NaN, 'b-', 'LineWidth', 1.2);
hBola = plot(NaN, NaN, 'r+', 'MarkerSize', 14, 'LineWidth', 2);
th = linspace(0, 2*pi, 100);

histX = []; histY = [];

while isgraphics(figTest)
    img = snapshot(cam);
    [bx, by, cx, cy, rBase, mmPx, okBase, okBola] = detectarBolas(img);
    set(hImg, 'CData', img);
    
    if okBase
        set(hBase, 'XData', cx, 'YData', cy);
        set(hCirc, 'XData', cx + rBase*cos(th), 'YData', cy + rBase*sin(th));
    end
    
    if okBase && okBola
        x_mm = (bx - cx) * mmPx;
        y_mm = (cy - by) * mmPx;
        histX(end+1) = x_mm; %#ok<SAGROW>
        histY(end+1) = y_mm; %#ok<SAGROW>
        
        set(hBola, 'XData', bx, 'YData', by);
        title(sprintf('X: %+.1f mm | Y: %+.1f mm | Ruido std: (%.2f, %.2f) mm', ...
              x_mm, y_mm, std(histX), std(histY)));
    else
        set(hBola, 'XData', NaN, 'YData', NaN);
        title('ALERTA: Se perdió la detección de base o bola');
    end
    drawnow limitrate;
end