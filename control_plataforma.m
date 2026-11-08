clear;
clc;

%% CONEXION SERIE

puerto = serialport("COM3",115200);

configureTerminator(puerto,"LF");

pause(2);

flush(puerto);

%% POSICION INICIAL

moverPlataforma(0,0,puerto);

pause(1);

disp('Plataforma horizontal');

%% CONTROL MANUAL

disp(' ');
disp('===================================');
disp(' CONTROL POR PENDIENTE');
disp('===================================');
disp(' ');
disp('betaX > 0 -> baja X+');
disp('betaX < 0 -> sube X+');
disp('betaY > 0 -> baja Y+');
disp('betaY < 0 -> sube Y+');
disp(' ');
disp('999 en betaX para salir');


while true

    fprintf('\n-------------------------------\n');

    betaX = input('Pendiente X [grados] = ');

    if betaX == 999
        break;
    end

    betaY = input('Pendiente Y [grados] = ');

    try

        moverPlataforma(betaX,betaY,puerto);

    catch ME

        fprintf('ERROR: %s\n',ME.message);

    end

end

%% VOLVER A HORIZONTAL

moverPlataforma(0,0,puerto);
disp('Fin del programa');
clear puerto