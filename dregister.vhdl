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
        if (reset = '1') then q <= bit_vector(to_unsigned(reset_value, width));   -- assíncrono
        elsif (load = '1' and rising_edge(clock)) then q <= d;                                  -- borda de subida do clock
        end if ;
    end process procD;    

end arch ; -- arch
