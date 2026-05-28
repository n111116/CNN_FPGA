%% 
N = 256;
t = [0:127,-128:-1];
y = exp(t/8);
gen_coe_txt_mif_float(y,32,N,'data\E_X.mif');
%% 16*n*exp，每256个数表示一个exp的结果，第n组就是16*n*exp的结果
N = 256 * 16;
t2 = [0:127,-128:-1];
n = 1:16;
y2 = exp(t2/8);
y3 = y2(:) * 16 * (n-1);
y3 = y3(:);
semilogy(y3(1:256))
gen_coe_txt_mif_float(y3,32,N,'data\E_X_16n.mif');
%% 生成sigmod
f_out = fopen("for_vh/detect_Cv3_conv2d_weights.txt","w");
N = 256;
t = [0:127,-128:-1];
y = 1./(1+exp(-t));
y_fix = fi(y, 0, 16, 15);

fprintf(y_out, "%s,", y_fix.hex);
% gen_coe_txt_mif_float(y,32,N,'data\E_X.mif');