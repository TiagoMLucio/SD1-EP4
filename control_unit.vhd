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

    combinatorio: process (mem_busy, instruction, EA)
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
                if (mem_busy = '0') then
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

end architecture arch;