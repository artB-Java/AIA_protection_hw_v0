%% ================================================================
%  CURVA 47 / VUF (IEEE C37.112): Geração de LUT (2048 entradas)
%  Endereço : VUF em cinquentavos de porcento (0 = 0.00%, 2047 = 102.35%)
%             Resolução: 0.05% por passo → compatível com blk_mem_gen_0 (11 bits)
%  Dado     : Tempo de operação em ms (20 bits, uint32)
%  Saída    : lut_47.coe  (Xilinx Block Memory Generator – mesmo formato da 51)
%             lut_47.mem  (formato $readmemh)
% ================================================================
clear; close all; clc;

%% --------- ENTRADAS DO USUÁRIO ---------------------------------
TD          = 0.5;      % Time Dial (segundos)
Pickup_VUF  = 5.0;      % Pickup em % (ex: 5.0 = 5%)
tmin_ms     = 10;       % Limite inferior de tempo (ms)
tmax_ms     = 30000;    % Limite superior / valor para M <= 1 (ms)

% Constantes IEEE C37.112 - Moderadamente Inversa
A = 0.0515;
B = 0.1140;
p = 0.02;

%% --------- EIXO DE VUF (11 bits, resolução 0.05%) --------------
DEPTH   = 2048;                         % 2^11 entradas — igual ao blk_mem_gen_0 da função 51
WIDTH   = 20;                           % bits por palavra
STEP    = 0.05;                         % resolução em % por endereço

idx_vec  = (0 : DEPTH-1);              % índices 0..2047
VUF_vec  = idx_vec * STEP;             % VUF em % (0.00% .. 102.35%)
M        = VUF_vec / max(Pickup_VUF, 0.001); % M = VUF / Pickup (evita /0)

%% --------- CÁLCULO DO TEMPO ------------------------------------
idx_act  = (M > 1);
denom    = (M(idx_act).^p) - 1.0;
t_s      = zeros(1, DEPTH);
t_s(idx_act) = TD * (A ./ denom + B);  % T = TD*(A/(M^p-1) + B)

t_ms           = t_s * 1000;
t_ms(idx_act)  = max(t_ms(idx_act), tmin_ms);
t_ms(idx_act)  = min(t_ms(idx_act), tmax_ms);
t_ms(~idx_act) = tmax_ms;              % abaixo do pickup → tmax

%% --------- QUANTIZAÇÃO -----------------------------------------
lut = uint32(round(t_ms));
lut = min(lut, uint32(2^WIDTH - 1));   % clamp em 20 bits

%% --------- ARQUIVO .MEM (formato $readmemh) --------------------
fid = fopen('lut_47.mem', 'w');
fprintf(fid, '%05X\n', lut);
fclose(fid);
fprintf('Arquivo lut_47.mem gerado (%d entradas x %d bits, passo=%.2f%%).\n', DEPTH, WIDTH, STEP);

%% --------- ARQUIVO .COE (Xilinx Block Memory Generator) --------
fid = fopen('lut_47.coe', 'w');
fprintf(fid, 'memory_initialization_radix=16;\n');
fprintf(fid, 'memory_initialization_vector=\n');
for i = 1:DEPTH
    sep = ',';
    if i == DEPTH, sep = ';'; end
    fprintf(fid, '%05X%s\n', lut(i), sep);
end
fclose(fid);
fprintf('Arquivo lut_47.coe gerado — carregar na porta B do blk_mem_gen_0 existente.\n');

%% --------- RELATÓRIO -------------------------------------------
fprintf('\n--- Pickup = %.1f%% | TD = %.2f s | Resolução = %.2f%% ---\n', ...
    Pickup_VUF, TD, STEP);
fprintf('%-12s %-8s %-10s %-15s\n', 'VUF (%)', 'Endereço', 'M', 'Tempo (ms)');
for vuf_ex = [Pickup_VUF*1.05, Pickup_VUF*1.1, Pickup_VUF*1.5, ...
              Pickup_VUF*2, Pickup_VUF*5, Pickup_VUF*10]
    addr = round(vuf_ex / STEP);
    if addr >= 1 && addr <= DEPTH
        fprintf('%-12.2f %-8d %-10.3f %-15d\n', ...
            vuf_ex, addr, vuf_ex/Pickup_VUF, lut(addr+1));
    end
end

%% --------- GRÁFICOS --------------------------------------------
figure('Name', 'LUT 47 - Curva de Temporização');
VUF_plot = VUF_vec(idx_act);
T_plot   = t_ms(idx_act);
semilogx(VUF_plot / Pickup_VUF, T_plot / 1000, 'b-', 'LineWidth', 2);
grid on;
xlabel('M = VUF / Pickup_{VUF} (adimensional, log)');
ylabel('Tempo de operação (s)');
title(sprintf('Função 47 | Pickup=%.1f%% | TD=%.2f s | Resolução=%.2f%% | 2048 entradas', ...
    Pickup_VUF, TD, STEP));
xline(1, '--r', 'Pickup', 'LabelVerticalAlignment', 'bottom');

figure('Name', 'LUT Completa (0..2047 endereços)');
plot(VUF_vec, double(lut) / 1000, 'LineWidth', 1.5);
grid on;
xlabel(sprintf('VUF (%%) — Endereço × %.2f', STEP));
ylabel('Tempo (s)');
title('LUT 47 completa — valores armazenados na BRAM (2048 × 20b)');
xline(Pickup_VUF, '--r', sprintf('Pickup = %.1f%%', Pickup_VUF), ...
    'LabelVerticalAlignment', 'bottom');