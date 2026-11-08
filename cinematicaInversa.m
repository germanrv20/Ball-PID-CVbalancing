function [q1,q2] = cinematicaInversa(betaX,betaY)

%% GEOMETRIA [mm]

P1_0 = [0;    77.6; 10.5];
P2_0 = [77.6; 0;    10.5];

S1 = [0;    55.8; -40.4];
S2 = [55.8; 0;    -40.4];

r = 22.1;
L = 47.5;

q_neutro = 90;

% Angulo geometrico del brazo en posicion neutra
theta0 = 8.8499;


%% MATRICES DE ROTACION

Ry = [ cosd(betaX)  0  sind(betaX);
       0             1  0;
      -sind(betaX)  0  cosd(betaX)];

Rx = [1  0             0;
      0  cosd(betaY)   sind(betaY);
      0 -sind(betaY)   cosd(betaY)];

R = Ry * Rx;


%% POSICION DE LAS UNIONES

P1 = R * P1_0;
P2 = R * P2_0;


%% =====================================================
%% SERVO 1
%% =====================================================

d1 = P1 - S1;

dx1 = d1(1);
dy1 = d1(2);
dz1 = d1(3);

C1 = (dx1^2 + dy1^2 + dz1^2 + r^2 - L^2)/(2*r);

rho1 = sqrt(dy1^2 + dz1^2);

if abs(C1/rho1) > 1
    error('Posicion imposible para el servo 1');
end

phi1 = atan2d(dz1,dy1);

gamma1 = acosd(C1/rho1);

% Dos soluciones
theta1_a = phi1 - gamma1;
theta1_b = phi1 + gamma1;

% Elegimos la solucion mas cercana al neutro
if abs(theta1_a-theta0) < abs(theta1_b-theta0)
    theta1 = theta1_a;
else
    theta1 = theta1_b;
end


%% =====================================================
%% SERVO 2
%% =====================================================

d2 = P2 - S2;

dx2 = d2(1);
dy2 = d2(2);
dz2 = d2(3);

C2 = (dx2^2 + dy2^2 + dz2^2 + r^2 - L^2)/(2*r);

rho2 = sqrt(dx2^2 + dz2^2);

if abs(C2/rho2) > 1
    error('Posicion imposible para el servo 2');
end

phi2 = atan2d(dz2,dx2);

gamma2 = acosd(C2/rho2);

theta2_a = phi2 - gamma2;
theta2_b = phi2 + gamma2;

if abs(theta2_a-theta0) < abs(theta2_b-theta0)
    theta2 = theta2_a;
else
    theta2 = theta2_b;
end


%% =====================================================
%% ANGULOS DE ARDUINO
%% =====================================================

% Sentido de giro
sigma1 = -1;
sigma2 = -1;

q1 = q_neutro + sigma1*(theta1-theta0);
q2 = q_neutro + sigma2*(theta2-theta0);


%% COMPROBAR LIMITES

if q1 < 0 || q1 > 180
    error('Angulo del servo 1 fuera de rango');
end

if q2 < 0 || q2 > 180
    error('Angulo del servo 2 fuera de rango');
end

end