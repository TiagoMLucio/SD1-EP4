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

architecture arch of control_unit 
    type estado_t is (fetch, decode, break, pushsp, poppc, operation, load);
    signal PE, EA : estado_t;

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
    sincrono: process(clock, reset, PE)
    begin
        if (reset = '1')
            EA <= fetch;
        elsif  (rising_edge(clock)) then
            EA <= PE;
    end process sincrono;

    combinatorio: process(EA)
    begin
        case (EA)
            when fetch =>
                pc_en <= '0';
                sp_en <= '0';
                ir_en <= '0';

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
                pc_en <= '0';
                sp_en <= '0';
                ir_en <= '0';
                if (instruction(7) = '0')
                    case (instruction) is
                        when  "00000000" => -- BREAK: Levanta o halt e trava o processador.
                            PE <= break;
                        when  "00000010" => -- PUSHSP: Empilha o conteúdo de SP.
                            alu_a_src <= "01";
                            alu_b_src <= "00";
                            alu_shfimm_src <= '1'; -- constante 4
                            alu_op <= "100"; -- subtração
                            sp_en <= '1';  -- sp = sp - 4

                            PE <= pushsp;
                        when  "00000100" => -- POPPC: Desempilha para o PC.
                            mem_a_addr_src <= '0';
                            pc_en <= '1';
                            pc_src <= '1';  -- pc=mem[sp]
                            wait_mem(false);



                            PE <= poppc;
                        when  "00000101"|"00000110"|"00000111" =>  -- ADD, AND, OR: Empilha a soma/and/or do topo com o segundo elemento da pilha.
                            mem_a_addr_src <= '0';
                            alu_a_src <= "01";
                            alu_b_src <= "00";
                            alu_shfimm_src <= '1'; -- constante 4
                            with instruction select alu_op <=
                                "001" when "00000101"; -- ADD
                                "010" when "00000110"; -- AND
                                "011" when "00000111"; -- OR
                            sp_en <= '1';  -- sp = sp + 4
                            mem_b_addr_src <= "01";

                            wait_men(false);

                            PE <= operation;

                        when  "00001000" => -- LOAD: Substitui o topo da pilha pelo conteúdo endereçado pelo topo.
                            mem_a_addr_src <= '0';
                
                            wait_men(false);

                            PE <= load;

                        when  "00001001" => -- NOT: Empilha o NOT do topo da pilha.
                            ;
                        when  "00001010" => ;
                        when  "00001011" => -- NOP: Não faz nada por um ciclo de clock
                            PE <= fetch;
                        when  "00001100" => ;
                        when  "00001101" => ;
                    end case;

                    if instruction(4) = '1' then
                        ;
                    elsif instruction(5) = '1' then
                        ;
                    elsif instruction(6 downto 5) = "10" then
                        ;
                    elsif instruction(6 downto 5) = "11" then
                        ;
                    end if;
                else
                    ;

            when break =>
                halted <= 1;

            when pushsp =>
                sp_en <= '0';

                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
    
                mem_b_addr_src <= "00";
                memB_wrd <= "00";-- mem[sp-4] =  sp
                wait_mem(true);

                PE <= fetch;
            
            when poppc =>
                pc_en <= '0';
                alu_a_src <= "01";
                alu_b_src <= "00";
                alu_shfimm_src <= '1'; -- constante 4
                alu_op <= "001"; -- adição
                sp_en <= '1';  -- sp = sp + 4
                
                PE <= fetch;
            
            when operation =>
                sp_en <= '0';
                alu_a_src <= "10";
                alu_b_src <= "01";
                alu_mem <= '1';
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "00

                wait_mem(true);
                
                PE <= fetch;

            when load =>
                mem_b_addr_src <= "00";
                mem_b_wrd_src <= "01";
                mem_b_mem_src <= '0';

                wait_mem(true);

                PE <= fetch;
            
        end case;

    end process combinatorio

end architecture arch;