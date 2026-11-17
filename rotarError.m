function [errX_girado, errY_girado] = rotarError(errX, errY, angulo)
    R = [ cosd(angulo), sind(angulo);
         -sind(angulo), cosd(angulo)];
         
    error_rotado = R * [errX; errY];
    
    errX_girado = error_rotado(1);
    errY_girado = error_rotado(2);
end