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