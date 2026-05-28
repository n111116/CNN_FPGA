% 权重生成脚本
load("detect_Cv3_conv2d.mat")
f_out = fopen("for_vh/detect_Cv3_conv2d_weights.txt","w");
weights = [weights; -32 * ones(24,64)];
% weights = ones(64,64);
[outW,inW,rowW,colW] = size(weights);
NUM_PE_PAGE = 1;
NUM_PE_COL = 4;
NUM_PE_ROW = 1;
OUTPUT_CHANNEL_PER_COL = outW/NUM_PE_COL;
INPUT_CHANNEL_PER_PAGE = inW/NUM_PE_PAGE;

fprintf(f_out,"'{");
for col = 1:NUM_PE_COL
    fprintf(f_out,"'{");
    for row = 1:NUM_PE_ROW
        fprintf(f_out,"'{");
        for input_channel = 1:INPUT_CHANNEL_PER_PAGE
            for output_channel = 1:OUTPUT_CHANNEL_PER_COL
                fprintf(f_out,"{");
                for page = 1:NUM_PE_PAGE
                    fprintf(f_out,"9'h%s",dec2hex(weights( ...
                        (output_channel-1)*NUM_PE_COL+col, ...
                        (input_channel-1)*NUM_PE_PAGE+page),3));
                    if(page ~= NUM_PE_PAGE)
                        fprintf(f_out,",");
                    end
                end
                fprintf(f_out,"}");
                if(input_channel ~= (INPUT_CHANNEL_PER_PAGE) || (output_channel ~= OUTPUT_CHANNEL_PER_COL))
                    fprintf(f_out,",");
                end
            end
        end
        fprintf(f_out,"}");
        if(row ~= NUM_PE_ROW)
            fprintf(f_out,",");
        end
    end
    fprintf(f_out,"}");
    if(col ~= NUM_PE_COL)
        fprintf(f_out,",");
        % fprintf(f_out,"/\n");
    end
end
fprintf(f_out,"}");
fprintf(f_out,"\n");
fclose(f_out);