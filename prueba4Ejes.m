function prueba4Ejes(puerto)

beta = 5;
tiempo = 2;
disp('Iniciando prueba');

%% X+

disp('X+');
moverPlataforma(beta,0,puerto);
pause(tiempo);

%% Y+

disp('Y+');
moverPlataforma(0,beta,puerto);
pause(tiempo);

%% X-

disp('X-');
moverPlataforma(-beta,0,puerto);
pause(tiempo);

%% Y-

disp('Y-');
moverPlataforma(0,-beta,puerto);
pause(tiempo);

%% X+

disp('X+');
moverPlataforma(beta,0,puerto);
pause(tiempo);

%% CENTRO

moverPlataforma(0,0,puerto);
disp('Prueba terminada');

end