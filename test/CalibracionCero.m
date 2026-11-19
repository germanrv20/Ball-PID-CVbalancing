%% CalibracionCero

% Calibración interactiva del punto de reposo (0,0)
offsetX = 0.0;
offsetY = 0.0;

fprintf('Calibrando reposo. Introduce incrementos en grados (ej: 0.2, -0.1) o 0 para mantener.\n');
fprintf('Escribe 999 en X para terminar.\n\n');

while true
    [q1, q2] = cinematicaInversa(offsetX, offsetY);
    enviarServos(puerto, q1, q2);
    fprintf('Actual -> offsetX = %+.2f° | offsetY = %+.2f°  (Servos: q1=%.2f°, q2=%.2f°)\n', ...
            offsetX, offsetY, q1, q2);
    
    incX = input('Ajuste en X (grados): ');
    if incX == 999
        break;
    end
    incY = input('Ajuste en Y (grados): ');
    
    offsetX = offsetX + incX;
    offsetY = offsetY + incY;
end

fprintf('\nValores finales para aplicarReposo.m:\noffsetX = %.2f;\noffsetY = %.2f;\n', offsetX, offsetY);