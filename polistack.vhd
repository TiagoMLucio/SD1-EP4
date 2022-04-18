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

    component data_flow is 
        generic (
            addr_s : natural := 16; -- address size in bits
            word_s : natural := 32  -- word size in bits
        );
        port (
            clock, reset : in bit;
            -- Memory Interface
            memA_addr, memB_addr : out bit_vector(addr_s-1 downto 0);
                    memB_wrd  : out bit_vector(word_s-1 downto 0);
            memA_rdd, memB_rdd   : in bit_vector(word_s-1 downto 0);
            -- Control Unit Interface
            pc_en, ir_en, sp_en             : in bit;
            pc_src, mem_a_addr_src,
            mem_b_mem_src                   : in bit;
            mem_b_addr_src, mem_b_wrd_src,
            alu_a_src, alu_b_src            : in bit_vector(1 downto 0);
            alu_shfimm_src, alu_mem_src     : in bit;
            alu_op                          : in bit_vector(2 downto 0);
            instruction                     : out bit_vector(7 downto 0)
        );
    end component;

    component control_unit is
        port (
            clock, reset : in bit;
            pc_en, ir_en, sp_en,
            pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src,
            mem_we, mem_enable : out bit;
            mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src : out bit_vector (1 downto 0);
            alu_op : out bit_vector (2 downto 0);
            mem_busy : in bit;
            instruction : in bit_vector (7 downto 0);
            halted : out bit
        );
    end component;

    signal pc_en, ir_en, sp_en                                                  : bit;
    signal pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src   : bit;
    signal mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src                  : bit_vector(1 downto 0);
    signal alu_op                                                               : bit_vector(2 downto 0);
    signal instruction                                                          : bit_vector(7 downto 0);

begin

    dfm : data_flow generic map (addr_s, word_s)
                    port map (clock, reset, 
                            memA_addr, memB_addr, memB_wrd, memA_rdd, memB_rdd, 
                            pc_en, ir_en, sp_en, pc_src,
                            mem_a_addr_src, mem_b_mem_src, mem_b_addr_src, mem_b_wrd_src, 
                            alu_a_src, alu_b_src, alu_shfimm_src, alu_mem_src, alu_op, 
                            instruction);
    
    ucm : control_unit port map (clock, reset,
                                pc_en, ir_en, sp_en, pc_src,
                                mem_a_addr_src, mem_b_mem_src, 
                                alu_shfimm_src, alu_mem_src, 
                                mem_we, mem_enable,
                                mem_b_addr_src, mem_b_wrd_src, 
                                alu_a_src, alu_b_src, alu_op,
                                busy,
                                instruction, 
                                halted);

end architecture; -- arch

-------------------------------------------------------
--! @file dregister.vhdl
--! @brief Descrição de um register do tipo D
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-11-10
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity d_register is
    generic (
        width       : natural := 4;
        reset_value : natural := 0
    );
    port (
        clock, reset, load  : in bit;
        d                   : in bit_vector(width - 1 downto 0);
        q                   : out bit_vector(width - 1 downto 0)
    );
end entity d_register;


architecture arch of d_register is

begin
    procD: process(clock, reset, load)
    begin 
        if (reset = '1') then q <= bit_vector(to_unsigned(reset_value, width));     -- assíncrono
        elsif (load = '1' and rising_edge(clock)) then q <= d;                      -- borda de subida do clock
        end if ;
    end process procD;    

end arch ; -- arch

-------------------------------------------------------
--! @file alu.vhdl
--! @brief Descrição de uma ALU
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-11-09
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity alu is
    generic (
        size : natural := 8
    );
    port (
        A, B    : in bit_vector(size - 1 downto 0); -- inputs
        F       : out bit_vector(size - 1 downto 0); -- output
        S       : in bit_vector(2 downto 0); -- op selection
        Z       : out bit; -- zero flag
        Ov      : out bit; -- overflow flag
        Co      : out bit -- carry out
    );
end entity alu;

entity full_adder is
  port (
    A, B, Ci   : in bit;
    Co, S     : out bit
  );
end full_adder ;

architecture arch_fa of full_adder is

    begin

    Co <= (A and B) or (A and Ci) or (B and Ci);
    S <= A xor B xor Ci;

end architecture ; -- arch_fa

architecture arch of alu is

    component full_adder is
        port (
            A, B, Ci   : in bit;
            Co, S     : out bit
          );
    end component;

    signal Ainv, F_min, F_aux, F_s, B_aux, Z_aux   : bit_vector (size - 1 downto 0);
    signal Co_aux                                  : bit_vector (size downto 0);
    signal Ov_aux                                  : bit;                                               

begin

    -- Cálculo valores auxiliares

    Co_aux(0) <= S(2);

    auxF : for i in 0 to size - 1 generate
        Ainv(i) <= A(size - 1 - i);
        F_min(i) <= '0';

        with S select
            B_aux(i) <= not B(i) when "100",
                        B(i)     when others;
        
        fai: full_adder port map (A(i), B_aux(i), Co_aux(i), Co_aux(i + 1), F_s(i));

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

    -- Zero Flag
    Z_aux(0) <= not F_aux(0);
    Z <= Z_aux(size - 1);

    auxZ : for i in 1 to size - 1 generate
        Z_aux(i) <= Z_aux(i - 1) and  not (F_aux(i)); 
    end generate;
    -- Z

    -- Overflow Flag
    Ov <= Ov_aux and (A(size - 1) xor F_aux(size - 1)); -- A e F tem sinais diferentes

    with S select
        Ov_aux <= (A(size - 1) xnor B(size - 1)) when "001", -- A e B tem mesmo sinal e é uma soma
                 (A(size - 1) xor B(size - 1))  when "100", -- A e B tem sinais diferentes e é uma subtração
                 '0'                            when others;
    -- Ov

    -- Carry Out Flag
        Co <= Co_aux(size) when S = "100" or S = "001" else
              '0';
    -- Co

end arch ; -- arch

-------------------------------------------------------
--! @data_flow.vhdl
--! @brief Descrição de um Data Flow para o PoliStack
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-12-16
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity data_flow is
    generic (
        addr_s : natural := 16; -- address size in bits
        word_s : natural := 32  -- word size in bits
    );
    port (
        clock, reset : in bit;
        -- Memory Interface
        memA_addr, memB_addr : out bit_vector(addr_s-1 downto 0);
                   memB_wrd  : out bit_vector(word_s-1 downto 0);
        memA_rdd, memB_rdd   : in bit_vector(word_s-1 downto 0);
        -- Control Unit Interface
        pc_en, ir_en, sp_en             : in bit;
        pc_src, mem_a_addr_src,
        mem_b_mem_src                   : in bit;
        mem_b_addr_src, mem_b_wrd_src,
        alu_a_src, alu_b_src            : in bit_vector(1 downto 0);
        alu_shfimm_src, alu_mem_src     : in bit;
        alu_op                          : in bit_vector(2 downto 0);
        instruction                     : out bit_vector(7 downto 0)
        );
end entity; 

architecture arch of data_flow is

    component alu is
        generic (
            size : natural := 8
        );
        port (
            A, B    : in bit_vector(size - 1 downto 0); -- inputs
            F       : out bit_vector(size - 1 downto 0); -- output
            S       : in bit_vector(2 downto 0); -- op selection
            Z       : out bit; -- zero flag
            Ov      : out bit; -- overflow flag
            Co      : out bit -- carry out
        );
    end component;

    component d_register
        generic (
            width       : natural := 6;
            reset_value : natural := 0
        );
        port (
            clock, reset, load  : in bit;
            d                   : in bit_vector(width - 1 downto 0);
            q                   : out bit_vector(width - 1 downto 0)
        );
    end component;

    signal ir3, ir3_f, ir4, ir6, ir6_se     : bit_vector(word_s-1 downto 0);
    signal alu_o, alu_a, alu_b              : bit_vector(word_s-1 downto 0);
    signal d_pc                             : bit_vector(word_s-1 downto 0);
    signal pc, sp                           : bit_vector(word_s-1 downto 0);
    signal imm_shft, memb_mem, alu_mem      : bit_vector(word_s-1 downto 0);
    signal ir                               : bit_vector(7 downto 0);

begin

    alum : alu generic map (word_s)
                port map (alu_a, alu_b, alu_o, alu_op, open, open, open);

    pcm : d_register generic map (word_s, 0)
                    port map (clock, reset, pc_en, d_pc, pc);

    spm : d_register generic map (word_s, 131064)
                    port map (clock, reset, sp_en, alu_o, sp);

    irm : d_register generic map (8, 0)
                    port map (clock, reset, ir_en, memA_rdd(7 downto 0), ir);


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
            ir6_se(i) <= ir(7);
        end generate;
        
    end generate;
            
    aux_ir3 : for i in word_s-1 downto 0 generate
        ir3_1 : if (i <= 1) generate
            ir3_f(i) <= '0';
        end generate;
        ir3_2 : if (i > 1 and i <= 5) generate
            ir3_f(i) <= ir3(i-2);
        end generate;
        ir3_3 : if (i > 5) generate
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

end architecture; -- arch

-------------------------------------------------------
--! @control_unit.vhdl
--! @brief Descrição da Unidade de Controle do PoliStack
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-12-17
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity control_unit is
    port (
        clock, reset : in bit;
        pc_en, ir_en, sp_en,
        pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src,
        mem_we, mem_enable : out bit;
        mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src : out bit_vector (1 downto 0);
        alu_op : out bit_vector (2 downto 0);
        mem_busy : in bit;
        instruction : in bit_vector (7 downto 0);
        halted : out bit
        );
end entity; 

architecture arch of control_unit is
    type estado_t is (
                    fetch, 
                    decode, 
                    -- Execute (
                    break, 
                    pushsp, 
                    poppc, 
                    operation_2, -- ADD, AND, OR
                    load, 
                    operation_1, -- NOT, FLIP
                    store_1, 
                    store_2, 
                    addsp,
                    call, 
                    storesp, 
                    loadsp
                    -- )
    );

    signal PE, EA : estado_t;

    signal im_count : bit;

begin
    sincrono: process(clock, reset, PE)
    begin
        if (reset = '1') then
            EA <= fetch;
        elsif  (rising_edge(clock)) then
            EA <= PE;
        end if;
    end process sincrono;

    combinatorio: process

    procedure wait_mem(dowrite: boolean) is
        begin
            if dowrite then
                mem_we <= '1';
            end if;
            mem_enable <= '1';
            wait until mem_busy = '1';
            mem_we <= '0';
            wait until mem_busy = '0';
            mem_enable <= '0';
        end procedure wait_mem;

    
    begin
        pc_en <= '0';
        ir_en <= '0';
        sp_en <= '0';
        pc_src <= '0';
        mem_a_addr_src <= '0';
        mem_b_mem_src <= '0';
        alu_shfimm_src <= '0';
        alu_mem_src <= '0';
        mem_we <= '0';
        mem_enable <= '0';
        mem_b_addr_src <= "00";
        mem_b_wrd_src <= "00";
        alu_a_src <= "00";
        alu_b_src <= "00";
        alu_op <= "000";
        halted <= '0';
        case (EA) is
            when fetch =>
                mem_a_addr_src <= '1';

                wait_mem(false);

                ir_en <= '1';

                pc_en <= '1';
                pc_src <= '0';
                alu_a_src <= "00";
                alu_b_src <= "00";
                alu_shfimm_src <= '0'; -- constante 1
                alu_op <= "001"; -- adição

                PE <= decode;

            when decode =>
                if (instruction(7) = '0') then
                    im_count <= '0';
                    if (instruction(6 downto 5) = "00") then
                        if (instruction(4) = '0') then
                            case (instruction(3 downto 0)) is
                                when  "0000" => -- BREAK: Levanta o halt e trava o processador.
                                    PE <= break;
                                when  "0010" => -- PUSHSP: Empilha o conteúdo de SP.
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_shfimm_src <= '1'; -- constante 4
                                    alu_op <= "100"; -- subtração
                                    sp_en <= '1';  -- sp = sp - 4

                                    PE <= pushsp;
                                when  "0100" => -- POPPC: Desempilha para o PC.
                                    mem_a_addr_src <= '0';
                                    pc_en <= '1';
                                    pc_src <= '1';  -- pc=mem[sp]
                                    wait_mem(false);

                                    PE <= poppc;
                                when  "0101"|"0110"|"0111" =>  -- ADD, AND, OR: Empilha a soma/and/or do topo com o segundo elemento da pilha.
                                    mem_a_addr_src <= '0';
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_shfimm_src <= '1'; -- constante 4

                                    case instruction(2 downto 0) is
                                        when "101" => -- ADD
                                            alu_op <= "001";
                                        when "110" => -- AND
                                            alu_op <= "010";
                                        when "111" => -- OR
                                            alu_op <= "011";
                                        when others => 
                                    end case;

                                    sp_en <= '1';  -- sp = sp + 4
                                    mem_b_addr_src <= "01";

                                    wait_mem(false);

                                    PE <= operation_2;

                                when  "1000" => -- LOAD: Substitui o topo da pilha pelo conteúdo endereçado pelo topo.
                                    mem_a_addr_src <= '0';
                        
                                    wait_mem(false);

                                    PE <= load;

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
                                    
                                    wait_mem(false);

                                    PE <= operation_1;

                                when  "1011" => -- NOP: Não faz nada por um ciclo de clock
                                    PE <= fetch;

                                when  "1100" => -- STORE: Guarda o segundo elemento da pilha no endereço apontado pelo topo. Desempilha ambos.
                                    alu_a_src <= "01";
                                    alu_b_src <= "00";
                                    alu_shfimm_src <= '1'; -- constante 4
                                    alu_op <= "001"; -- adição
                                    mem_b_addr_src <= "10";

                                    mem_b_wrd_src <= "01";
                                    mem_b_mem_src <= '1';

                                    mem_a_addr_src <= '0';

                                    wait_mem(false);

                                    PE <= store_1;

                                when  "1101" => -- POPSP: Desempilha para o SP
                                    mem_a_addr_src <= '0';
                                    alu_a_src <= "10";
                                    alu_op <= "000"; -- copia A para a saída
                                    sp_en <= '1';

                                    wait_mem(false);

                                    PE <= fetch;

                                when others => 

                            end case;
                        else -- ADDSP: Soma o topo da pilha com o conteúdo no endereço calculado.
                            mem_a_addr_src <= '0';
                            mem_b_addr_src <= "10";
                            alu_a_src <= "01";
                            alu_b_src <= "11";

                            wait_mem(false);

                            PE <= addsp;

                        end if;
                    else -- 0_nnnnnnn
                        case instruction(6 downto 5) is
                            when "01" => -- CALL: Empilha o PC e o sobrescreve com ir[4:0]«5n, causando um salto.
                                alu_a_src <= "01";
                                alu_b_src <= "00";
                                alu_shfimm_src <= '1'; -- constante 4
                                alu_op <= "100"; -- subtração
                                sp_en <= '1';  -- sp = sp - 4

                                mem_b_addr_src <= "00";
                                mem_b_wrd_src <= "00";

                                PE <= call;

                            when "10" => -- STORESP: Desempilha e guarda o valor desempilhado no endereço calculado.
                                alu_a_src <= "01";
                                alu_b_src <= "11"; --  (not(ir[4])&ir[3:0]«2)
                                alu_op <= "001"; -- adição

                                mem_a_addr_src <= '0';
                                mem_b_wrd_src <= "01";
                                mem_b_mem_src <= '0';
                                
                                mem_b_addr_src <= "10";

                                wait_mem(false);

                                PE <= storesp;

                            when "11" => -- LOADSP: Busca o valor no endereço calculado e empilha.
                                alu_a_src <= "01";
                                alu_b_src <= "11"; --  (not(ir[4])&ir[3:0]«2)
                                alu_op <= "001"; -- adição

                                mem_b_addr_src <= "10";
                                mem_b_mem_src <= '1';
                                mem_b_wrd_src <= "01";

                                wait_mem(false);

                                PE <= storesp;
                            
                            when others =>
                        end case;
                    end if;
                else -- 1_nnnnnnn
                    if im_count = '0' then -- IM*
                        im_count <= '1';

                        alu_a_src <= "01";
                        alu_b_src <= "00";
                        alu_shfimm_src <= '1'; -- constante 4
                        alu_op <= "100"; -- subtração
                        sp_en <= '1';  -- sp = sp - 4

                        mem_b_addr_src <= "10";
                        mem_b_wrd_src <= "11"; -- signExt(ir[6:0])

                        wait_mem(true);

                        PE <= fetch;
                    else -- IM*
                        mem_a_addr_src <= '0';
                        alu_mem_src <= '0'; -- memA_rdd«7 | IR[6:0]
                        alu_b_src <= "01";
                        alu_op <= "111"; -- copia B para a saída
                        mem_b_wrd_src <= "00";
                        mem_b_addr_src <= "00";
                        
                        wait_mem(true);

                        PE <= fetch;
                    end if;
                end if;

            when break =>
                halted <= '1';

            when pushsp =>
                -- sp_en <= '0';

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
    
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";-- mem[sp-4] =  sp
                wait_mem(true);

                PE <= fetch;
            
            when poppc =>
                -- pc_en <= '0';
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4
                
                PE <= fetch;
            
            when operation_2 =>
                -- sp_en <= '0';
                alu_a_src <= "10";
                alu_b_src <= "01";
                alu_mem_src <= '1';
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";

                wait_mem(true);
                
                PE <= fetch;

            when load =>
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "01";
                mem_b_mem_src <= '0';

                wait_mem(true);

                PE <= fetch;

            when operation_1 =>
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00";

                wait_mem(true);

                PE <= fetch;
            
            when store_1 =>
                mem_b_addr_src <= "01";

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4

                wait_mem(true);
                
                PE <= store_2;
            
            when store_2 =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4

                PE <= fetch;
            
            when addsp =>
                alu_a_src <= "10"; -- mem[sp]
                alu_b_src <= "01"; -- mem[sp + ir[3:0]<<2]
                alu_mem_src <= '0';
                alu_op <= "001"; --adição

                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "10";

                wait_mem(true);

                PE <= fetch;
            
            when call =>
                alu_a_src <= "00";
                alu_op <= "000";
                
                wait_mem(true);

                alu_b_src <= "10"; -- ir[4:0]«5
                alu_op <= "111"; -- copia B para a saída
                pc_src <= '0';
                pc_en <= '1';

                PE <= fetch;

            when storesp =>
                wait_mem(true);

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "100"; -- subtração
                sp_en <= '1';  -- sp = sp - 4

                PE <= fetch;

            when loadsp =>
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "100"; -- subtração
                sp_en <= '1';  -- sp = sp - 4
                
                mem_b_addr_src <= "10";

                wait_mem(true);

                PE <= fetch;
            
            when others =>

        end case;

    end process combinatorio;

end architecture arch;