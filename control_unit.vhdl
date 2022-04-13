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

begin
    my_proc: process  (instruction)
        variable im_count: integer := 0;
    begin
        if instruction(7) = '1' then
            im_count := im_count + 1;
            if im_count = 0 then
                ;
            else
                ;
        else
            im_count := 0; 
                 
            case (instruction) is
                when  "00000000" => halt <= '1';
                when  "00000010" => ;
                when  "00000100" => ;
                when  "00000101" => ;
                when  "00000110" => ;
                when  "00000111" => ;
                when  "00001000" => ;
                when  "00001001" => ;
                when  "00001010" => ;
                when  "00001011" => ;
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
        end if;

    end process my_proc;



end architecture; -- arch