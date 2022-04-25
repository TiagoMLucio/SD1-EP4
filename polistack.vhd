-------------------------------------------------------
--! @polistack.vhd
--! @brief Descrição do PoliStack
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2022-04-16
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity polistack is
    generic (
        addr_s : natural := 16; -- address size in bits
        word_s : natural := 32  -- word size in bits
    );
    port (
        clock, reset : in bit;
        halted : out bit;
        -- memory Interface
        mem_we, mem_enable   : out bit;
        memA_addr, memB_addr : out bit_vector(addr_s-1 downto 0);
                   memB_wrd  : out bit_vector(word_s-1 downto 0);
        memA_rdd, memB_rdd   : in  bit_vector(word_s-1 downto 0);
        busy                 : in  bit
        );
end entity; 

architecture allinone of polistack is

    signal pc_en, ir_en, sp_en                                                  : bit;
    signal pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src   : bit;
    signal mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src                  : bit_vector(1 downto 0);
    signal alu_op, S                                                            : bit_vector(2 downto 0);
    signal instruction                                                          : bit_vector(7 downto 0);

    type estado_t is (
            fetch, 
            fetch_wait,
            decode,
            wait_mem,
            -- Execute (
            break, 
            pushsp, 
            poppc, 
            operation_2, -- ADD, AND, OR
            operation_2_wait,
            load,
            load_wait,
            operation_1, -- NOT, FLIP
            store_1, 
            store_1_wait,
            store_2, 
            popsp,
            addsp,
            call, 
            call_wait,
            storesp, 
            storesp_wait,
            loadsp,
            loadsp_wait,
            im_wait,
            im2_wait
            -- )
        );

    signal PPE, PE, EA : estado_t;

    signal im_count : bit;

    signal teste : bit;

    signal ir3, ir3_f, ir4, ir6, ir6_se     : bit_vector(word_s-1 downto 0);
    signal A, B, F, alu_o, alu_a, alu_b       : bit_vector(word_s-1 downto 0);
    signal d_pc                             : bit_vector(word_s-1 downto 0);
    signal pc, sp                           : bit_vector(word_s-1 downto 0);
    signal imm_shft, memb_mem, alu_mem      : bit_vector(word_s-1 downto 0);
    signal ir                               : bit_vector(7 downto 0);

    signal Ainv, F_min, F_aux, F_s, B_aux, Z_aux   : bit_vector (word_s - 1 downto 0);
    signal Co_aux                                  : bit_vector (word_s downto 0);
    signal Ov_aux                                  : bit;   

begin

    pcm: process(clock, reset, pc_en)
    begin 
        if (reset = '1') then pc <= bit_vector(to_unsigned(0, word_s));     -- assíncrono
        elsif (pc_en = '1' and rising_edge(clock)) then pc <= d_pc;                      -- borda de subida do clock
        end if ;
    end process pcm;   

    spm: process(clock, reset, sp_en)
    begin 
        if (reset = '1') then sp <= bit_vector(to_unsigned(131064, word_s));     -- assíncrono
        elsif (sp_en = '1' and rising_edge(clock)) then sp <= alu_o;                      -- borda de subida do clock
        end if ;
    end process spm;   

    irm: process(clock, reset, ir_en)
    begin 
        if (reset = '1') then ir <= bit_vector(to_unsigned(0, 8));     -- assíncrono
        elsif (ir_en = '1' and rising_edge(clock)) then ir <= memA_rdd(7 downto 0);                      -- borda de subida do clock
        end if ;
    end process irm;   

    A <= alu_a;
    B <= alu_b;
    alu_o <= F;
    S <= alu_op;

        -- Cálculo valores auxiliares

        Co_aux(0) <= S(2);

        auxF : for i in 0 to word_s - 1 generate
            Ainv(i) <= A(word_s - 1 - i);
            F_min(i) <= '0';
    
            with S select
                B_aux(i) <= not B(i) when "100",
                            B(i)     when others;
            
            Co_aux(i + 1) <= (A(i) and B_aux(i)) or (A(i) and Co_aux(i)) or (B_aux(i) and Co_aux(i));
            F_s(i) <= A(i) xor B_aux(i) xor Co_aux(i);
            
        end generate;
        -- Cálculo valores auxiliares
    
        -- Sáida F
        with S select
            F_aux <= A   when "000", -- A
                 F_s     when "001", -- adição
                 A and B   when "010", -- and
                 A or B    when "011", -- or
                 F_s     when "100", -- subtração
                 not A    when "101", -- NOT A
                 Ainv    when "110", -- inverte A
                 B       when "111", -- B
                 F_min   when others;
    
        F <= F_aux;
        -- F

    aux_ir : for i in word_s-1 downto 0 generate

        ir_3i : if (i <= 3) generate
            ir3(i) <= ir(i);
        end generate;
        ir_3e : if (i > 3) generate
            ir3(i) <= '0';
        end generate;

        ir_4i : if (i <= 4) generate
            ir4(i) <= ir(i);
        end generate;
        ir_4e : if (i > 4) generate
            ir4(i) <= '0';
        end generate;

        ir_6i : if (i <= 6) generate
            ir6(i) <= ir(i);
            ir6_se(i) <= ir(i);
        end generate;
        ir_6e : if (i > 6) generate
            ir6(i) <= '0';
            ir6_se(i) <= ir(6);
        end generate;
        
    end generate;
            
    aux_ir3 : for i in word_s-1 downto 0 generate
        ir3_1 : if (i <= 1) generate
            ir3_f(i) <= '0';
        end generate;
        ir3_2 : if (i > 1 and i <= 5) generate
            ir3_f(i) <= ir3(i-2);
        end generate;
        ir3_3 : if (i = 6) generate
            ir3_f(i) <= not ir(4);
        end generate;
        ir3_4 : if (i > 6) generate
            ir3_f(i) <= '0';
        end generate;
    end generate;

    with pc_src select
        d_pc <= alu_o     when '0',
                memA_rdd  when '1';
    
    with mem_a_addr_src select
        memA_addr <= sp(addr_s-1 downto 0) when '0',
                     pc(addr_s-1 downto 0) when '1';  

    with mem_b_addr_src select
        memB_addr <= sp(addr_s-1 downto 0)          when "00",
                     memA_rdd(addr_s-1 downto 0)    when "01",
                     alu_o(addr_s-1 downto 0)       when others;

    with mem_b_wrd_src select
        memB_wrd <= alu_o       when "00",
                    memb_mem    when "01",
                    sp          when "10",
                    ir6_se      when "11";

    with mem_b_mem_src select
        memb_mem <= memA_rdd when '0',
                    memB_rdd when '1';

    with alu_a_src select
        alu_a <= pc         when "00",
                 sp         when "01",
                 memA_rdd   when others;
    
    with alu_b_src select
        alu_b <= imm_shft                                       when "00",
                 alu_mem                                        when "01",
                 ir4(word_s-6 downto 0) & "00000"               when "10",
                 ir3_f                                          when "11";

    with alu_shfimm_src select
        imm_shft <= bit_vector(to_unsigned(1, word_s)) when '0',
                    bit_vector(to_unsigned(4, word_s)) when '1';
    
    with alu_mem_src select
        alu_mem <= memA_rdd(word_s-8 downto 0) & "0000000" or ir6   when '0',
                   memB_rdd                                         when '1';

    instruction <= ir;

    sincrono: process(clock, reset, PE)
    begin
        if (teste = '1') then 
            teste <= '0';
        else teste <= '1';
        end if;

        if (reset = '1') then
            EA <= fetch;
        elsif  (rising_edge(clock)) then
            EA <= PE;
        end if;
    end process sincrono;

    combinatorio: process (busy, instruction, EA)
    begin
        sp_en <= '0';
        pc_en <= '0';
        ir_en <= '0';
        case (EA) is
            when fetch =>
                mem_a_addr_src <= '1';

                mem_enable <= '1';
                PPE <= fetch_wait;
                PE <= wait_mem;

            when wait_mem =>
                mem_we <= '0';
                if (busy = '0') then
                    mem_enable <= '0';
                    PE <= PPE;
                end if;

            when fetch_wait =>
                ir_en <= '1';

                pc_en <= '1';
                pc_src <= '0';
                alu_a_src <= "00";
                alu_b_src <= "00";
                alu_shfimm_src <= '0'; -- constante 1
                alu_op <= "001"; -- adição

                PE <= decode;

            when decode =>
                ir_en <= '0';
                pc_en <= '0';
                sp_en <= '0';
                if (instruction(7) = '0') then
                    im_count <= '0';
                    if (instruction(6 downto 5) = "00") then
                        if (instruction(4) = '0') then
                            case (instruction(3 downto 0)) is
                                when  "0000" => -- BREAK: Levanta o halt e trava o processador.
                                    PE <= break;
                                when  "0010" => -- PUSHSP: Empilha o conteúdo de SP.
                                    mem_enable <= '0';
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_shfimm_src <= '1'; -- constante 4
                                    alu_op <= "100"; -- subtração
                                    sp_en <= '1';  -- sp = sp - 4

                                    PE <= pushsp;
                                when  "0100" => -- POPPC: Desempilha para o PC.
                                    mem_a_addr_src <= '0';
                                    pc_src <= '1';  -- pc=mem[sp]
                                    mem_enable <= '1';
                                    PE <= wait_mem;
                                    PPE <= poppc;

                                when  "0101"|"0110"|"0111" =>  -- ADD, AND, OR: Empilha a soma/and/or do topo com o segundo elemento da pilha.
                                    mem_enable <= '0';
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_op <= "001"; -- adição
                                    alu_shfimm_src <= '1'; -- constante 4
                                    sp_en <= '1';  -- sp = sp + 4

                                    PE <= operation_2;

                                when  "1000" => -- LOAD: Substitui o topo da pilha pelo conteúdo endereçado pelo topo.
                                    mem_a_addr_src <= '0';
                        
                                    mem_enable <= '1';
                                    PE <= wait_mem;

                                    PPE <= load;

                                when  "1001"|"1010" => -- NOT/FLIP: Empilha o NOT/reverso do topo da pilha.
                                    mem_a_addr_src <= '0';
                                    alu_a_src <= "10";
                                    
                                    case instruction(1 downto 0) is
                                        when "01" => -- NOT
                                            alu_op <= "101";
                                        when "10" => -- FLIP
                                            alu_op <= "110";
                                        when others => 
                                    end case;
                                    
                                    mem_enable <= '1';
                                    PE <= wait_mem;

                                    PPE <= operation_1;

                                when  "1011" => -- NOP: Não faz nada por um ciclo de clock
                                    PE <= wait_mem;
                                    PPE <= fetch;

                                when  "1100" => -- STORE: Guarda o segundo elemento da pilha no endereço apontado pelo topo. Desempilha ambos.
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_shfimm_src <= '1'; -- constante 4
                                    alu_op <= "001"; -- adição
                                    mem_b_addr_src <= "10";

                                    mem_b_wrd_src <= "01";
                                    mem_b_mem_src <= '1';

                                    mem_a_addr_src <= '0';

                                    mem_enable <= '1';
                                    PE <= wait_mem;

                                    PPE <= store_1;

                                when  "1101" => -- POPSP: Desempilha para o SP
                                    mem_a_addr_src <= '0';
                                    alu_a_src <= "10";
                                    alu_op <= "000"; -- copia A para a saída

                                    mem_enable <= '1';
                                    PE <= wait_mem;

                                    PPE <= popsp;

                                when others => 

                            end case;
                        else -- ADDSP: Soma o topo da pilha com o conteúdo no endereço calculado.
                            mem_a_addr_src <= '0';
                            mem_b_addr_src <= "10";
                            alu_a_src <= "01";
                            alu_b_src <= "11"; -- ir[4:0] << 5
                            alu_op <= "001";

                            mem_enable <= '1';
                            PE <= wait_mem;

                            PPE <= addsp;

                        end if;
                    else -- 0_nnnnnnn != 000_nnnnn
                        case instruction(6 downto 5) is
                            when "01" => -- CALL: Empilha o PC e o sobrescreve com ir[4:0]«5n, causando um salto.
                                alu_a_src <= "01";
                                alu_b_src <= "00";
                                alu_shfimm_src <= '1'; -- constante 4
                                alu_op <= "100"; -- subtração
                                sp_en <= '1';  -- sp = sp - 4

                                mem_b_addr_src <= "00";
                                mem_b_wrd_src <= "00";

                                mem_enable <= '1';
                                PE <= wait_mem;
                                PPE <= call;

                            when "10" => -- STORESP: Desempilha e guarda o valor desempilhado no endereço calculado.
                                alu_a_src <= "01";
                                alu_b_src <= "11"; --  (not(ir[4])&ir[3:0]«2)
                                alu_op <= "001"; -- adição

                                mem_a_addr_src <= '0';
                                mem_b_wrd_src <= "01";
                                mem_b_mem_src <= '0';
                                
                                mem_b_addr_src <= "10";

                                mem_enable <= '1';
                                PE <= wait_mem;

                                PPE <= storesp;

                            when "11" => -- LOADSP: Busca o valor no endereço calculado e empilha.
                                alu_a_src <= "01";
                                alu_b_src <= "11"; --  (not(ir[4])&ir[3:0]«2)
                                alu_op <= "001"; -- adição

                                mem_b_addr_src <= "10";

                                mem_enable <= '1';
                                mem_we <= '0';
                                PE <= wait_mem;

                                PPE <= loadsp;
                            
                            when others =>
                        end case;
                    end if;
                else -- 1_nnnnnnn
                    if im_count = '0' then -- IM*
                        alu_a_src <= "01";
                        alu_b_src <= "00";
                        alu_shfimm_src <= '1'; -- constante 4
                        alu_op <= "100"; -- subtração

                        mem_b_addr_src <= "10";
                        mem_b_wrd_src <= "11"; -- signExt(ir[6:0])
                        
                        mem_enable <= '1';
                        mem_we <= '1';
                        PE <= wait_mem;
                        
                        PPE <= im_wait;
                        
                    else -- IM*
                        mem_a_addr_src <= '0';
                        alu_mem_src <= '0'; -- memA_rdd«7 | IR[6:0]
                        alu_b_src <= "01";
                        alu_op <= "111"; -- copia B para a saída
                        mem_b_wrd_src <= "00";
                        mem_b_addr_src <= "00";

                        mem_enable <= '1';
                        PE <= wait_mem;
                        
                        PPE <= im2_wait;

                    end if;
                end if;

            when break =>
                halted <= '1';

            when pushsp =>
                sp_en <= '0';

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
    
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";-- mem[sp-4] =  sp
                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;

                PPE <= fetch;
            
            when poppc =>
                pc_en <= '1';
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4
                
                PE <= fetch;
            
            when operation_2 =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "100"; -- subtração

                mem_a_addr_src <= '0'; -- sp + 4
                mem_b_addr_src <= "10"; -- sp

                mem_enable <= '1';
                PE <= wait_mem;

                PPE <= operation_2_wait;

            when operation_2_wait =>

                case instruction(2 downto 0) is
                    when "101" => -- ADD
                        alu_op <= "001";
                    when "110" => -- AND
                        alu_op <= "010";
                    when "111" => -- OR
                        alu_op <= "011";
                    when others => 
                end case;

                alu_a_src <= "10";
                alu_b_src <= "01";
                alu_mem_src <= '1';
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";

                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;
                
                PPE <= fetch;

            when load =>
                mem_b_addr_src <= "01";

                mem_enable <= '1';
                PE <= wait_mem;

                PPE <= load_wait;
                
            when load_wait =>
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "01";
                mem_b_mem_src <= '1';

                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;

                PPE <= fetch;

            when operation_1 =>
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";

                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;

                PPE <= fetch;
            
            when store_1 =>
                mem_b_addr_src <= "01";

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4
                
                PE <= store_1_wait;

            
            when store_1_wait =>
                sp_en <= '0';
                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;
                
                PPE <= store_2;
            
            when store_2 =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4

                PE <= fetch;
            
            when popsp =>
                sp_en <= '1';
                PE <= fetch;
            when addsp =>
                alu_a_src <= "10"; -- mem[sp]
                alu_b_src <= "01"; -- mem[sp + ir[3:0]<<2]
                alu_mem_src <= '1';
                alu_op <= "001"; --adição

                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";

                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;

                PPE <= fetch;
            
            when call =>
                sp_en <= '0';
                alu_a_src <= "00";
                alu_op <= "000";
                
                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;

                PPE <= call_wait;
            
            when call_wait =>

                alu_b_src <= "10"; -- ir[4:0]«5
                alu_op <= "111"; -- copia B para a saída
                pc_src <= '0';
                pc_en <= '1';

                PE <= fetch;

            when storesp =>
                mem_enable <= '1';
                mem_we <= '1';
                PE <= wait_mem;
                
                PPE <= storesp_wait;

            when storesp_wait =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4

                PE <= fetch;

            when loadsp =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "100"; -- subtração
                
                mem_b_addr_src <= "10";
                mem_b_mem_src <= '1';
                mem_b_wrd_src <= "01";
                
                PE <= loadsp_wait;
            
            when loadsp_wait =>
                sp_en <= '1';  -- sp = sp - 4
                mem_enable <= '1';
                mem_we <= '1';

                PE <= wait_mem;

                PPE <= fetch;
            
            when im_wait =>
                sp_en <= '1';
                im_count <= '1';
                
                PE <= fetch;
            
            when im2_wait =>
                mem_enable <= '1';
                mem_we <= '1';

                PE <= wait_mem;

                PPE <= fetch;

            when others =>

        end case;

    end process combinatorio;

end architecture; -- arch