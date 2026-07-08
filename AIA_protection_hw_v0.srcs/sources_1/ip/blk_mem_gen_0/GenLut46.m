%% ================================================================
%  CURVA 51 / 51N (IEC): Geração de LUT (0..4095 contagens RMS)
%  Entradas: Tp, Ip (counts), curva, tmin, tmax
%  Saída: LUT em ms (inteira), com tmax até Ip
% ================================================================
clear; close all; clc;

%% --------- ENTRADAS DO USUÁRIO ---------------------------------
Tp_s    = 0.100;     % Time dial (segundos)
Ip      = 120;       % Pickup em contagens RMS (0..4095)
curva   = 'IEEE_MI';      % 'NI' | 'VI' | 'EI' | 'LTI'
tmin_ms = 1;        % limite inferior (ms)
tmax_ms = 30000;     % limite superior (ms)

%% --------- EIXO DE IRMS (12 bits) ------------------------------
Irms = 0:4095;                       % todos os valores possíveis (RMS, 12 bits)
M    = Irms ./ max(Ip,1);            % razão M = I/Ip (evita divisão por zero)

%% --------- PARÂMETROS DA CURVA IEC -----------------------------
switch upper(strtrim(curva))
    case 'NI'   % Inversa Normal
        K = 0.14;   alpha = 0.02; B = 0;
    case 'VI'   % Muito Inversa
        K = 13.5;   alpha = 1.00; B = 0;
    case 'EI'   % Extremamente Inversa
        K = 80.0;   alpha = 2.00; B = 0;
    case 'LTI'  % Inversa Longa
        K = 120.0;  alpha = 1.00; B = 0;
    case 'IEEE_MI'
        K = 0.0515; alpha = 0.02; B = 0.1140;
    otherwise
        error('Curva inválida. Use: ''NI'', ''VI'', ''EI'' ou ''LTI''.');
end

%% --------- CÁLCULO DO TEMPO -----------------------------------
% Apenas para M>1 aplicamos a expressão; abaixo/igual a Ip => 0 (sem atuação)
idx_act  = (M > 1);
denom    = (M(idx_act).^alpha) - 1.0;
t_s      = zeros(size(Irms));             % segundos (double)
t_s(idx_act) = ((K ./ denom) + B) * Tp_s;       % t = K/(M^alpha - 1) * Tp

% Limites práticos em ms e quantização simples (inteiro)
t_ms          = 1000 * t_s;               % ms (double)
t_ms_raw = t_ms;
t_ms(idx_act) = max(t_ms(idx_act), tmin_ms);
t_ms(idx_act) = min(t_ms(idx_act), tmax_ms);

% ---- LUT final: 0..4095 em milissegundos, zeros até Ip ----------
lut_ms = round(t_ms);                      % inteiro (pode ser uint32 se quiser)
lut_ms(~idx_act) = tmax_ms;                      % força tmax nas posições Irms <= Ip

%% --------- GRÁFICOS --------------------------------------------
% (1) Temporização em segundos para Irms/Ip > 1
figure('Name','Tempo (s) apenas para M>1');
semilogx(M(idx_act), t_s(idx_act), 'LineWidth', 1.6);
grid on; xlabel('M = I_{RMS} / I_p (adimensional, log)');
ylabel('Tempo de atuação t (s)');
title(sprintf('Curva %s | I_p=%d counts, T_p=%.3f s', upper(curva), Ip, Tp_s));

% (2) LUT completa (0..4095) em ms
figure('Name','LUT completa 0..4095');
plot(Irms, lut_ms/1000, 'LineWidth', 1.2);
hold on; xline(Ip, '--r', 'Pickup (Ip)', 'LabelVerticalAlignment','bottom');
grid on; xlim([0 4095]);
xlabel('I_{RMS} (counts)');
ylabel('Tempo (s)');
title(sprintf('LUT 0..4095 (ms) | zeros até Ip=%d | Curva %s', Ip, upper(curva)));

%% --------- (Opcional) Exibir alguns valores --------------------
fprintf('Exemplos:\n');
for val = 0:4095
    if val >= 0 && val <= 4095
        fprintf('Irms=%4d -> LUT=%5d ms\n', val, lut_ms(val+1));
    end
end


%% Geração de arquivo para inicializar RAM
% Supondo que o seu vetor é 'lut_ms' (1x2048 ou 2048x1), inteiro não-negativo
lut = uint32(lut_ms(:));                       % garante tipo inteiro
lut = min(lut, uint32(2^20-1));                % clamp em 20 bits

fid = fopen('lut46_ms.mem','w');
fprintf(fid, '%05X\n', lut);                   % 20 bits -> 5 hex por linha
fclose(fid);

lut = uint32(lut_ms(:));
fid = fopen('lut46_init.vhd','w');
fprintf(fid,'shared variable ram : memory_t := (\n');
for i = 1:numel(lut)
    fprintf(fid,'  %4d => std_logic_vector(to_unsigned(%u, 20)),\n', i-1, lut(i));
end
fprintf(fid,'  others => (others => ''0'')\n);\n');
fclose(fid);


%% Gerar coe

% Parâmetros
WIDTH = 20; 
DEPTH = 4096;

% vetor:
lut = uint32(lut_ms(:));              % garante tipo inteiro sem sinal
lut = mod(lut, 2^WIDTH);              % clamp/two's complement para WIDTH

% Ajusta tamanho: corta ou preenche com zero
if numel(lut) < DEPTH
    lut(end+1:DEPTH) = 0;
elseif numel(lut) > DEPTH
    lut = lut(1:DEPTH);
end

% Escreve COE em HEX com 5 dígitos (20 bits)
fid = fopen('lut46_ms.coe','w');
fprintf(fid,'memory_initialization_radix=16;\n');
fprintf(fid,'memory_initialization_vector=\n');
for i = 1:DEPTH
    sep = ','; if i==DEPTH, sep = ';'; end
    fprintf(fid, '%05X%s\n', lut(i), sep);
end
fclose(fid);
