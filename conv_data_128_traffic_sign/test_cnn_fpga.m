input_11 = ones(128,128)*51;
input_22 = ones(128,128)*34;
input_33 = ones(128,128)*17;
out_p1 = conv2(input_11,  reshape(weights(1,1,3:-1:1,3:-1:1),[3,3]),"same");
out_p2 = conv2(input_22,  reshape(weights(1,2,3:-1:1,3:-1:1),[3,3]),"same");
out_p3 = conv2(input_33,  reshape(weights(1,3,3:-1:1,3:-1:1),[3,3]),"same");
out_co1 = out_p1 + out_p2 + out_p3;
%% 
out_c1 = (channel1) ./ 2^6;
out_c2 = (channel2) ./ 2^6;
out_c3 = (channel3) ./ 2^6;
out_c4 = (channel4) ./ 2^6;
out_c5 = (channel5) ./ 2^6;
out_c6 = (channel6) ./ 2^6;
out_c7 = (channel7) ./ 2^6;
out_c8 = (channel8) ./ 2^6;
out_c9 = (channel9) ./ 2^6;
out_c10 = (channel10) ./ 2^6;
out_c11 = (channel11) ./ 2^6;
out_c12 = (channel12) ./ 2^6;
out_c13 = (channel13) ./ 2^6;
out_c14 = (channel14) ./ 2^6;
out_c15 = (channel15) ./ 2^6;
out_c16 = (channel16) ./ 2^6;
%% 
re_w = reshape(weights(1,1,3:-1:1,3:-1:1),[3,3]);
re_i = reshape(quant_input(1,:,:),[64,64]);
re_i(1:5,1:5)
ans_temp = conv2(re_i,re_w,"same");
%% 
% 初始化空矩阵用于存储合并后的数据
merged = [];

% 循环遍历 channel1 到 channel64
for i = 1:64
    % 动态获取变量名
    varName = ['channel', num2str(i)];
    
    % 使用 eval 获取变量值
    ch = eval(varName);
    
    % 将当前 channel 添加到合并矩阵中（按列拼接）
    merged = cat(3,merged,ch);
end
result = [];
c_in_max = 32;
c_in = [1:c_in_max, 32+(1:c_in_max)];
for c_out = 1:64
    for i = 1:8
        for j = 1:8
            result(c_out,i,j) = sum(squeeze(weights(c_out,c_in,1,1))' .* squeeze(merged(i,j,c_in)));
            result(c_out,i,j) = result(c_out,i,j) + bias(c_out);
        end
    end
end
%% 
result_int16 = int16(result);

% === 写入带符号的十六进制文件 ===
[C_OUT, H, W] = size(result_int16);
fid = fopen('output_test2.hex', 'w');
if fid == -1
    error('无法创建 output_test.hex 文件');
end

for i = 1:H
    for j = 1:W
        for c = 1:C_OUT
            val = double(result_int16(c, i, j));  % 转为双精度以便判断符号
            
            if val >= 0
                hex_str = sprintf('%04x', val);
            else
                hex_str = sprintf('-%04x', -val);  % 输出如 -0x01A3
            end
            
            fprintf(fid, '%s\n', hex_str);
        end
    end
end

fclose(fid);
disp('数据已成功写入 output_test2.hex（带符号十六进制格式）');